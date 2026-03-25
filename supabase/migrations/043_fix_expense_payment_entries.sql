-- Fix expense payment entries - remove unwanted credit entries
-- Expense payments should only have a debit entry to the expense ledger, not a credit to cash/bank

-- Delete credit entries for expense payments (payments with no vendor and no purchase)
DELETE FROM public.ledger_entries
WHERE reference_type = 'payments'
  AND reference_id IN (
    SELECT p.id FROM public.payments p
    WHERE p.vendor_id IS NULL 
      AND p.purchase_id IS NULL
  )
  AND credit > 0 
  AND debit = 0;
