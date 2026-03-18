-- Migration 011: Ledger Entries (Double-Entry Accounting Journal)
-- ==============================================================
-- Records all debit/credit transactions against ledger accounts.
-- Every financial operation (sale, purchase, receipt, payment)
-- should create corresponding ledger entries.

CREATE TABLE IF NOT EXISTS public.ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ledger_id UUID NOT NULL REFERENCES public.ledger(id),
  debit NUMERIC(14,2) DEFAULT 0,
  credit NUMERIC(14,2) DEFAULT 0,
  narration TEXT,
  reference_type TEXT,   -- 'sales', 'purchases', 'receipts', 'payments'
  reference_id UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger_entries' AND policyname='le_anon_full') THEN
    CREATE POLICY le_anon_full ON public.ledger_entries FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger_entries' AND policyname='le_service_full') THEN
    CREATE POLICY le_service_full ON public.ledger_entries FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Index for fast lookups by ledger and reference
CREATE INDEX IF NOT EXISTS idx_le_ledger_id ON public.ledger_entries(ledger_id);
CREATE INDEX IF NOT EXISTS idx_le_reference ON public.ledger_entries(reference_type, reference_id);
