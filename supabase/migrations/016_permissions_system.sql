-- Migration 016: Per-User Permission Management System
-- =====================================================
-- Direct user-level access control for UI windows and CRUD operations.
-- Replaces old role-based permissions with per-user permissions.

-- 1. Drop old role-based objects if they exist
DROP TABLE IF EXISTS public.permissions CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;

-- Remove role_id column from users if it exists
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='role_id') THEN
    ALTER TABLE public.users DROP COLUMN role_id;
  END IF;
END $$;

-- 2. permissions table — one row per user + resource combination
CREATE TABLE public.permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  resource TEXT NOT NULL,
  can_view BOOLEAN DEFAULT false,
  can_create BOOLEAN DEFAULT false,
  can_edit BOOLEAN DEFAULT false,
  can_delete BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES public.users(id),
  UNIQUE(user_id, resource)
);

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY perm_anon_full ON public.permissions FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY perm_service_full ON public.permissions FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 3. Seed full permissions for existing admin user(s)
DO $$
DECLARE
  v_admin RECORD;
  r TEXT;
BEGIN
  FOR v_admin IN SELECT id FROM public.users WHERE role = 'admin'
  LOOP
    FOREACH r IN ARRAY ARRAY[
      'finance-customers', 'finance-vendors', 'finance-ledger', 'finance-assets',
      'finance-sales', 'finance-purchase', 'finance-receipt', 'finance-payment',
      'finance-sales-report', 'finance-purchase-report', 'finance-ledger-balance',
      'finance-day-book', 'finance-trial-balance', 'finance-profit-loss', 'finance-balance-sheet',
      'products-vehicles', 'products-products', 'products-stock-report',
      'appcontrol-users', 'appcontrol-permissions', 'appcontrol-audit-log'
    ]
    LOOP
      INSERT INTO public.permissions (user_id, resource, can_view, can_create, can_edit, can_delete)
      VALUES (v_admin.id, r, true, true, true, true)
      ON CONFLICT (user_id, resource) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- 4. Audit trigger
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_permissions') THEN
    CREATE TRIGGER trg_audit_permissions
      AFTER INSERT OR UPDATE OR DELETE ON public.permissions
      FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
  END IF;
END $$;

-- 5. Helper: hash a password (used by Users window to update password)
CREATE OR REPLACE FUNCTION public.hash_password(p_password TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN crypt(p_password, gen_salt('bf'));
END;
$$;