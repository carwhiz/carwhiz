<!-- ============================================================
     FINANCE > OPERATIONS > PURCHASE INVOICE WINDOW
     Purpose: Full purchase invoice entry with vendor, product search,
              barcode scan, line items, totals, payment, posting
     Window ID: finance-purchase
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  // ---- Invoice header ----
  let invoice_no = '';
  let invoice_date = new Date().toISOString().split('T')[0];
  let purchaseType: 'cash' | 'credit' = 'cash';

  // ---- Vendor ----
  let vendorSearch = '';
  let vendors: any[] = [];
  let filteredVendors: any[] = [];
  let selectedVendor: any = null;
  let showVendorDropdown = false;

  // ---- Products ----
  let allProducts: any[] = [];

  // ---- Product search / barcode ----
  let productSearch = '';
  let filteredProducts: any[] = [];
  let showProductDropdown = false;
  let barcodeInput = '';

  // ---- Purchase lines ----
  interface PurchaseLine {
    product_id: string;
    product_name: string;
    barcode: string;
    unit_id: string;
    unit_name: string;
    qty: number;
    rate: number;
    discount: number;
    line_total: number;
  }
  let lines: PurchaseLine[] = [];

  // ---- Totals ----
  $: subtotal = lines.reduce((s, l) => s + (l.qty * l.rate), 0);
  $: discountTotal = lines.reduce((s, l) => s + l.discount, 0);
  $: netTotal = subtotal - discountTotal;
  let paidAmount: string = '';
  $: balanceDue = netTotal - (parseFloat(paidAmount) || 0);

  // When purchase type changes, auto-set paid amount
  $: if (purchaseType === 'cash') { paidAmount = String(netTotal || ''); } else { paidAmount = '0'; }

  // ---- Payment ----
  let paymentModes: any[] = [];
  let payment_mode_id = '';
  let cashBankLedgers: any[] = [];
  let cash_bank_ledger_id = '';

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  onMount(async () => {
    await Promise.all([
      loadVendors(),
      loadProducts(),
      loadPaymentModes(),
      loadCashBankLedgers(),
      generateInvoiceNo(),
    ]);
  });

  async function generateInvoiceNo() {
    try {
      const { data } = await supabase.rpc('nextval', { seq_name: 'purchase_inv_seq' });
      if (data) { invoice_no = 'PI-' + String(data).padStart(5, '0'); return; }
    } catch {}
    invoice_no = 'PI-' + Date.now();
  }

  async function loadVendors() {
    const { data } = await supabase.from('vendors').select('id, name, place, ledger_id').order('name');
    vendors = data || [];
  }

  async function loadProducts() {
    const { data } = await supabase
      .from('products')
      .select('id, product_name, barcode, unit_id, current_cost, sales_price, units(name)')
      .order('product_name');
    allProducts = (data || []).map((p: any) => ({
      ...p,
      unit_name: p.units?.name || '',
    }));
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
  }

  function clearVendor() {
    selectedVendor = null;
    vendorSearch = '';
  }

  function openQuickCreateVendor() {
    windowStore.open('finance-create-vendor', 'Create Vendor');
  }

  // ---- Product search ----
  function handleProductSearch() {
    const q = productSearch.toLowerCase().trim();
    if (!q) { filteredProducts = []; showProductDropdown = false; return; }
    filteredProducts = allProducts.filter(p =>
      p.product_name.toLowerCase().includes(q) ||
      (p.barcode || '').toLowerCase().includes(q)
    ).slice(0, 10);
    showProductDropdown = filteredProducts.length > 0;
  }

  function addProductToLine(p: any) {
    const existing = lines.findIndex(l => l.product_id === p.id);
    if (existing >= 0) {
      lines[existing].qty += 1;
      recalcLine(existing);
    } else {
      lines = [...lines, {
        product_id: p.id,
        product_name: p.product_name,
        barcode: p.barcode || '',
        unit_id: p.unit_id || '',
        unit_name: p.unit_name || '',
        qty: 1,
        rate: p.current_cost || 0,
        discount: 0,
        line_total: p.current_cost || 0,
      }];
    }
    productSearch = '';
    showProductDropdown = false;
  }

  function handleBarcodeScan() {
    const code = barcodeInput.trim();
    if (!code) return;
    const found = allProducts.find(p => p.barcode === code);
    if (found) {
      addProductToLine(found);
    } else {
      saveError = `No product found with barcode: ${code}`;
      setTimeout(() => saveError = '', 3000);
    }
    barcodeInput = '';
  }

  function removeLine(idx: number) {
    lines = lines.filter((_, i) => i !== idx);
  }

  function recalcLine(idx: number) {
    const l = lines[idx];
    l.line_total = (l.qty * l.rate) - l.discount;
    lines = [...lines];
  }

  function handleQtyChange(idx: number, val: string) {
    lines[idx].qty = parseFloat(val) || 0;
    recalcLine(idx);
  }

  function handleRateChange(idx: number, val: string) {
    lines[idx].rate = parseFloat(val) || 0;
    recalcLine(idx);
  }

  function handleDiscountChange(idx: number, val: string) {
    lines[idx].discount = parseFloat(val) || 0;
    recalcLine(idx);
  }

  // ---- Post Purchase ----
  async function handlePost() {
    if (!selectedVendor) { saveError = 'Please select a vendor'; return; }
    if (lines.length === 0) { saveError = 'Add at least one product'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const paidAmt = parseFloat(paidAmount) || 0;

    const { data: purchase, error: purchErr } = await supabase.from('purchases').insert({
      invoice_no,
      invoice_date,
      vendor_id: selectedVendor.id,
      ledger_id: selectedVendor.ledger_id || null,
      subtotal,
      discount_total: discountTotal,
      net_total: netTotal,
      paid_amount: paidAmt,
      balance_due: netTotal - paidAmt,
      payment_mode_id: payment_mode_id || null,
      cash_bank_ledger_id: cash_bank_ledger_id || null,
      status: (netTotal - paidAmt) <= 0 ? 'paid' : 'posted',
    }).select('id').single();

    if (purchErr || !purchase) {
      saving = false;
      saveError = purchErr?.message || 'Failed to create purchase invoice';
      return;
    }

    const items = lines.map(l => ({
      purchase_id: purchase.id,
      product_id: l.product_id,
      barcode: l.barcode || null,
      unit_id: l.unit_id || null,
      qty: l.qty,
      rate: l.rate,
      discount: l.discount,
      line_total: l.line_total,
    }));

    const { error: itemsErr } = await supabase.from('purchase_items').insert(items);
    if (itemsErr) {
      saving = false;
      saveError = 'Failed to save line items: ' + itemsErr.message;
      return;
    }

    // Stock movements (inward)
    const movements = lines.map(l => ({
      product_id: l.product_id,
      movement_type: 'purchase',
      reference_type: 'purchases',
      reference_id: purchase.id,
      qty: l.qty, // positive = stock in
    }));
    await supabase.from('stock_movements').insert(movements);

    saving = false;
    saveSuccess = `Purchase Invoice ${invoice_no} posted successfully!`;

    // Reset
    lines = [];
    selectedVendor = null;
    vendorSearch = '';
    purchaseType = 'cash';
    paidAmount = '';
    payment_mode_id = '';
    cash_bank_ledger_id = '';
    await generateInvoiceNo();

    setTimeout(() => saveSuccess = '', 4000);
  }
</script>

<div class="pos-window">
  <div class="pos-header">
    <div class="header-left">
      <h2>Purchase Invoice</h2>
      <div class="purchase-type-toggle">
        <button class="type-btn" class:active={purchaseType === 'cash'} on:click={() => purchaseType = 'cash'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
          Cash Purchase
        </button>
        <button class="type-btn credit" class:active={purchaseType === 'credit'} on:click={() => purchaseType = 'credit'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          Credit Purchase
        </button>
      </div>
      <div class="bill-info">
        <span class="bill-tag">Invoice #</span>
        <input type="text" class="bill-no-input" bind:value={invoice_no} readonly />
        <input type="date" class="date-input" bind:value={invoice_date} />
      </div>
    </div>
    <div class="header-right">
      <button class="btn-quick-create" on:click={openQuickCreateVendor} title="Quick Create Vendor">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Vendor
      </button>
    </div>
  </div>

  {#if saveError}
    <div class="msg msg-error">{saveError}</div>
  {/if}
  {#if saveSuccess}
    <div class="msg msg-success">{saveSuccess}</div>
  {/if}

  <div class="pos-body">
    <div class="pos-main">
      <div class="search-row">
        <div class="search-group vendor-search">
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
        </div>

        <div class="search-group product-search">
          <label>Add Product</label>
          <div class="search-input-wrap">
            <input type="text" placeholder="Search product name..." bind:value={productSearch} on:input={handleProductSearch} on:focus={handleProductSearch} />
            {#if showProductDropdown}
              <div class="search-dropdown">
                {#each filteredProducts as p (p.id)}
                  <button class="dd-item" on:click={() => addProductToLine(p)}>
                    <span class="dd-name">{p.product_name}</span>
                    <span class="dd-price">₹{(p.current_cost || 0).toFixed(2)}</span>
                  </button>
                {/each}
              </div>
            {/if}
          </div>
        </div>

        <div class="search-group barcode-search">
          <label>Barcode</label>
          <div class="search-input-wrap barcode-wrap">
            <input type="text" placeholder="Scan / enter barcode" bind:value={barcodeInput} on:keydown={e => e.key === 'Enter' && handleBarcodeScan()} />
            <button class="barcode-go" on:click={handleBarcodeScan}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="9 18 15 12 9 6"/></svg>
            </button>
          </div>
        </div>
      </div>

      <div class="lines-table-wrap">
        <table class="lines-table">
          <thead>
            <tr>
              <th class="col-num">#</th>
              <th class="col-product">Product</th>
              <th class="col-barcode">Barcode</th>
              <th class="col-unit">Unit</th>
              <th class="col-qty">Qty</th>
              <th class="col-rate">Cost</th>
              <th class="col-disc">Discount</th>
              <th class="col-total">Total</th>
              <th class="col-act"></th>
            </tr>
          </thead>
          <tbody>
            {#if lines.length === 0}
              <tr><td colspan="9" class="empty-row">No items added. Search or scan a product above.</td></tr>
            {:else}
              {#each lines as line, idx (idx)}
                <tr>
                  <td class="col-num">{idx + 1}</td>
                  <td class="col-product">{line.product_name}</td>
                  <td class="col-barcode">{line.barcode}</td>
                  <td class="col-unit">{line.unit_name}</td>
                  <td class="col-qty"><input type="number" min="0" step="1" value={line.qty} on:input={e => handleQtyChange(idx, e.currentTarget.value)} /></td>
                  <td class="col-rate"><input type="number" min="0" step="0.01" value={line.rate} on:input={e => handleRateChange(idx, e.currentTarget.value)} /></td>
                  <td class="col-disc"><input type="number" min="0" step="0.01" value={line.discount} on:input={e => handleDiscountChange(idx, e.currentTarget.value)} /></td>
                  <td class="col-total num">{line.line_total.toFixed(2)}</td>
                  <td class="col-act"><button class="remove-btn" on:click={() => removeLine(idx)}>&times;</button></td>
                </tr>
              {/each}
            {/if}
          </tbody>
        </table>
      </div>
    </div>

    <div class="pos-sidebar">
      <div class="totals-card">
        <h3>Invoice Summary</h3>
        <div class="total-row"><span>Subtotal</span><span class="num">₹{subtotal.toFixed(2)}</span></div>
        <div class="total-row"><span>Discount</span><span class="num disc">-₹{discountTotal.toFixed(2)}</span></div>
        <div class="total-row net"><span>Net Total</span><span class="num">₹{netTotal.toFixed(2)}</span></div>
        <hr />
        <div class="pay-field">
          <label>Payment Mode</label>
          <select bind:value={payment_mode_id}>
            <option value="">Select...</option>
            {#each paymentModes as pm (pm.id)}
              <option value={pm.id}>{pm.name}</option>
            {/each}
          </select>
        </div>
        <div class="pay-field">
          <label>Cash / Bank Ledger</label>
          <select bind:value={cash_bank_ledger_id}>
            <option value="">Select...</option>
            {#each cashBankLedgers as cb (cb.id)}
              <option value={cb.id}>{cb.ledger_name}</option>
            {/each}
          </select>
        </div>
        <div class="pay-field">
          <label>Paid Amount</label>
          <input type="number" step="0.01" placeholder="0.00" bind:value={paidAmount} />
        </div>
        <div class="total-row balance" class:overdue={balanceDue > 0}>
          <span>Outstanding</span><span class="num">₹{balanceDue.toFixed(2)}</span>
        </div>
      </div>

      <button class="btn-post" on:click={handlePost} disabled={saving}>
        {saving ? 'Posting...' : 'Post Invoice'}
      </button>
    </div>
  </div>
</div>

<style>
  .pos-window { width:100%; height:100%; display:flex; flex-direction:column; background:#f8f9fb; font-family:inherit; }

  .pos-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:16px; }
  .pos-header h2 { margin:0; font-size:16px; font-weight:700; color:#111827; white-space:nowrap; }
  .bill-info { display:flex; align-items:center; gap:8px; }
  .bill-tag { font-size:12px; font-weight:600; color:#6b7280; }
  .bill-no-input { width:110px; padding:5px 8px; border:1px solid #e5e7eb; border-radius:5px; font-size:13px; background:#f9fafb; color:#374151; }
  .date-input { padding:5px 8px; border:1px solid #e5e7eb; border-radius:5px; font-size:13px; }
  .btn-quick-create { display:flex; align-items:center; gap:5px; padding:6px 12px; background:#eef2ff; border:1px solid #a5b4fc; border-radius:6px; font-size:12px; font-weight:600; color:#4f46e5; cursor:pointer; }
  .btn-quick-create:hover { background:#e0e7ff; }

  .purchase-type-toggle { display:flex; gap:0; border:1px solid #e5e7eb; border-radius:6px; overflow:hidden; }
  .type-btn { display:flex; align-items:center; gap:4px; padding:5px 12px; border:none; background:#f9fafb; font-size:12px; font-weight:600; color:#6b7280; cursor:pointer; transition:all .15s; }
  .type-btn.active { background:#4f46e5; color:white; }
  .type-btn.credit.active { background:#7c3aed; color:white; }

  .msg { padding:8px 14px; font-size:12px; font-weight:500; margin:0 18px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; border-radius:6px; margin-top:8px; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; border-radius:6px; margin-top:8px; }

  .pos-body { display:flex; flex:1; overflow:hidden; }
  .pos-main { flex:1; display:flex; flex-direction:column; overflow:hidden; padding:14px 18px; gap:12px; }
  .pos-sidebar { width:260px; flex-shrink:0; padding:14px 18px 14px 0; display:flex; flex-direction:column; gap:12px; }

  .search-row { display:flex; gap:10px; flex-shrink:0; }
  .search-group { display:flex; flex-direction:column; flex:1; position:relative; }
  .vendor-search { flex:1.2; }
  .product-search { flex:1.5; }
  .barcode-search { flex:0.8; }
  .search-group label { font-size:11px; font-weight:600; color:#6b7280; margin-bottom:3px; }
  .search-input-wrap { position:relative; }
  .search-input-wrap input { width:100%; padding:7px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; box-sizing:border-box; }
  .search-input-wrap input:focus { border-color:#F97316; box-shadow:0 0 0 2px rgba(249,115,22,.1); }

  .selected-chip { display:flex; align-items:center; gap:6px; padding:5px 10px; background:#eef2ff; border:1px solid #c7d2fe; border-radius:6px; font-size:13px; color:#3730a3; }
  .chip-clear { background:none; border:none; font-size:16px; color:#dc2626; cursor:pointer; padding:0 2px; }

  .search-dropdown { position:absolute; top:100%; left:0; right:0; max-height:200px; overflow-y:auto; background:white; border:1px solid #e5e7eb; border-radius:0 0 6px 6px; z-index:50; box-shadow:0 4px 12px rgba(0,0,0,.1); }
  .dd-item { display:flex; align-items:center; justify-content:space-between; width:100%; padding:8px 10px; border:none; background:none; cursor:pointer; font-size:13px; text-align:left; }
  .dd-item:hover { background:#eef2ff; }
  .dd-name { color:#111827; font-weight:500; }
  .dd-sub { color:#9ca3af; font-size:11px; }
  .dd-price { color:#4f46e5; font-weight:600; font-size:12px; }

  .barcode-wrap { display:flex; gap:0; }
  .barcode-wrap input { border-radius:6px 0 0 6px; flex:1; }
  .barcode-go { display:flex; align-items:center; justify-content:center; padding:0 10px; background:#4f46e5; color:white; border:1px solid #4f46e5; border-radius:0 6px 6px 0; cursor:pointer; }
  .barcode-go:hover { background:#4338ca; }

  .lines-table-wrap { flex:1; overflow-y:auto; border:1px solid #e5e7eb; border-radius:8px; background:white; }
  .lines-table { width:100%; border-collapse:collapse; font-size:13px; }
  .lines-table thead { position:sticky; top:0; z-index:2; }
  .lines-table th { padding:8px; background:#f9fafb; font-weight:600; color:#6b7280; text-align:left; border-bottom:1px solid #e5e7eb; font-size:11px; text-transform:uppercase; }
  .lines-table td { padding:6px 8px; border-bottom:1px solid #f3f4f6; color:#374151; }
  .lines-table .num { text-align:right; font-family:'Courier New',monospace; font-weight:600; }
  .col-num { width:30px; text-align:center; }
  .col-product { min-width:140px; }
  .col-barcode { width:100px; }
  .col-unit { width:60px; }
  .col-qty, .col-rate, .col-disc { width:80px; }
  .col-total { width:90px; }
  .col-act { width:30px; text-align:center; }
  .lines-table td input { width:100%; padding:4px 6px; border:1px solid #e5e7eb; border-radius:4px; font-size:13px; text-align:right; outline:none; box-sizing:border-box; }
  .lines-table td input:focus { border-color:#4f46e5; }
  .empty-row { text-align:center; color:#9ca3af; padding:30px 0 !important; font-style:italic; }
  .remove-btn { background:none; border:none; color:#dc2626; font-size:18px; cursor:pointer; padding:0; line-height:1; }
  .remove-btn:hover { color:#991b1b; }

  .totals-card { background:white; border:1px solid #e5e7eb; border-radius:10px; padding:16px; display:flex; flex-direction:column; gap:8px; }
  .totals-card h3 { margin:0 0 4px; font-size:14px; font-weight:700; color:#111827; }
  .total-row { display:flex; justify-content:space-between; align-items:center; font-size:13px; color:#374151; }
  .total-row .num { font-family:'Courier New',monospace; font-weight:600; }
  .total-row .disc { color:#dc2626; }
  .total-row.net { font-size:15px; font-weight:700; color:#111827; padding:4px 0; }
  .total-row.balance { font-size:14px; font-weight:700; padding:6px 0 0; }
  .total-row.balance.overdue .num { color:#dc2626; }
  .totals-card hr { border:none; border-top:1px solid #e5e7eb; margin:4px 0; }

  .pay-field { display:flex; flex-direction:column; gap:3px; }
  .pay-field label { font-size:11px; font-weight:600; color:#6b7280; }
  .pay-field select, .pay-field input { padding:6px 8px; border:1px solid #d1d5db; border-radius:5px; font-size:13px; outline:none; }
  .pay-field select:focus, .pay-field input:focus { border-color:#4f46e5; }

  .btn-post { padding:10px; background:#4f46e5; border:none; border-radius:8px; font-size:14px; font-weight:700; color:white; cursor:pointer; transition:background .15s; }
  .btn-post:hover { background:#4338ca; }
  .btn-post:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:800px) {
    .pos-body { flex-direction:column; }
    .pos-sidebar { width:100%; flex-direction:row; flex-wrap:wrap; padding:10px 18px; }
    .search-row { flex-direction:column; }
  }
</style>
