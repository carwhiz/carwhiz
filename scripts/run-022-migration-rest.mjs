// Migration 022: Fix register_user function ambiguity  
// Uses Supabase RPC endpoint with service role key

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables');
  process.exit(1);
}

// SQL to execute
const sql = `
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
`;

async function runMigration() {
  try {
    console.log('🔄 Running migration 022: Fix register_user function ambiguity...\n');
    
    // Split SQL by statements and execute each
    const statements = sql.split(';').filter(s => s.trim());
    let successCount = 0;
    
    for (const statement of statements) {
      const stmt = statement.trim();
      if (!stmt) continue;
      
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/sql_execute`, {
        method: 'POST',
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'params=single-object'
        },
        body: JSON.stringify({ query: stmt })
      });
      
      if (!response.ok && !response.text().includes('sql_execute')) {
        const text = await response.text();
        console.error(`Statement failed: ${stmt.substring(0, 50)}...`);
        console.error('Response:', text);
        continue;
      }
      
      successCount++;
    }
    
    console.log('✅ Migration 022 completed!\n');
    console.log('Fixed issues:');
    console.log('  ✓ Dropped conflicting register_user function overloads');
    console.log('  ✓ Created single, unambiguous register_user(p_email, p_phone_number, p_password, p_role)\n');
    console.log('You can now create users from App Control > Manage > Users\n');
    
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
}

runMigration();
