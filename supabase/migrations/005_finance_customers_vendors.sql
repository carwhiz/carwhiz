-- Migration 005: Finance - Customers, Vendors, Ledger
-- ===================================================

-- 1. ledger_types (scalable for future IFRS account heads)
CREATE TABLE IF NOT EXISTS public.ledger_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  category TEXT,          -- e.g. 'asset','liability','equity','revenue','expense'
  parent_id UUID REFERENCES public.ledger_types(id),
  description TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ledger_types ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger_types' AND policyname='ledger_types_anon_full') THEN
    CREATE POLICY ledger_types_anon_full ON public.ledger_types FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger_types' AND policyname='ledger_types_service_full') THEN
    CREATE POLICY ledger_types_service_full ON public.ledger_types FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Seed default ledger types
INSERT INTO public.ledger_types (name, category, sort_order) VALUES
  ('Receivables', 'asset', 1),
  ('Payables', 'liability', 2)
ON CONFLICT (name) DO NOTHING;

-- 2. ledger (single ledger table for all account parties)
CREATE TABLE IF NOT EXISTS public.ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_name TEXT NOT NULL,
  ledger_type_id UUID REFERENCES public.ledger_types(id),
  reference_type TEXT,      -- 'customer', 'vendor', or future types
  reference_id UUID,        -- FK to customer or vendor id
  opening_balance NUMERIC(14,2) DEFAULT 0,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ledger ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger' AND policyname='ledger_anon_full') THEN
    CREATE POLICY ledger_anon_full ON public.ledger FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger' AND policyname='ledger_service_full') THEN
    CREATE POLICY ledger_service_full ON public.ledger FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 3. customers
CREATE TABLE IF NOT EXISTS public.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  place TEXT,
  gender TEXT,
  ledger_id UUID REFERENCES public.ledger(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='customers' AND policyname='customers_anon_full') THEN
    CREATE POLICY customers_anon_full ON public.customers FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='customers' AND policyname='customers_service_full') THEN
    CREATE POLICY customers_service_full ON public.customers FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 4. customer_phones
CREATE TABLE IF NOT EXISTS public.customer_phones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.customer_phones ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='customer_phones' AND policyname='customer_phones_anon_full') THEN
    CREATE POLICY customer_phones_anon_full ON public.customer_phones FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='customer_phones' AND policyname='customer_phones_service_full') THEN
    CREATE POLICY customer_phones_service_full ON public.customer_phones FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 5. customer_vehicle_numbers
CREATE TABLE IF NOT EXISTS public.customer_vehicle_numbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  vehicle_number TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.customer_vehicle_numbers ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='customer_vehicle_numbers' AND policyname='cvn_anon_full') THEN
    CREATE POLICY cvn_anon_full ON public.customer_vehicle_numbers FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='customer_vehicle_numbers' AND policyname='cvn_service_full') THEN
    CREATE POLICY cvn_service_full ON public.customer_vehicle_numbers FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 6. vendors
CREATE TABLE IF NOT EXISTS public.vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  state TEXT,
  district TEXT,
  place TEXT,
  pin_code TEXT,
  address_detail TEXT,
  email TEXT,
  ledger_id UUID REFERENCES public.ledger(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='vendors' AND policyname='vendors_anon_full') THEN
    CREATE POLICY vendors_anon_full ON public.vendors FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='vendors' AND policyname='vendors_service_full') THEN
    CREATE POLICY vendors_service_full ON public.vendors FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 7. vendor_phones
CREATE TABLE IF NOT EXISTS public.vendor_phones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.vendor_phones ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='vendor_phones' AND policyname='vendor_phones_anon_full') THEN
    CREATE POLICY vendor_phones_anon_full ON public.vendor_phones FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='vendor_phones' AND policyname='vendor_phones_service_full') THEN
    CREATE POLICY vendor_phones_service_full ON public.vendor_phones FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;
