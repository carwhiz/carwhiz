import pg from 'pg';

// Try multiple connection methods
const configs = [
  {
    name: 'Supavisor Session (ap-south-1, port 5432)',
    host: 'aws-0-ap-south-1.pooler.supabase.com',
    port: 5432, database: 'postgres',
    user: 'postgres.jlnntevahhmgzrkhuuta',
    password: '@Alzaidy123',
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
  },
  {
    name: 'Supavisor Transaction (ap-south-1, port 6543)',
    host: 'aws-0-ap-south-1.pooler.supabase.com',
    port: 6543, database: 'postgres',
    user: 'postgres.jlnntevahhmgzrkhuuta',
    password: '@Alzaidy123',
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
  },
  {
    name: 'Direct IPv6',
    host: '2406:da12:b78:de17:8b74:cdeb:3d5a:b00f',
    port: 5432, database: 'postgres',
    user: 'postgres',
    password: '@Alzaidy123',
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
  },
];

async function main() {
  for (const cfg of configs) {
    const { name, ...pgCfg } = cfg;
    console.log(`\nTrying: ${name} (${cfg.host}:${cfg.port})...`);
    const client = new pg.Client(pgCfg);
    try {
      await client.connect();
      console.log('CONNECTED!');
      const res = await client.query('SELECT current_database(), current_user');
      console.log('Database:', res.rows[0].current_database, 'User:', res.rows[0].current_user);
      await client.end();
      console.log('\n*** USE THIS CONFIG ***');
      return;
    } catch (e) {
      console.log('FAILED:', e.message);
    }
  }
  console.log('\nAll connection methods failed.');
}

main();
