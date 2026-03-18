-- Migration 013: Stock Management
-- ================================
-- 1. Add stock columns to products table
-- 2. Update products stock on purchase (increase) and sale (decrease) via trigger
-- 3. Initialize current_stock from existing stock_movements

-- ============================================================
-- 1. Add stock columns to products table
-- ============================================================
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS current_stock NUMERIC(12,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS minimum_stock NUMERIC(12,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS maximum_stock NUMERIC(12,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS reorder_level NUMERIC(12,2) DEFAULT 0;

-- ============================================================
-- 2. Trigger function: Auto-update products.current_stock
--    on stock_movements insert
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_update_product_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.products
  SET current_stock = COALESCE(current_stock, 0) + NEW.qty
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$;

-- Attach trigger
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_product_stock') THEN
    CREATE TRIGGER trg_update_product_stock
    AFTER INSERT ON public.stock_movements
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_product_stock();
  END IF;
END $$;

-- ============================================================
-- 3. Initialize current_stock from existing stock_movements
-- ============================================================
UPDATE public.products p
SET current_stock = COALESCE(
  (SELECT SUM(sm.qty) FROM public.stock_movements sm WHERE sm.product_id = p.id),
  0
);

-- ============================================================
-- 4. Update create_product RPC to accept stock fields
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
  p_reorder_level NUMERIC DEFAULT 0
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
    barcode, part_number, brand_id, expiry_date, file_path, created_by,
    current_stock, minimum_stock, maximum_stock, reorder_level
  ) VALUES (
    p_product_name, p_product_type, p_applicability, p_vehicle_id,
    p_unit_id, p_unit_qty, p_current_cost, p_sales_price,
    p_first_level_discount, p_second_level_discount, p_third_level_discount,
    p_barcode, p_part_number, p_brand_id, p_expiry_date, p_file_path, p_created_by,
    p_current_stock, p_minimum_stock, p_maximum_stock, p_reorder_level
  )
  RETURNING * INTO new_product;

  RETURN json_build_object(
    'id', new_product.id,
    'product_name', new_product.product_name,
    'product_type', new_product.product_type
  );
END;
$$;
