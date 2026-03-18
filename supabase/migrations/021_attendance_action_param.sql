-- Migration 021: Add action parameter to attendance punch RPC
-- ==========================================================
-- Allows user to choose check-in or check-out instead of auto-deciding

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

  IF p_action = 'check_in' THEN
    IF existing IS NOT NULL AND existing.check_in IS NOT NULL THEN
      -- Already checked in, update the check-in time
      UPDATE public.attendance
      SET check_in = now(), check_out = NULL, updated_by = p_user_id, updated_at = now()
      WHERE id = existing.id;
      RETURN json_build_object('success', true, 'action', 'check_in', 'message', 'Checked in again (reset)!');
    ELSE
      INSERT INTO public.attendance (user_id, date, check_in, created_by)
      VALUES (p_user_id, today, now(), p_user_id);
      RETURN json_build_object('success', true, 'action', 'check_in', 'message', 'Checked in successfully!');
    END IF;

  ELSIF p_action = 'check_out' THEN
    IF existing IS NULL OR existing.check_in IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'You must check in first before checking out.');
    ELSE
      UPDATE public.attendance
      SET check_out = now(), updated_by = p_user_id, updated_at = now()
      WHERE id = existing.id;
      RETURN json_build_object('success', true, 'action', 'check_out', 'message', 'Checked out successfully!');
    END IF;

  ELSE
    -- No action specified (legacy): auto-decide
    IF existing IS NULL THEN
      INSERT INTO public.attendance (user_id, date, check_in, created_by)
      VALUES (p_user_id, today, now(), p_user_id);
      RETURN json_build_object('success', true, 'action', 'check_in', 'message', 'Checked in successfully!');
    ELSIF existing.check_out IS NULL THEN
      UPDATE public.attendance
      SET check_out = now(), updated_by = p_user_id, updated_at = now()
      WHERE id = existing.id;
      RETURN json_build_object('success', true, 'action', 'check_out', 'message', 'Checked out successfully!');
    ELSE
      RETURN json_build_object('success', false, 'message', 'Already checked in and out for today.');
    END IF;
  END IF;
END;
$$;
