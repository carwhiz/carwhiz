-- ============================================================
-- Migration 009: Create public RPC wrapper for nextval
-- Supabase PostgREST only exposes user-defined functions,
-- so we need a wrapper to call PostgreSQL's built-in nextval.
-- ============================================================

CREATE OR REPLACE FUNCTION public.nextval(seq_name text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN nextval(seq_name::regclass);
END;
$$;
