-- Migration 041: Add inspection fields to job_cards
-- ===================================================
-- Add mechanical_inspection and body_inspection columns to job_cards table

ALTER TABLE public.job_cards
ADD COLUMN IF NOT EXISTS mechanical_inspection TEXT,
ADD COLUMN IF NOT EXISTS body_inspection TEXT;

COMMENT ON COLUMN public.job_cards.mechanical_inspection IS 'Mechanical inspection details - engine, transmission, brakes, suspension, etc.';
COMMENT ON COLUMN public.job_cards.body_inspection IS 'Body inspection details - paint, dents, rust, interior condition, etc.';
