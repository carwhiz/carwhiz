-- Migration 043: Add Extended Employee Fields
-- ==================================================
-- Add additional employee information columns to users table

-- ============================================================
-- 1. Add new columns to users table
-- ============================================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS blood_group VARCHAR(5);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS education TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS joining_date DATE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS driving_license_number VARCHAR(100);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS aadhar_number VARCHAR(20);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS basic_salary NUMERIC(12, 2) DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS resident_location TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS cv_document_url TEXT;

-- ============================================================
-- 2. Add audit fields if not already present
-- ============================================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- ============================================================
-- 3. Create RPC function to fetch employees (bypasses 1000 row limit)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_employees_extended()
RETURNS TABLE (
  id uuid,
  email text,
  user_name text,
  phone_number text,
  role text,
  created_at timestamptz,
  date_of_birth date,
  blood_group varchar,
  education text,
  joining_date date,
  driving_license_number varchar,
  aadhar_number varchar,
  bank_account_number varchar,
  bank_name varchar,
  basic_salary numeric,
  resident_location text,
  cv_document_url text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    u.id,
    u.email,
    u.user_name,
    u.phone_number,
    u.role,
    u.created_at,
    u.date_of_birth,
    u.blood_group,
    u.education,
    u.joining_date,
    u.driving_license_number,
    u.aadhar_number,
    u.bank_account_number,
    u.bank_name,
    u.basic_salary,
    u.resident_location,
    u.cv_document_url
  FROM public.users u
  WHERE u.is_employee = true
  ORDER BY u.user_name ASC;
$$;

-- Comment: The cv_document_url will store the path/URL to the CV file in Supabase Storage
