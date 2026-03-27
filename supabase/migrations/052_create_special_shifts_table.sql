-- Create special_shifts table for date-specific shift assignments
CREATE TABLE IF NOT EXISTS public.special_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  shift_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  start_buffer NUMERIC(5, 2) DEFAULT 0,
  end_buffer NUMERIC(5, 2) DEFAULT 0,
  working_hours NUMERIC(5, 2) GENERATED ALWAYS AS (
    CASE 
      WHEN end_time > start_time THEN 
        EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0
      ELSE 
        EXTRACT(EPOCH FROM (end_time + INTERVAL '24 hours' - start_time)) / 3600.0
    END
  ) STORED,
  overlaps_next_day BOOLEAN DEFAULT FALSE,
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable Row Level Security
ALTER TABLE public.special_shifts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "anon_full_access" ON public.special_shifts;
DROP POLICY IF EXISTS "service_role_full_access" ON public.special_shifts;

-- Full grant for anon
CREATE POLICY "anon_full_access" ON public.special_shifts
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- Full grant for service_role
CREATE POLICY "service_role_full_access" ON public.special_shifts
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.special_shifts TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.special_shifts TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.special_shifts TO authenticated;

-- Create audit trigger
DROP TRIGGER IF EXISTS trg_audit_special_shifts ON public.special_shifts;
CREATE TRIGGER trg_audit_special_shifts
  AFTER INSERT OR UPDATE OR DELETE ON public.special_shifts
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

-- Create indexes for performance
CREATE INDEX idx_special_shifts_employee_id ON public.special_shifts(employee_id);
CREATE INDEX idx_special_shifts_shift_date ON public.special_shifts(shift_date);
CREATE INDEX idx_special_shifts_employee_date ON public.special_shifts(employee_id, shift_date);
