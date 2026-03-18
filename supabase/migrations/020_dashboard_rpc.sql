-- Migration 020: Dashboard Summary RPC
-- ======================================
-- Single RPC to return all mobile dashboard data in one call,
-- replacing ~10 separate queries.

CREATE OR REPLACE FUNCTION public.fn_dashboard_summary(p_date DATE)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sales_total NUMERIC := 0;
  v_sales_count INT := 0;
  v_purchase_total NUMERIC := 0;
  v_purchase_count INT := 0;
  v_expense_total NUMERIC := 0;
  v_expense_count INT := 0;
  v_cash_balance NUMERIC := 0;
  v_bank_balance NUMERIC := 0;
  v_sales_balance NUMERIC := 0;
  v_purchase_balance NUMERIC := 0;
BEGIN
  -- Sales for date
  SELECT COALESCE(SUM(net_total), 0), COUNT(*)
    INTO v_sales_total, v_sales_count
    FROM public.sales WHERE bill_date = p_date;

  -- Purchases for date
  SELECT COALESCE(SUM(net_total), 0), COUNT(*)
    INTO v_purchase_total, v_purchase_count
    FROM public.purchases WHERE invoice_date = p_date;

  -- Expenses for date (debit entries on Expense / Operational Expense ledgers)
  SELECT COALESCE(SUM(le.debit), 0), COUNT(*)
    INTO v_expense_total, v_expense_count
    FROM public.ledger_entries le
    JOIN public.ledger l ON l.id = le.ledger_id
    JOIN public.ledger_types lt ON lt.id = l.ledger_type_id
   WHERE lt.name IN ('Expense', 'Operational Expense')
     AND le.entry_date = p_date;

  -- Sales balance due (all-time outstanding)
  SELECT COALESCE(SUM(balance_due), 0)
    INTO v_sales_balance
    FROM public.sales WHERE balance_due > 0;

  -- Purchase balance due (all-time outstanding)
  SELECT COALESCE(SUM(balance_due), 0)
    INTO v_purchase_balance
    FROM public.purchases WHERE balance_due > 0;

  -- Cash balance (opening_balance + sum(debit - credit) for Cash type ledgers)
  SELECT COALESCE(SUM(l.opening_balance + COALESCE(eb.net, 0)), 0)
    INTO v_cash_balance
    FROM public.ledger l
    JOIN public.ledger_types lt ON lt.id = l.ledger_type_id
    LEFT JOIN (
      SELECT ledger_id, SUM(debit - credit) AS net
        FROM public.ledger_entries GROUP BY ledger_id
    ) eb ON eb.ledger_id = l.id
   WHERE lt.name = 'Cash';

  -- Bank balance (opening_balance + sum(debit - credit) for Bank type ledgers)
  SELECT COALESCE(SUM(l.opening_balance + COALESCE(eb.net, 0)), 0)
    INTO v_bank_balance
    FROM public.ledger l
    JOIN public.ledger_types lt ON lt.id = l.ledger_type_id
    LEFT JOIN (
      SELECT ledger_id, SUM(debit - credit) AS net
        FROM public.ledger_entries GROUP BY ledger_id
    ) eb ON eb.ledger_id = l.id
   WHERE lt.name = 'Bank';

  RETURN json_build_object(
    'sales_total', v_sales_total,
    'sales_count', v_sales_count,
    'purchase_total', v_purchase_total,
    'purchase_count', v_purchase_count,
    'expense_total', v_expense_total,
    'expense_count', v_expense_count,
    'cash_balance', v_cash_balance,
    'bank_balance', v_bank_balance,
    'sales_balance', v_sales_balance,
    'purchase_balance', v_purchase_balance
  );
END;
$$;
