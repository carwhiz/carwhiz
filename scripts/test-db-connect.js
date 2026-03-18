import pg from 'pg';
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const envFile = readFileSync(join(__dir, '..', '.env'), 'utf-8');
const dbPassword = envFile.split('\n').find(l => l.startsWith('DB_PASSWORD='))?.split('=').slice(1).join('=') || '';

const regions = [
  'ap-south-1', 'ap-southeast-1', 'ap-southeast-2', 'ap-northeast-1',
  'us-east-1', 'us-west-1', 'us-west-2', 'eu-west-1', 'eu-west-2', 'eu-central-1',
];
const configs = [];
for (const r of regions) {
  configs.push({ label: `Pooler ${r} 6543`, host: `aws-0-${r}.pooler.supabase.com`, port: 6543, user: 'postgres.jlnntevahhmgzrkhuuta' });
}
configs.push({ label: 'Direct', host: 'db.jlnntevahhmgzrkhuuta.supabase.co', port: 5432, user: 'postgres' });

async function tryConnect(cfg) {
  const client = new pg.Client({
    host: cfg.host,
    port: cfg.port,
    database: 'postgres',
    user: cfg.user,
    password: dbPassword,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
  });
  try {
    await client.connect();
    const r = await client.query('SELECT current_database()');
    console.log(`[${cfg.label}] CONNECTED! DB: ${r.rows[0].current_database}`);
    await client.end();
    return true;
  } catch (e) {
    console.log(`[${cfg.label}] FAILED: ${e.message}`);
    return false;
  }
}

(async () => {
  for (const cfg of configs) {
    const ok = await tryConnect(cfg);
    if (ok) {
      console.log(`\nWorking config: host=${cfg.host} port=${cfg.port} user=${cfg.user}`);
      break;
    }
  }
})();
