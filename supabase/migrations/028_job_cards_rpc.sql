-- Migration 028: Job Cards RPC Functions
-- ========================================

-- Function to get user's jobs
CREATE OR REPLACE FUNCTION public.fn_get_user_jobs(
  p_status TEXT[] DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  job_card_no TEXT,
  customer_name TEXT,
  vehicle_model TEXT,
  status TEXT,
  created_at TIMESTAMPTZ,
  created_by UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    jc.id,
    jc.job_card_no,
    c.name,
    v.model_name,
    jc.status,
    jc.created_at,
    jc.created_by
  FROM public.job_cards jc
  LEFT JOIN public.customers c ON c.id = jc.customer_id
  LEFT JOIN public.vehicles v ON v.id = jc.vehicle_id
  WHERE jc.created_by = auth.uid()
    AND (p_status IS NULL OR jc.status = ANY(p_status))
  ORDER BY jc.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.fn_get_user_jobs TO authenticated, anon;

-- Function to get job details with items
CREATE OR REPLACE FUNCTION public.fn_get_job_details(p_job_id UUID)
RETURNS TABLE (
  id UUID,
  job_card_no TEXT,
  customer_name TEXT,
  vehicle_model TEXT,
  status TEXT,
  description TEXT,
  details TEXT,
  expected_date DATE,
  created_at TIMESTAMPTZ,
  items JSON
) AS $$
DECLARE
  v_items JSON;
BEGIN
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'id', jci.id,
        'item_type', jci.item_type,
        'name', jci.name,
        'qty', jci.qty,
        'price', jci.price,
        'total', jci.total
      ) ORDER BY jci.created_at
    ),
    '[]'::json
  ) INTO v_items
  FROM public.job_card_items jci
  WHERE jci.job_card_id = p_job_id;

  RETURN QUERY
  SELECT 
    jc.id,
    jc.job_card_no,
    c.name,
    v.model_name,
    jc.status,
    jc.description,
    jc.details,
    jc.expected_date,
    jc.created_at,
    v_items
  FROM public.job_cards jc
  LEFT JOIN public.customers c ON c.id = jc.customer_id
  LEFT JOIN public.vehicles v ON v.id = jc.vehicle_id
  WHERE jc.id = p_job_id
    AND jc.created_by = auth.uid();
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.fn_get_job_details TO authenticated, anon;
