import pg from 'pg';

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
  console.log('Connected');

  await client.query(`
    CREATE TABLE IF NOT EXISTS public.brands (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL UNIQUE,
      created_at TIMESTAMPTZ DEFAULT now()
    );

    ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

    DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='brands' AND policyname='brands_anon_full') THEN
        CREATE POLICY brands_anon_full ON public.brands FOR ALL TO anon USING (true) WITH CHECK (true);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='brands' AND policyname='brands_service_full') THEN
        CREATE POLICY brands_service_full ON public.brands FOR ALL TO service_role USING (true) WITH CHECK (true);
      END IF;
    END $$;

    ALTER TABLE public.products ADD COLUMN IF NOT EXISTS part_number TEXT;
    ALTER TABLE public.products ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES public.brands(id);
  `);

  console.log('Done: brands table + part_number + brand_id columns added');
  await client.end();
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
