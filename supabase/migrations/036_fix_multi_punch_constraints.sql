-- Migration 036: Fix Multi-Punch Attendance Constraints
-- =======================================================
-- Issue: UNIQUE(user_id, date) constraint from migration 019 prevents multiple punches per day
-- Solution: Drop the constraint and ensure multi-punch setup is correct

-- 1. Find and drop UNIQUE constraint if it exists
DO $$ 
DECLARE
  v_constraint_name TEXT;
BEGIN
  SELECT tc.constraint_name INTO v_constraint_name
  FROM information_schema.table_constraints tc
  WHERE tc.table_name = 'attendance' 
    AND tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
  LIMIT 1;
  
  IF v_constraint_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.attendance DROP CONSTRAINT ' || quote_ident(v_constraint_name);
  END IF;
END $$;

-- 2. Ensure punch_order column exists
ALTER TABLE public.attendance 
ADD COLUMN IF NOT EXISTS punch_order INT DEFAULT 1;

-- 3. Create an index on (user_id, date, punch_order) for efficient lookup
DROP INDEX IF EXISTS idx_attendance_user_date_order;
CREATE INDEX idx_attendance_user_date_order 
ON public.attendance(user_id, date, punch_order);

-- 4. Drop old function signatures and recreate
DROP FUNCTION IF EXISTS public.fn_attendance_punch(text, uuid, text);
DROP FUNCTION IF EXISTS public.fn_attendance_punch(text, uuid);

CREATE OR REPLACE FUNCTION public.fn_attendance_punch(
  p_token TEXT,
  p_user_id UUID,
  p_action TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  time_slot BIGINT;
  secret TEXT := 'CARWHIZZ_HR_2026_SECRET';
  valid_token TEXT;
  prev_token TEXT;
  today DATE := CURRENT_DATE;
  open_punch RECORD;
  punch_cnt INT;
BEGIN
  -- Validate token
  time_slot := EXTRACT(EPOCH FROM now())::BIGINT / 10;
  valid_token := md5(time_slot::TEXT || secret);
  prev_token := md5((time_slot - 1)::TEXT || secret);

  IF p_token != valid_token AND p_token != prev_token THEN
    RETURN json_build_object('success', false, 'message', 'Invalid or expired QR code. Please scan again.');
  END IF;

  -- Find any open punch (check_in exists but no check_out) for today
  SELECT * INTO open_punch FROM public.attendance
  WHERE user_id = p_user_id AND date = today AND check_in IS NOT NULL AND check_out IS NULL
  ORDER BY punch_order DESC
  LIMIT 1;

  -- Count existing punches today
  SELECT COALESCE(MAX(punch_order), 0) INTO punch_cnt
  FROM public.attendance
  WHERE user_id = p_user_id AND date = today;

  IF p_action = 'check_in' THEN
    IF open_punch IS NOT NULL THEN
      RETURN json_build_object('success', false, 'message', 'You are already checked in. Please check out first.');
    END IF;
    INSERT INTO public.attendance (user_id, date, check_in, punch_order, created_by)
    VALUES (p_user_id, today, now(), punch_cnt + 1, p_user_id);
    RETURN json_build_object('success', true, 'action', 'check_in', 'message', 'Checked in successfully! (Punch #' || (punch_cnt + 1) || ')');

  ELSIF p_action = 'check_out' THEN
    IF open_punch IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'You must check in first before checking out.');
    END IF;
    UPDATE public.attendance
    SET check_out = now(), updated_by = p_user_id, updated_at = now()
    WHERE id = open_punch.id;
    RETURN json_build_object('success', true, 'action', 'check_out', 'message', 'Checked out successfully! (Punch #' || open_punch.punch_order || ')');

  ELSE
    -- Legacy auto-decide: if open punch exists → check out, else → check in
    IF open_punch IS NOT NULL THEN
      UPDATE public.attendance
      SET check_out = now(), updated_by = p_user_id, updated_at = now()
      WHERE id = open_punch.id;
      RETURN json_build_object('success', true, 'action', 'check_out', 'message', 'Checked out successfully!');
    ELSE
      INSERT INTO public.attendance (user_id, date, check_in, punch_order, created_by)
      VALUES (p_user_id, today, now(), punch_cnt + 1, p_user_id);
      RETURN json_build_object('success', true, 'action', 'check_in', 'message', 'Checked in successfully!');
    END IF;
  END IF;
END;
$$;
