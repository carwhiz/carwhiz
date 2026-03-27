-- Salary Management RPC Functions
-- All operations batched server-side to avoid request limits

-- Drop old functions if they exist
DROP FUNCTION IF EXISTS public.fn_get_salary_data(DATE, DATE);
DROP FUNCTION IF EXISTS public.fn_book_salary(UUID, DATE, DATE, JSONB, UUID);
DROP FUNCTION IF EXISTS public.fn_get_payment_methods();
DROP FUNCTION IF EXISTS public.fn_get_salary_status(UUID, DATE, DATE);
DROP FUNCTION IF EXISTS public.fn_pay_salary(UUID, UUID, JSONB, UUID);
DROP FUNCTION IF EXISTS public.fn_save_booked_amount(UUID, DATE, NUMERIC, UUID);
DROP FUNCTION IF EXISTS public.fn_get_salary_summary(DATE, DATE);

-- 1. Get all salary calculation data for date range - returns multiple result sets
CREATE OR REPLACE FUNCTION public.fn_get_salary_data(
  p_date_from DATE,
  p_date_to DATE
)
RETURNS TABLE (
  result_type TEXT,
  data JSONB
) AS $$
BEGIN
  -- Return all employees with their basic salary - use COALESCE to return empty array if no data
  RETURN QUERY
  SELECT 'employees'::TEXT, COALESCE(jsonb_agg(row_to_json(t.*)), '[]'::JSONB)
  FROM (
    SELECT u.employee_id AS id, u.id AS user_id, u.user_name, u.email, u.basic_salary
    FROM public.users u
    WHERE u.is_employee = true
  ) t;

  -- Return attendance (join with users to get both user_id and employee_id) - use COALESCE to return empty array if no data
  RETURN QUERY
  SELECT 'attendance'::TEXT, COALESCE(jsonb_agg(row_to_json(t.*)), '[]'::JSONB)
  FROM (
    SELECT 
      a.id,
      a.user_id,
      u.employee_id,
      a.date,
      a.check_in,
      a.check_out
    FROM public.attendance a
    JOIN public.users u ON u.id = a.user_id
    WHERE a.date BETWEEN p_date_from AND p_date_to
  ) t;

  -- Return special shifts - use COALESCE to return empty array if no data
  RETURN QUERY
  SELECT 'special_shifts'::TEXT, COALESCE(jsonb_agg(row_to_json(t.*)), '[]'::JSONB)
  FROM (
    SELECT 
      u.employee_id,
      ss.shift_date,
      ss.start_time,
      ss.end_time,
      ss.start_buffer,
      ss.end_buffer,
      ss.overlaps_next_day
    FROM public.special_shifts ss
    JOIN public.users u ON u.id = ss.employee_id
    WHERE ss.shift_date BETWEEN p_date_from AND p_date_to
  ) t;

  -- Return shifts (regular shifts with employee_id) - use COALESCE to return empty array if no data
  RETURN QUERY
  SELECT 'shifts'::TEXT, COALESCE(jsonb_agg(row_to_json(t.*)), '[]'::JSONB)
  FROM (
    SELECT 
      u.employee_id,
      s.start_time,
      s.end_time,
      s.start_buffer,
      s.end_buffer,
      s.working_hours,
      s.overlaps_next_day
    FROM public.shifts s
    JOIN public.users u ON u.id = s.employee_id
  ) t;

  -- Return leaves - use COALESCE to return empty array if no data
  RETURN QUERY
  SELECT 'leaves'::TEXT, COALESCE(jsonb_agg(row_to_json(t.*)), '[]'::JSONB)
  FROM (
    SELECT 
      u.employee_id,
      ol.leave_type,
      ol.leave_date,
      ol.weekday,
      ol.title
    FROM public.official_leaves ol
    JOIN public.users u ON u.id = ol.employee_id
  ) t;
END;
$$ LANGUAGE plpgsql STABLE;

-- 2. Book salary for date range - 3-step flow: (1) Expense→Payable, (2) Payable→Employee, (3) cleared on payment
CREATE OR REPLACE FUNCTION public.fn_book_salary(
  p_employee_id UUID,
  p_date_from DATE,
  p_date_to DATE,
  p_details JSONB,
  p_created_by UUID
)
RETURNS TABLE (
  inserted_count INT,
  updated_count INT
) AS $$
DECLARE
  v_inserted_count INT := 0;
  v_updated_count INT := 0;
  v_detail JSONB;
  v_date DATE;
  v_booked_amt NUMERIC;
  v_existing_id UUID;
  v_salary_expense_id UUID;
  v_salary_payable_id UUID;
  v_employee_ledger_id UUID;
