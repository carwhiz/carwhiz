import fs from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const envFile = fs.readFileSync(join(__dirname, '..', '.env'), 'utf-8');
const env = Object.fromEntries(envFile.split('\n').filter(l => l && !l.startsWith('#')).map(l => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1)]; }));
const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

// Split SQL into individual statements and run them via PostgREST
// by first creating a temp exec function, then calling it, then dropping it.

const migrationFile = process.argv[2];
if (!migrationFile) {
  console.error('Usage: node scripts/run-sql-via-rpc.mjs <migration-file>');
  process.exit(1);
}

const sql = fs.readFileSync(migrationFile, 'utf-8');

async function rpc(fnName, params) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fnName}`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_KEY,
      'Authorization': `Bearer ${SERVICE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params),
  });
  return { status: r.status, body: await r.text() };
}

async function main() {
  // Step 1: Create a temporary exec_sql function via the existing create_product RPC trick
  // Actually, we can't create functions via PostgREST. Let's check if we can use pg_net or another approach.
  
  // Alternative: Use Supabase's built-in pg endpoint (available in newer versions)
  console.log('Attempting to run migration via Supabase SQL endpoint...');
  
  // Try the /sql endpoint (available in some Supabase versions)
  const endpoints = [
    '/rest/v1/rpc/exec_sql',
    '/sql',
    '/database/query',
  ];
  
  // First, let's just try to check if ledger_entries already exists
  const checkR = await fetch(`${SUPABASE_URL}/rest/v1/ledger_entries?select=id&limit=1`, {
    headers: {
      'apikey': SERVICE_KEY,
      'Authorization': `Bearer ${SERVICE_KEY}`,
    },
  });
  
  console.log('Check ledger_entries exists:', checkR.status);
  if (checkR.status === 200) {
    console.log('ledger_entries table already exists!');
    const data = await checkR.text();
    console.log('Data:', data);
    return;
  }
  
  const checkBody = await checkR.text();
  console.log('Response:', checkBody);
  
  // If table doesn't exist (404/406), we need to create it
  // The only way with service_role key is via the pg-meta API
  console.log('\nTrying pg-meta SQL endpoint...');
  const pgMetaR = await fetch(`${SUPABASE_URL}/pg/query`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_KEY,
      'Authorization': `Bearer ${SERVICE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  console.log('pg-meta status:', pgMetaR.status);
  console.log('pg-meta body:', await pgMetaR.text());
}

main().catch(console.error);
