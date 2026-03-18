<!-- ============================================================
     FINANCE > OPERATIONS > RECEIPT ENTRY WINDOW
     Purpose: Record money received from customers / receivables
     Window ID: finance-receipt
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';

  // ---- Header ----
  let receipt_no = '';
  let receipt_date = new Date().toISOString().split('T')[0];
  let receiptType: 'customer' | 'income' = 'customer';

  // ---- Customer / Ledger ----
  let customerSearch = '';
  let customers: any[] = [];
  let filteredCustomers: any[] = [];
  let selectedCustomer: any = null;
  let showCustomerDropdown = false;

  // ---- Income ledger (for other income receipts) ----
  let incomeLedgers: any[] = [];
  let incomeLedgerSearch = '';
  let filteredIncomeLedgers: any[] = [];
  let selectedIncomeLedger: any = null;
  let showIncomeLedgerDropdown = false;

  // ---- Reference bill ----
  let salesBills: any[] = [];
  let sales_id = '';

  // ---- Amount + payment ----
  let amount: string = '';
  let paymentModes: any[] = [];
  let payment_mode_id = '';
  let cashBankLedgers: any[] = [];
  let cash_bank_ledger_id = '';
  let notes = '';

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  onMount(async () => {
    await Promise.all([
      loadCustomers(),
      loadPaymentModes(),
      loadCashBankLedgers(),
      loadIncomeLedgers(),
      generateReceiptNo(),
    ]);
  });

  async function generateReceiptNo() {
    try {
      const { data } = await supabase.rpc('nextval', { seq_name: 'receipt_seq' });
      if (data) { receipt_no = 'REC-' + String(data).padStart(5, '0'); return; }
    } catch {}
    receipt_no = 'REC-' + Date.now();
  }

  async function loadCustomers() {
    const { data } = await supabase.from('customers').select('id, name, place, ledger_id').order('name');
    customers = data || [];
  }

  async function loadPaymentModes() {
    const { data } = await supabase.from('payment_modes').select('id, name').order('sort_order');
    paymentModes = data || [];
  }

  async function loadCashBankLedgers() {
    const { data: types } = await supabase.from('ledger_types').select('id, name').in('name', ['Cash', 'Bank']);
    const typeIds = (types || []).map((t: any) => t.id);
    const { data } = await supabase.from('ledger').select('id, ledger_name, ledger_type_id').order('ledger_name');
    cashBankLedgers = (data || []).filter((l: any) => typeIds.includes(l.ledger_type_id));
  }

  async function loadIncomeLedgers() {
    const { data: types } = await supabase.from('ledger_types').select('id, name').in('name', ['Revenue', 'Other']);
    const typeIds = (types || []).map((t: any) => t.id);
    const { data } = await supabase.from('ledger').select('id, ledger_name, ledger_type_id').order('ledger_name');
    incomeLedgers = (data || []).filter((l: any) => typeIds.includes(l.ledger_type_id));
  }

  async function loadCustomerBills(customerId: string) {
    const { data } = await supabase
      .from('sales')
      .select('id, bill_no, bill_date, net_total, balance_due')
      .eq('customer_id', customerId)
      .gt('balance_due', 0)
      .order('bill_date', { ascending: false });
    salesBills = data || [];
  }

  // ---- Customer search ----
  function handleCustomerSearch() {
    const q = customerSearch.toLowerCase().trim();
    if (!q) { filteredCustomers = []; showCustomerDropdown = false; return; }
    filteredCustomers = customers.filter(c =>
      c.name.toLowerCase().includes(q) || (c.place || '').toLowerCase().includes(q)
    ).slice(0, 10);
    showCustomerDropdown = filteredCustomers.length > 0;
  }

  function selectCustomer(c: any) {
    selectedCustomer = c;
    customerSearch = c.name;
    showCustomerDropdown = false;
    sales_id = '';
    loadCustomerBills(c.id);
  }

  function clearCustomer() {
    selectedCustomer = null;
    customerSearch = '';
    salesBills = [];
    sales_id = '';
  }

  // ---- Income ledger search ----
  function handleIncomeLedgerSearch() {
    const q = incomeLedgerSearch.toLowerCase().trim();
    if (!q) { filteredIncomeLedgers = []; showIncomeLedgerDropdown = false; return; }
    filteredIncomeLedgers = incomeLedgers.filter(l =>
      l.ledger_name.toLowerCase().includes(q)
    ).slice(0, 10);
    showIncomeLedgerDropdown = filteredIncomeLedgers.length > 0;
  }

  function selectIncomeLedger(l: any) {
    selectedIncomeLedger = l;
    incomeLedgerSearch = l.ledger_name;
    showIncomeLedgerDropdown = false;
  }

  function clearIncomeLedger() {
    selectedIncomeLedger = null;
    incomeLedgerSearch = '';
  }

  function switchReceiptType(type: 'customer' | 'income') {
    receiptType = type;
    clearCustomer();
    clearIncomeLedger();
  }

  // ---- Save receipt ----
  async function handleSave() {
    if (receiptType === 'customer' && !selectedCustomer) { saveError = 'Please select a customer'; return; }
    if (receiptType === 'income' && !selectedIncomeLedger) { saveError = 'Please select an income ledger'; return; }
    if (!amount || parseFloat(amount) <= 0) { saveError = 'Enter a valid amount'; return; }
    if (!cash_bank_ledger_id) { saveError = 'Please select a Cash / Bank Ledger'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const { data: rec, error: recErr } = await supabase.from('receipts').insert({
      receipt_no,
      receipt_date,
      ledger_id: receiptType === 'customer' ? (selectedCustomer?.ledger_id || null) : (selectedIncomeLedger?.id || null),
      customer_id: receiptType === 'customer' ? selectedCustomer?.id : null,
      sales_id: (receiptType === 'customer' && sales_id) ? sales_id : null,
      amount: parseFloat(amount),
      payment_mode_id: payment_mode_id || null,
      cash_bank_ledger_id: cash_bank_ledger_id || null,
      notes: notes.trim() || null,
      created_by: $authStore.user?.id || null,
    }).select('id').single();

    if (recErr) {
      saving = false;
      saveError = recErr.message;
      return;
    }

    // ---- Ledger entries (double-entry posting) ----
    const recAmt = parseFloat(amount);
    const ledgerEntries: any[] = [];
    const sourceLedgerId = receiptType === 'customer' ? (selectedCustomer?.ledger_id || null) : (selectedIncomeLedger?.id || null);

    // Debit Cash/Bank ledger (money received)
    if (cash_bank_ledger_id && recAmt > 0) {
      ledgerEntries.push({
        entry_date: receipt_date,
        ledger_id: cash_bank_ledger_id,
        debit: recAmt,
        credit: 0,
        narration: `Receipt - ${receipt_no}`,
        reference_type: 'receipts',
        reference_id: rec.id,
        created_by: $authStore.user?.id || null,
      });
    }

    // Credit Customer/Income ledger
    if (sourceLedgerId && recAmt > 0) {
      ledgerEntries.push({
        entry_date: receipt_date,
        ledger_id: sourceLedgerId,
        debit: 0,
        credit: recAmt,
        narration: `Receipt - ${receipt_no}`,
        reference_type: 'receipts',
        reference_id: rec.id,
        created_by: $authStore.user?.id || null,
      });
    }

    if (ledgerEntries.length > 0) {
      await supabase.from('ledger_entries').insert(ledgerEntries);
    }

    // If linked to a sales bill, reduce balance_due
    if (sales_id) {
      const bill = salesBills.find(b => b.id === sales_id);
      if (bill) {
        const newBalance = Math.max(0, (bill.balance_due || 0) - parseFloat(amount));
        const newPaid = (bill.net_total || 0) - newBalance;
        await supabase.from('sales').update({
          paid_amount: newPaid,
          balance_due: newBalance,
          status: newBalance <= 0 ? 'paid' : 'posted',
          updated_by: $authStore.user?.id || null,
        }).eq('id', sales_id);
      }
    }

    saving = false;
    saveSuccess = `Receipt ${receipt_no} saved successfully!`;

    // Reset
    selectedCustomer = null;
    customerSearch = '';
    selectedIncomeLedger = null;
    incomeLedgerSearch = '';
    sales_id = '';
    salesBills = [];
    receiptType = 'customer';
    amount = '';
    payment_mode_id = '';
    cash_bank_ledger_id = '';
    notes = '';
    await generateReceiptNo();

    setTimeout(() => saveSuccess = '', 4000);
  }

  function handleCancel() {
    windowStore.close('finance-receipt');
  }
</script>

<div class="entry-window">
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Receipt Entry</h2>
      <div class="type-toggle">
        <button class="type-btn" class:active={receiptType === 'customer'} on:click={() => switchReceiptType('customer')}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>
          Customer Receipt
        </button>
        <button class="type-btn income" class:active={receiptType === 'income'} on:click={() => switchReceiptType('income')}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          Other Income
        </button>
      </div>
    </div>
    <div class="header-right">
      <span class="doc-tag">#{receipt_no}</span>
    </div>
  </div>

  <div class="form-body">
    {#if saveError}
      <div class="msg msg-error">{saveError}</div>
    {/if}
    {#if saveSuccess}
      <div class="msg msg-success">{saveSuccess}</div>
    {/if}

    <div class="form-card">
      <!-- Row 1: Receipt date + Customer/Income ledger -->
      <div class="form-row two-col">
        <div class="field">
          <label for="r-date">Receipt Date</label>
          <input id="r-date" type="date" bind:value={receipt_date} />
        </div>
        <div class="field">
          {#if receiptType === 'customer'}
            <label>Customer</label>
            <div class="search-input-wrap">
              {#if selectedCustomer}
                <div class="selected-chip">
                  <span>{selectedCustomer.name}</span>
                  <button class="chip-clear" on:click={clearCustomer}>&times;</button>
                </div>
              {:else}
                <input type="text" placeholder="Search customer..." bind:value={customerSearch} on:input={handleCustomerSearch} on:focus={handleCustomerSearch} />
                {#if showCustomerDropdown}
                  <div class="search-dropdown">
                    {#each filteredCustomers as c (c.id)}
                      <button class="dd-item" on:click={() => selectCustomer(c)}>
                        <span class="dd-name">{c.name}</span>
                        {#if c.place}<span class="dd-sub">{c.place}</span>{/if}
                      </button>
                    {/each}
                  </div>
                {/if}
              {/if}
            </div>
          {:else}
            <label>Income Ledger</label>
            <div class="search-input-wrap">
              {#if selectedIncomeLedger}
                <div class="selected-chip income-chip">
                  <span>{selectedIncomeLedger.ledger_name}</span>
                  <button class="chip-clear" on:click={clearIncomeLedger}>&times;</button>
                </div>
              {:else}
                <input type="text" placeholder="Search income/revenue ledger..." bind:value={incomeLedgerSearch} on:input={handleIncomeLedgerSearch} on:focus={handleIncomeLedgerSearch} />
                {#if showIncomeLedgerDropdown}
                  <div class="search-dropdown">
                    {#each filteredIncomeLedgers as l (l.id)}
                      <button class="dd-item" on:click={() => selectIncomeLedger(l)}>
                        <span class="dd-name">{l.ledger_name}</span>
                      </button>
                    {/each}
                  </div>
                {/if}
              {/if}
            </div>
          {/if}
        </div>
      </div>

      <!-- Row 2: Reference bill (customer only) + Amount -->
      <div class="form-row two-col">
        {#if receiptType === 'customer'}
          <div class="field">
            <label for="r-bill">Reference Bill (optional)</label>
            <select id="r-bill" bind:value={sales_id}>
              <option value="">None</option>
              {#each salesBills as bill (bill.id)}
                <option value={bill.id}>{bill.bill_no} — Due ₹{(bill.balance_due || 0).toFixed(2)}</option>
              {/each}
            </select>
          </div>
        {:else}
          <div class="field"></div>
        {/if}
        <div class="field">
          <label for="r-amt">Receipt Amount</label>
          <input id="r-amt" type="number" step="0.01" placeholder="0.00" bind:value={amount} />
        </div>
      </div>

      <!-- Row 3: Payment mode + Cash/Bank ledger -->
      <div class="form-row two-col">
        <div class="field">
          <label for="r-pm">Payment Mode</label>
          <select id="r-pm" bind:value={payment_mode_id}>
            <option value="">Select...</option>
            {#each paymentModes as pm (pm.id)}
              <option value={pm.id}>{pm.name}</option>
            {/each}
          </select>
        </div>
        <div class="field">
          <label for="r-cb">Cash / Bank Ledger</label>
          <select id="r-cb" bind:value={cash_bank_ledger_id}>
            <option value="">Select...</option>
            {#each cashBankLedgers as cb (cb.id)}
              <option value={cb.id}>{cb.ledger_name}</option>
            {/each}
          </select>
        </div>
      </div>

      <!-- Notes -->
      <div class="form-row">
        <div class="field full">
          <label for="r-notes">Notes / Remarks</label>
          <textarea id="r-notes" rows="3" bind:value={notes} placeholder="Optional notes..."></textarea>
        </div>
      </div>
    </div>
  </div>

  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    <button class="btn-save" on:click={handleSave} disabled={saving}>
      {saving ? 'Saving...' : 'Save Receipt'}
    </button>
  </div>
</div>

<style>
  .entry-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }

  .form-header { display:flex; align-items:center; justify-content:space-between; padding:14px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#F97316; color:#EA580C; }
  .form-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .doc-tag { font-size:13px; font-weight:600; color:#F97316; background:#fff7ed; padding:4px 10px; border-radius:6px; border:1px solid #fed7aa; }

  .form-body { flex:1; overflow-y:auto; padding:24px; }
  .msg { padding:10px 14px; border-radius:6px; font-size:13px; font-weight:500; margin-bottom:16px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; }

  .form-card { background:white; border:1px solid #e5e7eb; border-radius:12px; padding:24px; display:flex; flex-direction:column; gap:18px; max-width:700px; }
  .form-row { display:flex; gap:16px; }
  .two-col > .field { flex:1; }
  .field { display:flex; flex-direction:column; position:relative; }
  .field.full { flex:1; }
  .field label { font-size:12px; font-weight:600; color:#374151; margin-bottom:4px; }
  .field input[type="text"], .field input[type="number"], .field input[type="date"], .field select, .field textarea { padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; background:white; font-family:inherit; }
  .field input:focus, .field select:focus, .field textarea:focus { border-color:#F97316; box-shadow:0 0 0 3px rgba(249,115,22,.1); }
  .field textarea { resize:vertical; }

  .search-input-wrap { position:relative; }
  .search-input-wrap input { width:100%; padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; box-sizing:border-box; }
  .search-input-wrap input:focus { border-color:#F97316; box-shadow:0 0 0 3px rgba(249,115,22,.1); }
  .selected-chip { display:flex; align-items:center; gap:6px; padding:7px 10px; background:#fff7ed; border:1px solid #fed7aa; border-radius:6px; font-size:13px; color:#9a3412; }
  .chip-clear { background:none; border:none; font-size:16px; color:#dc2626; cursor:pointer; padding:0 2px; }
  .search-dropdown { position:absolute; top:100%; left:0; right:0; max-height:180px; overflow-y:auto; background:white; border:1px solid #e5e7eb; border-radius:0 0 6px 6px; z-index:50; box-shadow:0 4px 12px rgba(0,0,0,.1); }
  .dd-item { display:flex; align-items:center; justify-content:space-between; width:100%; padding:8px 10px; border:none; background:none; cursor:pointer; font-size:13px; text-align:left; }
  .dd-item:hover { background:#fff7ed; }
  .dd-name { color:#111827; font-weight:500; }
  .dd-sub { color:#9ca3af; font-size:11px; }

  .type-toggle { display:flex; gap:0; border:1px solid #e5e7eb; border-radius:6px; overflow:hidden; margin-left:8px; }
  .type-btn { display:flex; align-items:center; gap:4px; padding:5px 12px; border:none; background:#f9fafb; font-size:12px; font-weight:600; color:#6b7280; cursor:pointer; transition:all .15s; }
  .type-btn.active { background:#16a34a; color:white; }
  .type-btn.income.active { background:#0ea5e9; color:white; }
  .income-chip { background:#f0f9ff !important; border-color:#bae6fd !important; color:#0369a1 !important; }

  .form-footer { display:flex; justify-content:flex-end; gap:10px; padding:14px 20px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-cancel { padding:9px 20px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:8px; font-size:14px; font-weight:500; color:#6b7280; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .btn-save { padding:9px 28px; background:#16a34a; border:none; border-radius:8px; font-size:14px; font-weight:600; color:white; cursor:pointer; transition:background .15s; }
  .btn-save:hover { background:#15803d; }
  .btn-save:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:700px) { .two-col { flex-direction:column; } }
</style>
