import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const envFile = readFileSync(join(__dirname, '..', '.env'), 'utf-8');
const env = Object.fromEntries(
  envFile.split('\n')
    .filter(l => l.trim() && !l.startsWith('#'))
    .map(l => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim()]; })
);

const URL = env.VITE_SUPABASE_URL;
const KEY = env.SUPABASE_SERVICE_ROLE_KEY;

// Test REST API - this definitely works since the app works
const endpoint = `${URL}/rest/v1/users?select=id&limit=1`;
console.log('Testing REST API:', endpoint);

const res = await fetch(endpoint, {
  headers: {
    'apikey': KEY,
    'Authorization': `Bearer ${KEY}`,
  }
});
console.log('Status:', res.status);
const text = await res.text();
console.log('Response:', text.substring(0, 200));

// Now check if there's a database/query endpoint in the management API
const mgmtEndpoints = [
  `${URL}/rest/v1/rpc/`,
];

for (const ep of mgmtEndpoints) {
  console.log('\nChecking:', ep);
  const r = await fetch(ep, { headers: { 'apikey': KEY, 'Authorization': `Bearer ${KEY}` } });
  console.log('Status:', r.status);
}
