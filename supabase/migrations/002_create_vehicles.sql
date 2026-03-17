-- ============================================================
-- MIGRATION 002: Vehicles & Master Data Tables
-- Creates: makes, generations, generation_types, variants,
--          gearboxes, fuel_types, body_sides, vehicles
-- RLS: Full access for anon and service_role
-- ============================================================

-- 1. MAKES
CREATE TABLE IF NOT EXISTS public.makes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.makes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "makes_anon_all" ON public.makes FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "makes_service_all" ON public.makes FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 2. GENERATIONS
CREATE TABLE IF NOT EXISTS public.generations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.generations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "generations_anon_all" ON public.generations FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "generations_service_all" ON public.generations FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 3. GENERATION TYPES
CREATE TABLE IF NOT EXISTS public.generation_types (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.generation_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "generation_types_anon_all" ON public.generation_types FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "generation_types_service_all" ON public.generation_types FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 4. VARIANTS
CREATE TABLE IF NOT EXISTS public.variants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.variants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "variants_anon_all" ON public.variants FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "variants_service_all" ON public.variants FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 5. GEARBOXES
CREATE TABLE IF NOT EXISTS public.gearboxes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.gearboxes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "gearboxes_anon_all" ON public.gearboxes FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "gearboxes_service_all" ON public.gearboxes FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 6. FUEL TYPES
CREATE TABLE IF NOT EXISTS public.fuel_types (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.fuel_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "fuel_types_anon_all" ON public.fuel_types FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "fuel_types_service_all" ON public.fuel_types FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 7. BODY SIDES
CREATE TABLE IF NOT EXISTS public.body_sides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.body_sides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "body_sides_anon_all" ON public.body_sides FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "body_sides_service_all" ON public.body_sides FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 8. VEHICLES (references all master tables)
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  model_name TEXT NOT NULL,
  make_id UUID REFERENCES public.makes(id),
  generation_id UUID REFERENCES public.generations(id),
  generation_type_id UUID REFERENCES public.generation_types(id),
  variant_id UUID REFERENCES public.variants(id),
  gearbox_id UUID REFERENCES public.gearboxes(id),
  fuel_type_id UUID REFERENCES public.fuel_types(id),
  body_side_id UUID REFERENCES public.body_sides(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "vehicles_anon_all" ON public.vehicles FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "vehicles_service_all" ON public.vehicles FOR ALL TO service_role USING (true) WITH CHECK (true);
