import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';

const SUPABASE_URL = process.env.PUBLIC_SUPABASE_URL || 'https://jlnntevahhmgzrkhuuta.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Error: SUPABASE_SERVICE_ROLE_KEY environment variable not set');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function runMigration() {
  const migrationPath = path.resolve('supabase/migrations/026_attendance_authenticated_rls.sql');
  const sql = fs.readFileSync(migrationPath, 'utf-8');
  
  console.log('Running migration: 026_attendance_authenticated_rls.sql');
  
  try {
    const { data, error } = await supabase.rpc('exec_sql', { sql });
    if (error) {
      console.error('Error executing migration:', error);
      process.exit(1);
    }
    console.log('Migration completed successfully');
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

runMigration();
