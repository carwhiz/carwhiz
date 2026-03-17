-- Migration 008: Billing, Purchase, Receipt, Payment System
-- ==========================================================
-- Tables: payment_modes, sales, sales_items, purchases, purchase_items,
--         receipts, payments, stock_movements

-- 1. payment_modes
CREATE TABLE IF NOT EXISTS public.payment_modes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.payment_modes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='payment_modes' AND policyname='pm_anon_full') THEN
    CREATE POLICY pm_anon_full ON public.payment_modes FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='payment_modes' AND policyname='pm_service_full') THEN
    CREATE POLICY pm_service_full ON public.payment_modes FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

INSERT INTO public.payment_modes (name, sort_order) VALUES
  ('Cash', 1),
  ('Bank Transfer', 2),
  ('UPI', 3),
  ('Credit Card', 4),
  ('Debit Card', 5),
  ('Cheque', 6),
  ('Online / Net Banking', 7),
  ('Wallet', 8),
  ('Other', 9)
ON CONFLICT (name) DO NOTHING;

-- 2. sales
CREATE TABLE IF NOT EXISTS public.sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_no TEXT NOT NULL UNIQUE,
  bill_date DATE NOT NULL DEFAULT CURRENT_DATE,
  customer_id UUID REFERENCES public.customers(id),
  ledger_id UUID REFERENCES public.ledger(id),
  subtotal NUMERIC(14,2) DEFAULT 0,
  discount_total NUMERIC(14,2) DEFAULT 0,
  net_total NUMERIC(14,2) DEFAULT 0,
  paid_amount NUMERIC(14,2) DEFAULT 0,
  balance_due NUMERIC(14,2) DEFAULT 0,
  payment_mode_id UUID REFERENCES public.payment_modes(id),
  cash_bank_ledger_id UUID REFERENCES public.ledger(id),
  notes TEXT,
  status TEXT DEFAULT 'posted',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sales' AND policyname='sales_anon_full') THEN
    CREATE POLICY sales_anon_full ON public.sales FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sales' AND policyname='sales_service_full') THEN
    CREATE POLICY sales_service_full ON public.sales FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 3. sales_items
CREATE TABLE IF NOT EXISTS public.sales_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id),
  barcode TEXT,
  unit_id UUID REFERENCES public.units(id),
  qty NUMERIC(14,3) DEFAULT 1,
  rate NUMERIC(14,2) DEFAULT 0,
  discount NUMERIC(14,2) DEFAULT 0,
  line_total NUMERIC(14,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.sales_items ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sales_items' AND policyname='si_anon_full') THEN
    CREATE POLICY si_anon_full ON public.sales_items FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sales_items' AND policyname='si_service_full') THEN
    CREATE POLICY si_service_full ON public.sales_items FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 4. purchases
CREATE TABLE IF NOT EXISTS public.purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no TEXT NOT NULL UNIQUE,
  invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
  vendor_id UUID REFERENCES public.vendors(id),
  ledger_id UUID REFERENCES public.ledger(id),
  subtotal NUMERIC(14,2) DEFAULT 0,
  discount_total NUMERIC(14,2) DEFAULT 0,
  net_total NUMERIC(14,2) DEFAULT 0,
  paid_amount NUMERIC(14,2) DEFAULT 0,
  balance_due NUMERIC(14,2) DEFAULT 0,
  payment_mode_id UUID REFERENCES public.payment_modes(id),
  cash_bank_ledger_id UUID REFERENCES public.ledger(id),
  notes TEXT,
  status TEXT DEFAULT 'posted',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='purchases' AND policyname='pur_anon_full') THEN
    CREATE POLICY pur_anon_full ON public.purchases FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='purchases' AND policyname='pur_service_full') THEN
    CREATE POLICY pur_service_full ON public.purchases FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 5. purchase_items
CREATE TABLE IF NOT EXISTS public.purchase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID NOT NULL REFERENCES public.purchases(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id),
  barcode TEXT,
  unit_id UUID REFERENCES public.units(id),
  qty NUMERIC(14,3) DEFAULT 1,
  rate NUMERIC(14,2) DEFAULT 0,
  discount NUMERIC(14,2) DEFAULT 0,
  line_total NUMERIC(14,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.purchase_items ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='purchase_items' AND policyname='pi_anon_full') THEN
    CREATE POLICY pi_anon_full ON public.purchase_items FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='purchase_items' AND policyname='pi_service_full') THEN
    CREATE POLICY pi_service_full ON public.purchase_items FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 6. receipts
CREATE TABLE IF NOT EXISTS public.receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_no TEXT NOT NULL UNIQUE,
  receipt_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ledger_id UUID REFERENCES public.ledger(id),
  customer_id UUID REFERENCES public.customers(id),
  sales_id UUID REFERENCES public.sales(id),
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  payment_mode_id UUID REFERENCES public.payment_modes(id),
  cash_bank_ledger_id UUID REFERENCES public.ledger(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='receipts' AND policyname='rec_anon_full') THEN
    CREATE POLICY rec_anon_full ON public.receipts FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='receipts' AND policyname='rec_service_full') THEN
    CREATE POLICY rec_service_full ON public.receipts FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 7. payments
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_no TEXT NOT NULL UNIQUE,
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ledger_id UUID REFERENCES public.ledger(id),
  vendor_id UUID REFERENCES public.vendors(id),
  purchase_id UUID REFERENCES public.purchases(id),
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  payment_mode_id UUID REFERENCES public.payment_modes(id),
  cash_bank_ledger_id UUID REFERENCES public.ledger(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='payments' AND policyname='pay_anon_full') THEN
    CREATE POLICY pay_anon_full ON public.payments FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='payments' AND policyname='pay_service_full') THEN
    CREATE POLICY pay_service_full ON public.payments FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 8. stock_movements (for future stock tracking)
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id),
  movement_type TEXT NOT NULL, -- 'sale', 'purchase', 'return', 'adjustment'
  reference_type TEXT,         -- 'sales', 'purchases'
  reference_id UUID,
  qty NUMERIC(14,3) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stock_movements' AND policyname='sm_anon_full') THEN
    CREATE POLICY sm_anon_full ON public.stock_movements FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stock_movements' AND policyname='sm_service_full') THEN
    CREATE POLICY sm_service_full ON public.stock_movements FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 9. Sequence helpers for auto-generating bill/invoice/receipt/payment numbers
CREATE SEQUENCE IF NOT EXISTS public.sales_bill_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.purchase_inv_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.receipt_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.payment_seq START 1;
