-- Add employee_id to official_leaves (leaves are per-employee, not universal)
ALTER TABLE public.official_leaves
  ADD COLUMN IF NOT EXISTS employee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE;

-- Index for employee lookup
CREATE INDEX IF NOT EXISTS idx_official_leaves_employee ON public.official_leaves(employee_id);
