-- Migration 029: Attendance RPC Functions V2
-- ============================================

-- Function to get all attendance records for current user for a specific date
CREATE OR REPLACE FUNCTION public.fn_get_user_attendance(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  id UUID,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  punch_order INT,
  date DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id,
    a.check_in,
    a.check_out,
    COALESCE(a.punch_order, 1)::int,
    DATE(a.check_in AT TIME ZONE 'Asia/Kolkata')
  FROM public.attendance a
  WHERE a.user_id = auth.uid()
    AND DATE(a.check_in AT TIME ZONE 'Asia/Kolkata') = p_date
  ORDER BY COALESCE(a.punch_order, 1) ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.fn_get_user_attendance TO authenticated, anon;

-- Function to get attendance summary for the month
CREATE OR REPLACE FUNCTION public.fn_get_attendance_summary(
  p_year INT DEFAULT EXTRACT(YEAR FROM now())::int,
  p_month INT DEFAULT EXTRACT(MONTH FROM now())::int
)
RETURNS TABLE (
  date DATE,
  check_in_count INT,
  total_hours NUMERIC,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    DATE(a.check_in AT TIME ZONE 'Asia/Kolkata') as date,
    COUNT(a.id)::int,
    SUM(
      EXTRACT(EPOCH FROM (COALESCE(a.check_out, now()) - a.check_in)) / 3600
    )::numeric,
    CASE 
      WHEN COUNT(a.id) > 0 AND a.check_out IS NULL THEN 'Checked In'
      WHEN COUNT(a.id) > 0 THEN 'Present'
      ELSE 'Absent'
    END
  FROM public.attendance a
  WHERE a.user_id = auth.uid()
    AND EXTRACT(YEAR FROM a.check_in AT TIME ZONE 'Asia/Kolkata') = p_year
    AND EXTRACT(MONTH FROM a.check_in AT TIME ZONE 'Asia/Kolkata') = p_month
  GROUP BY DATE(a.check_in AT TIME ZONE 'Asia/Kolkata'), a.check_out
  ORDER BY date DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.fn_get_attendance_summary TO authenticated, anon;
