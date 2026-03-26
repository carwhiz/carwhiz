import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '043_add_employee_extended_fields.sql');
const sql = readFileSync(sqlPath, 'utf-8');

const client = new pg.Client({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  console.log('🚀 Starting migration 043 - Add Employee Extended Fields\n');
  console.log('Connecting to Supabase PostgreSQL...');
  
  try {
    await client.connect();
    console.log('✓ Connected!\n');

    console.log('Running migration SQL...');
    await client.query(sql);
    console.log('✓ Migration executed successfully!\n');

    // Verify the new columns were created
    const tableCheck = await client.query(
      `SELECT column_name, data_type FROM information_schema.columns 
       WHERE table_name = 'users' AND table_schema = 'public' 
       AND column_name IN ('date_of_birth', 'blood_group', 'education', 'joining_date', 
                           'driving_license_number', 'aadhar_number', 'bank_account_number', 
                           'bank_name', 'basic_salary', 'resident_location', 'cv_document_url', 'updated_by')
       ORDER BY ordinal_position`
    );
    
    console.log('✓ New columns created in users table:');
    if (tableCheck.rows.length > 0) {
      for (const row of tableCheck.rows) {
        console.log(`  ✓ ${row.column_name} (${row.data_type})`);
      }
    } else {
      console.log('  ⚠️  No new columns found. They may already exist.');
    }
    
    console.log('\n✅ Migration 043 completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
