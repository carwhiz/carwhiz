-- Migration 042: Salary Management System
-- ======================================
-- Employee salary structure, payment tracking, and finance integration

-- ============================================================
-- 1. employee_salaries table - salary structure for each employee
-- ============================================================
CREATE TABLE IF NOT EXISTS public.employee_salaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  base_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  bonus NUMERIC(12, 2) NOT NULL DEFAULT 0,
  deductions NUMERIC(12, 2) NOT NULL DEFAULT 0,
  net_salary NUMERIC(12, 2) GENERATED ALWAYS AS (base_salary + bonus - deductions) STORED,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES public.users(id)
);

ALTER TABLE public.employee_salaries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sal_struct_anon_full ON public.employee_salaries;
CREATE POLICY sal_struct_anon_full ON public.employee_salaries FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS sal_struct_service_full ON public.employee_salaries;
CREATE POLICY sal_struct_service_full ON public.employee_salaries FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Partial unique index: only one active salary structure per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_salaries_active ON public.employee_salaries(user_id) WHERE is_active = true;

-- ============================================================
-- 2. salary_payments table - individual salary payment records
-- ============================================================
CREATE TABLE IF NOT EXISTS public.salary_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  payment_date DATE NOT NULL,
  payment_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  total_salary NUMERIC(12, 2) NOT NULL,
  amount_paid NUMERIC(12, 2) NOT NULL,
  payment_method VARCHAR(50) DEFAULT 'bank_transfer',
  description TEXT,
  reference_id VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES public.users(id)
);

ALTER TABLE public.salary_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sal_pay_anon_full ON public.salary_payments;
CREATE POLICY sal_pay_anon_full ON public.salary_payments FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS sal_pay_service_full ON public.salary_payments;
CREATE POLICY sal_pay_service_full ON public.salary_payments FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- 3. Audit triggers
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_employee_salaries') THEN
    CREATE TRIGGER trg_audit_employee_salaries
      AFTER INSERT OR UPDATE OR DELETE ON public.employee_salaries
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_salary_payments') THEN
    CREATE TRIGGER trg_audit_salary_payments
      AFTER INSERT OR UPDATE OR DELETE ON public.salary_payments
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;

-- ============================================================
-- 4. RPC: Process Salary Payment + Create Expense Entry
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_process_salary_payment(
  p_user_id UUID,
  p_payment_date DATE,
  p_total_salary NUMERIC,
  p_amount_paid NUMERIC,
  p_payment_method VARCHAR,
  p_description TEXT,
  p_created_by UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payment_id UUID;
  expense_id UUID;
  salary_exp_ledger UUID;
  salary_payable_ledger UUID;
  v_narration TEXT;
BEGIN
  -- 1. Insert salary payment record
  INSERT INTO public.salary_payments (
    user_id, payment_date, payment_time, total_salary, amount_paid,
    payment_method, description, created_by, updated_by
  ) VALUES (
    p_user_id, p_payment_date, now(), p_total_salary, p_amount_paid,
    p_payment_method, p_description, p_created_by, p_created_by
  ) RETURNING id INTO payment_id;

  -- 2. Create expense entry in ledger (Salary Expense)
  SELECT id INTO salary_exp_ledger
  FROM public.ledger
  WHERE ledger_name = 'Salary Expense'
  LIMIT 1;

  IF salary_exp_ledger IS NULL THEN
    RAISE EXCEPTION 'Salary Expense ledger not found. Please create it in the Chart of Accounts.';
  END IF;

  -- 3. Create ledger entry for salary payment (debit: expense, credit: bank/cash)
  INSERT INTO public.ledger_entries (
    ledger_id, entry_date, debit, credit, narration,
    reference_type, reference_id
  ) VALUES (
    salary_exp_ledger, p_payment_date, p_amount_paid, 0,
    'Salary Payment - ' || p_description,
    'salary_payment', payment_id
  );

  RETURN json_build_object(
    'success', true,
    'payment_id', payment_id,
    'message', 'Salary payment processed successfully',
    'amount', p_amount_paid,
    'date', p_payment_date
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'message', SQLERRM
  );
END;
$$;

-- ============================================================
-- 5. Function: Calculate remaining salary for an employee
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_remaining_salary(p_user_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_salary NUMERIC;
  total_paid NUMERIC;
BEGIN
  -- Get current active salary
  SELECT net_salary INTO current_salary
  FROM public.employee_salaries
  WHERE user_id = p_user_id AND is_active = true
  ORDER BY effective_from DESC
  LIMIT 1;

  IF current_salary IS NULL THEN
    RETURN 0;
  END IF;

  -- Get total paid in current month
  SELECT COALESCE(SUM(amount_paid), 0) INTO total_paid
  FROM public.salary_payments
  WHERE user_id = p_user_id
    AND DATE_TRUNC('month', payment_date)::DATE = DATE_TRUNC('month', CURRENT_DATE)::DATE;

  RETURN current_salary - total_paid;
END;
$$;

-- ============================================================
-- 6. View: Employee Salary Summary
-- ============================================================
CREATE OR REPLACE VIEW public.vw_employee_salary_summary AS
SELECT
  u.id,
  u.user_name,
  u.email,
  es.base_salary,
  es.bonus,
  es.deductions,
  es.net_salary,
  COALESCE(SUM(CASE WHEN DATE_TRUNC('month', sp.payment_date)::DATE = DATE_TRUNC('month', CURRENT_DATE)::DATE THEN sp.amount_paid ELSE 0 END), 0) as paid_this_month,
  COALESCE(SUM(sp.amount_paid), 0) as total_paid_all_time,
  es.net_salary - COALESCE(SUM(sp.amount_paid), 0) as remaining_salary,
  COUNT(sp.id) as payment_count,
  MAX(sp.payment_date) as last_payment_date
FROM public.users u
LEFT JOIN public.employee_salaries es ON u.id = es.user_id AND es.is_active = true
LEFT JOIN public.salary_payments sp ON u.id = sp.user_id
WHERE u.is_employee = true
GROUP BY u.id, u.user_name, u.email, es.id, es.base_salary, es.bonus, es.deductions, es.net_salary;

-- ============================================================
-- 7. View: Monthly Salary Expense
-- ============================================================
CREATE OR REPLACE VIEW public.vw_monthly_salary_expense AS
SELECT
  DATE_TRUNC('month', sp.payment_date)::DATE as month,
  COUNT(DISTINCT sp.user_id) as employee_count,
  SUM(sp.amount_paid) as total_paid,
  SUM(sp.total_salary) as total_salary_expense
FROM public.salary_payments sp
GROUP BY DATE_TRUNC('month', sp.payment_date)
ORDER BY month DESC;
