#!/usr/bin/env node

/**
 * Run Migration 042: Salary Management System
 * Uses direct PostgreSQL connection via environment variables
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const client = new pg.Client({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
});

async function runMigration() {
  try {
    console.log('📋 Running Migration 042: Salary Management System...');
    
    await client.connect();
    console.log('✓ Connected to database');
    
    const migrationPath = join(__dirname, '..', 'supabase', 'migrations', '042_salary_management.sql');
    const sql = readFileSync(migrationPath, 'utf8');
    
    await client.query(sql);
    console.log('✅ Migration 042 completed successfully!\n');
    
    console.log('📌 Tables created:');
    console.log('   - employee_salaries');
    console.log('   - salary_payments');
    console.log('\n🔧 RPC Functions created:');
    console.log('   - fn_process_salary_payment()');
    console.log('   - fn_calculate_remaining_salary()');
    console.log('\n👁️  Views created:');
    console.log('   - vw_employee_salary_summary');
    console.log('   - vw_monthly_salary_expense');
    
    await client.end();
  } catch (err) {
    console.error('❌ Migration error:', err.message);
    process.exit(1);
  }
}

runMigration();

