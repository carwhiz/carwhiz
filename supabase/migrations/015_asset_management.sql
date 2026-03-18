-- Migration 015: Asset Management System
-- ========================================
-- Complete fixed asset management as per Indian Accounting Standards
-- (Ind AS 16 - Property, Plant & Equipment)
-- Tables: asset_categories, assets, asset_depreciation
-- Depreciation Methods: SLM (Straight Line) & WDV (Written Down Value) per Companies Act 2013

-- 1. asset_categories (grouping of fixed assets)
CREATE TABLE IF NOT EXISTS public.asset_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  default_useful_life_years NUMERIC(5,2) DEFAULT 5,
  default_depreciation_method TEXT DEFAULT 'SLM' CHECK (default_depreciation_method IN ('SLM', 'WDV')),
  default_depreciation_rate NUMERIC(5,2) DEFAULT 10,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID
);

ALTER TABLE public.asset_categories ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='asset_categories' AND policyname='ac_anon_full') THEN
    CREATE POLICY ac_anon_full ON public.asset_categories FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='asset_categories' AND policyname='ac_service_full') THEN
    CREATE POLICY ac_service_full ON public.asset_categories FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Seed standard asset categories as per Companies Act 2013 Schedule II
INSERT INTO public.asset_categories (name, description, default_useful_life_years, default_depreciation_method, default_depreciation_rate, sort_order) VALUES
  ('Building',                   'Factory, Office, Warehouse buildings',       30,   'SLM', 3.34,  1),
  ('Plant & Machinery',         'Workshop equipment, lifts, hoists',           15,   'SLM', 6.33,  2),
  ('Furniture & Fixtures',      'Office & workshop furniture',                 10,   'SLM', 10.00, 3),
  ('Vehicles',                  'Company owned vehicles',                       8,   'WDV', 25.89, 4),
  ('Computer & Electronics',    'Computers, printers, servers, phones',         3,   'SLM', 31.67, 5),
  ('Office Equipment',          'Air conditioners, water coolers, etc.',       5,   'SLM', 19.00, 6),
  ('Electrical Installation',   'Wiring, panels, power backup',               10,   'SLM', 9.50,  7),
  ('Tools & Dies',              'Specialized tools, moulds',                    8,   'SLM', 11.88, 8),
  ('Intangible Assets',         'Software, licenses, patents',                  3,   'SLM', 31.67, 9),
  ('Land',                      'Freehold / Leasehold land',                    0,   'SLM', 0.00, 10)
ON CONFLICT (name) DO NOTHING;

-- 2. assets (main asset register)
CREATE TABLE IF NOT EXISTS public.assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_code TEXT NOT NULL UNIQUE,
  asset_name TEXT NOT NULL,
  asset_category_id UUID REFERENCES public.asset_categories(id),
  description TEXT,

  -- Purchase / Acquisition details
  purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
  vendor_id UUID REFERENCES public.vendors(id),
  invoice_no TEXT,
  invoice_date DATE,
  purchase_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
  installation_cost NUMERIC(14,2) DEFAULT 0,
  other_cost NUMERIC(14,2) DEFAULT 0,
  total_cost NUMERIC(14,2) GENERATED ALWAYS AS (purchase_cost + installation_cost + other_cost) STORED,

  -- Bill / Document
  bill_file_path TEXT,

  -- Depreciation settings
  depreciation_method TEXT DEFAULT 'SLM' CHECK (depreciation_method IN ('SLM', 'WDV')),
  useful_life_years NUMERIC(5,2) DEFAULT 5,
  residual_value NUMERIC(14,2) DEFAULT 0,
  depreciation_rate NUMERIC(5,2) DEFAULT 10,

  -- Computed running values (updated by depreciation runs)
  accumulated_depreciation NUMERIC(14,2) DEFAULT 0,
  written_down_value NUMERIC(14,2) DEFAULT 0,

  -- Ledger link
  asset_ledger_id UUID REFERENCES public.ledger(id),

  -- Location / details
  location TEXT,
  serial_number TEXT,
  warranty_expiry DATE,

  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'disposed', 'written_off', 'under_maintenance')),
  disposal_date DATE,
  disposal_amount NUMERIC(14,2) DEFAULT 0,
  disposal_narration TEXT,

  -- Payment
  payment_mode_id UUID REFERENCES public.payment_modes(id),
  cash_bank_ledger_id UUID REFERENCES public.ledger(id),
  paid_amount NUMERIC(14,2) DEFAULT 0,
  balance_due NUMERIC(14,2) DEFAULT 0,

  -- Audit
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID,
  updated_by UUID
);

ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='assets' AND policyname='assets_anon_full') THEN
    CREATE POLICY assets_anon_full ON public.assets FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='assets' AND policyname='assets_service_full') THEN
    CREATE POLICY assets_service_full ON public.assets FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 3. asset_depreciation (depreciation log per asset per period)
