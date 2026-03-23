<!-- ============================================================
     FINANCE > OPERATIONS > PURCHASE RETURN WINDOW
     Purpose: Process purchase returns - can import invoices, adjust qtys, remove items
     Window ID: finance-purchase-return
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import { canUserCreateResource } from '../../../../lib/services/permissionService';

  let permDenied = false;

  // ---- Return Invoice header ----
  let return_no = '';
  let return_date = new Date().toISOString().split('T')[0];

  // ---- Invoice Import ----
  let showInvoiceImport = false;
  let closedInvoices: any[] = [];
  let selectedInvoice: any = null;
  let invoiceSearch = '';
  let filteredInvoices: any[] = [];
  let showInvoiceDropdown = false;

  // ---- Vendor ----
  let selectedVendor: any = null;

  // ---- Items ----
  interface ReturnItem {
    purchase_item_id: string;
    product_id: string;
    product_name: string;
    original_qty: number;
    original_rate: number;
    qty: number; // qty to return
    rate: number;
    line_total: number;
  }
  let returnItems: ReturnItem[] = [];
  $: grandTotal = returnItems.reduce((s, i) => s + i.line_total, 0);

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';
  let showSuccess = false;
  let savedReturnNo = '';

  onMount(async () => {
    const userId = $authStore.user?.id;
    if (userId) {
      const allowed = await canUserCreateResource(userId, 'finance-purchase-return');
      if (!allowed) { permDenied = true; return; }
    }
    await loadClosedInvoices();
  });

  async function loadClosedInvoices() {
    const { data } = await supabase
      .from('purchases')
      .select('id, invoice_no, invoice_date, vendor_id, vendors(name), net_total')
      .neq('status', 'cancelled')
      .order('invoice_date', { ascending: false })
      .limit(100);
    closedInvoices = data || [];
  }

  async function importInvoice(invoice: any) {
    // Load invoice items
    const { data: items } = await supabase
      .from('purchase_items')
      .select('id, product_id, products(product_name), qty, rate')
      .eq('purchase_id', invoice.id);

    if (!items || items.length === 0) {
      saveError = 'No items in this invoice';
      return;
    }

    selectedInvoice = invoice;
    selectedVendor = invoice.vendors;
    
    returnItems = (items || []).map((it: any) => ({
      purchase_item_id: it.id,
      product_id: it.product_id,
      product_name: it.products?.product_name || 'Unknown',
      original_qty: it.qty,
      original_rate: it.rate,
      qty: 0, // Start with 0, user can adjust
      rate: it.rate,
      line_total: 0,
    }));

    showInvoiceImport = false;
    saveError = '';
  }

  function updateItemQty(index: number, qty: number) {
    const item = returnItems[index];
    if (qty < 0) qty = 0;
    if (qty > item.original_qty) qty = item.original_qty;
    item.qty = qty;
    item.line_total = qty * item.rate;
    returnItems = returnItems; // Trigger reactivity
  }

  function removeItem(index: number) {
    returnItems.splice(index, 1);
    returnItems = returnItems;
  }

  async function handleSaveReturn() {
    if (!selectedInvoice) {
      saveError = 'Invoice not selected';
      return;
    }
    if (!selectedVendor) {
      saveError = 'Vendor not found';
      return;
    }
    const returnedItems = returnItems.filter(i => i.qty > 0);
    if (returnedItems.length === 0) {
      saveError = 'At least one item must be returned';
      return;
    }

    saving = true;
    saveError = '';

    // Generate return number
    const now = new Date();
    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const year = now.getFullYear();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const returnNoValue = `PRET-${day}${month}${year}${hours}${minutes}-${selectedInvoice.invoice_no}`;

    // Calculate totals
    const subtotal = returnedItems.reduce((s, i) => s + (i.qty * i.rate), 0);
    const netTotal = subtotal;

    // Create purchase return
    const { data: ret, error: retErr } = await supabase.from('purchase_returns').insert({
      return_no: returnNoValue,
      return_date,
      original_invoice_id: selectedInvoice.id,
      vendor_id: selectedVendor.id,
      subtotal,
      discount_total: 0,
      net_total: netTotal,
      created_by: $authStore.user?.id || null,
    }).select('id, return_no').single();

    if (retErr || !ret) {
      saving = false;
      saveError = 'Failed to create return: ' + (retErr?.message || '');
      return;
    }

    // Save return items
    const itemRows = returnedItems.map(it => ({
      purchase_return_id: ret.id,
      purchase_item_id: it.purchase_item_id,
      product_id: it.product_id,
      qty: it.qty,
      rate: it.rate,
      line_total: it.line_total,
      created_by: $authStore.user?.id || null,
    }));

    const { error: itemsErr } = await supabase.from('purchase_return_items').insert(itemRows);
    if (itemsErr) {
      saving = false;
      saveError = 'Return created but failed to save items: ' + itemsErr.message;
      return;
    }

    // Stock movements (outward - negative qty for returned items)
    const movements: any[] = [];
    for (const item of returnedItems) {
      movements.push({
        product_id: item.product_id,
        movement_type: 'purchase_return',
        reference_type: 'purchase_returns',
        reference_id: ret.id,
        qty: -(item.qty), // Negative for return/outward
        created_by: $authStore.user?.id || null,
      });
    }
    if (movements.length > 0) {
      await supabase.from('stock_movements').insert(movements);
    }

    // Ledger entries
    const ledgerEntries: any[] = [];
    const vendorLedgerId = selectedVendor.ledger_id;

    // Credit Purchase Return Account (Contra Expense)
    const { data: purRetLedger } = await supabase
      .from('ledger')
      .select('id')
      .eq('ledger_name', 'Purchase Return Account')
      .maybeSingle();

    if (purRetLedger) {
      ledgerEntries.push({
        entry_date: return_date,
        ledger_id: purRetLedger.id,
        debit: 0,
        credit: netTotal,
        narration: `Purchase Return - ${returnNoValue}`,
        reference_type: 'purchase_returns',
        reference_id: ret.id,
        created_by: $authStore.user?.id || null,
      });
    }

    // Debit Vendor ledger
    if (vendorLedgerId) {
      ledgerEntries.push({
        entry_date: return_date,
        ledger_id: vendorLedgerId,
        debit: netTotal,
        credit: 0,
        narration: `Purchase Return - ${returnNoValue}`,
        reference_type: 'purchase_returns',
        reference_id: ret.id,
        created_by: $authStore.user?.id || null,
      });
    }

    if (ledgerEntries.length > 0) {
      await supabase.from('ledger_entries').insert(ledgerEntries);
    }

    saving = false;
    savedReturnNo = ret.return_no;
    saveSuccess = `Return ${returnNoValue} created successfully!`;
    showSuccess = true;
  }

  function handleNewReturn() {
    selectedInvoice = null;
    selectedVendor = null;
    returnItems = [];
    return_date = new Date().toISOString().split('T')[0];
    saveError = '';
    saveSuccess = '';
    showSuccess = false;
  }

  function handleClose() {
    windowStore.closeWindow('finance-purchase-return');
  }

  function filterInvoices() {
    const search = invoiceSearch.toLowerCase();
    filteredInvoices = closedInvoices.filter(i =>
      i.invoice_no.toLowerCase().includes(search) ||
      i.vendors?.name.toLowerCase().includes(search)
    );
  }

  $: invoiceSearch, filterInvoices();
