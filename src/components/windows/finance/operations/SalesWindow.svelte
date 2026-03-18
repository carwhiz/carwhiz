<!-- ============================================================
     FINANCE > OPERATIONS > SALES / POS BILLING WINDOW
     Purpose: Full POS billing with customer, product search,
              barcode scan, line items, totals, payment, posting
     Window ID: finance-sales
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';

  // ---- Bill header ----
  let bill_no = '';
  let bill_date = new Date().toISOString().split('T')[0];
  let saleType: 'cash' | 'credit' = 'cash';

  // ---- Customer ----
  let customerSearch = '';
  let customers: any[] = [];
  let filteredCustomers: any[] = [];
  let selectedCustomer: any = null;
  let showCustomerDropdown = false;

  // ---- Products master data ----
  let allProducts: any[] = [];

  // ---- Product search / barcode ----
  let productSearch = '';
  let filteredProducts: any[] = [];
  let showProductDropdown = false;
  let barcodeInput = '';

  // ---- Bill lines ----
  interface BillLine {
    product_id: string;
    product_name: string;
    product_type: string;
    barcode: string;
    unit_id: string;
    unit_name: string;
    unit_qty: number;
    qty: number;
    rate: number;
    discount: number;
    line_total: number;
  }
  let lines: BillLine[] = [];

  // ---- Totals ----
  $: subtotal = lines.reduce((s, l) => s + (l.qty * l.rate), 0);
  $: discountTotal = lines.reduce((s, l) => s + l.discount, 0);
  $: netTotal = subtotal - discountTotal;
  let paidAmount: string = '';
  $: balanceDue = netTotal - (parseFloat(paidAmount) || 0);

  // When sale type changes, auto-set paid amount and clear payment fields for credit
  $: if (saleType === 'cash') { paidAmount = String(netTotal || ''); } else { paidAmount = '0'; payment_mode_id = ''; cash_bank_ledger_id = ''; }

  // ---- Payment ----
  let paymentModes: any[] = [];
  let payment_mode_id = '';
  let cashBankLedgers: any[] = [];
  let cash_bank_ledger_id = '';
  let salesLedgerId = ''; // Sales Account (Revenue) - auto-fetched

  // ---- Job Card Import ----
  let showJobCardImport = false;
  let closedJobCards: any[] = [];
  let jcLoading = false;
  let selectedJobCard: any = null;
  let jcItems: any[] = [];

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';
  let importedJobCardId = '';

  onMount(async () => {
    await Promise.all([
      loadCustomers(),
      loadProducts(),
      loadPaymentModes(),
      loadCashBankLedgers(),
      loadSalesLedger(),
      generateBillNo(),
    ]);
  });

  async function generateBillNo() {
    try {
      const { data } = await supabase.rpc('nextval', { seq_name: 'sales_bill_seq' });
      if (data) { bill_no = 'SB-' + String(data).padStart(5, '0'); return; }
    } catch {}
    bill_no = 'SB-' + Date.now();
  }

  async function loadCustomers() {
    const { data } = await supabase.from('customers').select('id, name, place, ledger_id').order('name');
    customers = data || [];
  }

  async function loadProducts() {
    const { data } = await supabase
      .from('products')
      .select('id, product_name, product_type, barcode, unit_id, unit_qty, sales_price, current_cost, units(name)')
      .order('product_name');
    allProducts = (data || []).map((p: any) => ({
      ...p,
      unit_qty: p.unit_qty || 1,
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

  async function loadClosedJobCards() {
    jcLoading = true;
    const { data } = await supabase
      .from('job_cards')
      .select('id, job_card_no, description, customer_id, vehicle_id, customers(name), vehicles(model_name)')
      .eq('status', 'Closed')
      .is('billed_invoice_id', null)
      .order('created_at', { ascending: false });
    closedJobCards = (data || []).map((j: any) => ({
      ...j,
      customer_name: j.customers?.name || '—',
      vehicle_name: j.vehicles?.model_name || '—',
    }));
    jcLoading = false;
  }

  async function importJobCard(jc: any) {
    // Load job card items
    const { data: items } = await supabase
      .from('job_card_items')
      .select('item_type, item_id, name, qty, price, discount, total')
      .eq('job_card_id', jc.id);

    if (!items || items.length === 0) { saveError = 'No items in this job card'; return; }

    // Set customer
    const cust = customers.find(c => c.id === jc.customer_id);
    if (cust) { selectedCustomer = cust; customerSearch = cust.name; }

    // Set line items
    lines = items.map((it: any) => {
      const prod = allProducts.find(p => p.id === it.item_id);
      return {
        product_id: it.item_id || '',
        product_name: it.name,
        product_type: it.item_type || 'product',
        barcode: prod?.barcode || '',
        unit_id: prod?.unit_id || '',
        unit_name: prod?.unit_name || '',
        unit_qty: prod?.unit_qty || 1,
        qty: it.qty || 1,
        rate: it.price || 0,
        discount: it.discount || 0,
        line_total: it.total || ((it.qty || 1) * (it.price || 0) - (it.discount || 0)),
      };
    });

    importedJobCardId = jc.id;
    selectedJobCard = jc;
    showJobCardImport = false;
  }

  async function loadSalesLedger() {
    // Ind AS: Sales must credit a Revenue ledger ("Sales Account")
    const { data } = await supabase.from('ledger').select('id, ledger_name').eq('ledger_name', 'Sales Account').maybeSingle();
    if (data) { salesLedgerId = data.id; return; }
    // Auto-create if not exists
    const { data: revType } = await supabase.from('ledger_types').select('id').eq('name', 'Revenue').maybeSingle();
    const { data: incCat } = await supabase.from('ledger_categories').select('id').eq('name', 'Income').maybeSingle();
    if (revType) {
      const { data: created } = await supabase.from('ledger').insert({
        ledger_name: 'Sales Account',
        ledger_type_id: revType.id,
        ledger_category_id: incCat?.id || null,
        opening_balance: 0,
        status: 'active',
        created_by: $authStore.user?.id || null,
      }).select('id').single();
      if (created) salesLedgerId = created.id;
    }
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
  }

  function clearCustomer() {
    selectedCustomer = null;
    customerSearch = '';
  }

  function openQuickCreateCustomer() {
    windowStore.open('finance-create-customer', 'Create Customer');
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
        product_type: p.product_type || 'product',
        barcode: p.barcode || '',
        unit_id: p.unit_id || '',
        unit_name: p.unit_name || '',
        unit_qty: p.unit_qty || 1,
        qty: 1,
        rate: p.sales_price || 0,
        discount: 0,
        line_total: p.sales_price || 0,
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

  // ---- Save / Post Bill ----
  async function handlePost() {
    if (!selectedCustomer) { saveError = 'Please select a customer'; return; }
    if (lines.length === 0) { saveError = 'Add at least one product'; return; }
    const paidAmt = parseFloat(paidAmount) || 0;
    if (saleType === 'cash' && !payment_mode_id) { saveError = 'Please select a Payment Mode for cash sale'; return; }
    if (saleType === 'cash' && !cash_bank_ledger_id) { saveError = 'Please select a Cash / Bank Ledger for cash sale'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const { data: sale, error: saleErr } = await supabase.from('sales').insert({
      bill_no,
      bill_date,
      customer_id: selectedCustomer.id,
      ledger_id: selectedCustomer.ledger_id || null,
      subtotal,
      discount_total: discountTotal,
      net_total: netTotal,
      paid_amount: paidAmt,
      balance_due: netTotal - paidAmt,
      payment_mode_id: payment_mode_id || null,
      cash_bank_ledger_id: cash_bank_ledger_id || null,
      status: (netTotal - paidAmt) <= 0 ? 'paid' : 'posted',
      created_by: $authStore.user?.id || null,
    }).select('id').single();

    if (saleErr || !sale) {
      saving = false;
      saveError = saleErr?.message || 'Failed to create bill';
      return;
    }

    const items = lines.map(l => ({
      sales_id: sale.id,
      product_id: l.product_id,
      barcode: l.barcode || null,
      unit_id: l.unit_id || null,
      qty: l.qty,
      rate: l.rate,
      discount: l.discount,
      line_total: l.line_total,
      created_by: $authStore.user?.id || null,
    }));

    const { error: itemsErr } = await supabase.from('sales_items').insert(items);
    if (itemsErr) {
      saving = false;
      saveError = 'Failed to save line items: ' + itemsErr.message;
      return;
    }

    // Stock movements (outward)
    // For regular products/consumables: DB trigger multiplies by unit_qty
    // For services: reduce stock of each component (no unit_qty multiply)
    const movements: any[] = [];
    for (const l of lines) {
      if (l.product_type === 'service') {
        // Fetch service components and create movements for each
        const { data: comps } = await supabase
          .from('product_components')
          .select('component_product_id, qty')
          .eq('product_id', l.product_id);
        for (const comp of (comps || [])) {
          movements.push({
            product_id: comp.component_product_id,
            movement_type: 'service_sale',
            reference_type: 'sales',
            reference_id: sale.id,
            qty: -(comp.qty * l.qty),
            created_by: $authStore.user?.id || null,
          });
        }
      } else {
        movements.push({
          product_id: l.product_id,
          movement_type: 'sale',
          reference_type: 'sales',
          reference_id: sale.id,
          qty: -(l.qty),
          created_by: $authStore.user?.id || null,
        });
      }
    }
    if (movements.length > 0) {
      await supabase.from('stock_movements').insert(movements);
    }

    // ---- Ledger entries (Ind AS double-entry posting) ----
    const ledgerEntries: any[] = [];
    const customerLedgerId = selectedCustomer.ledger_id;

    // 1. Credit Sales Account (Revenue) for full sale amount (Ind AS 115)
    if (salesLedgerId) {
      ledgerEntries.push({
        entry_date: bill_date,
        ledger_id: salesLedgerId,
        debit: 0,
        credit: netTotal,
        narration: `Sales - ${bill_no}`,
        reference_type: 'sales',
        reference_id: sale.id,
        created_by: $authStore.user?.id || null,
      });
    }

    // 2. Debit Customer ledger (Sundry Debtors) for full sale amount
    if (customerLedgerId) {
      ledgerEntries.push({
        entry_date: bill_date,
        ledger_id: customerLedgerId,
        debit: netTotal,
        credit: 0,
        narration: `Sales - ${bill_no}`,
        reference_type: 'sales',
        reference_id: sale.id,
        created_by: $authStore.user?.id || null,
      });
    }

    // 3. If paid amount > 0: Credit Customer (paid), Debit Cash/Bank (money in)
    if (paidAmt > 0 && customerLedgerId) {
      ledgerEntries.push({
        entry_date: bill_date,
        ledger_id: customerLedgerId,
        debit: 0,
        credit: paidAmt,
        narration: `Payment received - ${bill_no}`,
        reference_type: 'sales',
        reference_id: sale.id,
        created_by: $authStore.user?.id || null,
      });
    }
    if (paidAmt > 0 && cash_bank_ledger_id) {
      ledgerEntries.push({
        entry_date: bill_date,
        ledger_id: cash_bank_ledger_id,
        debit: paidAmt,
        credit: 0,
        narration: `Sales receipt - ${bill_no}`,
        reference_type: 'sales',
        reference_id: sale.id,
        created_by: $authStore.user?.id || null,
      });
    }

    if (ledgerEntries.length > 0) {
      await supabase.from('ledger_entries').insert(ledgerEntries);
    }

    // Mark job card as billed if imported
    if (importedJobCardId) {
      await supabase.from('job_cards').update({
        status: 'Billed',
        billed_invoice_id: sale.id,
        billed_at: new Date().toISOString(),
        updated_by: $authStore.user?.id || null,
        updated_at: new Date().toISOString(),
      }).eq('id', importedJobCardId);

      await supabase.from('job_card_logs').insert({
        job_card_id: importedJobCardId,
        action: 'Billed',
        from_status: 'Closed',
        to_status: 'Billed',
        note: `Billed via invoice ${bill_no}`,
        action_by: $authStore.user?.id || null,
        created_by: $authStore.user?.id || null,
      });
    }

    saving = false;
    saveSuccess = `Bill ${bill_no} posted successfully!`;

    // Reset
    importedJobCardId = '';
    selectedJobCard = null;
    lines = [];
    selectedCustomer = null;
    customerSearch = '';
    saleType = 'cash';
    paidAmount = '';
    payment_mode_id = '';
    cash_bank_ledger_id = '';
    await generateBillNo();

    setTimeout(() => saveSuccess = '', 4000);
  }
</script>

<div class="pos-window">
  <!-- ===== TOP HEADER BAR ===== -->
  <div class="pos-header">
    <div class="header-left">
      <h2>Sales / POS Billing</h2>
      <div class="sale-type-toggle">
        <button class="type-btn" class:active={saleType === 'cash'} on:click={() => saleType = 'cash'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
          Cash Sale
        </button>
        <button class="type-btn credit" class:active={saleType === 'credit'} on:click={() => saleType = 'credit'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          Credit Sale
        </button>
      </div>
      <div class="bill-info">
        <span class="bill-tag">Bill #</span>
        <input type="text" class="bill-no-input" bind:value={bill_no} readonly />
        <input type="date" class="date-input" bind:value={bill_date} />
      </div>
    </div>
    <div class="header-right">
      <button class="btn-import-jc" on:click={() => { showJobCardImport = true; loadClosedJobCards(); }} title="Import from Job Card">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 12 15 15"/></svg>
        Import Job Card
      </button>
      <button class="btn-quick-create" on:click={openQuickCreateCustomer} title="Quick Create Customer">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Customer
      </button>
    </div>
  </div>

  {#if selectedJobCard}
    <div class="msg msg-jc">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
      Imported from Job Card: <strong>{selectedJobCard.job_card_no}</strong>
      <button class="jc-clear" on:click={() => { importedJobCardId = ''; selectedJobCard = null; }}>&times;</button>
    </div>
  {/if}

  {#if saveError}
    <div class="msg msg-error">{saveError}</div>
  {/if}
  {#if saveSuccess}
    <div class="msg msg-success">{saveSuccess}</div>
  {/if}

  <!-- Job Card Import Modal -->
  {#if showJobCardImport}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="jc-overlay" on:click={() => showJobCardImport = false}>
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="jc-modal" on:click|stopPropagation>
        <div class="jc-modal-header">
          <h3>Import from Job Card</h3>
          <button class="jc-close" on:click={() => showJobCardImport = false}>&times;</button>
        </div>
        <div class="jc-modal-body">
          {#if jcLoading}
            <div class="jc-loading">Loading closed job cards...</div>
          {:else if closedJobCards.length === 0}
            <div class="jc-empty">No closed & unbilled job cards found.</div>
          {:else}
            {#each closedJobCards as jc}
              <button class="jc-card" on:click={() => importJobCard(jc)}>
                <div class="jc-card-top"><span class="jc-no">{jc.job_card_no}</span></div>
                <div class="jc-card-info">{jc.customer_name} — {jc.vehicle_name}</div>
                <div class="jc-card-desc">{jc.description || ''}</div>
              </button>
            {/each}
          {/if}
        </div>
      </div>
    </div>
  {/if}

  <div class="pos-body">
    <!-- ===== LEFT: Customer + Product search + Lines ===== -->
    <div class="pos-main">
      <!-- Customer + Product + Barcode search row -->
      <div class="search-row">
        <div class="search-group customer-search">
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
                    <span class="dd-price">₹{(p.sales_price || 0).toFixed(2)}</span>
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

      <!-- ===== BILL LINES TABLE ===== -->
      <div class="lines-table-wrap">
        <table class="lines-table">
          <thead>
            <tr>
              <th class="col-num">#</th>
              <th class="col-product">Product</th>
              <th class="col-barcode">Barcode</th>
              <th class="col-unit">Unit</th>
              <th class="col-qty">Qty</th>
              <th class="col-rate">Rate</th>
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

    <!-- ===== RIGHT: Totals + Payment ===== -->
    <div class="pos-sidebar">
      <div class="totals-card">
        <h3>Bill Summary</h3>
        <div class="total-row"><span>Subtotal</span><span class="num">₹{subtotal.toFixed(2)}</span></div>
        <div class="total-row"><span>Discount</span><span class="num disc">-₹{discountTotal.toFixed(2)}</span></div>
        <div class="total-row net"><span>Net Total</span><span class="num">₹{netTotal.toFixed(2)}</span></div>
        <hr />
        {#if saleType === 'cash'}
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
        {/if}
        <div class="total-row balance" class:overdue={balanceDue > 0}>
          <span>Balance Due</span><span class="num">₹{balanceDue.toFixed(2)}</span>
        </div>
      </div>

      <button class="btn-post" on:click={handlePost} disabled={saving}>
        {saving ? 'Posting...' : 'Post Bill'}
      </button>
    </div>
  </div>
</div>

<style>
  .pos-window { width:100%; height:100%; display:flex; flex-direction:column; background:#f8f9fb; font-family:inherit; box-sizing:border-box; }

  .pos-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:16px; }
  .pos-header h2 { margin:0; font-size:16px; font-weight:700; color:#111827; white-space:nowrap; }
  .bill-info { display:flex; align-items:center; gap:8px; }
  .bill-tag { font-size:12px; font-weight:600; color:#6b7280; }
  .bill-no-input { width:110px; padding:5px 8px; border:1px solid #e5e7eb; border-radius:5px; font-size:13px; background:#f9fafb; color:#374151; }
  .date-input { padding:5px 8px; border:1px solid #e5e7eb; border-radius:5px; font-size:13px; }
  .btn-quick-create { display:flex; align-items:center; gap:5px; padding:6px 12px; background:#f0fdf4; border:1px solid #86efac; border-radius:6px; font-size:12px; font-weight:600; color:#16a34a; cursor:pointer; }
  .btn-quick-create:hover { background:#dcfce7; }

  .sale-type-toggle { display:flex; gap:0; border:1px solid #e5e7eb; border-radius:6px; overflow:hidden; }
  .type-btn { display:flex; align-items:center; gap:4px; padding:5px 12px; border:none; background:#f9fafb; font-size:12px; font-weight:600; color:#6b7280; cursor:pointer; transition:all .15s; }
  .type-btn.active { background:#C41E3A; color:white; }
  .type-btn.credit.active { background:#7c3aed; color:white; }

  .msg { padding:8px 14px; font-size:12px; font-weight:500; margin:0 18px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; border-radius:6px; margin-top:8px; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; border-radius:6px; margin-top:8px; }

  .pos-body { display:flex; flex:1; overflow:hidden; }
  .pos-main { flex:1; display:flex; flex-direction:column; overflow:hidden; padding:14px 18px; gap:12px; }
  .pos-sidebar { flex:1; min-width:200px; max-width:300px; flex-shrink:0; padding:14px 18px 14px 0; display:flex; flex-direction:column; gap:12px; box-sizing:border-box; overflow-y:auto; }

  .search-row { display:flex; gap:10px; flex-shrink:0; }
  .search-group { display:flex; flex-direction:column; flex:1; position:relative; }
  .customer-search { flex:1.2; }
  .product-search { flex:1.5; }
  .barcode-search { flex:0.8; }
  .search-group label { font-size:11px; font-weight:600; color:#6b7280; margin-bottom:3px; }
  .search-input-wrap { position:relative; }
  .search-input-wrap input { width:100%; padding:7px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; box-sizing:border-box; }
  .search-input-wrap input:focus { border-color:#C41E3A; box-shadow:0 0 0 2px rgba(249,115,22,.1); }

  .selected-chip { display:flex; align-items:center; gap:6px; padding:5px 10px; background:#fff7ed; border:1px solid #fed7aa; border-radius:6px; font-size:13px; color:#C41E3A; }
  .chip-clear { background:none; border:none; font-size:16px; color:#dc2626; cursor:pointer; padding:0 2px; }

  .search-dropdown { position:absolute; top:100%; left:0; right:0; max-height:200px; overflow-y:auto; background:white; border:1px solid #e5e7eb; border-radius:0 0 6px 6px; z-index:50; box-shadow:0 4px 12px rgba(0,0,0,.1); }
  .dd-item { display:flex; align-items:center; justify-content:space-between; width:100%; padding:8px 10px; border:none; background:none; cursor:pointer; font-size:13px; text-align:left; }
  .dd-item:hover { background:#fff7ed; }
  .dd-name { color:#111827; font-weight:500; }
  .dd-sub { color:#9ca3af; font-size:11px; }
  .dd-price { color:#C41E3A; font-weight:600; font-size:12px; }

  .barcode-wrap { display:flex; gap:0; }
  .barcode-wrap input { border-radius:6px 0 0 6px; flex:1; }
  .barcode-go { display:flex; align-items:center; justify-content:center; padding:0 10px; background:#C41E3A; color:white; border:1px solid #C41E3A; border-radius:0 6px 6px 0; cursor:pointer; }
  .barcode-go:hover { background:#C41E3A; }

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
  .lines-table td input:focus { border-color:#C41E3A; }
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
  .pay-field select:focus, .pay-field input:focus { border-color:#C41E3A; }

  .btn-post { padding:10px; background:#C41E3A; border:none; border-radius:8px; font-size:14px; font-weight:700; color:white; cursor:pointer; transition:background .15s; }
  .btn-post:hover { background:#C41E3A; }
  .btn-post:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:800px) {
    .pos-body { flex-direction:column; }
    .pos-sidebar { width:100%; flex-direction:row; flex-wrap:wrap; padding:10px 18px; }
    .search-row { flex-direction:column; }
  }

  /* Job Card Import */
  .btn-import-jc { display:flex; align-items:center; gap:5px; padding:6px 12px; background:#eef2ff; border:1px solid #a5b4fc; border-radius:6px; font-size:12px; font-weight:600; color:#4338ca; cursor:pointer; }
  .btn-import-jc:hover { background:#e0e7ff; }
  .msg-jc { display:flex; align-items:center; gap:6px; background:#eef2ff; color:#4338ca; border:1px solid #a5b4fc; }
  .jc-clear { background:none; border:none; color:#dc2626; font-size:18px; cursor:pointer; margin-left:auto; font-weight:700; }
  .jc-overlay { position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.4); z-index:1000; display:flex; align-items:center; justify-content:center; }
  .jc-modal { background:white; border-radius:12px; width:480px; max-height:70vh; display:flex; flex-direction:column; box-shadow:0 8px 32px rgba(0,0,0,0.2); }
  .jc-modal-header { display:flex; justify-content:space-between; align-items:center; padding:14px 18px; border-bottom:1px solid #e5e7eb; }
  .jc-modal-header h3 { font-size:15px; font-weight:700; margin:0; }
  .jc-close { background:none; border:none; font-size:22px; cursor:pointer; color:#6b7280; }
  .jc-modal-body { flex:1; overflow-y:auto; padding:12px 18px; display:flex; flex-direction:column; gap:8px; }
  .jc-loading, .jc-empty { text-align:center; color:#9ca3af; padding:30px; font-size:14px; }
  .jc-card { background:#fafafa; border:1px solid #e5e7eb; border-radius:8px; padding:12px; cursor:pointer; text-align:left; width:100%; transition:background 0.15s; }
  .jc-card:hover { background:#eef2ff; border-color:#a5b4fc; }
  .jc-no { font-family:monospace; font-weight:700; color:#C41E3A; font-size:13px; }
  .jc-card-info { font-size:13px; color:#111827; margin:4px 0 2px; }
  .jc-card-desc { font-size:12px; color:#6b7280; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
</style>