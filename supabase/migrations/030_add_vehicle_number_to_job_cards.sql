-- Migration 030: Add vehicle_number to job_cards table
-- =====================================================

-- Add vehicle_number column to job_cards
ALTER TABLE IF EXISTS public.job_cards 
ADD COLUMN IF NOT EXISTS vehicle_number TEXT;

-- Add comment
COMMENT ON COLUMN public.job_cards.vehicle_number IS 'Vehicle registration number selected for this job card';