BEGIN
  -- Find general ledgers
  SELECT id INTO v_salary_expense_id FROM public.ledger 
  WHERE ledger_name = 'Salary Expense' LIMIT 1;
  
  SELECT id INTO v_salary_payable_id FROM public.ledger 
  WHERE ledger_name = 'Salary Payable' AND reference_id IS NULL LIMIT 1;
  
  -- Find employee's personal ledger
  SELECT id INTO v_employee_ledger_id FROM public.ledger 
  WHERE reference_id = p_employee_id AND reference_type = 'employee'
  LIMIT 1;
  
  IF v_salary_expense_id IS NULL THEN
    RAISE EXCEPTION 'ERROR: Salary Expense ledger not found';
  END IF;
  IF v_salary_payable_id IS NULL THEN
    RAISE EXCEPTION 'ERROR: General Salary Payable ledger not found (need ledger_name="Salary Payable" with reference_id IS NULL)';
  END IF;
  IF v_employee_ledger_id IS NULL THEN
    RAISE EXCEPTION 'ERROR: Employee ledger not found for employee %. Check ledger with reference_type=employee and reference_id=%', p_employee_id, p_employee_id;
  END IF;

  -- Process each day in the details array
  FOR v_detail IN SELECT jsonb_array_elements(p_details)
  LOOP
    v_date := (v_detail->>'date')::DATE;
    v_booked_amt := (v_detail->>'bookedAmount')::NUMERIC;

    -- Check if already booked for this date (check employee ledger entries)
    SELECT id INTO v_existing_id FROM public.ledger_entries
    WHERE reference_id = p_employee_id 
      AND reference_type = 'salary_day'
      AND entry_date = v_date
      AND ledger_id = v_employee_ledger_id
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      -- Update existing employee ledger entry
      UPDATE public.ledger_entries
      SET credit = v_booked_amt
      WHERE id = v_existing_id;
      v_updated_count := v_updated_count + 1;
    ELSE
      -- STEP 1: Book to general liability
      -- Debit: Salary Expense A/c
      INSERT INTO public.ledger_entries (ledger_id, entry_date, debit, credit, narration, reference_id, reference_type, created_by)
      VALUES (v_salary_expense_id, v_date, v_booked_amt, 0, 'Salary expense - general', p_employee_id, 'salary_booking', p_created_by);
      
      -- Credit: Salary Payable A/c (general)
      INSERT INTO public.ledger_entries (ledger_id, entry_date, debit, credit, narration, reference_id, reference_type, created_by)
      VALUES (v_salary_payable_id, v_date, 0, v_booked_amt, 'Salary liability - general', p_employee_id, 'salary_booking', p_created_by);

      -- STEP 2: Allocate from general payable to employee
      -- Debit: Salary Payable A/c (general) - reducing it
      INSERT INTO public.ledger_entries (ledger_id, entry_date, debit, credit, narration, reference_id, reference_type, created_by)
      VALUES (v_salary_payable_id, v_date, v_booked_amt, 0, 'Salary allocated to employee', p_employee_id, 'salary_allocation', p_created_by);
      
      -- Credit: Employee A/c (individual) - what they're owed
      INSERT INTO public.ledger_entries (ledger_id, entry_date, debit, credit, narration, reference_id, reference_type, created_by)
      VALUES (v_employee_ledger_id, v_date, 0, v_booked_amt, 'Salary booked - allocated', p_employee_id, 'salary_day', p_created_by);

      v_inserted_count := v_inserted_count + 1;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_inserted_count, v_updated_count;
END;
$$ LANGUAGE plpgsql;

