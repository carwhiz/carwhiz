-- Migration 006: Ledger management expansion
-- =============================================
-- Adds: ledger_categories, expense_categories, employees, employee_documents
-- Updates: ledger table (new columns), ledger_types (more seeds)

-- 1. ledger_categories (for grouping/filtering ledgers by party or role)
CREATE TABLE IF NOT EXISTS public.ledger_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ledger_categories ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger_categories' AND policyname='lc_anon_full') THEN
    CREATE POLICY lc_anon_full ON public.ledger_categories FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ledger_categories' AND policyname='lc_service_full') THEN
    CREATE POLICY lc_service_full ON public.ledger_categories FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

INSERT INTO public.ledger_categories (name, sort_order) VALUES
  ('Customer', 1),
  ('Vendor', 2),
  ('Employee', 3),
  ('Bank', 4),
  ('Cash', 5),
  ('Expense', 6),
  ('Operational Expense', 7),
  ('Income', 8),
  ('Asset', 9),
  ('Liability', 10),
  ('Equity', 11),
  ('Other', 12)
ON CONFLICT (name) DO NOTHING;

-- 2. expense_categories (IFRS-style, expandable)
CREATE TABLE IF NOT EXISTS public.expense_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='expense_categories' AND policyname='ec_anon_full') THEN
    CREATE POLICY ec_anon_full ON public.expense_categories FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='expense_categories' AND policyname='ec_service_full') THEN
    CREATE POLICY ec_service_full ON public.expense_categories FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

INSERT INTO public.expense_categories (name) VALUES
  ('Cost of Sales'),
  ('Salaries and Wages'),
  ('Rent Expense'),
  ('Utilities Expense'),
  ('Repairs and Maintenance'),
  ('Office Expense'),
  ('Administrative Expense'),
  ('Selling and Distribution Expense'),
  ('Marketing Expense'),
  ('Transportation Expense'),
  ('Fuel Expense'),
  ('Insurance Expense'),
  ('Depreciation Expense'),
  ('Amortization Expense'),
  ('Bank Charges'),
  ('Interest Expense'),
  ('Professional Fees'),
  ('Communication Expense'),
  ('IT and Software Expense'),
  ('Training Expense'),
  ('Travel Expense'),
  ('Miscellaneous Expense')
ON CONFLICT (name) DO NOTHING;

-- 3. Add more ledger_types (IFRS-style, scalable)
INSERT INTO public.ledger_types (name, category, sort_order) VALUES
  ('Expense', 'expense', 3),
  ('Operational Expense', 'expense', 4),
  ('Bank', 'asset', 5),
  ('Cash', 'asset', 6),
  ('Revenue', 'revenue', 7),
  ('Asset', 'asset', 8),
  ('Liability', 'liability', 9),
  ('Equity', 'equity', 10),
  ('Other', NULL, 11)
ON CONFLICT (name) DO NOTHING;

-- 4. Alter ledger table: add ledger_category_id, bank_account_number, expense_category_id
ALTER TABLE public.ledger ADD COLUMN IF NOT EXISTS ledger_category_id UUID REFERENCES public.ledger_categories(id);
ALTER TABLE public.ledger ADD COLUMN IF NOT EXISTS bank_account_number TEXT;
ALTER TABLE public.ledger ADD COLUMN IF NOT EXISTS expense_category_id UUID REFERENCES public.expense_categories(id);

-- 5. employees
CREATE TABLE IF NOT EXISTS public.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_name TEXT NOT NULL,
  ledger_id UUID REFERENCES public.ledger(id),
  ledger_type_id UUID REFERENCES public.ledger_types(id),
  joining_date DATE,
  salary NUMERIC(14,2),
  aadhaar_number TEXT,
  aadhaar_file_path TEXT,
  cv_file_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employees' AND policyname='emp_anon_full') THEN
    CREATE POLICY emp_anon_full ON public.employees FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employees' AND policyname='emp_service_full') THEN
    CREATE POLICY emp_service_full ON public.employees FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 6. employee_documents (multiple docs per employee)
CREATE TABLE IF NOT EXISTS public.employee_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_type TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.employee_documents ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employee_documents' AND policyname='ed_anon_full') THEN
    CREATE POLICY ed_anon_full ON public.employee_documents FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employee_documents' AND policyname='ed_service_full') THEN
    CREATE POLICY ed_service_full ON public.employee_documents FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 7. Storage bucket for employee files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('employee-files', 'employee-files', true, 524288000, NULL)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='employee_files_select') THEN
    CREATE POLICY employee_files_select ON storage.objects FOR SELECT TO anon, service_role USING (bucket_id = 'employee-files');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='employee_files_insert') THEN
    CREATE POLICY employee_files_insert ON storage.objects FOR INSERT TO anon, service_role WITH CHECK (bucket_id = 'employee-files');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='employee_files_update') THEN
    CREATE POLICY employee_files_update ON storage.objects FOR UPDATE TO anon, service_role USING (bucket_id = 'employee-files');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='employee_files_delete') THEN
    CREATE POLICY employee_files_delete ON storage.objects FOR DELETE TO anon, service_role USING (bucket_id = 'employee-files');
  END IF;
END $$;
