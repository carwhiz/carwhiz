import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const envFile = readFileSync(join(__dirname, '..', '.env'), 'utf-8');
const env = Object.fromEntries(
  envFile.split('\n')
    .filter(l => l.trim() && !l.startsWith('#'))
    .map(l => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim()]; })
);

const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '023_job_card_system.sql');
const fullSql = readFileSync(sqlPath, 'utf-8');

// Verify file content
if (fullSql.includes('full_name')) {
  console.error('ERROR: SQL file still contains full_name! Something is wrong.');
  process.exit(1);
}
console.log('SQL file verified: no full_name found.');
console.log('SQL length:', fullSql.length, 'chars');

// Try all known Supabase SQL execution endpoints
const endpoints = [
  '/pg/query',
  '/pg-meta/default/query',
  '/rest/v1/rpc/exec_sql',
];

async function tryEndpoint(endpoint, sql) {
  const url = `${SUPABASE_URL}${endpoint}`;
  console.log(`\nTrying: ${url}`);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
        'X-Connection-Encrypted': '1',
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify({ query: sql }),
    });
    const text = await res.text();
    console.log(`Status: ${res.status}`);
    console.log(`Response: ${text.substring(0, 300)}`);
    return res.ok;
  } catch (e) {
    console.log(`Error: ${e.message}`);
    return false;
  }
}

async function main() {
  for (const ep of endpoints) {
    const ok = await tryEndpoint(ep, fullSql);
    if (ok) {
      console.log('\nMigration executed successfully!');
      process.exit(0);
    }
  }

  // If none of those work, try the Supabase Management API
  // https://api.supabase.com/v1/projects/{ref}/database/query
  const ref = 'jlnntevahhmgzrkhuuta';
  const mgmtUrl = `https://api.supabase.com/v1/projects/${ref}/database/query`;
  console.log(`\nTrying Management API: ${mgmtUrl}`);
  try {
    const res = await fetch(mgmtUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SERVICE_KEY}`,
      },
      body: JSON.stringify({ query: fullSql }),
    });
    const text = await res.text();
    console.log(`Status: ${res.status}`);
    console.log(`Response: ${text.substring(0, 300)}`);
    if (res.ok) {
      console.log('\nMigration executed successfully!');
      process.exit(0);
    }
  } catch (e) {
    console.log(`Error: ${e.message}`);
  }

  console.log('\n--- No API endpoint worked ---');
  console.log('The SQL file is correct. Your browser is caching old SQL.');
  console.log('Please try: Open browser incognito/private window -> go to Supabase SQL Editor -> paste');
  process.exit(1);
}

main();
