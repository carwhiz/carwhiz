-- CarWhizz Custom Auth Migration
-- Creates users table with custom authentication (no Supabase Auth)

-- Enable pgcrypto for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create users table
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  phone_number TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Full grant for anon
CREATE POLICY "anon_full_access" ON public.users
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- Full grant for service_role
CREATE POLICY "service_role_full_access" ON public.users
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- RPC function: authenticate user (login)
CREATE OR REPLACE FUNCTION public.authenticate_user(
  p_email TEXT,
  p_password TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  found_user public.users;
BEGIN
  SELECT * INTO found_user
  FROM public.users
  WHERE email = p_email
  AND password_hash = crypt(p_password, password_hash);

  IF found_user IS NULL THEN
    RETURN json_build_object('error', 'Invalid email or password');
  END IF;

  -- Update last login
  UPDATE public.users SET updated_at = now() WHERE id = found_user.id;

  RETURN json_build_object(
    'id', found_user.id,
    'email', found_user.email,
    'phone_number', found_user.phone_number,
    'role', found_user.role,
    'created_at', found_user.created_at
  );
END;
$$;

-- RPC function: register user (sign up)
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

-- Insert master admin user
INSERT INTO public.users (email, phone_number, password_hash, role)
VALUES (
  'mk.yousafali@gmail.com',
  '+918891460530',
  crypt('460530', gen_salt('bf')),
  'admin'
)
ON CONFLICT (email) DO NOTHING;
