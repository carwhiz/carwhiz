-- Official Leaves table
-- Supports two types:
--   'weekday' – recurring leave on a specific day of the week (0=Sun,1=Mon,...6=Sat)
--   'date'    – one-time leave on a specific date (e.g. national holiday)

CREATE TABLE IF NOT EXISTS public.official_leaves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  leave_type TEXT NOT NULL CHECK (leave_type IN ('weekday', 'date')),
  weekday INT CHECK (weekday >= 0 AND weekday <= 6),  -- 0=Sunday .. 6=Saturday
  leave_date DATE,                                     -- specific date for 'date' type
  title TEXT NOT NULL,                                 -- e.g. "Sunday Off", "Republic Day"
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

  -- Ensure weekday leaves have weekday set, date leaves have leave_date set
  CONSTRAINT chk_leave_weekday CHECK (leave_type != 'weekday' OR weekday IS NOT NULL),
  CONSTRAINT chk_leave_date CHECK (leave_type != 'date' OR leave_date IS NOT NULL)
);

-- Enable Row Level Security
ALTER TABLE public.official_leaves ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "anon_full_access" ON public.official_leaves;
DROP POLICY IF EXISTS "service_role_full_access" ON public.official_leaves;

-- Full grant for anon
CREATE POLICY "anon_full_access" ON public.official_leaves
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- Full grant for service_role
CREATE POLICY "service_role_full_access" ON public.official_leaves
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.official_leaves TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.official_leaves TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.official_leaves TO authenticated;

-- Audit trigger
DROP TRIGGER IF EXISTS trg_audit_official_leaves ON public.official_leaves;
CREATE TRIGGER trg_audit_official_leaves
  AFTER INSERT OR UPDATE OR DELETE ON public.official_leaves
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

-- Indexes
CREATE INDEX idx_official_leaves_type ON public.official_leaves(leave_type);
CREATE INDEX idx_official_leaves_weekday ON public.official_leaves(weekday) WHERE leave_type = 'weekday';
CREATE INDEX idx_official_leaves_date ON public.official_leaves(leave_date) WHERE leave_type = 'date';
