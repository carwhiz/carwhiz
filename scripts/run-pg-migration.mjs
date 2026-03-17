import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '001_create_users.sql');
const sql = readFileSync(sqlPath, 'utf-8');

const client = new pg.Client({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  console.log('Connecting to Supabase PostgreSQL...');
  await client.connect();
  console.log('Connected!\n');

  console.log('Running migration SQL...');
  await client.query(sql);
  console.log('✓ Migration executed successfully!\n');

  // Verify the table was created
  const tableCheck = await client.query(
    `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'users' AND table_schema = 'public' ORDER BY ordinal_position`
  );
  console.log('Users table columns:');
  for (const row of tableCheck.rows) {
    console.log(`  ${row.column_name} (${row.data_type})`);
  }

  // Verify admin user
  const adminCheck = await client.query(
    `SELECT id, email, phone_number, role, created_at FROM public.users WHERE email = 'mk.yousafali@gmail.com'`
  );
  if (adminCheck.rows.length > 0) {
    const admin = adminCheck.rows[0];
    console.log('\nMaster admin user:');
    console.log(`  ID:    ${admin.id}`);
    console.log(`  Email: ${admin.email}`);
    console.log(`  Phone: ${admin.phone_number}`);
    console.log(`  Role:  ${admin.role}`);
  }

  // Verify RPC functions
  const funcCheck = await client.query(
    `SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name IN ('authenticate_user', 'register_user')`
  );
  console.log('\nRPC functions:');
  for (const row of funcCheck.rows) {
    console.log(`  ✓ ${row.routine_name}`);
  }

  // Verify RLS policies
  const policyCheck = await client.query(
    `SELECT policyname, roles FROM pg_policies WHERE tablename = 'users' AND schemaname = 'public'`
  );
  console.log('\nRLS policies:');
  for (const row of policyCheck.rows) {
    console.log(`  ✓ ${row.policyname} (${row.roles})`);
  }

  await client.end();
  console.log('\nDone!');
}

run().catch(async (err) => {
  console.error('Migration failed:', err.message);
  try { await client.end(); } catch {}
  process.exit(1);
});