-- 3. Get payment methods with available balances
CREATE OR REPLACE FUNCTION public.fn_get_payment_methods()
RETURNS TABLE (
  id UUID,
  ledger_name TEXT,
  available_balance NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.id,
    l.ledger_name,
    COALESCE(l.opening_balance, 0) + 
    COALESCE(SUM(le.debit - le.credit), 0) as available_balance
  FROM public.ledger l
  LEFT JOIN public.ledger_entries le ON le.ledger_id = l.id
  LEFT JOIN public.ledger_types lt ON lt.id = l.ledger_type_id
  WHERE (lt.name IN ('Cash', 'Bank') OR l.ledger_name IN ('Cash in Hand', 'Petty Cash', 'Primary Bank Account', 'Secondary Bank Account', 'UPI / Digital Wallet'))
    AND l.status = 'active'
  GROUP BY l.id, l.ledger_name, l.opening_balance
  ORDER BY l.ledger_name;
END;
$$ LANGUAGE plpgsql STABLE;

-- 4. Get booked and paid amounts for employee
CREATE OR REPLACE FUNCTION public.fn_get_salary_status(
  p_employee_id UUID,
  p_date_from DATE,
  p_date_to DATE
)
RETURNS TABLE (
  date DATE,
  booked_amount NUMERIC,
  paid_amount NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH booked AS (
    SELECT 
      le.entry_date as date,
      SUM(le.credit) as amount
    FROM public.ledger_entries le
    JOIN public.ledger l ON l.id = le.ledger_id
    WHERE le.reference_id = p_employee_id 
      AND le.reference_type = 'salary_day'
      AND l.reference_type = 'employee'
      AND l.reference_id = p_employee_id
      AND le.entry_date BETWEEN p_date_from AND p_date_to
    GROUP BY le.entry_date
  ),
  paid AS (
    SELECT
      le.entry_date as date,
      SUM(le.debit) as amount
    FROM public.ledger_entries le
    JOIN public.ledger l ON l.id = le.ledger_id
    WHERE le.reference_id = p_employee_id 
      AND le.reference_type = 'salary_payment'
      AND l.reference_type = 'employee'
      AND l.reference_id = p_employee_id
      AND le.entry_date BETWEEN p_date_from AND p_date_to
    GROUP BY le.entry_date
  )
  SELECT
    COALESCE(booked.date, paid.date),
    COALESCE(booked.amount, 0),
    COALESCE(paid.amount, 0)
  FROM booked
  FULL OUTER JOIN paid ON booked.date = paid.date
  ORDER BY COALESCE(booked.date, paid.date);
END;
$$ LANGUAGE plpgsql STABLE;

-- 5. Pay salary for employee (per-day) - Clears employee ledger when payment made
CREATE OR REPLACE FUNCTION public.fn_pay_salary(
  p_employee_id UUID,
  p_payment_ledger_id UUID,
  p_payments JSONB,
  p_created_by UUID
)
RETURNS TABLE (
  payment_count INT
) AS $$
DECLARE
  v_payment_count INT := 0;
  v_payment JSONB;
  v_date DATE;
  v_amount NUMERIC;
  v_employee_ledger_id UUID;
BEGIN
  -- Find employee's personal ledger
  SELECT id INTO v_employee_ledger_id FROM public.ledger
  WHERE reference_id = p_employee_id AND reference_type = 'employee'
  LIMIT 1;

  IF v_employee_ledger_id IS NULL THEN
    RAISE EXCEPTION 'Employee ledger not found for employee %', p_employee_id;
  END IF;

  -- Process each payment
  FOR v_payment IN SELECT jsonb_array_elements(p_payments)
  LOOP
    v_date := (v_payment->>'date')::DATE;
    v_amount := (v_payment->>'payAmount')::NUMERIC;

    IF v_amount > 0 THEN
      -- STEP 3: Clear employee liability with payment
      -- Debit: Employee A/c (liability reduces)
      INSERT INTO public.ledger_entries (ledger_id, entry_date, debit, credit, narration, reference_id, reference_type, created_by)
      VALUES (v_employee_ledger_id, v_date, v_amount, 0, 'Salary payment - employee cleared', p_employee_id, 'salary_payment', p_created_by);

      -- Credit: Payment method (Bank/Cash outflow)
      INSERT INTO public.ledger_entries (ledger_id, entry_date, debit, credit, narration, reference_id, reference_type, created_by)
      VALUES (p_payment_ledger_id, v_date, 0, v_amount, 'Salary payment disbursed', p_employee_id, 'salary_payment', p_created_by);

      v_payment_count := v_payment_count + 1;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_payment_count;
END;
$$ LANGUAGE plpgsql;

-- 6. Save edited booked amount - updates all 4 ledger entries per day
CREATE OR REPLACE FUNCTION public.fn_save_booked_amount(
  p_employee_id UUID,
  p_date DATE,
  p_new_amount NUMERIC,
  p_created_by UUID
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) AS $$
DECLARE
  v_salary_expense_id UUID;
  v_salary_payable_id UUID;
  v_employee_ledger_id UUID;
  v_old_amount NUMERIC;
BEGIN
  -- Get ledgers
  SELECT id INTO v_salary_expense_id FROM public.ledger 
  WHERE ledger_name = 'Salary Expense' LIMIT 1;
  
  SELECT id INTO v_salary_payable_id FROM public.ledger 
  WHERE ledger_name = 'Salary Payable' AND reference_id IS NULL LIMIT 1;
  
  SELECT id INTO v_employee_ledger_id FROM public.ledger
  WHERE reference_id = p_employee_id AND reference_type = 'employee' LIMIT 1;

  IF v_salary_expense_id IS NULL OR v_salary_payable_id IS NULL OR v_employee_ledger_id IS NULL THEN
    RETURN QUERY SELECT false, 'Required ledgers not found'::TEXT;
    RETURN;
  END IF;

  -- Get old amount for comparison
  SELECT COALESCE(credit, 0) INTO v_old_amount FROM public.ledger_entries
  WHERE reference_id = p_employee_id 
    AND reference_type = 'salary_day'
    AND entry_date = p_date
    AND ledger_id = v_employee_ledger_id
  LIMIT 1;

  -- Update Salary Expense entry (debit)
  UPDATE public.ledger_entries
  SET debit = p_new_amount, credit = 0
  WHERE reference_id = p_employee_id 
    AND reference_type = 'salary_booking'
    AND entry_date = p_date
    AND ledger_id = v_salary_expense_id;

  -- Update general Salary Payable credit entry
  UPDATE public.ledger_entries
  SET debit = 0, credit = p_new_amount
  WHERE reference_id = p_employee_id 
    AND reference_type = 'salary_booking'
    AND entry_date = p_date
    AND ledger_id = v_salary_payable_id;

  -- Update general Salary Payable debit entry (allocation)
  UPDATE public.ledger_entries
  SET debit = p_new_amount, credit = 0
  WHERE reference_id = p_employee_id 
    AND reference_type = 'salary_allocation'
    AND entry_date = p_date
    AND ledger_id = v_salary_payable_id;

  -- Update employee ledger credit entry
  UPDATE public.ledger_entries
  SET debit = 0, credit = p_new_amount
  WHERE reference_id = p_employee_id 
    AND reference_type = 'salary_day'
    AND entry_date = p_date
    AND ledger_id = v_employee_ledger_id;

  RETURN QUERY SELECT true, 'Booked amount updated successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- 7. Get booked and paid summary for all employees in date range
CREATE OR REPLACE FUNCTION public.fn_get_salary_summary(
  p_date_from DATE,
  p_date_to DATE
)
RETURNS TABLE (
  employee_id UUID,
  total_booked NUMERIC,
  total_paid NUMERIC,
  ledger_balance NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH booked_sum AS (
    SELECT 
      le.reference_id,
      SUM(le.credit) as amount
    FROM public.ledger_entries le
    JOIN public.ledger l ON l.id = le.ledger_id
    WHERE le.reference_type = 'salary_day'
      AND l.reference_type = 'employee'
      AND le.entry_date BETWEEN p_date_from AND p_date_to
    GROUP BY le.reference_id
  ),
  paid_sum AS (
    SELECT
      le.reference_id,
      SUM(le.debit) as amount
    FROM public.ledger_entries le
    JOIN public.ledger l ON l.id = le.ledger_id
    WHERE le.reference_type = 'salary_payment'
      AND l.reference_type = 'employee'
      AND le.entry_date BETWEEN p_date_from AND p_date_to
    GROUP BY le.reference_id
  ),
  -- Actual employee ledger balance (all entries, not just date-filtered)
  emp_ledger AS (
    SELECT
      l.reference_id,
      COALESCE(l.opening_balance, 0) + COALESCE(SUM(le.credit - le.debit), 0) as balance
    FROM public.ledger l
    LEFT JOIN public.ledger_entries le ON le.ledger_id = l.id
    WHERE l.reference_type = 'employee'
    GROUP BY l.reference_id, l.opening_balance
  )
  SELECT
    COALESCE(booked_sum.reference_id, paid_sum.reference_id, emp_ledger.reference_id),
    COALESCE(booked_sum.amount, 0),
    COALESCE(paid_sum.amount, 0),
    COALESCE(emp_ledger.balance, 0)
  FROM booked_sum
  FULL OUTER JOIN paid_sum ON booked_sum.reference_id = paid_sum.reference_id
  FULL OUTER JOIN emp_ledger ON COALESCE(booked_sum.reference_id, paid_sum.reference_id) = emp_ledger.reference_id;
END;
$$ LANGUAGE plpgsql STABLE;
