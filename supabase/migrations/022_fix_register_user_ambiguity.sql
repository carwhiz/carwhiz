-- Migration 022: Fix register_user function ambiguity
-- ====================================================
-- There are two conflicting register_user functions causing ambiguity errors.
-- This migration drops all versions and creates a single, clear definition.

-- 1. Drop all conflicting register_user function overloads
DROP FUNCTION IF EXISTS public.register_user(text, text, text, text);
DROP FUNCTION IF EXISTS public.register_user(text, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.register_user(p_email text, p_phone_number text, p_password text, p_role text);
DROP FUNCTION IF EXISTS public.register_user(p_email text, p_phone_number text, p_password text, p_role text, p_role_id uuid);

-- 2. Create single, unambiguous register_user function
CREATE OR REPLACE FUNCTION public.register_user(
  p_email TEXT,
  p_phone_number TEXT,
  p_password TEXT,
  p_role TEXT DEFAULT 'user'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_user public.users;
  existing_user public.users;
BEGIN
  -- Check if email already exists
  SELECT * INTO existing_user FROM public.users WHERE email = p_email;
  IF existing_user IS NOT NULL THEN
    RETURN json_build_object('error', 'Email already registered');
  END IF;

  INSERT INTO public.users (email, phone_number, password_hash, role)
  VALUES (p_email, p_phone_number, crypt(p_password, gen_salt('bf')), p_role)
  RETURNING * INTO new_user;

  RETURN json_build_object(
    'id', new_user.id,
    'email', new_user.email,
    'phone_number', new_user.phone_number,
    'role', new_user.role,
    'created_at', new_user.created_at
  );
END;
$$;
