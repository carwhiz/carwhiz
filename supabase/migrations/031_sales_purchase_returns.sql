-- Migration 031: Sales & Purchase Returns
-- ===================================
-- Tables: sales_returns, sales_return_items, purchase_returns, purchase_return_items

-- 1. sales_returns
CREATE TABLE IF NOT EXISTS public.sales_returns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  return_no TEXT NOT NULL UNIQUE,
  return_date DATE NOT NULL DEFAULT CURRENT_DATE,
  original_bill_id UUID NOT NULL REFERENCES public.sales(id),
  customer_id UUID NOT NULL REFERENCES public.customers(id),
  ledger_id UUID REFERENCES public.ledger(id),
  subtotal NUMERIC(14,2) DEFAULT 0,
  discount_total NUMERIC(14,2) DEFAULT 0,
  net_total NUMERIC(14,2) DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES public.users(id),
  updated_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.sales_returns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sr_anon_full ON public.sales_returns;
CREATE POLICY sr_anon_full ON public.sales_returns FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS sr_service_full ON public.sales_returns;
CREATE POLICY sr_service_full ON public.sales_returns FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 2. sales_return_items
CREATE TABLE IF NOT EXISTS public.sales_return_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_return_id UUID NOT NULL REFERENCES public.sales_returns(id) ON DELETE CASCADE,
  sales_item_id UUID NOT NULL REFERENCES public.sales_items(id),
  product_id UUID REFERENCES public.products(id),
  qty NUMERIC(14,3) DEFAULT 1,
  rate NUMERIC(14,2) DEFAULT 0,
  line_total NUMERIC(14,2) DEFAULT 0,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.sales_return_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sri_anon_full ON public.sales_return_items;
CREATE POLICY sri_anon_full ON public.sales_return_items FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS sri_service_full ON public.sales_return_items;
CREATE POLICY sri_service_full ON public.sales_return_items FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 3. purchase_returns
CREATE TABLE IF NOT EXISTS public.purchase_returns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  return_no TEXT NOT NULL UNIQUE,
  return_date DATE NOT NULL DEFAULT CURRENT_DATE,
  original_invoice_id UUID NOT NULL REFERENCES public.purchases(id),
  vendor_id UUID NOT NULL REFERENCES public.vendors(id),
  ledger_id UUID REFERENCES public.ledger(id),
  subtotal NUMERIC(14,2) DEFAULT 0,
  discount_total NUMERIC(14,2) DEFAULT 0,
  net_total NUMERIC(14,2) DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES public.users(id),
  updated_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.purchase_returns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pr_anon_full ON public.purchase_returns;
CREATE POLICY pr_anon_full ON public.purchase_returns FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS pr_service_full ON public.purchase_returns;
CREATE POLICY pr_service_full ON public.purchase_returns FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 4. purchase_return_items
CREATE TABLE IF NOT EXISTS public.purchase_return_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_return_id UUID NOT NULL REFERENCES public.purchase_returns(id) ON DELETE CASCADE,
  purchase_item_id UUID NOT NULL REFERENCES public.purchase_items(id),
  product_id UUID REFERENCES public.products(id),
  qty NUMERIC(14,3) DEFAULT 1,
  rate NUMERIC(14,2) DEFAULT 0,
  line_total NUMERIC(14,2) DEFAULT 0,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.purchase_return_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pri_anon_full ON public.purchase_return_items;
CREATE POLICY pri_anon_full ON public.purchase_return_items FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS pri_service_full ON public.purchase_return_items;
CREATE POLICY pri_service_full ON public.purchase_return_items FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Add audit log triggers
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_sales_returns') THEN
    CREATE TRIGGER trg_audit_sales_returns AFTER INSERT OR UPDATE OR DELETE ON public.sales_returns
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_sales_return_items') THEN
    CREATE TRIGGER trg_audit_sales_return_items AFTER INSERT OR UPDATE OR DELETE ON public.sales_return_items
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_purchase_returns') THEN
    CREATE TRIGGER trg_audit_purchase_returns AFTER INSERT OR UPDATE OR DELETE ON public.purchase_returns
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_purchase_return_items') THEN
    CREATE TRIGGER trg_audit_purchase_return_items AFTER INSERT OR UPDATE OR DELETE ON public.purchase_return_items
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;
