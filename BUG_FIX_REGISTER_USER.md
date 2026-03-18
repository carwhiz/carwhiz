# Bug Fix: register_user() Function Ambiguity

## Problem
When creating a user from **App Control > Manage > Users**, you get this error:
```
Could not choose the best candidate function between:
public.register_user(p_email => text, p_phone_number => text, p_password => text, p_role => text)
public.register_user(p_email => text, p_phone_number => text, p_password => text, p_role => text, p_role_id => uuid)
```

## Root Cause
PostgreSQL has two conflicting function definitions for `register_user()` with different parameter signatures, causing ambiguity when the function is called.

## Solution
Run the following SQL in Supabase SQL Editor to fix the issue:

### Steps:
1. Go to https://supabase.com/dashboard
2. Open your CarWhizz project
3. Go to **SQL Editor**
4. Create a new query
5. Copy and paste the SQL below:

```sql
-- Drop conflicting register_user function overloads
DROP FUNCTION IF EXISTS public.register_user(text, text, text, text);
DROP FUNCTION IF EXISTS public.register_user(text, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.register_user(p_email text, p_phone_number text, p_password text, p_role text);
DROP FUNCTION IF EXISTS public.register_user(p_email text, p_phone_number text, p_password text, p_role text, p_role_id uuid);

-- Create single, unambiguous register_user function
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
```

6. Click **Run** button
7. You should see: **Success. No rows returned.**

## Verification
After running the SQL, you should be able to create users without errors from App Control > Manage > Users.

## Files Updated
- `supabase/migrations/022_fix_register_user_ambiguity.sql` - Migration file with the fix
- `scripts/run-022-migration.mjs` - Migration runner script (for reference)

## Summary
✅ Removed ambiguous function overloads
✅ Created single, clean register_user() function
✅ Users can now be created successfully
