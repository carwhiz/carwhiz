#!/usr/bin/env node
/**
 * Deploy migration 051: Fix Shifts RLS for anon/service_role
 * Usage: node scripts/run-051-migration.mjs
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '051_fix_shifts_rls_anon.sql');
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

    console.log('Running Migration 051: Fix Shifts RLS for anon/service_role...');
    await client.query(sql);
    console.log('Migration 051 executed successfully!\n');

    // Verify
    const policies = await client.query(`
      SELECT policyname, permissive, roles, cmd
      FROM pg_policies WHERE tablename = 'shifts';
    `);
    console.log('Current policies on shifts:');
    policies.rows.forEach(p => console.log(`  - ${p.policyname} (${p.cmd}) -> roles: ${p.roles}`));

  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
