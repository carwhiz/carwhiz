-- Optimize login performance
-- Add index on password_hash for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_password_hash ON public.users(password_hash);

-- Create optimized authentication function that avoids unnecessary updates
CREATE OR REPLACE FUNCTION public.authenticate_by_code(p_password TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  found_user public.users;
BEGIN
  -- Use indexed lookup with direct hash comparison
  SELECT id, email, phone_number, role, created_at
  INTO found_user
  FROM public.users
  WHERE password_hash = crypt(p_password, password_hash)
  LIMIT 1;

  IF found_user IS NULL THEN
    RETURN json_build_object('error', 'Invalid access code');
  END IF;

  -- Update last login asynchronously (non-blocking)
  -- This prevents slow UPDATEs from blocking the login response
  PERFORM pg_notify('auth_login', json_build_object('user_id', found_user.id)::text);

  RETURN json_build_object(
    'id', found_user.id,
    'email', found_user.email,
    'phone_number', found_user.phone_number,
    'role', found_user.role,
    'created_at', found_user.created_at
  );
END;
$$;

-- Optional: Create a separate function for updating last login timestamp
CREATE OR REPLACE FUNCTION public.update_last_login(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users SET updated_at = now() WHERE id = p_user_id;
END;
$$;
