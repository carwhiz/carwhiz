-- Migration 019: HR Attendance System
-- ====================================
-- QR-based attendance: Desktop shows rotating QR code,
-- employees scan from mobile to check-in / check-out.
-- Token is validated server-side via RPC.

-- ============================================================
-- 1. attendance table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES public.users(id),
  UNIQUE(user_id, date)
);

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS att_anon_full ON public.attendance;
CREATE POLICY att_anon_full ON public.attendance FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS att_service_full ON public.attendance;
CREATE POLICY att_service_full ON public.attendance FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- 2. Audit trigger
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_attendance') THEN
    CREATE TRIGGER trg_audit_attendance
      AFTER INSERT OR UPDATE OR DELETE ON public.attendance
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;

-- ============================================================
-- 3. QR token generation & validation RPCs
-- ============================================================

-- Generate a token: md5 of a time-slot key + secret
-- Token changes every 10 seconds (time_slot = epoch / 10)
CREATE OR REPLACE FUNCTION public.fn_generate_attendance_token()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  time_slot BIGINT;
  secret TEXT := 'CARWHIZZ_HR_2026_SECRET';
BEGIN
  time_slot := EXTRACT(EPOCH FROM now())::BIGINT / 10;
  RETURN md5(time_slot::TEXT || secret);
END;
$$;

-- Validate token and punch attendance (check-in or check-out)
CREATE OR REPLACE FUNCTION public.fn_attendance_punch(
  p_token TEXT,
  p_user_id UUID
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
  existing RECORD;
BEGIN
  -- Validate token: accept current slot or previous slot (±10s tolerance)
  time_slot := EXTRACT(EPOCH FROM now())::BIGINT / 10;
  valid_token := md5(time_slot::TEXT || secret);
  prev_token := md5((time_slot - 1)::TEXT || secret);

  IF p_token != valid_token AND p_token != prev_token THEN
    RETURN json_build_object('success', false, 'message', 'Invalid or expired QR code. Please scan again.');
  END IF;

  -- Check if attendance record exists for today
  SELECT * INTO existing FROM public.attendance
  WHERE user_id = p_user_id AND date = today;

  IF existing IS NULL THEN
    -- First scan today → Check In
    INSERT INTO public.attendance (user_id, date, check_in, created_by)
    VALUES (p_user_id, today, now(), p_user_id);
    RETURN json_build_object('success', true, 'action', 'check_in', 'message', 'Checked in successfully!');
  ELSIF existing.check_out IS NULL THEN
    -- Second scan today → Check Out
    UPDATE public.attendance
    SET check_out = now(), updated_by = p_user_id, updated_at = now()
    WHERE id = existing.id;
    RETURN json_build_object('success', true, 'action', 'check_out', 'message', 'Checked out successfully!');
  ELSE
    RETURN json_build_object('success', false, 'message', 'Already checked in and out for today.');
  END IF;
END;
$$;
