#!/usr/bin/env node
/**
 * Deploy migration 052: Create Special Shifts Table
 * Usage: node scripts/run-052-migration.mjs
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '052_create_special_shifts_table.sql');
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

    console.log('Running Migration 052: Create Special Shifts Table...');
    await client.query(sql);
    console.log('Migration 052 executed successfully!\n');

    // Verify
    const tableCheck = await client.query(`
      SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'special_shifts' AND table_schema = 'public'
      ) as exists;
    `);
    console.log('✓ special_shifts table exists:', tableCheck.rows[0].exists);

  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
