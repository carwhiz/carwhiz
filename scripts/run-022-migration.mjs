import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Run migration 022 - Fix register_user ambiguity
const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '022_fix_register_user_ambiguity.sql');
const sql = readFileSync(sqlPath, 'utf-8');

const client = new pg.Client({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.DB_PASSWORD,
  ssl: true,
  sslmode: 'require',
});

async function run() {
  try {
    console.log('🔄 Connecting to Supabase PostgreSQL...');
    console.log(`   Host: ${process.env.DB_HOST}`);
    
    await client.connect();
    console.log('✅ Connected!\n');

    console.log('📋 Running migration 022: Fix register_user function ambiguity...');
    
    // Split and execute SQL statements
    const statements = sql.split(';').filter(s => s.trim());
    
    for (const statement of statements) {
      if (statement.trim()) {
        await client.query(statement);
      }
    }
    
    console.log('✅ Migration 022 executed successfully!\n');
    
    console.log('✓ Fixed issues:');
    console.log('  • Dropped conflicting register_user function overloads');
    console.log('  • Created single, unambiguous register_user(p_email, p_phone_number, p_password, p_role)\n');
    console.log('✓ Users can now be created from App Control > Manage > Users\n');
    
    await client.end();
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    if (err.code === 'ECONNREFUSED') {
      console.error('\n⚠️  Could not connect to database. Please:');
      console.error('  1. Go to Supabase Dashboard: https://supabase.com/dashboard');
      console.error('  2. Open your project');
      console.error('  3. Go to SQL Editor');
      console.error('  4. Copy-paste the SQL from: supabase/migrations/022_fix_register_user_ambiguity.sql');
      console.error('  5. Click "Run"\n');
    }
    await client.end();
    process.exit(1);
  }
}

run();
