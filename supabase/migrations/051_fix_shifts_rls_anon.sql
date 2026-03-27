-- Fix shifts RLS policies to match custom auth system (anon/service_role full access)

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Anyone can view shifts" ON public.shifts;
DROP POLICY IF EXISTS "Authenticated users can create shifts" ON public.shifts;
DROP POLICY IF EXISTS "Users can update own shifts or admins can update any" ON public.shifts;
DROP POLICY IF EXISTS "Users can delete own shifts or admins can delete any" ON public.shifts;

-- Full grant for anon
CREATE POLICY "anon_full_access" ON public.shifts
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- Full grant for service_role
CREATE POLICY "service_role_full_access" ON public.shifts
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Grant full DML to anon (was SELECT only)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shifts TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shifts TO service_role;
