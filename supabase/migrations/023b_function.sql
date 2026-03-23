DROP FUNCTION IF EXISTS public.fn_get_users();
CREATE OR REPLACE FUNCTION public.fn_get_users()
RETURNS TABLE (id UUID, email TEXT, phone_number TEXT, role TEXT, created_at TIMESTAMPTZ)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT u.id, u.email, u.phone_number, u.role, u.created_at FROM public.users u ORDER BY u.email ASC;
$$;
