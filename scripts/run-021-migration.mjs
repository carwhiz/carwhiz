import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Run migration 021 - Mobile Dashboard Permissions
const sqlPath = join(__dirname, '..', 'supabase', 'migrations', '021_mobile_dashboard_permissions.sql');
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
  console.log('Connecting to Supabase PostgreSQL...');
  await client.connect();
  console.log('Connected!\n');

  console.log('Running migration 021: Mobile Dashboard Permissions...');
  await client.query(sql);
  console.log('✓ Migration 021 executed successfully!\n');

  // Verify the permissions were created
  const verifyQuery = `
    SELECT resource, COUNT(*) as user_count, 
           SUM(CASE WHEN can_view THEN 1 ELSE 0 END) as can_view_count
    FROM public.permissions
    WHERE resource LIKE 'mobile-dashboard-%'
    GROUP BY resource
    ORDER BY resource;
  `;

  const result = await client.query(verifyQuery);
  
  if (result.rows.length > 0) {
    console.log('Mobile dashboard permissions created:');
    console.log('-'.repeat(70));
    console.log('Resource'.padEnd(35), 'Users'.padEnd(10), 'Can View');
    console.log('-'.repeat(70));
    for (const row of result.rows) {
      console.log(
        row.resource.padEnd(35),
        String(row.user_count).padEnd(10),
        row.can_view_count
      );
    }
    console.log('-'.repeat(70));
    console.log(`\n✅ Total mobile card resources: ${result.rows.length}`);
  } else {
    console.log('⚠️  No mobile dashboard permissions found. Check migration output above.');
  }

  await client.end();
  console.log('\nDone!');
}

run().catch(async (err) => {
  console.error('Migration failed:', err.message);
  try { await client.end(); } catch {}
  process.exit(1);
});
