import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const envFile = readFileSync(join(__dirname, '..', '.env'), 'utf-8');
const env = Object.fromEntries(
  envFile.split('\n')
    .filter(l => l.trim() && !l.startsWith('#'))
    .map(l => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim()]; })
);

const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '023_job_card_system.sql');
const sql = readFileSync(sqlPath, 'utf-8');

// Try multiple possible connection configurations
const configs = [
  {
    name: 'Supavisor Session (ap-south-1)',
    host: 'aws-0-ap-south-1.pooler.supabase.com',
    port: 5432,
    user: 'postgres.jlnntevahhmgzrkhuuta',
    password: env.DB_PASSWORD,
    database: 'postgres',
    ssl: { rejectUnauthorized: false },
  },
  {
    name: 'Supavisor Transaction (ap-south-1)',
    host: 'aws-0-ap-south-1.pooler.supabase.com',
    port: 6543,
    user: 'postgres.jlnntevahhmgzrkhuuta',
    password: env.DB_PASSWORD,
    database: 'postgres',
    ssl: { rejectUnauthorized: false },
  },
  {
    name: 'Direct DB',
    host: env.DB_HOST,
    port: 5432,
    user: 'postgres',
    password: env.DB_PASSWORD,
    database: 'postgres',
    ssl: { rejectUnauthorized: false },
  },
  {
    name: 'Supavisor Session (us-east-1)',
    host: 'aws-0-us-east-1.pooler.supabase.com',
    port: 5432,
    user: 'postgres.jlnntevahhmgzrkhuuta',
    password: env.DB_PASSWORD,
    database: 'postgres',
    ssl: { rejectUnauthorized: false },
  },
  {
    name: 'Supavisor Session (ap-southeast-1)',
    host: 'aws-0-ap-southeast-1.pooler.supabase.com',
    port: 5432,
    user: 'postgres.jlnntevahhmgzrkhuuta',
    password: env.DB_PASSWORD,
    database: 'postgres',
    ssl: { rejectUnauthorized: false },
  },
];

async function tryConnect(config) {
  const { name, ...pgConfig } = config;
  const client = new pg.Client(pgConfig);
  try {
    await client.connect();
    console.log(`Connected via: ${name}`);
    return client;
  } catch (e) {
    console.log(`${name}: ${e.message}`);
    return null;
  }
}

async function main() {
  let client = null;
  for (const config of configs) {
    client = await tryConnect(config);
    if (client) break;
  }

  if (!client) {
    console.error('\nCould not connect to database via any method.');
    console.error('Please paste the SQL into Supabase SQL Editor manually.');
    process.exit(1);
  }

  console.log('\nRunning migration 023_job_card_system.sql...\n');

  try {
    await client.query(sql);
    console.log('Migration completed successfully!');
  } catch (e) {
    console.error('Migration failed:', e.message);
    console.error('\nStatement position:', e.position);
  } finally {
    await client.end();
  }
}

main();
