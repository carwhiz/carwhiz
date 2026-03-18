import fs from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const envFile = fs.readFileSync(join(__dirname, '..', '.env'), 'utf-8');
const env = Object.fromEntries(envFile.split('\n').filter(l => l.trim() && !l.startsWith('#')).map(l => { const line = l.trim(); const i = line.indexOf('='); return [line.slice(0, i).trim(), line.slice(i + 1).trim()]; }));
const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;
const DB_HOST = env.DB_HOST;
const DB_PASSWORD = env.DB_PASSWORD;

const migrationFile = process.argv[2];
if (!migrationFile) {
  console.error('Usage: node scripts/run-sql-via-rpc.mjs <migration-file>');
  process.exit(1);
}

const fullSql = fs.readFileSync(migrationFile, 'utf-8');

// Split SQL into individual statements (respects single-quoted strings)
function splitStatements(sql) {
  const statements = [];
  let current = '';
  let inSingleQuote = false;

  for (let i = 0; i < sql.length; i++) {
    const ch = sql[i];
    if (ch === "'" && !inSingleQuote) { inSingleQuote = true; current += ch; continue; }
    if (ch === "'" && inSingleQuote) {
      if (sql[i + 1] === "'") { current += "''"; i++; continue; }
      inSingleQuote = false; current += ch; continue;
    }
    if (!inSingleQuote && ch === '-' && sql[i + 1] === '-') {
      const nl = sql.indexOf('\n', i);
      if (nl === -1) break;
      i = nl; current += '\n'; continue;
    }
    if (!inSingleQuote && ch === ';') {
      current += ch;
      const trimmed = current.trim();
      if (trimmed && trimmed !== ';') statements.push(trimmed);
      current = ''; continue;
    }
    current += ch;
  }
  const remaining = current.trim();
  if (remaining && remaining !== ';') statements.push(remaining);
  return statements;
}

async function tryPgMeta(statements) {
  // Try multiple known Supabase pg-meta SQL endpoints
  const endpoints = ['/pg/query', '/pg-meta/query'];

  for (const endpoint of endpoints) {
    try {
      const testRes = await fetch(`${SUPABASE_URL}${endpoint}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SERVICE_KEY,
          'Authorization': `Bearer ${SERVICE_KEY}`,
        },
        body: JSON.stringify({ query: 'SELECT 1' }),
      });
      if (testRes.status === 404) continue;

      console.log(`Using endpoint: ${endpoint}\n`);
      let success = 0, failed = 0;

      for (let i = 0; i < statements.length; i++) {
        const stmt = statements[i];
        const preview = stmt.replace(/\s+/g, ' ').substring(0, 80);
        process.stdout.write(`[${i + 1}/${statements.length}] ${preview}... `);

        const res = await fetch(`${SUPABASE_URL}${endpoint}`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SERVICE_KEY,
            'Authorization': `Bearer ${SERVICE_KEY}`,
          },
          body: JSON.stringify({ query: stmt }),
        });

        if (res.ok) { console.log('OK'); success++; }
        else { const t = await res.text(); console.log(`FAIL: ${t.substring(0, 200)}`); failed++; }
      }
      return { success, failed };
    } catch (e) { continue; }
  }
  return null;
}

async function tryPsql(statements) {
  // Use psql via the database connection string
  if (!DB_HOST || !DB_PASSWORD) return null;

  let pg;
  try {
    pg = await import('pg');
  } catch {
    console.log('pg module not installed. Installing...');
    const { execSync } = await import('child_process');
    execSync('npm install pg', { stdio: 'inherit', cwd: join(__dirname, '..') });
    pg = await import('pg');
  }

  const { Client } = pg.default || pg;
  const client = new Client({
    host: DB_HOST,
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: DB_PASSWORD,
    ssl: { rejectUnauthorized: false },
  });

  await client.connect();
  console.log('Connected to database directly\n');

  let success = 0, failed = 0;
  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i];
    const preview = stmt.replace(/\s+/g, ' ').substring(0, 80);
    process.stdout.write(`[${i + 1}/${statements.length}] ${preview}... `);

    try {
      await client.query(stmt);
      console.log('OK');
      success++;
    } catch (err) {
      console.log(`FAIL: ${err.message}`);
      failed++;
    }
  }

  await client.end();
  return { success, failed };
}

async function main() {
  const statements = splitStatements(fullSql);
  console.log(`Running migration: ${migrationFile}`);
  console.log(`${statements.length} statements to execute\n`);

  // Try pg-meta API first, then direct database connection
  let result = await tryPgMeta(statements);

  if (!result) {
    console.log('pg-meta API not available, trying direct database connection...');
    result = await tryPsql(statements);
  }

  if (!result) {
    console.error('Could not connect via API or database. Run the SQL manually in Supabase SQL Editor.');
    process.exit(1);
  }

  console.log(`\nDone: ${result.success} succeeded, ${result.failed} failed`);
  if (result.failed > 0) process.exit(1);
}

main().catch(console.error);
