-- Migration 007: Seed Standard / Starter Ledgers for Automotive Business
-- ========================================================================
-- Inserts default ledgers across all categories relevant to a car service
-- workshop / automobile dealership / spare-parts business.
-- Each ledger links to its ledger_type and ledger_category by name lookup.
-- Uses ON CONFLICT to be safely re-runnable.

-- ============================================================
-- EXPENSE LEDGERS  (ledger_type = 'Expense', category = 'Expense')
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, expense_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, ec.id, 'active'
FROM (VALUES
  ('Spare Parts Purchase',            'Cost of Sales'),
  ('Lubricants & Oils Expense',       'Cost of Sales'),
  ('Tyres & Tubes Expense',           'Cost of Sales'),
  ('Batteries Expense',               'Cost of Sales'),
  ('Accessories Purchase',            'Cost of Sales'),
  ('Body Parts & Panels Expense',     'Cost of Sales'),
  ('Painting & Denting Material',     'Cost of Sales'),
  ('Glass & Mirror Expense',          'Cost of Sales'),
  ('Electrical Parts Expense',        'Cost of Sales'),
  ('AC Parts & Gas Expense',          'Cost of Sales'),
  ('Workshop Consumables',            'Cost of Sales'),
  ('Staff Salaries',                  'Salaries and Wages'),
  ('Technician Wages',                'Salaries and Wages'),
  ('Helper / Apprentice Wages',       'Salaries and Wages'),
  ('Workshop Rent',                   'Rent Expense'),
  ('Showroom Rent',                   'Rent Expense'),
  ('Electricity Expense',             'Utilities Expense'),
  ('Water Expense',                   'Utilities Expense'),
  ('Generator Fuel Expense',          'Fuel Expense'),
  ('Equipment Repair',                'Repairs and Maintenance'),
  ('Workshop Maintenance',            'Repairs and Maintenance'),
  ('Vehicle Lift Maintenance',        'Repairs and Maintenance'),
  ('Office Stationery & Supplies',    'Office Expense'),
  ('Printing & Photocopying',         'Office Expense'),
  ('Computer & IT Expense',           'IT and Software Expense'),
  ('Software Subscription',           'IT and Software Expense'),
  ('Tow Vehicle Fuel',                'Transportation Expense'),
  ('Delivery Charges',                'Transportation Expense'),
  ('Courier & Freight',               'Transportation Expense'),
  ('Vehicle Insurance',               'Insurance Expense'),
  ('Shop Insurance',                  'Insurance Expense'),
  ('Employee Insurance',              'Insurance Expense'),
  ('Equipment Depreciation',          'Depreciation Expense'),
  ('Vehicle Depreciation',            'Depreciation Expense'),
  ('Furniture Depreciation',          'Depreciation Expense'),
  ('Bank Charges & Commission',       'Bank Charges'),
  ('Loan Interest',                   'Interest Expense'),
  ('Audit & CA Fees',                 'Professional Fees'),
  ('Legal Fees',                      'Professional Fees'),
  ('Consultant Fees',                 'Professional Fees'),
  ('Telephone & Internet',            'Communication Expense'),
  ('Advertising & Marketing',         'Marketing Expense'),
  ('Signboard & Branding',            'Marketing Expense'),
  ('Online Listing & Ads',            'Marketing Expense'),
  ('Staff Training',                  'Training Expense'),
  ('Business Travel',                 'Travel Expense'),
  ('Entertainment Expense',           'Miscellaneous Expense'),
  ('Donation & CSR',                  'Miscellaneous Expense'),
  ('Penalty & Fine',                  'Miscellaneous Expense'),
  ('Waste Disposal & Environment',    'Miscellaneous Expense'),
  ('Miscellaneous Expense',           'Miscellaneous Expense')
) AS v(ledger_name, expense_cat)
JOIN public.ledger_types lt ON lt.name = 'Expense'
JOIN public.ledger_categories lc ON lc.name = 'Expense'
JOIN public.expense_categories ec ON ec.name = v.expense_cat
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);

-- ============================================================
-- OPERATIONAL EXPENSE LEDGERS  (type = 'Operational Expense', category = 'Operational Expense')
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, expense_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, ec.id, 'active'
FROM (VALUES
  ('Workshop Tools & Equipment',      'Repairs and Maintenance'),
  ('Safety Equipment & PPE',          'Administrative Expense'),
  ('Uniforms & Workwear',             'Administrative Expense'),
  ('Cleaning & Sanitation',           'Administrative Expense'),
  ('Parking & Toll Charges',          'Transportation Expense'),
  ('Government Fees & License',       'Administrative Expense'),
  ('Trade License & Permits',         'Administrative Expense'),
  ('GST & Tax Compliance Fee',        'Professional Fees'),
  ('Annual Maintenance Contracts',    'Repairs and Maintenance'),
  ('CCTV & Security Expense',         'Administrative Expense'),
  ('Fire Safety Expense',             'Administrative Expense')
) AS v(ledger_name, expense_cat)
JOIN public.ledger_types lt ON lt.name = 'Operational Expense'
JOIN public.ledger_categories lc ON lc.name = 'Operational Expense'
JOIN public.expense_categories ec ON ec.name = v.expense_cat
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);

