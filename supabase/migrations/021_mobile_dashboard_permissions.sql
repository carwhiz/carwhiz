-- Migration 021: Mobile Dashboard Card Permissions
-- ==================================================
-- Extends permission system to control visibility of cards on mobile dashboard
-- Card permissions use can_view flag to determine card visibility
-- All cards default to visible for all users unless explicitly restricted

-- 1. Mobile dashboard card resource IDs (add to existing resource pool)
-- These are the cards displayed on the mobile home page:
-- - Sales (daily sales total & count)
-- - Purchase (daily purchases total & count)
-- - Expense (daily expenses total & count)
-- - Cash Balance (all cash ledgers balance)
-- - Bank Balance (all bank ledgers balance)
-- - Sales Balance (receivables from customers)
-- - Purchase Balance (payables to vendors)

-- 2. Seed mobile dashboard permissions for all existing users
-- Default: ALL USERS can view all mobile cards (unless admin restricts later)
DO $$
DECLARE
  v_user RECORD;
  v_card TEXT;
BEGIN
  -- For each existing user
  FOR v_user IN SELECT id, email FROM public.users
  LOOP
    -- For each mobile dashboard card
    FOREACH v_card IN ARRAY ARRAY[
      'mobile-dashboard-sales',
      'mobile-dashboard-purchase',
      'mobile-dashboard-expense',
      'mobile-dashboard-cash-balance',
      'mobile-dashboard-bank-balance',
      'mobile-dashboard-sales-balance',
      'mobile-dashboard-purchase-balance'
    ]
    LOOP
      -- Insert or ignore (if already exists)
      INSERT INTO public.permissions (user_id, resource, can_view, can_create, can_edit, can_delete)
      VALUES (v_user.id, v_card, true, false, false, false)
      ON CONFLICT (user_id, resource) DO NOTHING;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Mobile dashboard permissions seeded for % users', 
    (SELECT COUNT(*) FROM public.users);
END $$;

-- 3. Migration verification query (run manually if needed):
-- SELECT resource, COUNT(*) as user_count, SUM(CASE WHEN can_view THEN 1 ELSE 0 END) as can_view_count
-- FROM public.permissions
-- WHERE resource LIKE 'mobile-dashboard-%'
-- GROUP BY resource
-- ORDER BY resource;
