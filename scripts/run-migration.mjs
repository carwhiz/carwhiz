import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SERVICE_ROLE_KEY = readFileSync(join(__dirname, '..', '.env'), 'utf-8')
  .split('\n')
  .find(l => l.startsWith('SUPABASE_SERVICE_ROLE_KEY='))
  ?.split('=')
  .slice(1)
  .join('=')
  .trim();

if (!SERVICE_ROLE_KEY) {
  console.error('Could not read SUPABASE_SERVICE_ROLE_KEY from .env');
  process.exit(1);
}

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '001_create_users.sql');
const fullSql = readFileSync(sqlPath, 'utf-8');

// Split into individual statements, keeping $$ blocks intact
function splitStatements(sql) {
  const statements = [];
  let current = '';
  let inDollarQuote = false;

  const lines = sql.split('\n');
  for (const line of lines) {
    // Skip comment-only lines at top level
    if (!inDollarQuote && line.trim().startsWith('--') && current.trim() === '') {
      continue;
    }

    current += line + '\n';

    // Track $$ blocks
    const dollarMatches = line.match(/\$\$/g);
    if (dollarMatches) {
      for (const _ of dollarMatches) {
        inDollarQuote = !inDollarQuote;
      }
    }

    // Statement ends with ; at end of line, not inside $$ block
    if (!inDollarQuote && line.trim().endsWith(';')) {
      const stmt = current.trim();
      if (stmt && !stmt.startsWith('--')) {
        statements.push(stmt);
      }
      current = '';
    }
  }

  if (current.trim() && !current.trim().startsWith('--')) {
    statements.push(current.trim());
  }

  return statements;
}

const statements = splitStatements(fullSql);

async function runSQL(query) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ query }),
  });
  return res;
}

async function runMigration() {
  console.log(`Running migration with ${statements.length} statements...\n`);

  // Try running the entire SQL as one block first via pg endpoint
  console.log('Attempting to execute full SQL via Supabase API...\n');

  // Try multiple known endpoints
  const endpoints = [
    '/pg/query',
    '/rest/v1/rpc/exec_sql',
  ];

  for (const endpoint of endpoints) {
    try {
      const res = await fetch(`${SUPABASE_URL}${endpoint}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SERVICE_ROLE_KEY,
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({ query: fullSql }),
      });

      if (res.ok) {
        const data = await res.text();
        console.log(`Success via ${endpoint}!`);
        console.log(data);
        console.log('\n✓ Migration complete!');
        console.log('\nMaster admin user created:');
        console.log('  Email: mk.yousafali@gmail.com');
        console.log('  Phone: +918891460530');
        console.log('  Role:  admin');
        return;
      } else if (res.status !== 404) {
        const text = await res.text();
        console.log(`Endpoint ${endpoint} returned ${res.status}: ${text}`);
      }
    } catch (e) {
      // endpoint doesn't exist, try next
    }
  }

  // If API endpoints didn't work, try statement by statement via the query endpoint
  console.log('API endpoints not available. Trying individual statements...\n');
  
  let success = 0;
  let failed = 0;
  
  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i];
    const preview = stmt.substring(0, 80).replace(/\n/g, ' ');
    console.log(`[${i + 1}/${statements.length}] ${preview}...`);

    try {
      // Try the postgres meta API
      const res = await fetch(`${SUPABASE_URL}/pg/query`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SERVICE_ROLE_KEY,
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          'X-Connection-Encrypted': '1',
        },
        body: JSON.stringify({ query: stmt }),
      });

      if (res.ok) {
        console.log('  ✓ OK');
        success++;
      } else {
        const text = await res.text();
        console.log(`  ✗ ${res.status}: ${text.substring(0, 200)}`);
        failed++;
      }
    } catch (err) {
      console.log(`  ✗ ${err.message}`);
      failed++;
    }
  }

  if (success > 0 && failed === 0) {
    console.log(`\n✓ All ${success} statements executed successfully!`);
  } else if (success > 0) {
    console.log(`\n⚠ ${success} succeeded, ${failed} failed`);
  } else {
    console.log('\n✗ Could not execute SQL via API.');
    console.log('\n╔══════════════════════════════════════════════════════════╗');
    console.log('║  Please run the SQL manually in Supabase SQL Editor:    ║');
    console.log('║                                                          ║');
    console.log('║  1. Go to https://supabase.com/dashboard                ║');
    console.log('║  2. Open project: jlnntevahhmgzrkhuuta                  ║');
    console.log('║  3. Go to SQL Editor (left sidebar)                     ║');
    console.log('║  4. Click "+ New Query"                                 ║');
    console.log('║  5. Paste contents of:                                  ║');
    console.log('║     supabase/migrations/001_create_users.sql            ║');
    console.log('║  6. Click "Run"                                         ║');
    console.log('╚══════════════════════════════════════════════════════════╝');
  }
}

runMigration().catch(console.error);
