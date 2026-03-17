-- ============================================================
-- MIGRATION 003: Products, Units & Storage
-- Creates: units, products
-- RLS: Full access for anon and service_role
-- Storage: product-files bucket
-- ============================================================

-- 1. UNITS (master table)
CREATE TABLE IF NOT EXISTS public.units (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
CREATE POLICY "units_anon_all" ON public.units FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "units_service_all" ON public.units FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 2. PRODUCTS
CREATE TABLE IF NOT EXISTS public.products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_name TEXT NOT NULL,
  product_type TEXT NOT NULL CHECK (product_type IN ('product', 'service', 'consumable')),
  applicability TEXT CHECK (applicability IN ('universal', 'specific')),
  vehicle_id UUID REFERENCES public.vehicles(id),
  unit_id UUID REFERENCES public.units(id),
  unit_qty NUMERIC(12,2),
  current_cost NUMERIC(12,2),
  sales_price NUMERIC(12,2),
  first_level_discount NUMERIC(5,2),
  second_level_discount NUMERIC(5,2),
  third_level_discount NUMERIC(5,2),
  file_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "products_anon_all" ON public.products FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "products_service_all" ON public.products FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 3. STORAGE BUCKET for product files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-files',
  'product-files',
  true,
  524288000,  -- 500MB max
  NULL        -- allow all file types
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS policies
CREATE POLICY "product_files_anon_select" ON storage.objects FOR SELECT TO anon USING (bucket_id = 'product-files');
CREATE POLICY "product_files_anon_insert" ON storage.objects FOR INSERT TO anon WITH CHECK (bucket_id = 'product-files');
CREATE POLICY "product_files_anon_update" ON storage.objects FOR UPDATE TO anon USING (bucket_id = 'product-files');
CREATE POLICY "product_files_anon_delete" ON storage.objects FOR DELETE TO anon USING (bucket_id = 'product-files');
CREATE POLICY "product_files_service_select" ON storage.objects FOR SELECT TO service_role USING (bucket_id = 'product-files');
CREATE POLICY "product_files_service_insert" ON storage.objects FOR INSERT TO service_role WITH CHECK (bucket_id = 'product-files');
CREATE POLICY "product_files_service_update" ON storage.objects FOR UPDATE TO service_role USING (bucket_id = 'product-files');
CREATE POLICY "product_files_service_delete" ON storage.objects FOR DELETE TO service_role USING (bucket_id = 'product-files');
