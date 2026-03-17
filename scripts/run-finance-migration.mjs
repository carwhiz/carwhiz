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

async function run() {
  await client.connect();
  console.log('Connected to database');

  const sql = readFileSync(join(__dirname, '..', 'supabase', 'migrations', '005_finance_customers_vendors.sql'), 'utf8');
  console.log('Running migration 005...');
  await client.query(sql);
  console.log('Migration completed successfully!');

  await client.end();
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
