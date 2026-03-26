import pg from 'pg';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Parse .env file manually
function loadEnv() {
  const envPath = resolve('./.env');
  const envContent = readFileSync(envPath, 'utf-8');
  const lines = envContent.split('\n');
  
  for (const line of lines) {
    if (line.trim() && !line.startsWith('#')) {
      const [key, ...valueParts] = line.split('=');
      const value = valueParts.join('=').trim();
      process.env[key.trim()] = value;
    }
  }
}

loadEnv();

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
    console.log('Connecting to database...');
    console.log('Host:', process.env.DB_HOST);
    
    await client.connect();
    console.log('✓ Connected to database');

    const sqlPath = resolve('./supabase/migrations/050_optimize_login_performance.sql');
    console.log('Reading migration file:', sqlPath);
    
    const sql = readFileSync(sqlPath, 'utf-8');
    console.log('Executing migration...');

    await client.query(sql);
    console.log('✓ Migration applied successfully!');
    console.log('\n📊 Performance Optimizations Applied:');
    console.log('  ✓ Added index on password_hash for faster lookups');
    console.log('  ✓ Optimized authenticate_by_code RPC function');
    console.log('  ✓ Removed blocking UPDATE from login RPC');
    console.log('  ✓ Added async last_login update function');
    
    await client.end();
  } catch (error) {
    console.error('✗ Migration failed:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

runMigration();
