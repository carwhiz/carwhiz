-- Two-way ledger entries for vendor and expense payments
-- Updated to support double-entry bookkeeping
-- Both debit (vendor/expense) and credit (cash/bank) entries are now required

-- This migration no longer deletes credit entries
-- Instead, payments should have both:
-- 1. Debit to vendor ledger (or expense ledger)
-- 2. Credit to cash/bank ledger
-- See: src/components/windows/finance/operations/PaymentWindow.svelte