CREATE TABLE IF NOT EXISTS public.asset_depreciation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  financial_year TEXT NOT NULL,
  period_from DATE NOT NULL,
  period_to DATE NOT NULL,
  opening_wdv NUMERIC(14,2) DEFAULT 0,
  depreciation_amount NUMERIC(14,2) DEFAULT 0,
  closing_wdv NUMERIC(14,2) DEFAULT 0,
  method TEXT NOT NULL CHECK (method IN ('SLM', 'WDV')),
  rate NUMERIC(5,2) DEFAULT 0,
  days_used INT DEFAULT 365,
  ledger_entry_id UUID,
  posted BOOLEAN DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID,
  UNIQUE(asset_id, financial_year)
);

ALTER TABLE public.asset_depreciation ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='asset_depreciation' AND policyname='ad_anon_full') THEN
    CREATE POLICY ad_anon_full ON public.asset_depreciation FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='asset_depreciation' AND policyname='ad_service_full') THEN
    CREATE POLICY ad_service_full ON public.asset_depreciation FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 4. Sequence for asset codes
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'asset_code_seq') THEN
    CREATE SEQUENCE public.asset_code_seq START WITH 1 INCREMENT BY 1;
  END IF;
END $$;

-- 5. Ensure "Depreciation Account" expense ledger exists
DO $$
DECLARE
  v_type_id UUID;
  v_cat_id UUID;
BEGIN
  SELECT id INTO v_type_id FROM public.ledger_types WHERE name = 'Expense' LIMIT 1;
  SELECT id INTO v_cat_id FROM public.ledger_categories WHERE name = 'Expense' LIMIT 1;
  INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, opening_balance, status)
  VALUES ('Depreciation Account', v_type_id, v_cat_id, 0, 'active')
  ON CONFLICT DO NOTHING;
END $$;

-- 6. Ensure "Accumulated Depreciation" asset contra ledger exists
DO $$
DECLARE
  v_type_id UUID;
  v_cat_id UUID;
BEGIN
  SELECT id INTO v_type_id FROM public.ledger_types WHERE name = 'Asset' LIMIT 1;
  SELECT id INTO v_cat_id FROM public.ledger_categories WHERE name = 'Asset' LIMIT 1;
  INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, opening_balance, status)
  VALUES ('Accumulated Depreciation', v_type_id, v_cat_id, 0, 'active')
  ON CONFLICT DO NOTHING;
END $$;

-- 7. Audit triggers for asset tables
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_asset_categories') THEN
    CREATE TRIGGER trg_audit_asset_categories
      AFTER INSERT OR UPDATE OR DELETE ON public.asset_categories
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_assets') THEN
    CREATE TRIGGER trg_audit_assets
      AFTER INSERT OR UPDATE OR DELETE ON public.assets
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_asset_depreciation') THEN
    CREATE TRIGGER trg_audit_asset_depreciation
      AFTER INSERT OR UPDATE OR DELETE ON public.asset_depreciation
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;
