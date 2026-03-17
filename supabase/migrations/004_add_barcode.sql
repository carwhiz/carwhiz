-- Migration 004: Add barcode field to products table
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS barcode TEXT;
