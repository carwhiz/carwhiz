-- Migration 032: Sales and Purchase Returns Permissions + Stock Management
-- ===============================================================================
-- Adds permission records for Sales Return, Purchase Return, and Stock Management features

-- Insert default permissions for finance-sales-return
INSERT INTO public.permissions (resource, user_id, can_view, can_create, can_edit, can_delete, created_at)
SELECT 'finance-sales-return' as resource, users.id, true, true, true, true, now()
FROM public.users
WHERE NOT EXISTS (
  SELECT 1 FROM public.permissions 
  WHERE resource = 'finance-sales-return' AND user_id = users.id
);

-- Insert default permissions for finance-purchase-return
INSERT INTO public.permissions (resource, user_id, can_view, can_create, can_edit, can_delete, created_at)
SELECT 'finance-purchase-return' as resource, users.id, true, true, true, true, now()
FROM public.users
WHERE NOT EXISTS (
  SELECT 1 FROM public.permissions 
  WHERE resource = 'finance-purchase-return' AND user_id = users.id
);

-- Insert default permissions for products-stock-management
INSERT INTO public.permissions (resource, user_id, can_view, can_create, can_edit, can_delete, created_at)
SELECT 'products-stock-management' as resource, users.id, true, false, true, false, now()
FROM public.users
WHERE NOT EXISTS (
  SELECT 1 FROM public.permissions 
  WHERE resource = 'products-stock-management' AND user_id = users.id
);
