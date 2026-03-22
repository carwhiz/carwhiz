-- Fix negative stock values by recalculating from stock_movements
-- This resets current_stock for all products based on the sum of stock_movements qty

UPDATE public.products p
SET current_stock = COALESCE(
  (SELECT SUM(sm.qty) FROM public.stock_movements sm WHERE sm.product_id = p.id),
  0
);

-- Log the correction
COMMENT ON TABLE public.products IS 'Products table - stock corrected on migration 034';
