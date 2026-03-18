<!-- ============================================================
     FINANCE > OPERATIONS > PAYMENT ENTRY WINDOW
     Purpose: Record money paid to vendors / expense / payable ledgers
     Window ID: finance-payment
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';

  // ---- Header ----
  let payment_no = '';
  let payment_date = new Date().toISOString().split('T')[0];
  let paymentType: 'vendor' | 'expense' = 'vendor';

  // ---- Vendor / Ledger ----
  let vendorSearch = '';
  let vendors: any[] = [];
  let filteredVendors: any[] = [];
  let selectedVendor: any = null;
  let showVendorDropdown = false;

  // ---- Expense ledger (for expense payments) ----
  let expenseLedgers: any[] = [];
  let expenseLedgerSearch = '';
  let filteredExpenseLedgers: any[] = [];
  let selectedExpenseLedger: any = null;
  let showExpenseLedgerDropdown = false;

  // ---- Reference purchase ----
  let purchaseInvoices: any[] = [];
  let purchase_id = '';

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
      loadVendors(),
      loadPaymentModes(),
      loadCashBankLedgers(),
      loadExpenseLedgers(),
      generatePaymentNo(),
    ]);
  });

  async function generatePaymentNo() {
    try {
      const { data } = await supabase.rpc('nextval', { seq_name: 'payment_seq' });
      if (data) { payment_no = 'PAY-' + String(data).padStart(5, '0'); return; }
    } catch {}
    payment_no = 'PAY-' + Date.now();
  }

  async function loadVendors() {
    const { data } = await supabase.from('vendors').select('id, name, place, ledger_id').order('name');
    vendors = data || [];
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

  async function loadExpenseLedgers() {
    const { data: types } = await supabase.from('ledger_types').select('id, name').in('name', ['Expense', 'Operational Expense']);
    const typeIds = (types || []).map((t: any) => t.id);
    const { data } = await supabase.from('ledger').select('id, ledger_name, ledger_type_id').order('ledger_name');
    expenseLedgers = (data || []).filter((l: any) => typeIds.includes(l.ledger_type_id));
  }

  async function loadVendorInvoices(vendorId: string) {
    const { data } = await supabase
      .from('purchases')
      .select('id, invoice_no, invoice_date, net_total, balance_due')
      .eq('vendor_id', vendorId)
      .gt('balance_due', 0)
      .order('invoice_date', { ascending: false });
    purchaseInvoices = data || [];
  }

  // ---- Vendor search ----
  function handleVendorSearch() {
    const q = vendorSearch.toLowerCase().trim();
    if (!q) { filteredVendors = []; showVendorDropdown = false; return; }
    filteredVendors = vendors.filter(v =>
      v.name.toLowerCase().includes(q) || (v.place || '').toLowerCase().includes(q)
    ).slice(0, 10);
    showVendorDropdown = filteredVendors.length > 0;
  }

  function selectVendor(v: any) {
    selectedVendor = v;
    vendorSearch = v.name;
    showVendorDropdown = false;
    purchase_id = '';
    loadVendorInvoices(v.id);
  }

  function clearVendor() {
    selectedVendor = null;
    vendorSearch = '';
    purchaseInvoices = [];
    purchase_id = '';
  }

  // ---- Expense ledger search ----
  function handleExpenseLedgerSearch() {
    const q = expenseLedgerSearch.toLowerCase().trim();
    if (!q) { filteredExpenseLedgers = []; showExpenseLedgerDropdown = false; return; }
    filteredExpenseLedgers = expenseLedgers.filter(l =>
      l.ledger_name.toLowerCase().includes(q)
    ).slice(0, 10);
    showExpenseLedgerDropdown = filteredExpenseLedgers.length > 0;
  }

  function selectExpenseLedger(l: any) {
    selectedExpenseLedger = l;
    expenseLedgerSearch = l.ledger_name;
    showExpenseLedgerDropdown = false;
  }

  function clearExpenseLedger() {
    selectedExpenseLedger = null;
    expenseLedgerSearch = '';
  }

  function switchPaymentType(type: 'vendor' | 'expense') {
    paymentType = type;
    clearVendor();
    clearExpenseLedger();
  }

  // ---- Save payment ----
  async function handleSave() {
    if (paymentType === 'vendor' && !selectedVendor) { saveError = 'Please select a vendor'; return; }
    if (paymentType === 'expense' && !selectedExpenseLedger) { saveError = 'Please select an expense ledger'; return; }
    if (!amount || parseFloat(amount) <= 0) { saveError = 'Enter a valid amount'; return; }
    if (!cash_bank_ledger_id) { saveError = 'Please select a Cash / Bank Ledger'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const { data: pay, error: payErr } = await supabase.from('payments').insert({
      payment_no,
      payment_date,
      ledger_id: paymentType === 'vendor' ? (selectedVendor?.ledger_id || null) : (selectedExpenseLedger?.id || null),
      vendor_id: paymentType === 'vendor' ? selectedVendor?.id : null,
      purchase_id: (paymentType === 'vendor' && purchase_id) ? purchase_id : null,
      amount: parseFloat(amount),
      payment_mode_id: payment_mode_id || null,
      cash_bank_ledger_id: cash_bank_ledger_id || null,
      notes: notes.trim() || null,
      created_by: $authStore.user?.id || null,
    }).select('id').single();

    if (payErr) {
      saving = false;
      saveError = payErr.message;
      return;
    }

    // ---- Ledger entries (double-entry posting) ----
    const payAmt = parseFloat(amount);
    const ledgerEntries: any[] = [];
    const targetLedgerId = paymentType === 'vendor' ? (selectedVendor?.ledger_id || null) : (selectedExpenseLedger?.id || null);

    // Credit Cash/Bank ledger (money going out)
    if (cash_bank_ledger_id && payAmt > 0) {
      ledgerEntries.push({
        entry_date: payment_date,
        ledger_id: cash_bank_ledger_id,
        debit: 0,
        credit: payAmt,
        narration: `Payment - ${payment_no}`,
        reference_type: 'payments',
        reference_id: pay.id,
        created_by: $authStore.user?.id || null,
      });
    }

    // Debit Vendor/Expense ledger
    if (targetLedgerId && payAmt > 0) {
      ledgerEntries.push({
        entry_date: payment_date,
        ledger_id: targetLedgerId,
        debit: payAmt,
        credit: 0,
        narration: `Payment - ${payment_no}`,
        reference_type: 'payments',
        reference_id: pay.id,
        created_by: $authStore.user?.id || null,
      });
    }

    if (ledgerEntries.length > 0) {
      await supabase.from('ledger_entries').insert(ledgerEntries);
    }

    // If linked to a purchase invoice, reduce balance_due
    if (purchase_id) {
      const inv = purchaseInvoices.find(p => p.id === purchase_id);
      if (inv) {
        const newBalance = Math.max(0, (inv.balance_due || 0) - parseFloat(amount));
        const newPaid = (inv.net_total || 0) - newBalance;
        await supabase.from('purchases').update({
          paid_amount: newPaid,
          balance_due: newBalance,
          status: newBalance <= 0 ? 'paid' : 'posted',
          updated_by: $authStore.user?.id || null,
        }).eq('id', purchase_id);
      }
    }

    saving = false;
    saveSuccess = `Payment ${payment_no} saved successfully!`;

    // Reset
    selectedVendor = null;
    vendorSearch = '';
    selectedExpenseLedger = null;
    expenseLedgerSearch = '';
    purchase_id = '';
    purchaseInvoices = [];
    paymentType = 'vendor';
    amount = '';
    payment_mode_id = '';
    cash_bank_ledger_id = '';
    notes = '';
    await generatePaymentNo();

    setTimeout(() => saveSuccess = '', 4000);
  }

  function handleCancel() {
    windowStore.close('finance-payment');
  }
</script>

<div class="entry-window">
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Payment Entry</h2>
      <div class="type-toggle">
        <button class="type-btn" class:active={paymentType === 'vendor'} on:click={() => switchPaymentType('vendor')}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          Vendor Payment
        </button>
        <button class="type-btn expense" class:active={paymentType === 'expense'} on:click={() => switchPaymentType('expense')}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          Expense Payment
        </button>
      </div>
    </div>
    <div class="header-right">
      <span class="doc-tag">#{payment_no}</span>
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
      <!-- Row 1: Payment date + Vendor/Expense -->
      <div class="form-row two-col">
        <div class="field">
          <label for="p-date">Payment Date</label>
          <input id="p-date" type="date" bind:value={payment_date} />
        </div>
        <div class="field">
          {#if paymentType === 'vendor'}
            <label>Vendor</label>
            <div class="search-input-wrap">
              {#if selectedVendor}
                <div class="selected-chip">
                  <span>{selectedVendor.name}</span>
                  <button class="chip-clear" on:click={clearVendor}>&times;</button>
                </div>
              {:else}
                <input type="text" placeholder="Search vendor..." bind:value={vendorSearch} on:input={handleVendorSearch} on:focus={handleVendorSearch} />
                {#if showVendorDropdown}
                  <div class="search-dropdown">
                    {#each filteredVendors as v (v.id)}
                      <button class="dd-item" on:click={() => selectVendor(v)}>
                        <span class="dd-name">{v.name}</span>
                        {#if v.place}<span class="dd-sub">{v.place}</span>{/if}
                      </button>
                    {/each}
                  </div>
                {/if}
              {/if}
            </div>
          {:else}
            <label>Expense Ledger</label>
            <div class="search-input-wrap">
              {#if selectedExpenseLedger}
                <div class="selected-chip expense-chip">
                  <span>{selectedExpenseLedger.ledger_name}</span>
                  <button class="chip-clear" on:click={clearExpenseLedger}>&times;</button>
                </div>
              {:else}
                <input type="text" placeholder="Search expense ledger..." bind:value={expenseLedgerSearch} on:input={handleExpenseLedgerSearch} on:focus={handleExpenseLedgerSearch} />
                {#if showExpenseLedgerDropdown}
                  <div class="search-dropdown">
                    {#each filteredExpenseLedgers as l (l.id)}
                      <button class="dd-item" on:click={() => selectExpenseLedger(l)}>
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

      <!-- Row 2: Reference invoice (vendor only) + Amount -->
      <div class="form-row two-col">
        {#if paymentType === 'vendor'}
          <div class="field">
            <label for="p-inv">Reference Invoice (optional)</label>
            <select id="p-inv" bind:value={purchase_id}>
              <option value="">None</option>
              {#each purchaseInvoices as inv (inv.id)}
                <option value={inv.id}>{inv.invoice_no} — Due ₹{(inv.balance_due || 0).toFixed(2)}</option>
              {/each}
            </select>
          </div>
        {:else}
          <div class="field"></div>
        {/if}
        <div class="field">
          <label for="p-amt">Payment Amount</label>
          <input id="p-amt" type="number" step="0.01" placeholder="0.00" bind:value={amount} />
        </div>
      </div>

      <!-- Row 3: Payment mode + Cash/Bank ledger -->
      <div class="form-row two-col">
        <div class="field">
          <label for="p-pm">Payment Mode</label>
          <select id="p-pm" bind:value={payment_mode_id}>
            <option value="">Select...</option>
            {#each paymentModes as pm (pm.id)}
              <option value={pm.id}>{pm.name}</option>
            {/each}
          </select>
        </div>
        <div class="field">
          <label for="p-cb">Cash / Bank Ledger</label>
          <select id="p-cb" bind:value={cash_bank_ledger_id}>
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
          <label for="p-notes">Notes / Remarks</label>
          <textarea id="p-notes" rows="3" bind:value={notes} placeholder="Optional notes..."></textarea>
        </div>
      </div>
    </div>
  </div>

  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    <button class="btn-save" on:click={handleSave} disabled={saving}>
      {saving ? 'Saving...' : 'Save Payment'}
    </button>
  </div>
</div>

<style>
  .entry-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }

  .form-header { display:flex; align-items:center; justify-content:space-between; padding:14px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#C41E3A; color:#C41E3A; }
  .form-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .doc-tag { font-size:13px; font-weight:600; color:#dc2626; background:#fef2f2; padding:4px 10px; border-radius:6px; border:1px solid #fecaca; }

  .form-body { flex:1; overflow-y:auto; padding:24px; }
  .msg { padding:10px 14px; border-radius:6px; font-size:13px; font-weight:500; margin-bottom:16px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; }

  .form-card { background:white; border:1px solid #e5e7eb; border-radius:12px; padding:24px; display:flex; flex-direction:column; gap:18px; width:100%; box-sizing:border-box; overflow-y:auto; }
  .form-row { display:flex; gap:16px; }
  .two-col > .field { flex:1; }
  .field { display:flex; flex-direction:column; position:relative; }
  .field.full { flex:1; }
  .field label { font-size:12px; font-weight:600; color:#374151; margin-bottom:4px; }
  .field input[type="text"], .field input[type="number"], .field input[type="date"], .field select, .field textarea { padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; background:white; font-family:inherit; }
  .field input:focus, .field select:focus, .field textarea:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,.1); }
  .field textarea { resize:vertical; }

  .search-input-wrap { position:relative; }
  .search-input-wrap input { width:100%; padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; box-sizing:border-box; }
  .search-input-wrap input:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,.1); }
  .selected-chip { display:flex; align-items:center; gap:6px; padding:7px 10px; background:#eef2ff; border:1px solid #c7d2fe; border-radius:6px; font-size:13px; color:#3730a3; }
  .chip-clear { background:none; border:none; font-size:16px; color:#dc2626; cursor:pointer; padding:0 2px; }
  .search-dropdown { position:absolute; top:100%; left:0; right:0; max-height:180px; overflow-y:auto; background:white; border:1px solid #e5e7eb; border-radius:0 0 6px 6px; z-index:50; box-shadow:0 4px 12px rgba(0,0,0,.1); }
  .dd-item { display:flex; align-items:center; justify-content:space-between; width:100%; padding:8px 10px; border:none; background:none; cursor:pointer; font-size:13px; text-align:left; }
  .dd-item:hover { background:#eef2ff; }
  .dd-name { color:#111827; font-weight:500; }
  .dd-sub { color:#9ca3af; font-size:11px; }

  .type-toggle { display:flex; gap:0; border:1px solid #e5e7eb; border-radius:6px; overflow:hidden; margin-left:8px; }
  .type-btn { display:flex; align-items:center; gap:4px; padding:5px 12px; border:none; background:#f9fafb; font-size:12px; font-weight:600; color:#6b7280; cursor:pointer; transition:all .15s; }
  .type-btn.active { background:#dc2626; color:white; }
  .type-btn.expense.active { background:#7c3aed; color:white; }
  .expense-chip { background:#f5f3ff !important; border-color:#c4b5fd !important; color:#5b21b6 !important; }

  .form-footer { display:flex; justify-content:flex-end; gap:10px; padding:14px 20px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-cancel { padding:9px 20px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:8px; font-size:14px; font-weight:500; color:#6b7280; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .btn-save { padding:9px 28px; background:#dc2626; border:none; border-radius:8px; font-size:14px; font-weight:600; color:white; cursor:pointer; transition:background .15s; }
  .btn-save:hover { background:#b91c1c; }
  .btn-save:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:700px) { .two-col { flex-direction:column; } }
</style>
