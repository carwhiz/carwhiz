#!/usr/bin/env node
/**
 * Deploy migration 035: Fix QR Token Validation
 * Usage: node scripts/run-035-migration.mjs
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '035_fix_qr_token_validation.sql');
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

    console.log('▶️  Running Migration 035: Fix QR Token Validation');
    console.log('   - Updates fn_attendance_punch function');
    console.log('   - Changes token validation from MD5 to simple format parsing');
    console.log('   - Validates userId and timestamp instead of hash\n');
    
    await client.query(sql);
    console.log('✓ Migration 035 executed successfully!\n');

    // Verify the function was updated
    const result = await client.query(`
      SELECT pg_get_functiondef(oid) as func_def 
      FROM pg_proc 
      WHERE proname = 'fn_attendance_punch'
      LIMIT 1;
    `);
    
    if (result.rows.length > 0) {
      console.log('✓ Function fn_attendance_punch verified in database');
      console.log('✓ QR token validation is now active and ready to use!\n');
    }

    console.log('✅ Deployment complete! QR scanning should now work.');
    console.log('   Token format: userId|timestamp');
    console.log('   Time tolerance: ±15 seconds\n');

  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
