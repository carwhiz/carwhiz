import pg from 'pg';

// All known Supabase pooler regions
const regions = [
  'aws-0-ap-south-1',
  'aws-0-us-east-1', 
  'aws-0-us-west-1',
  'aws-0-eu-west-1',
  'aws-0-eu-central-1',
  'aws-0-ap-southeast-1',
  'aws-0-ap-northeast-1',
  'aws-0-sa-east-1',
  'aws-0-ca-central-1',
  'aws-0-eu-west-2',
  'aws-0-ap-southeast-2',
  'aws-0-eu-north-1',
  'aws-0-us-east-2',
  'aws-0-us-west-2',
  'aws-0-me-south-1',
  'aws-0-af-south-1',
];

async function main() {
  for (const region of regions) {
    const host = `${region}.pooler.supabase.com`;
    process.stdout.write(`${region}... `);
    const client = new pg.Client({
      host,
      port: 5432,
      database: 'postgres',
      user: 'postgres.jlnntevahhmgzrkhuuta',
      password: '@Alzaidy123',
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 8000,
    });
    try {
      await client.connect();
      console.log('CONNECTED!');
      const res = await client.query('SELECT 1 as ok');
      console.log('Query OK:', res.rows[0]);
      await client.end();
      console.log(`\n*** WORKING REGION: ${region} ***`);
      console.log(`Host: ${host}`);
      return;
    } catch (e) {
      console.log(e.message.substring(0, 60));
    }
  }
  console.log('\nNo region worked.');
}

main();
