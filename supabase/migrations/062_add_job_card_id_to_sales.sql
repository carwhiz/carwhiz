-- Migration 062: Add job_card_id to sales table
-- Allows tracking which job card each sale came from (for partial billing)

ALTER TABLE public.sales 
ADD COLUMN IF NOT EXISTS job_card_id UUID REFERENCES public.job_cards(id);

-- Add created_by and updated_by for audit trail if missing
ALTER TABLE public.sales 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

ALTER TABLE public.sales 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.users(id);

-- Index for fast lookup of sales by job card
CREATE INDEX IF NOT EXISTS idx_sales_job_card_id 
ON public.sales(job_card_id) 
WHERE job_card_id IS NOT NULL;

-- Create audit trigger for sales if it doesn't exist
DROP TRIGGER IF EXISTS trg_audit_sales ON public.sales;
CREATE TRIGGER trg_audit_sales
  AFTER INSERT OR UPDATE OR DELETE ON public.sales
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_audit_log();
