-- Add reason column to stock_movements table for audit tracking
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS reason TEXT;

-- Create updated_by column for potential future updates (consistency with other tables)
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
