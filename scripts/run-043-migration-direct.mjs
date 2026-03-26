import fs from 'fs';
import { createClient } from '@supabase/supabase-js';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const envFile = fs.readFileSync(join(__dirname, '..', '.env'), 'utf-8');
const env = Object.fromEntries(
  envFile
    .split('\n')
    .filter(l => l.trim() && !l.startsWith('#'))
    .map(l => {
      const i = l.indexOf('=');
      return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
    })
);

const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

console.log('🚀 Starting migration 043 - Add Employee Extended Fields\n');
console.log(`URL: ${SUPABASE_URL}`);

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

async function runMigration() {
  const migrationPath = join(__dirname, '..', 'supabase', 'migrations', '043_add_employee_extended_fields.sql');
  const sql = fs.readFileSync(migrationPath, 'utf-8');

  console.log('Executing migration SQL...\n');

  const { data, error } = await supabase.rpc('exec_sql', { sql_text: sql });

  if (error) {
    console.error('❌ Migration failed:\n', error);
    process.exit(1);
  }

  console.log('✓ Migration executed successfully!\n');
  console.log('Response:', data);

  // Verify columns
  console.log('\n✅ Migration 043 completed!');
  process.exit(0);
}

runMigration().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