-- ============================================================
-- INCOME / REVENUE LEDGERS  (type = 'Revenue', category = 'Income')
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, 'active'
FROM (VALUES
  ('Vehicle Service Income'),
  ('Spare Parts Sales'),
  ('Labour Income'),
  ('Painting & Denting Income'),
  ('AC Service Income'),
  ('Wheel Alignment & Balancing Income'),
  ('Car Wash Income'),
  ('Towing Service Income'),
  ('Insurance Claim Income'),
  ('Extended Warranty Income'),
  ('Accessories Sales Income'),
  ('Used Vehicle Sales Income'),
  ('Scrap Sales Income'),
  ('Commission Income'),
  ('Discount Received'),
  ('Interest Income'),
  ('Rental Income'),
  ('Other Income')
) AS v(ledger_name)
JOIN public.ledger_types lt ON lt.name = 'Revenue'
JOIN public.ledger_categories lc ON lc.name = 'Income'
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);

-- ============================================================
-- CASH LEDGERS  (type = 'Cash', category = 'Cash')
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, 'active'
FROM (VALUES
  ('Cash in Hand'),
  ('Petty Cash')
) AS v(ledger_name)
JOIN public.ledger_types lt ON lt.name = 'Cash'
JOIN public.ledger_categories lc ON lc.name = 'Cash'
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);

-- ============================================================
-- BANK LEDGERS  (type = 'Bank', category = 'Bank')
-- (Bank account numbers to be filled by user)
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, 'active'
FROM (VALUES
  ('Primary Bank Account'),
  ('Secondary Bank Account'),
  ('UPI / Digital Wallet')
) AS v(ledger_name)
JOIN public.ledger_types lt ON lt.name = 'Bank'
JOIN public.ledger_categories lc ON lc.name = 'Bank'
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);

-- ============================================================
-- ASSET LEDGERS  (type = 'Asset', category = 'Asset')
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, 'active'
FROM (VALUES
  ('Workshop Equipment'),
  ('Furniture & Fixtures'),
  ('Vehicles (Company Owned)'),
  ('Computer & Electronics'),
  ('Goodwill'),
  ('Stock in Trade'),
  ('Accounts Receivable (General)'),
  ('Advance to Suppliers'),
  ('Security Deposits'),
  ('Prepaid Expenses'),
  ('TDS Receivable'),
  ('GST Input Credit')
) AS v(ledger_name)
JOIN public.ledger_types lt ON lt.name = 'Asset'
JOIN public.ledger_categories lc ON lc.name = 'Asset'
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);

-- ============================================================
-- LIABILITY LEDGERS  (type = 'Liability', category = 'Liability')
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, 'active'
FROM (VALUES
  ('Accounts Payable (General)'),
  ('Advance from Customers'),
  ('Vehicle Loan'),
  ('Equipment Loan'),
  ('Business Loan'),
  ('Credit Card Payable'),
  ('GST Output Liability'),
  ('TDS Payable'),
  ('PF Payable'),
  ('ESI Payable'),
  ('Salary Payable'),
  ('Provision for Expenses')
) AS v(ledger_name)
JOIN public.ledger_types lt ON lt.name = 'Liability'
JOIN public.ledger_categories lc ON lc.name = 'Liability'
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);

-- ============================================================
-- EQUITY LEDGERS  (type = 'Equity', category = 'Equity')
-- ============================================================
INSERT INTO public.ledger (ledger_name, ledger_type_id, ledger_category_id, status)
SELECT v.ledger_name, lt.id, lc.id, 'active'
FROM (VALUES
  ('Owner Capital'),
  ('Partner Capital'),
  ('Retained Earnings'),
  ('Drawings / Withdrawals'),
  ('Profit & Loss Account')
) AS v(ledger_name)
JOIN public.ledger_types lt ON lt.name = 'Equity'
JOIN public.ledger_categories lc ON lc.name = 'Equity'
WHERE NOT EXISTS (
  SELECT 1 FROM public.ledger l WHERE l.ledger_name = v.ledger_name
);
