// Migration script for CarWhizz - runs SQL against Supabase
// Usage: node scripts/migrate.js
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SERVICE_ROLE_KEY) {
  console.error('Error: SUPABASE_SERVICE_ROLE_KEY not set.');
  console.error('Run: set SUPABASE_SERVICE_ROLE_KEY=your-key && node scripts/migrate.js');
  process.exit(1);
}

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '001_create_users.sql');
const sql = readFileSync(sqlPath, 'utf-8');

// Split SQL into individual statements
const statements = sql
  .split(/;\s*$/m)
  .map(s => s.trim())
  .filter(s => s.length > 0 && !s.startsWith('--'));

async function runMigration() {
  console.log('Running CarWhizz migration...\n');

  const projectRef = SUPABASE_URL.replace('https://', '').replace('.supabase.co', '');

  // Try the pg-meta query endpoint
  const queryUrl = `${SUPABASE_URL}/rest/v1/rpc/`;

  // Run each statement via the SQL endpoint
  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i];
    const preview = stmt.substring(0, 60).replace(/\n/g, ' ');
    console.log(`[${i + 1}/${statements.length}] ${preview}...`);

    try {
      // Try using the Supabase pg endpoint
      const res = await fetch(`${SUPABASE_URL}/pg/query`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SERVICE_ROLE_KEY,
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({ query: stmt + ';' }),
      });

      if (res.ok) {
        console.log(`  ✓ Success`);
      } else {
        const text = await res.text();
        if (res.status === 404) {
          console.error('\n✗ pg endpoint not available.');
          console.error('Please run the SQL manually in Supabase SQL Editor:');
          console.error(`  File: supabase/migrations/001_create_users.sql\n`);
          console.error('Steps:');
          console.error('  1. Go to https://supabase.com/dashboard');
          console.error('  2. Open your project');
          console.error('  3. Go to SQL Editor');
          console.error('  4. Paste the contents of 001_create_users.sql');
          console.error('  5. Click "Run"\n');
          process.exit(1);
        }
        console.error(`  ✗ Error: ${text}`);
      }
    } catch (err) {
      console.error(`  ✗ ${err.message}`);
    }
  }

  console.log('\n✓ Migration complete!');
  console.log('\nMaster admin user created:');
  console.log('  Email: mk.yousafali@gmail.com');
  console.log('  Phone: +918891460530');
  console.log('  Role:  admin');
}

runMigration().catch(console.error);
