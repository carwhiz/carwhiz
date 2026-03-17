import pg from 'pg';

const client = new pg.Client({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  await client.connect();
  console.log('Connected. Creating authenticate_by_code function...');

  await client.query(`
    CREATE OR REPLACE FUNCTION public.authenticate_by_code(p_password TEXT)
    RETURNS JSON
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
      found_user public.users;
    BEGIN
      SELECT * INTO found_user
      FROM public.users
      WHERE password_hash = crypt(p_password, password_hash);

      IF found_user IS NULL THEN
        RETURN json_build_object('error', 'Invalid access code');
      END IF;

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
  `);

  const check = await client.query(
    `SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'authenticate_by_code'`
  );
  console.log('Function created:', check.rows.length > 0 ? 'YES' : 'NO');
  await client.end();
}

run().catch(async (e) => { console.error(e.message); try { await client.end(); } catch {} process.exit(1); });
