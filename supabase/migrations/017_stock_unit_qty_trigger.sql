-- Migration 017: Database-level unit_qty handling for stock movements
-- ==================================================================
-- Moves unit_qty multiplication from frontend to database trigger.
-- When a stock movement is inserted, the qty is automatically
-- multiplied by the product's unit_qty (e.g. 1 Box = 5 LTR → qty × 5).
--
-- Frontend now just inserts raw qty (units purchased/sold).
-- The BEFORE INSERT trigger converts it to actual pieces.
-- The existing AFTER INSERT trigger (fn_update_product_stock) then
-- adds the correct piece qty to products.current_stock.

-- ============================================================
-- 1. BEFORE INSERT trigger: multiply qty by product's unit_qty
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_stock_movement_unit_qty()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_unit_qty NUMERIC;
BEGIN
  SELECT COALESCE(unit_qty, 1) INTO v_unit_qty
  FROM public.products
  WHERE id = NEW.product_id;

  NEW.qty := NEW.qty * v_unit_qty;
  RETURN NEW;
END;
$$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_stock_movement_unit_qty') THEN
    CREATE TRIGGER trg_stock_movement_unit_qty
    BEFORE INSERT ON public.stock_movements
    FOR EACH ROW EXECUTE FUNCTION public.fn_stock_movement_unit_qty();
  END IF;
END $$;
