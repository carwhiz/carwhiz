-- QUICK FIX: Run this in Supabase SQL Editor
-- ============================================
-- 1. Fix audit trigger to handle missing updated_by column
-- 2. Delete all data from ledger_entries

-- Step 1: Fix the audit trigger function to be resilient
CREATE OR REPLACE FUNCTION public.fn_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rec_id UUID;
  user_id UUID;
BEGIN
  -- Try to get record id
  IF TG_OP = 'DELETE' THEN
    rec_id := OLD.id;
  ELSE
    rec_id := NEW.id;
  END IF;

  -- Try to get user from created_by / updated_by (safely)
  BEGIN
    IF TG_OP = 'INSERT' THEN
      user_id := NEW.created_by;
    ELSIF TG_OP = 'UPDATE' THEN
      user_id := NEW.updated_by;
    ELSE
      user_id := OLD.updated_by;
    END IF;
  EXCEPTION WHEN undefined_column THEN
    -- Column doesn't exist on this table, use created_by as fallback
    BEGIN
      IF TG_OP = 'DELETE' THEN
        user_id := OLD.created_by;
      ELSE
        user_id := NEW.created_by;
      END IF;
    EXCEPTION WHEN undefined_column THEN
      user_id := NULL;
    END;
  END;

  INSERT INTO public.audit_log (table_name, record_id, action, old_data, new_data, changed_by)
  VALUES (
    TG_TABLE_NAME,
    rec_id,
    TG_OP,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
    user_id
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Step 2: Delete all data from ledger_entries
DELETE FROM public.ledger_entries;

-- Verify
SELECT COUNT(*) AS remaining_rows FROM public.ledger_entries;
