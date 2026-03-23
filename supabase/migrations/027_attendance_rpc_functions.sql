-- Migration 027: Add RPC function for fetching attendance records
-- =================================================================
-- Allow users to fetch their attendance records with proper service_role access

-- 1. Create function to get attendance records for a user on a specific date
CREATE OR REPLACE FUNCTION public.fn_get_attendance_by_date(
  p_user_id UUID DEFAULT NULL,
  p_date DATE DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  date DATE,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  punch_order INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If called by user, only return their own records
  -- If called by service_role, return requested user's records
  IF auth.role() = 'service_role' THEN
    RETURN QUERY
    SELECT a.id, a.user_id, a.date, a.check_in, a.check_out, a.punch_order
    FROM public.attendance a
    WHERE (p_user_id IS NULL OR a.user_id = p_user_id)
      AND (p_date IS NULL OR a.date = p_date)
    ORDER BY a.punch_order ASC;
  ELSE
    -- Regular authenticated user can only see their own records
    RETURN QUERY
    SELECT a.id, a.user_id, a.date, a.check_in, a.check_out, a.punch_order
    FROM public.attendance a
    WHERE a.user_id = auth.uid()
      AND (p_date IS NULL OR a.date = p_date)
    ORDER BY a.punch_order ASC;
  END IF;
END;
$$;

-- 2. Grant execute permission to authenticated users and anon
GRANT EXECUTE ON FUNCTION public.fn_get_attendance_by_date TO authenticated, anon;

-- 3. Add another function to get attendance summary for the day
CREATE OR REPLACE FUNCTION public.fn_get_attendance_summary(
  p_date DATE DEFAULT NULL
)
RETURNS TABLE (
  total_punches INT,
  total_hours TEXT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  p_user_id UUID;
  punch_count INT;
  worked_minutes INT;
  worked_hours INT;
  worked_mins INT;
  status_text TEXT;
  open_punch RECORD;
BEGIN
  p_user_id := auth.uid();
  
  IF p_user_id IS NULL THEN
    RETURN NEXT (0, '0h 0m', 'Not authenticated');
    RETURN;
  END IF;
  
  p_date := COALESCE(p_date, CURRENT_DATE);
  
  -- Count punches
  SELECT COUNT(*) INTO punch_count
  FROM public.attendance
  WHERE user_id = p_user_id AND date = p_date;
  
  -- Calculate total worked minutes from all completed punches
  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (check_out - check_in))::INT / 60), 0) INTO worked_minutes
  FROM public.attendance
  WHERE user_id = p_user_id AND date = p_date AND check_in IS NOT NULL AND check_out IS NOT NULL;
  
  -- For open punch (if any), include time up to now
  SELECT INTO open_punch
  FROM public.attendance
  WHERE user_id = p_user_id AND date = p_date AND check_in IS NOT NULL AND check_out IS NULL
  ORDER BY punch_order DESC
  LIMIT 1;
  
  IF open_punch IS NOT NULL THEN
    worked_minutes := worked_minutes + (EXTRACT(EPOCH FROM (NOW() - open_punch.check_in))::INT / 60);
    status_text := 'Checked In';
  ELSE
    IF punch_count > 0 THEN
      status_text := 'Checked Out';
    ELSE
      status_text := 'Not Started';
    END IF;
  END IF;
  
  worked_hours := worked_minutes / 60;
  worked_mins := worked_minutes % 60;
  
  RETURN NEXT (punch_count, worked_hours || 'h ' || worked_mins || 'm', status_text);
END;
$$;

-- 4. Grant execute permission
GRANT EXECUTE ON FUNCTION public.fn_get_attendance_summary TO authenticated, anon;
