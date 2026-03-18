-- Migration 010: RPC for creating a product in a single round-trip
-- ================================================================

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
  p_file_path TEXT DEFAULT NULL
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
    barcode, part_number, brand_id, expiry_date, file_path
  ) VALUES (
    p_product_name, p_product_type, p_applicability, p_vehicle_id,
    p_unit_id, p_unit_qty, p_current_cost, p_sales_price,
    p_first_level_discount, p_second_level_discount, p_third_level_discount,
    p_barcode, p_part_number, p_brand_id, p_expiry_date, p_file_path
  )
  RETURNING * INTO new_product;

  RETURN json_build_object(
    'id', new_product.id,
    'product_name', new_product.product_name,
    'product_type', new_product.product_type
  );
END;
$$;