</script>

<div class="return-window">
  {#if permDenied}
    <div class="perm-denied"><p>You do not have permission to create purchase returns.</p></div>
  {:else if showSuccess}
    <!-- ===== SUCCESS SCREEN ===== -->
    <div class="success-screen">
      <div class="success-card">
        <svg viewBox="0 0 24 24" fill="none" stroke="#16a34a" stroke-width="2" width="60" height="60"><circle cx="12" cy="12" r="10"/><polyline points="9 12 11 14 15 10"/></svg>
        <h2>Return Created!</h2>
        <p class="return-no">{savedReturnNo}</p>
        <div class="success-actions">
          <button class="btn-primary" on:click={handleNewReturn}>Create Another</button>
          <button class="btn-secondary" on:click={handleClose}>Close</button>
        </div>
      </div>
    </div>
  {:else}
    <!-- ===== MAIN FORM ===== -->
    <div class="form-section">
      <h3>Purchase Return</h3>

      {#if !selectedInvoice}
        <!-- Invoice Selection -->
        <div class="form-group">
          <label>Select Invoice to Return</label>
          <div class="search-box">
            <input
              type="text"
              placeholder="Search invoice no or vendor..."
              bind:value={invoiceSearch}
              on:focus={() => (showInvoiceDropdown = true)}
            />
            {#if showInvoiceDropdown && filteredInvoices.length > 0}
              <div class="dropdown">
                {#each filteredInvoices as invoice}
                  <div class="dropdown-item" on:click={() => importInvoice(invoice)}>
                    <strong>{invoice.invoice_no}</strong>
                    <span class="sub">{invoice.vendors?.name} — ₹{invoice.net_total.toLocaleString('en-IN')}</span>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </div>
      {/if}

      {#if selectedInvoice && selectedVendor}
        <!-- Invoice Info -->
        <div class="info-box">
          <div class="info-row">
            <strong>Invoice No:</strong> {selectedInvoice.invoice_no}
          </div>
          <div class="info-row">
            <strong>Vendor:</strong> {selectedVendor.name}
          </div>
          <div class="info-row">
            <strong>Original Amount:</strong> ₹{selectedInvoice.net_total.toLocaleString('en-IN')}
          </div>
        </div>

        <!-- Return Date -->
        <div class="form-group">
          <label for="return-date">Return Date</label>
          <input type="date" id="return-date" bind:value={return_date} />
        </div>

        <!-- Items Table -->
        <div class="items-section">
          <h4>Return Items (Select quantities to return)</h4>
          <table class="items-table">
            <thead>
              <tr>
                <th>Product</th>
                <th class="r">Orig. Qty</th>
                <th class="r">Rate</th>
                <th class="r">Return Qty</th>
                <th class="r">Line Total</th>
                <th class="c">Action</th>
              </tr>
            </thead>
            <tbody>
              {#each returnItems as item, idx}
                <tr>
                  <td>{item.product_name}</td>
                  <td class="r">{item.original_qty.toLocaleString('en-IN', {maximumFractionDigits: 3})}</td>
                  <td class="r">₹{item.rate.toLocaleString('en-IN', {maximumFractionDigits: 2})}</td>
                  <td class="r">
                    <input
                      type="number"
                      min="0"
                      max={item.original_qty}
                      step="0.001"
                      value={item.qty}
                      on:input={e => updateItemQty(idx, parseFloat(e.target.value) || 0)}
                      class="qty-input"
                    />
                  </td>
                  <td class="r">₹{item.line_total.toLocaleString('en-IN', {maximumFractionDigits: 2})}</td>
                  <td class="c">
                    <button class="btn-remove" on:click={() => removeItem(idx)}>✕</button>
                  </td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr>
                <td colspan="4" style="text-align: right; font-weight: bold;">Total:</td>
                <td class="r" style="font-weight: bold;">₹{grandTotal.toLocaleString('en-IN', {maximumFractionDigits: 2})}</td>
                <td></td>
              </tr>
            </tfoot>
          </table>
        </div>

        {#if saveError}
          <div class="error-box">{saveError}</div>
        {/if}

        <!-- Buttons -->
        <div class="button-group">
          <button class="btn-primary" on:click={handleSaveReturn} disabled={saving}>
            {saving ? 'Processing...' : 'Create Return'}
          </button>
          <button class="btn-secondary" on:click={handleNewReturn}>New Return</button>
          <button class="btn-secondary" on:click={handleClose}>Close</button>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .return-window {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow-y: auto;
    background: #fafafa;
    padding: 20px;
    gap: 15px;
  }

  .form-section {
    background: white;
    border-radius: 8px;
    padding: 20px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  h3 {
    margin: 0 0 20px 0;
    font-size: 18px;
    color: #333;
  }

  h4 {
    margin: 15px 0 10px 0;
    font-size: 14px;
    color: #555;
  }

  .form-group {
    margin-bottom: 15px;
  }

  label {
    display: block;
    margin-bottom: 6px;
    font-weight: 600;
    font-size: 13px;
    color: #333;
  }

  input[type="text"],
  input[type="date"],
  input[type="number"] {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 13px;
    font-family: inherit;
  }

  input[type="text"]:focus,
  input[type="date"]:focus,
  input[type="number"]:focus {
    outline: none;
    border-color: #4a90e2;
    box-shadow: 0 0 0 2px rgba(74, 144, 226, 0.1);
  }

  .search-box {
    position: relative;
  }

  .dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: white;
    border: 1px solid #ddd;
    border-top: none;
    max-height: 200px;
    overflow-y: auto;
    z-index: 10;
  }

  .dropdown-item {
    padding: 10px;
    cursor: pointer;
    border-bottom: 1px solid #eee;
    transition: background 0.15s;
  }

  .dropdown-item:hover {
    background: #f5f5f5;
  }

  .dropdown-item strong {
    display: block;
    margin-bottom: 3px;
    color: #333;
  }

  .dropdown-item .sub {
    font-size: 12px;
    color: #666;
  }

  .info-box {
    background: #f9f9f9;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 12px;
    margin-bottom: 15px;
  }

  .info-row {
    margin: 6px 0;
    font-size: 13px;
  }

  .items-section {
    margin: 20px 0;
  }

  .items-table {
    width: 100%;
    border-collapse: collapse;
    border: 1px solid #ddd;
    background: white;
  }

  .items-table th,
  .items-table td {
    padding: 8px 10px;
    text-align: left;
    font-size: 12px;
    border: 1px solid #ddd;
  }

  .items-table th {
    background: #f5f5f5;
    font-weight: 600;
    color: #333;
  }

  .items-table th.r,
  .items-table td.r {
    text-align: right;
  }

  .items-table th.c,
  .items-table td.c {
    text-align: center;
  }

  .items-table tbody tr:hover {
    background: #fafafa;
  }

  .qty-input {
    width: 70px !important;
    text-align: right;
  }

  .btn-remove {
    padding: 4px 8px;
    background: #f5f5f5;
    border: 1px solid #ddd;
    border-radius: 3px;
    cursor: pointer;
    font-size: 12px;
    color: #d9534f;
    transition: all 0.15s;
  }

  .btn-remove:hover {
    background: #d9534f;
    color: white;
    border-color: #d9534f;
  }

  .error-box {
    background: #fee;
    border: 1px solid #fcc;
    border-radius: 4px;
    padding: 10px;
    color: #c33;
    margin: 10px 0;
    font-size: 13px;
  }

  .button-group {
    display: flex;
    gap: 8px;
    margin-top: 20px;
  }

  .btn-primary,
  .btn-secondary {
    padding: 10px 16px;
    border: none;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-primary {
    background: #4a90e2;
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background: #357abc;
  }

  .btn-primary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .btn-secondary {
    background: #f5f5f5;
    color: #333;
    border: 1px solid #ddd;
  }

  .btn-secondary:hover {
    background: #efefef;
  }

  .success-screen {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    background: white;
  }

  .success-card {
    text-align: center;
    display: flex;
    flex-direction: column;
    gap: 15px;
  }

  .success-card svg {
    margin: 0 auto;
  }

  .success-card h2 {
    margin: 0;
    color: #16a34a;
  }

  .return-no {
    font-size: 18px;
    font-weight: bold;
    color: #333;
    margin: 0;
  }

  .success-actions {
    display: flex;
    gap: 8px;
    justify-content: center;
  }

  .perm-denied {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    color: #c33;
    font-weight: 600;
  }
</style>
