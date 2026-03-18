import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const sql = readFileSync(join(__dirname, '..', 'supabase', 'migrations', '012_audit_log_and_created_by.sql'), 'utf-8');
const envFile = readFileSync(join(__dirname, '..', '.env'), 'utf-8');
const key = process.env.SUPABASE_MGMT_KEY || envFile.split('\n').find(l => l.startsWith('SUPABASE_SERVICE_ROLE_KEY='))?.split('=').slice(1).join('=') || '';

async function run() {
  console.log('Running migration 012 via Management API...');
  const r = await fetch('https://api.supabase.com/v1/projects/jlnntevahhmgzrkhuuta/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  console.log('Status:', r.status);
  const text = await r.text();
  console.log(text.substring(0, 1000));
  if (r.status === 200 || r.status === 201) {
    console.log('\nMigration 012 completed successfully!');
  } else {
    console.error('\nMigration failed.');
    process.exit(1);
  }
}

run().catch(e => { console.error(e); process.exit(1); });
