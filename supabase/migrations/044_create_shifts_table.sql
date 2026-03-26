-- Create shifts table for regular shift management
CREATE TABLE IF NOT EXISTS public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  start_time TIME NOT NULL,
  start_buffer NUMERIC(5, 2) DEFAULT 0,
  end_time TIME NOT NULL,
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
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view shifts" ON public.shifts;
DROP POLICY IF EXISTS "Authenticated users can create shifts" ON public.shifts;
DROP POLICY IF EXISTS "Users can update own shifts or admins can update any" ON public.shifts;
DROP POLICY IF EXISTS "Users can delete own shifts or admins can delete any" ON public.shifts;

-- Anyone can view shifts
CREATE POLICY "Anyone can view shifts" ON public.shifts
  FOR SELECT USING (true);

-- Authenticated users can create shifts
CREATE POLICY "Authenticated users can create shifts" ON public.shifts
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Only shift creator or admin can update
CREATE POLICY "Users can update own shifts or admins can update any" ON public.shifts
  FOR UPDATE USING (
    created_by = auth.uid() OR 
    EXISTS(SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- Only shift creator or admin can delete
CREATE POLICY "Users can delete own shifts or admins can delete any" ON public.shifts
  FOR DELETE USING (
    created_by = auth.uid() OR 
    EXISTS(SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- Create audit trigger
DROP TRIGGER IF EXISTS trg_audit_shifts ON public.shifts;
CREATE TRIGGER trg_audit_shifts
  AFTER INSERT OR UPDATE OR DELETE ON public.shifts
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

-- Create index on created_by for performance
DROP INDEX IF EXISTS idx_shifts_created_by;
CREATE INDEX idx_shifts_created_by ON public.shifts(created_by);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shifts TO authenticated;
GRANT SELECT ON public.shifts TO anon;
