#!/usr/bin/env node
/**
 * Deploy migration 060: Salary Management RPC Functions
 * Usage: node scripts/run-060-migration.mjs
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

dotenv.config();

const __dirname = dirname(fileURLToPath(import.meta.url));
const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '060_salary_management_rpc.sql');
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
  try {
    console.log('Connecting to Supabase PostgreSQL...');
    await client.connect();
    console.log('Connected!\n');

    console.log('Deploying Salary Management RPC functions...');
    await client.query(sql);
    console.log('All 7 RPC functions deployed successfully!\n');

    // Verify fn_get_salary_data exists and check its definition
    const verify = await client.query(`
      SELECT routine_name 
      FROM information_schema.routines 
      WHERE routine_schema = 'public' 
        AND routine_name LIKE 'fn_%salary%'
      ORDER BY routine_name
    `);
    console.log('Deployed salary functions:');
    verify.rows.forEach(r => console.log(`  ✓ ${r.routine_name}`));

    // Quick test: check that fn_get_salary_data returns user_id in employees
    const test = await client.query(`
      SELECT prosrc 
      FROM pg_proc 
      WHERE proname = 'fn_get_salary_data'
    `);
    if (test.rows.length > 0) {
      const src = test.rows[0].prosrc;
      if (src.includes('u.id AS user_id')) {
        console.log('\n✓ fn_get_salary_data includes user_id in employees query');
      } else {
        console.log('\n✗ WARNING: fn_get_salary_data does NOT include user_id - old version still active!');
      }
      if (src.includes('u.employee_id')) {
        console.log('✓ fn_get_salary_data includes employee_id in attendance query');
      }
    }

  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
    console.log('\nDone.');
  }
}

run();
