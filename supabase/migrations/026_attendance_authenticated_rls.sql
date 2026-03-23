-- Migration 026: Add authenticated user RLS policy for attendance table
-- ======================================================================
-- Allow authenticated users to read their own attendance records
-- and allow service_role to modify them (for RPC functions)

-- 1. Add policy for authenticated users to read their own records
DROP POLICY IF EXISTS att_authenticated_select ON public.attendance;
CREATE POLICY att_authenticated_select ON public.attendance
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- 2. Add policy for authenticated users to insert/update their own records
DROP POLICY IF EXISTS att_authenticated_modify ON public.attendance;
CREATE POLICY att_authenticated_modify ON public.attendance
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid() OR auth.role() = 'service_role')
  WITH CHECK (user_id = auth.uid() OR auth.role() = 'service_role');

-- 3. Ensure service_role still has full access
DROP POLICY IF EXISTS att_service_full ON public.attendance;
CREATE POLICY att_service_full ON public.attendance
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
