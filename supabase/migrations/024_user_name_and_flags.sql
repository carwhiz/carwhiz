-- Migration 024: Add user_name, is_employee, is_partner to users table
-- ====================================================================
-- Extends users table with name and flags for employee/partner roles.
-- Updates register_user RPC to accept the new fields.

-- 1. Add new columns
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_name TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_employee BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_partner BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES public.employees(id);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- 2. Update register_user function to accept new fields
DROP FUNCTION IF EXISTS public.register_user(text, text, text, text);
DROP FUNCTION IF EXISTS public.register_user(text, text, text, text, text, boolean, boolean);

CREATE OR REPLACE FUNCTION public.register_user(
  p_email TEXT,
  p_phone_number TEXT,
  p_password TEXT,
  p_role TEXT DEFAULT 'user',
  p_user_name TEXT DEFAULT NULL,
  p_is_employee BOOLEAN DEFAULT false,
  p_is_partner BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_user public.users;
  existing_user public.users;
BEGIN
  SELECT * INTO existing_user FROM public.users WHERE email = p_email;
  IF existing_user IS NOT NULL THEN
    RETURN json_build_object('error', 'Email already registered');
  END IF;

  INSERT INTO public.users (email, phone_number, password_hash, role, user_name, is_employee, is_partner)
  VALUES (p_email, p_phone_number, crypt(p_password, gen_salt('bf')), p_role, p_user_name, p_is_employee, p_is_partner)
  RETURNING * INTO new_user;

  RETURN json_build_object(
    'id', new_user.id,
    'email', new_user.email,
    'phone_number', new_user.phone_number,
    'role', new_user.role,
    'user_name', new_user.user_name,
    'is_employee', new_user.is_employee,
    'is_partner', new_user.is_partner,
    'created_at', new_user.created_at
  );
END;
$$;

-- 3. Update fn_get_users to return new columns
DROP FUNCTION IF EXISTS public.fn_get_users();
CREATE OR REPLACE FUNCTION public.fn_get_users()
RETURNS TABLE (id UUID, email TEXT, phone_number TEXT, role TEXT, user_name TEXT, is_employee BOOLEAN, is_partner BOOLEAN, employee_id UUID, created_at TIMESTAMPTZ)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT u.id, u.email, u.phone_number, u.role, u.user_name, u.is_employee, u.is_partner, u.employee_id, u.created_at
  FROM public.users u ORDER BY u.email ASC;
$$;

-- 4. Audit trigger for users table
DROP TRIGGER IF EXISTS trg_audit_users ON public.users;
CREATE TRIGGER trg_audit_users
  AFTER INSERT OR UPDATE OR DELETE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
