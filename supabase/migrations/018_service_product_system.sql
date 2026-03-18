-- Migration 018: Service Product System
-- ======================================
-- Allows "service" type products to include:
--   - Multiple consumable/product components with qty
--   - Labor charge and additional charges
-- When a service is sold, stock of components is reduced
-- without unit_qty multiplication (component qty is in pieces).

-- ============================================================
-- 1. Add labor_charge and additional_charges to products table
-- ============================================================
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS labor_charge NUMERIC(12,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS additional_charges NUMERIC(12,2) DEFAULT 0;

-- ============================================================
-- 2. product_components table (BOM for service products)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.product_components (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  component_product_id UUID NOT NULL REFERENCES public.products(id),
  qty NUMERIC(12,2) NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES public.users(id)
);

ALTER TABLE public.product_components ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pc_anon_full ON public.product_components;
CREATE POLICY pc_anon_full ON public.product_components FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS pc_service_full ON public.product_components;
CREATE POLICY pc_service_full ON public.product_components FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- 3. Audit trigger for product_components
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_product_components') THEN
    CREATE TRIGGER trg_audit_product_components
      AFTER INSERT OR UPDATE OR DELETE ON public.product_components
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;

-- ============================================================
-- 4. Update unit_qty trigger — skip for service_sale movements
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_stock_movement_unit_qty()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_unit_qty NUMERIC;
BEGIN
  -- Skip unit_qty multiplication for service component movements
  IF NEW.movement_type = 'service_sale' THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(unit_qty, 1) INTO v_unit_qty
  FROM public.products
  WHERE id = NEW.product_id;

  NEW.qty := NEW.qty * v_unit_qty;
  RETURN NEW;
END;
$$;

-- ============================================================
-- 5. Update create_product RPC to support new columns
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
  p_created_by UUID DEFAULT NULL,
  p_current_stock NUMERIC DEFAULT 0,
  p_minimum_stock NUMERIC DEFAULT 0,
  p_maximum_stock NUMERIC DEFAULT 0,
  p_reorder_level NUMERIC DEFAULT 0,
  p_labor_charge NUMERIC DEFAULT 0,
  p_additional_charges NUMERIC DEFAULT 0
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
    barcode, part_number, brand_id, expiry_date, file_path,
    created_by, current_stock, minimum_stock, maximum_stock, reorder_level,
    labor_charge, additional_charges
  ) VALUES (
    p_product_name, p_product_type, p_applicability, p_vehicle_id,
    p_unit_id, p_unit_qty, p_current_cost, p_sales_price,
    p_first_level_discount, p_second_level_discount, p_third_level_discount,
    p_barcode, p_part_number, p_brand_id, p_expiry_date, p_file_path,
    p_created_by, p_current_stock, p_minimum_stock, p_maximum_stock, p_reorder_level,
    p_labor_charge, p_additional_charges
  )
  RETURNING * INTO new_product;

  RETURN json_build_object(
    'id', new_product.id,
    'product_name', new_product.product_name,
    'product_type', new_product.product_type
  );
END;
$$;
