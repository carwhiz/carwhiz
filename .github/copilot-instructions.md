# CarWhizz – AI Coding Instructions

## Audit Log System

Every new feature that **creates, updates, or deletes** a database record **must** include audit log support:

1. **Database trigger** – Ensure the table has an `AFTER INSERT OR UPDATE OR DELETE` trigger calling `fn_audit_log()`. If one doesn't exist, add it in a new migration:
   ```sql
   CREATE TRIGGER trg_audit_<table>
     AFTER INSERT OR UPDATE OR DELETE ON public.<table>
     FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
   ```

2. **`created_by` / `updated_by` columns** – The table must have these UUID columns (referencing `public.users(id)`). Set them in every insert/update call:
   - **Insert**: `created_by: $authStore.user?.id`
   - **Update**: `updated_by: $authStore.user?.id`

3. **Supabase client calls** – Always include the user ID fields so the trigger can record *who* made the change.

4. **AuditLogWindow** – When adding a new table, update `friendlyTableName()` in `AuditLogWindow.svelte` with a human-readable label.

### Tables already covered by audit triggers

sales, purchases, receipts, payments, ledger, ledger_entries, customers, vendors, products, vehicles, employees, sales_items, purchase_items, stock_movements, makes, generations, generation_types, variants, gearboxes, fuel_types, body_sides, units, brands, expense_categories, asset_categories, assets, asset_depreciation, permissions, product_components, attendance

## General Rules

- Use `.maybeSingle()` instead of `.single()` for lookups that may return 0 rows (prevents 406 errors).
- Indian Financial Year: April 1 – March 31.
- Stock movements: purchases add positive qty, sales add negative qty.
- Follow Ind AS / Schedule III for financial reports.
