import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SERVICE_ROLE_KEY = readFileSync(join(__dirname, '..', '.env.local'), 'utf-8')
  .split('\n')
  .find(l => l.startsWith('SUPABASE_SERVICE_ROLE_KEY='))
  ?.split('=')
  .slice(1)
  .join('=')
  .trim();

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

async function runMigration() {
  try {
    const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '029_attendance_rpc_v2.sql');
    const fullSql = readFileSync(sqlPath, 'utf-8');

    // Split statements carefully
    const statements = [];
    let current = '';
    let inDollarQuote = false;

    const lines = fullSql.split('\n');
    for (const line of lines) {
      if (!inDollarQuote && line.trim().startsWith('--')) {
        continue;
      }

      current += line + '\n';

      const dollarMatches = line.match(/\$\$/g);
      if (dollarMatches && dollarMatches.length % 2 === 1) {
        inDollarQuote = !inDollarQuote;
      }

      if (!inDollarQuote && (line.includes(';') || line.trim() === '')) {
        if (current.trim()) {
          statements.push(current.trim());
        }
        current = '';
      }
    }

    console.log(`Found ${statements.length} SQL statements to execute`);

    for (const stmt of statements) {
      if (!stmt.trim()) continue;
      
      console.log(`Executing: ${stmt.substring(0, 50)}...`);
      const { error } = await supabase.rpc('exec_sql', { sql: stmt });
      
      if (error) {
        console.error('Error executing SQL:', error);
      } else {
        console.log('✓ Statement executed successfully');
      }
    }

    console.log('✓ Migration 029 completed successfully');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  }
}

// Try simpler approach - directly execute the SQL
async function runMigrationDirect() {
  try {
    const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '029_attendance_rpc_v2.sql');
    const fullSql = readFileSync(sqlPath, 'utf-8');

    // Use Supabase's sql execution
    const { data, error } = await supabase.rpc('exec_sql_direct', { sql_text: fullSql });
    
    if (error) {
      console.error('Error:', error.message);
      process.exit(1);
    }
    
    console.log('✓ Migration 029 executed successfully');
  } catch (err) {
    console.error('Error:', err.message);
    console.log('\nNote: If exec_sql function does not exist, apply migration manually:');
    console.log('1. Go to Supabase Dashboard');
    console.log('2. Open SQL Editor');
    console.log('3. Copy and paste the contents of supabase/migrations/029_attendance_rpc_v2.sql');
    console.log('4. Execute it');
  }
}

runMigrationDirect();
