-- Migration 012: Audit Log & Created By / Updated By
-- ==================================================
-- 1. Add created_by, updated_by to all transaction tables
-- 2. Create audit_log table for automatic change tracking
-- 3. Create trigger function for auto-logging changes

-- ============================================================
-- 1. Add created_by / updated_by columns (UUID references users)
-- ============================================================

-- Sales
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Purchases
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Receipts
ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Payments
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Ledger Entries
ALTER TABLE public.ledger_entries ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

-- Ledger
ALTER TABLE public.ledger ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.ledger ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Customers
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Vendors
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Products
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Vehicles
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Employees
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Sales Items
ALTER TABLE public.sales_items ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

-- Purchase Items
ALTER TABLE public.purchase_items ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

-- Stock Movements
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

-- Master Data Tables (AddMasterDataPopup / EditMasterDataPopup)
ALTER TABLE public.makes ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.makes ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.generations ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.generations ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.generation_types ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.generation_types ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.variants ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.variants ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.gearboxes ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.gearboxes ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.fuel_types ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.fuel_types ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.body_sides ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.body_sides ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.units ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.units ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.brands ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.brands ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

ALTER TABLE public.expense_categories ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);
ALTER TABLE public.expense_categories ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- ============================================================
-- 2. Audit Log Table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  record_id UUID,
  action TEXT NOT NULL,           -- 'INSERT', 'UPDATE', 'DELETE'
  old_data JSONB,                 -- previous row data (for UPDATE/DELETE)
  new_data JSONB,                 -- new row data (for INSERT/UPDATE)
  changed_by UUID REFERENCES public.users(id),
  changed_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='audit_log' AND policyname='audit_log_anon_full') THEN
    CREATE POLICY audit_log_anon_full ON public.audit_log FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='audit_log' AND policyname='audit_log_service_full') THEN
    CREATE POLICY audit_log_service_full ON public.audit_log FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_audit_log_table ON public.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_record ON public.audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON public.audit_log(changed_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_by ON public.audit_log(changed_by);

-- ============================================================
-- 3. Trigger Function: Auto-log INSERT, UPDATE, DELETE
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rec_id UUID;
  user_id UUID;
BEGIN
  -- Try to get record id
  IF TG_OP = 'DELETE' THEN
    rec_id := OLD.id;
  ELSE
    rec_id := NEW.id;
  END IF;

  -- Try to get user from created_by / updated_by (safely)
  BEGIN
    IF TG_OP = 'INSERT' THEN
      user_id := NEW.created_by;
    ELSIF TG_OP = 'UPDATE' THEN
      user_id := NEW.updated_by;
    ELSE
      user_id := OLD.updated_by;
    END IF;
  EXCEPTION WHEN undefined_column THEN
    -- Column doesn't exist on this table, use created_by as fallback
    BEGIN
      IF TG_OP = 'DELETE' THEN
        user_id := OLD.created_by;
      ELSE
        user_id := NEW.created_by;
      END IF;
    EXCEPTION WHEN undefined_column THEN
      user_id := NULL;
    END;
  END;

  INSERT INTO public.audit_log (table_name, record_id, action, old_data, new_data, changed_by)
  VALUES (
    TG_TABLE_NAME,
    rec_id,
    TG_OP,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
    user_id
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- ============================================================
-- 4. Attach Triggers to Transaction Tables
-- ============================================================
DO $$ BEGIN
  -- Sales
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_sales') THEN
    CREATE TRIGGER trg_audit_sales AFTER INSERT OR UPDATE OR DELETE ON public.sales
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Purchases
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_purchases') THEN
    CREATE TRIGGER trg_audit_purchases AFTER INSERT OR UPDATE OR DELETE ON public.purchases
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Receipts
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_receipts') THEN
    CREATE TRIGGER trg_audit_receipts AFTER INSERT OR UPDATE OR DELETE ON public.receipts
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Payments
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_payments') THEN
    CREATE TRIGGER trg_audit_payments AFTER INSERT OR UPDATE OR DELETE ON public.payments
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Ledger
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_ledger') THEN
    CREATE TRIGGER trg_audit_ledger AFTER INSERT OR UPDATE OR DELETE ON public.ledger
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Customers
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_customers') THEN
    CREATE TRIGGER trg_audit_customers AFTER INSERT OR UPDATE OR DELETE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Vendors
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_vendors') THEN
    CREATE TRIGGER trg_audit_vendors AFTER INSERT OR UPDATE OR DELETE ON public.vendors
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Products
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_products') THEN
    CREATE TRIGGER trg_audit_products AFTER INSERT OR UPDATE OR DELETE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Ledger Entries
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_ledger_entries') THEN
    CREATE TRIGGER trg_audit_ledger_entries AFTER INSERT OR UPDATE OR DELETE ON public.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Vehicles
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_vehicles') THEN
    CREATE TRIGGER trg_audit_vehicles AFTER INSERT OR UPDATE OR DELETE ON public.vehicles
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Employees
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_employees') THEN
    CREATE TRIGGER trg_audit_employees AFTER INSERT OR UPDATE OR DELETE ON public.employees
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Sales Items
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_sales_items') THEN
    CREATE TRIGGER trg_audit_sales_items AFTER INSERT OR UPDATE OR DELETE ON public.sales_items
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Purchase Items
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_purchase_items') THEN
    CREATE TRIGGER trg_audit_purchase_items AFTER INSERT OR UPDATE OR DELETE ON public.purchase_items
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Stock Movements
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_stock_movements') THEN
    CREATE TRIGGER trg_audit_stock_movements AFTER INSERT OR UPDATE OR DELETE ON public.stock_movements
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  -- Master Data Tables
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_makes') THEN
    CREATE TRIGGER trg_audit_makes AFTER INSERT OR UPDATE OR DELETE ON public.makes
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_generations') THEN
    CREATE TRIGGER trg_audit_generations AFTER INSERT OR UPDATE OR DELETE ON public.generations
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_generation_types') THEN
    CREATE TRIGGER trg_audit_generation_types AFTER INSERT OR UPDATE OR DELETE ON public.generation_types
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_variants') THEN
    CREATE TRIGGER trg_audit_variants AFTER INSERT OR UPDATE OR DELETE ON public.variants
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_gearboxes') THEN
    CREATE TRIGGER trg_audit_gearboxes AFTER INSERT OR UPDATE OR DELETE ON public.gearboxes
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_fuel_types') THEN
    CREATE TRIGGER trg_audit_fuel_types AFTER INSERT OR UPDATE OR DELETE ON public.fuel_types
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_body_sides') THEN
    CREATE TRIGGER trg_audit_body_sides AFTER INSERT OR UPDATE OR DELETE ON public.body_sides
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_units') THEN
    CREATE TRIGGER trg_audit_units AFTER INSERT OR UPDATE OR DELETE ON public.units
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_brands') THEN
    CREATE TRIGGER trg_audit_brands AFTER INSERT OR UPDATE OR DELETE ON public.brands
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_expense_categories') THEN
    CREATE TRIGGER trg_audit_expense_categories AFTER INSERT OR UPDATE OR DELETE ON public.expense_categories
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;

-- ============================================================
-- 5. Update create_product RPC to accept p_created_by
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_product(
  p_product_name TEXT,
  p_product_type TEXT,
  p_applicability TEXT DEFAULT NULL,
  p_vehicle_id UUID DEFAULT NULL,
  p_unit_id UUID DEFAULT NULL,
  p_unit_qty NUMERIC DEFAULT NULL,
  p_current_cost NUMERIC DEFAULT NULL,
  p_sales_price NUMERIC DEFAULT NULL,
  p_first_level_discount NUMERIC DEFAULT NULL,
  p_second_level_discount NUMERIC DEFAULT NULL,
  p_third_level_discount NUMERIC DEFAULT NULL,
  p_barcode TEXT DEFAULT NULL,
  p_part_number TEXT DEFAULT NULL,
  p_brand_id UUID DEFAULT NULL,
  p_expiry_date DATE DEFAULT NULL,
  p_file_path TEXT DEFAULT NULL,
  p_created_by UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_product public.products;
BEGIN
  INSERT INTO public.products (
    product_name, product_type, applicability, vehicle_id,
    unit_id, unit_qty, current_cost, sales_price,
    first_level_discount, second_level_discount, third_level_discount,
    barcode, part_number, brand_id, expiry_date, file_path, created_by
  ) VALUES (
    p_product_name, p_product_type, p_applicability, p_vehicle_id,
    p_unit_id, p_unit_qty, p_current_cost, p_sales_price,
    p_first_level_discount, p_second_level_discount, p_third_level_discount,
    p_barcode, p_part_number, p_brand_id, p_expiry_date, p_file_path, p_created_by
  )
  RETURNING * INTO new_product;

  RETURN json_build_object(
    'id', new_product.id,
    'product_name', new_product.product_name,
    'product_type', new_product.product_type
  );
END;
$$;
