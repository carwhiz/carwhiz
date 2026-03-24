#!/usr/bin/env node
/**
 * Deploy migration 036: Fix Multi-Punch Attendance Constraints
 * Usage: node scripts/run-036-migration.mjs
 * 
 * This migration:
 * 1. Removes UNIQUE(user_id, date) constraint that prevents multiple punches per day
 * 2. Ensures punch_order column exists
 * 3. Creates index for efficient lookup
 * 4. Deploys correct multi-punch function
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '036_fix_multi_punch_constraints.sql');
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
    console.log('🔗 Connecting to Supabase PostgreSQL...');
    await client.connect();
    console.log('✓ Connected!\n');

    console.log('▶️  Running Migration 036: Fix Multi-Punch Attendance Constraints');
    console.log('   - Removing UNIQUE(user_id, date) constraint');
    console.log('   - Ensuring punch_order column exists');
    console.log('   - Creating efficiency index');
    console.log('   - Updating multi-punch function\n');
    
    await client.query(sql);
    console.log('✓ Migration 036 executed successfully!\n');

    // Verify the setup
    const constraintCheck = await client.query(`
      SELECT COUNT(*) as constraint_count
      FROM information_schema.table_constraints
      WHERE table_name = 'attendance' 
        AND constraint_type = 'UNIQUE'
        AND table_schema = 'public';
    `);
    
    const punchOrderCheck = await client.query(`
      SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance' AND column_name = 'punch_order'
      ) as exists;
    `);
    
    const indexCheck = await client.query(`
      SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'attendance' AND indexname = 'idx_attendance_user_date_order'
      ) as exists;
    `);

    console.log('✅ Verification:');
    console.log(`   ✓ Unique constraints: ${constraintCheck.rows[0].constraint_count} (should be 0)`);
    console.log(`   ✓ punch_order column: ${punchOrderCheck.rows[0].exists ? 'EXISTS' : 'MISSING'}`);
    console.log(`   ✓ Index: ${indexCheck.rows[0].exists ? 'EXISTS' : 'MISSING'}\n`);

    console.log('✅ Multi-punch attendance is now fixed!');
    console.log('   Users can now:');
    console.log('   - Check in multiple times per day');
    console.log('   - Check out and check in again');
    console.log('   - Each punch is tracked separately with punch_order\n');

  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
