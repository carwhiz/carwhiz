<!-- ============================================================
     FINANCE > MANAGE > CREATE ASSET WINDOW
     Purpose: Register a new fixed asset with full purchase details,
              depreciation config, bill upload, vendor, payment & ledger posting
     Works like Purchase Window but for capital expenditure.
     Ind AS 16 compliant (Property, Plant & Equipment)
     Window ID: finance-create-asset
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';

  // ---- Asset header ----
  let asset_code = '';
  let asset_name = '';
  let description = '';

  // ---- Category ----
  let categories: any[] = [];
  let selectedCategoryId = '';
  let selectedCategory: any = null;

  // ---- Purchase details ----
  let purchase_date = new Date().toISOString().split('T')[0];
  let invoice_no = '';
  let invoice_date = new Date().toISOString().split('T')[0];
  let purchase_cost: string = '';
  let installation_cost: string = '';
  let other_cost: string = '';
  $: totalCost = (parseFloat(purchase_cost) || 0) + (parseFloat(installation_cost) || 0) + (parseFloat(other_cost) || 0);

  // ---- Vendor ----
  let vendorSearch = '';
  let vendors: any[] = [];
  let filteredVendors: any[] = [];
  let selectedVendor: any = null;
  let showVendorDropdown = false;

  // ---- Depreciation ----
  let depreciation_method = 'SLM';
  let useful_life_years: string = '';
  let residual_value: string = '';
  let depreciation_rate: string = '';

  // ---- Location / Details ----
  let location = '';
  let serial_number = '';
  let warranty_expiry = '';

  // ---- Bill Upload ----
  let billFile: File | null = null;
  let billPreviewUrl = '';

  // ---- Payment ----
  let purchaseType: 'cash' | 'credit' = 'cash';
  let paymentModes: any[] = [];
  let payment_mode_id = '';
  let cashBankLedgers: any[] = [];
  let cash_bank_ledger_id = '';
  let paidAmount: string = '';
  $: balanceDue = totalCost - (parseFloat(paidAmount) || 0);

  $: if (purchaseType === 'cash') { paidAmount = String(totalCost || ''); } else { paidAmount = '0'; payment_mode_id = ''; cash_bank_ledger_id = ''; }

  // ---- Notes ----
  let notes = '';

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  onMount(async () => {
    await Promise.all([
      loadCategories(),
      loadVendors(),
      loadPaymentModes(),
      loadCashBankLedgers(),
      generateAssetCode(),
    ]);
  });

  async function generateAssetCode() {
    try {
      const { data } = await supabase.rpc('nextval', { seq_name: 'asset_code_seq' });
      if (data) { asset_code = 'FA-' + String(data).padStart(5, '0'); return; }
    } catch {}
    asset_code = 'FA-' + Date.now();
  }

  async function loadCategories() {
    const { data } = await supabase.from('asset_categories').select('*').order('sort_order');
    categories = data || [];
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

  function handleCategoryChange() {
    selectedCategory = categories.find(c => c.id === selectedCategoryId) || null;
    if (selectedCategory) {
      depreciation_method = selectedCategory.default_depreciation_method || 'SLM';
      useful_life_years = String(selectedCategory.default_useful_life_years || 5);
      depreciation_rate = String(selectedCategory.default_depreciation_rate || 10);
    }
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

  // ---- Bill upload ----
  function handleBillSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      billFile = input.files[0];
      billPreviewUrl = URL.createObjectURL(billFile);
    }
  }

  function clearBill() {
    billFile = null;
    billPreviewUrl = '';
  }

  // ---- Save / Post ----
  async function handleSave() {
    if (!asset_name.trim()) { saveError = 'Asset name is required'; return; }
    if (!selectedCategoryId) { saveError = 'Please select a category'; return; }
    if (totalCost <= 0) { saveError = 'Purchase cost must be greater than zero'; return; }
    if (purchaseType === 'cash' && !payment_mode_id) { saveError = 'Please select a payment mode for cash purchase'; return; }
    if (purchaseType === 'cash' && !cash_bank_ledger_id) { saveError = 'Please select a Cash / Bank ledger for cash purchase'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    // 1. Upload bill if provided
    let bill_file_path = '';
    if (billFile) {
      const ext = billFile.name.split('.').pop() || 'pdf';
      const fileName = `assets/${asset_code}.${ext}`;
      const { error: uploadErr } = await supabase.storage.from('documents').upload(fileName, billFile, { upsert: true });
      if (!uploadErr) bill_file_path = fileName;
    }

    // 2. Find or create appropriate asset ledger
    let assetLedgerId = '';
    const categoryName = selectedCategory?.name || 'Fixed Assets';

    // Try to find matching asset ledger
    const { data: existingLedger } = await supabase.from('ledger')
      .select('id')
      .eq('ledger_name', categoryName)
      .single();

    if (existingLedger) {
      assetLedgerId = existingLedger.id;
    } else {
      // Map common category names to existing seeded ledgers
      const mappings: Record<string, string> = {
        'Plant & Machinery': 'Workshop Equipment',
        'Vehicles': 'Vehicles (Company Owned)',
        'Computer & Electronics': 'Computer & Electronics',
        'Furniture & Fixtures': 'Furniture & Fixtures',
        'Office Equipment': 'Workshop Equipment',
        'Tools & Dies': 'Workshop Equipment',
      };
      const mappedName = mappings[categoryName];
      if (mappedName) {
        const { data: mapped } = await supabase.from('ledger').select('id').eq('ledger_name', mappedName).maybeSingle();
        if (mapped) assetLedgerId = mapped.id;
      }

      // If still not found, create one
      if (!assetLedgerId) {
        const { data: assetType } = await supabase.from('ledger_types').select('id').eq('name', 'Asset').maybeSingle();
        const { data: assetCat } = await supabase.from('ledger_categories').select('id').eq('name', 'Asset').maybeSingle();
        if (assetType) {
          const { data: created } = await supabase.from('ledger').insert({
            ledger_name: categoryName,
            ledger_type_id: assetType.id,
            ledger_category_id: assetCat?.id || null,
            opening_balance: 0,
            status: 'active',
            created_by: $authStore.user?.id || null,
          }).select('id').single();
          if (created) assetLedgerId = created.id;
        }
      }
    }

    const paidAmt = parseFloat(paidAmount) || 0;

    // 3. Insert asset record
    const { data: asset, error: assetErr } = await supabase.from('assets').insert({
      asset_code,
      asset_name: asset_name.trim(),
      asset_category_id: selectedCategoryId,
      description: description.trim() || null,
      purchase_date,
      vendor_id: selectedVendor?.id || null,
      invoice_no: invoice_no.trim() || null,
      invoice_date: invoice_date || null,
      purchase_cost: parseFloat(purchase_cost) || 0,
      installation_cost: parseFloat(installation_cost) || 0,
      other_cost: parseFloat(other_cost) || 0,
      bill_file_path: bill_file_path || null,
      depreciation_method,
      useful_life_years: parseFloat(useful_life_years) || 5,
      residual_value: parseFloat(residual_value) || 0,
      depreciation_rate: parseFloat(depreciation_rate) || 10,
      accumulated_depreciation: 0,
      written_down_value: totalCost,
      asset_ledger_id: assetLedgerId || null,
      location: location.trim() || null,
      serial_number: serial_number.trim() || null,
      warranty_expiry: warranty_expiry || null,
      payment_mode_id: payment_mode_id || null,
      cash_bank_ledger_id: cash_bank_ledger_id || null,
      paid_amount: paidAmt,
      balance_due: totalCost - paidAmt,
      status: 'active',
      notes: notes.trim() || null,
      created_by: $authStore.user?.id || null,
    }).select('id').single();

    if (assetErr || !asset) {
      saving = false;
      saveError = assetErr?.message || 'Failed to create asset';
      return;
    }

    // 4. Ledger entries (Ind AS double-entry posting)
    // Capital expenditure: Dr Asset A/c, Cr Vendor/Cash/Bank
    const ledgerEntries: any[] = [];
    const vendorLedgerId = selectedVendor?.ledger_id;

    // Dr: Asset ledger (increase in asset)
    if (assetLedgerId) {
      ledgerEntries.push({
        entry_date: purchase_date,
        ledger_id: assetLedgerId,
        debit: totalCost,
        credit: 0,
        narration: `Asset Purchase - ${asset_name.trim()} (${asset_code})`,
        reference_type: 'assets',
        reference_id: asset.id,
        created_by: $authStore.user?.id || null,
      });
    }

    if (purchaseType === 'credit' && vendorLedgerId) {
      // Credit purchase: Cr Vendor (Sundry Creditors)
      ledgerEntries.push({
        entry_date: purchase_date,
        ledger_id: vendorLedgerId,
        debit: 0,
        credit: totalCost,
        narration: `Asset Purchase (Credit) - ${asset_name.trim()} (${asset_code})`,
        reference_type: 'assets',
        reference_id: asset.id,
        created_by: $authStore.user?.id || null,
      });

      // If partial payment: Dr Vendor, Cr Cash/Bank
      if (paidAmt > 0) {
        ledgerEntries.push({
          entry_date: purchase_date,
          ledger_id: vendorLedgerId,
          debit: paidAmt,
          credit: 0,
          narration: `Asset Payment - ${asset_name.trim()} (${asset_code})`,
          reference_type: 'assets',
          reference_id: asset.id,
          created_by: $authStore.user?.id || null,
        });
        if (cash_bank_ledger_id) {
          ledgerEntries.push({
            entry_date: purchase_date,
            ledger_id: cash_bank_ledger_id,
            debit: 0,
            credit: paidAmt,
            narration: `Asset Payment - ${asset_name.trim()} (${asset_code})`,
            reference_type: 'assets',
            reference_id: asset.id,
            created_by: $authStore.user?.id || null,
          });
        }
      }
    } else if (purchaseType === 'cash') {
      // Cash purchase: Cr Cash/Bank directly
      if (cash_bank_ledger_id) {
        ledgerEntries.push({
          entry_date: purchase_date,
          ledger_id: cash_bank_ledger_id,
          debit: 0,
          credit: totalCost,
          narration: `Asset Purchase (Cash) - ${asset_name.trim()} (${asset_code})`,
          reference_type: 'assets',
          reference_id: asset.id,
          created_by: $authStore.user?.id || null,
        });
      }
    }

    if (ledgerEntries.length > 0) {
      await supabase.from('ledger_entries').insert(ledgerEntries);
    }

    saving = false;
    saveSuccess = `Asset ${asset_code} - ${asset_name.trim()} registered successfully!`;

    // Reset form
    asset_name = '';
    description = '';
    selectedCategoryId = '';
    selectedCategory = null;
    purchase_cost = '';
    installation_cost = '';
    other_cost = '';
    invoice_no = '';
    clearVendor();
    clearBill();
    depreciation_method = 'SLM';
    useful_life_years = '';
    residual_value = '';
    depreciation_rate = '';
    location = '';
    serial_number = '';
    warranty_expiry = '';
    purchaseType = 'cash';
    paidAmount = '';
    payment_mode_id = '';
    cash_bank_ledger_id = '';
    notes = '';
    await generateAssetCode();
    setTimeout(() => saveSuccess = '', 4000);
  }

  function handleBack() {
    windowStore.close('finance-create-asset');
  }
</script>

<div class="form-window">
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <div>
        <h2>Add Fixed Asset</h2>
        <span class="subtitle">Capital Expenditure (Ind AS 16)</span>
      </div>
    </div>
    <div class="header-right">
      <div class="purchase-type-toggle">
        <button class="type-btn" class:active={purchaseType === 'cash'} on:click={() => purchaseType = 'cash'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
          Cash
        </button>
        <button class="type-btn credit" class:active={purchaseType === 'credit'} on:click={() => purchaseType = 'credit'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          Credit
        </button>
      </div>
      <div class="code-tag">{asset_code}</div>
    </div>
  </div>

  {#if saveError}
    <div class="msg msg-error">{saveError}</div>
  {/if}
  {#if saveSuccess}
    <div class="msg msg-success">{saveSuccess}</div>
  {/if}

  <div class="form-body">
    <div class="form-grid">

      <!-- ---- SECTION: Asset Details ---- -->
      <div class="section-title">Asset Details</div>

      <div class="field full">
        <label for="asset-name">Asset Name *</label>
        <input id="asset-name" type="text" bind:value={asset_name} placeholder="e.g. Hydraulic Car Lift" />
      </div>

      <div class="field">
        <label for="asset-cat">Category *</label>
        <select id="asset-cat" bind:value={selectedCategoryId} on:change={handleCategoryChange}>
          <option value="">-- Select Category --</option>
          {#each categories as cat (cat.id)}
            <option value={cat.id}>{cat.name}</option>
          {/each}
        </select>
      </div>

      <div class="field">
        <label for="asset-desc">Description</label>
        <input id="asset-desc" type="text" bind:value={description} placeholder="Brief description" />
      </div>

      <!-- ---- SECTION: Purchase / Invoice ---- -->
      <div class="section-title">Purchase / Invoice Details</div>

      <div class="field">
        <!-- svelte-ignore a11y_label_has_associated_control -->
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

      <div class="field">
        <label for="inv-no">Invoice No.</label>
        <input id="inv-no" type="text" bind:value={invoice_no} placeholder="Vendor invoice number" />
      </div>

      <div class="field">
        <label for="inv-date">Invoice Date</label>
        <input id="inv-date" type="date" bind:value={invoice_date} />
      </div>

      <div class="field">
        <label for="purchase-date">Purchase / Acquisition Date *</label>
        <input id="purchase-date" type="date" bind:value={purchase_date} />
      </div>

      <!-- ---- SECTION: Cost Breakdown ---- -->
      <div class="section-title">Cost Breakdown (Ind AS 16 - Total Cost of Asset)</div>

      <div class="field">
        <label for="cost">Purchase Cost (₹) *</label>
        <input id="cost" type="number" min="0" step="0.01" bind:value={purchase_cost} placeholder="0.00" />
      </div>

      <div class="field">
        <label for="inst-cost">Installation Cost (₹)</label>
        <input id="inst-cost" type="number" min="0" step="0.01" bind:value={installation_cost} placeholder="0.00" />
      </div>

      <div class="field">
        <label for="other-cost">Other Cost (₹)</label>
        <input id="other-cost" type="number" min="0" step="0.01" bind:value={other_cost} placeholder="Transport, taxes etc." />
      </div>

      <div class="field">
        <!-- svelte-ignore a11y_label_has_associated_control -->
        <label>Total Cost</label>
        <div class="total-display">₹{totalCost.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
      </div>

      <!-- ---- SECTION: Bill Upload ---- -->
      <div class="section-title">Bill / Invoice Document</div>

      <div class="field full">
        {#if billPreviewUrl}
          <div class="bill-preview">
            {#if billFile && billFile.type.startsWith('image/')}
              <img src={billPreviewUrl} alt="Bill preview" class="bill-img" />
            {:else}
              <div class="bill-file-name">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                {billFile?.name}
              </div>
            {/if}
            <button class="clear-bill-btn" on:click={clearBill}>&times; Remove</button>
          </div>
        {:else}
          <label class="upload-area">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
            <span>Click to upload bill / invoice (PDF, Image)</span>
            <input type="file" accept=".pdf,.jpg,.jpeg,.png,.webp" on:change={handleBillSelect} class="file-input" />
          </label>
        {/if}
      </div>

      <!-- ---- SECTION: Depreciation ---- -->
      <div class="section-title">Depreciation (Companies Act 2013, Schedule II)</div>

      <div class="field">
        <label for="dep-method">Method</label>
        <select id="dep-method" bind:value={depreciation_method}>
          <option value="SLM">SLM (Straight Line Method)</option>
          <option value="WDV">WDV (Written Down Value)</option>
        </select>
      </div>

      <div class="field">
        <label for="useful-life">Useful Life (Years)</label>
        <input id="useful-life" type="number" min="0" step="0.5" bind:value={useful_life_years} placeholder="As per Schedule II" />
      </div>

      <div class="field">
        <label for="dep-rate">Depreciation Rate (%)</label>
        <input id="dep-rate" type="number" min="0" step="0.01" bind:value={depreciation_rate} placeholder="Annual rate" />
      </div>

      <div class="field">
        <label for="residual">Residual / Scrap Value (₹)</label>
        <input id="residual" type="number" min="0" step="0.01" bind:value={residual_value} placeholder="Default: 0" />
      </div>

      <!-- ---- SECTION: Location & Details ---- -->
      <div class="section-title">Location & Additional Details</div>

      <div class="field">
        <label for="location">Location</label>
        <input id="location" type="text" bind:value={location} placeholder="e.g. Workshop Bay 2" />
      </div>

      <div class="field">
        <label for="serial">Serial Number</label>
        <input id="serial" type="text" bind:value={serial_number} placeholder="Manufacturer serial" />
      </div>

      <div class="field">
        <label for="warranty">Warranty Expiry</label>
        <input id="warranty" type="date" bind:value={warranty_expiry} />
      </div>

      <div class="field full">
        <label for="notes">Notes</label>
        <textarea id="notes" bind:value={notes} rows="2" placeholder="Additional notes..."></textarea>
      </div>

      <!-- ---- SECTION: Payment ---- -->
      {#if purchaseType === 'cash' || (purchaseType === 'credit' && totalCost > 0)}
        <div class="section-title">Payment Details</div>

        {#if purchaseType === 'cash'}
          <div class="field">
            <label for="pay-mode">Payment Mode *</label>
            <select id="pay-mode" bind:value={payment_mode_id}>
              <option value="">-- Select --</option>
              {#each paymentModes as pm (pm.id)}
                <option value={pm.id}>{pm.name}</option>
              {/each}
            </select>
          </div>

          <div class="field">
            <label for="cash-bank">Cash / Bank Ledger *</label>
            <select id="cash-bank" bind:value={cash_bank_ledger_id}>
              <option value="">-- Select --</option>
              {#each cashBankLedgers as cb (cb.id)}
                <option value={cb.id}>{cb.ledger_name}</option>
              {/each}
            </select>
          </div>
        {/if}

        <div class="field">
          <label for="paid-amt">Paid Amount (₹)</label>
          <input id="paid-amt" type="number" min="0" step="0.01" bind:value={paidAmount} />
        </div>

        <div class="field">
          <!-- svelte-ignore a11y_label_has_associated_control -->
          <label>Balance Due</label>
          <div class="total-display" class:balance-warning={balanceDue > 0}>
            ₹{balanceDue.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
          </div>
        </div>

        {#if purchaseType === 'credit' && (parseFloat(paidAmount) || 0) > 0}
          <div class="field">
            <label for="credit-pay-mode">Payment Mode</label>
            <select id="credit-pay-mode" bind:value={payment_mode_id}>
              <option value="">-- Select --</option>
              {#each paymentModes as pm (pm.id)}
                <option value={pm.id}>{pm.name}</option>
              {/each}
            </select>
          </div>
          <div class="field">
            <label for="credit-cash-bank">Cash / Bank Ledger</label>
            <select id="credit-cash-bank" bind:value={cash_bank_ledger_id}>
              <option value="">-- Select --</option>
              {#each cashBankLedgers as cb (cb.id)}
                <option value={cb.id}>{cb.ledger_name}</option>
              {/each}
            </select>
          </div>
        {/if}
      {/if}
    </div>

    <!-- Save Button -->
    <div class="form-actions">
      <button class="save-btn" on:click={handleSave} disabled={saving}>
        {#if saving}
          <span class="spinner"></span> Saving...
        {:else}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="20 6 9 17 4 12"/></svg>
          Register Asset & Post Entry
        {/if}
      </button>
    </div>
  </div>
</div>

<style>
  .form-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }
  .form-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .header-right { display:flex; align-items:center; gap:12px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }
  h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .subtitle { font-size:11px; color:#9ca3af; }
  .code-tag { background:#dbeafe; color:#1d4ed8; padding:4px 12px; border-radius:6px; font-size:13px; font-weight:700; font-family:'Courier New',monospace; }

  .purchase-type-toggle { display:flex; gap:0; border:1px solid #e5e7eb; border-radius:6px; overflow:hidden; }
  .type-btn { display:flex; align-items:center; gap:4px; padding:6px 12px; background:white; border:none; cursor:pointer; font-size:12px; font-weight:600; color:#6b7280; transition:all .15s; }
  .type-btn.active { background:#2563eb; color:white; }
  .type-btn.credit.active { background:#f59e0b; color:white; }

  .msg { padding:8px 18px; font-size:13px; font-weight:500; }
  .msg-error { background:#fee2e2; color:#dc2626; }
  .msg-success { background:#dcfce7; color:#16a34a; }

  .form-body { flex:1; overflow:auto; padding:16px 18px; }
  .form-grid { display:grid; grid-template-columns:1fr 1fr; gap:12px 16px; }
  .section-title { grid-column:1/-1; font-size:13px; font-weight:700; color:#374151; padding:10px 0 2px; border-bottom:2px solid #e5e7eb; margin-top:6px; text-transform:uppercase; letter-spacing:0.5px; }
  .field { display:flex; flex-direction:column; gap:4px; }
  .field.full { grid-column:1/-1; }
  .field label { font-size:12px; font-weight:600; color:#374151; }
  .field input, .field select, .field textarea { padding:8px 12px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; background:white; box-sizing:border-box; }
  .field input:focus, .field select:focus, .field textarea:focus { border-color:#2563eb; outline:none; box-shadow:0 0 0 2px rgba(37,99,235,.15); }

  .total-display { padding:8px 12px; background:#f0f9ff; border:1px solid #93c5fd; border-radius:6px; font-family:'Courier New',monospace; font-size:16px; font-weight:700; color:#1d4ed8; }
  .balance-warning { background:#fef3c7; border-color:#f59e0b; color:#d97706; }

  /* Vendor search */
  .search-input-wrap { position:relative; }
  .search-input-wrap input { width:100%; padding:8px 12px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; box-sizing:border-box; }
  .search-dropdown { position:absolute; top:100%; left:0; right:0; background:white; border:1px solid #d1d5db; border-radius:0 0 6px 6px; max-height:160px; overflow-y:auto; z-index:20; box-shadow:0 4px 12px rgba(0,0,0,.1); }
  .dd-item { display:flex; justify-content:space-between; align-items:center; width:100%; padding:8px 12px; border:none; background:white; cursor:pointer; font-size:13px; text-align:left; border-bottom:1px solid #f3f4f6; }
  .dd-item:hover { background:#f0f9ff; }
  .dd-name { font-weight:600; color:#111827; }
  .dd-sub { font-size:11px; color:#9ca3af; }
  .selected-chip { display:flex; align-items:center; gap:8px; padding:6px 12px; background:#dbeafe; border:1px solid #93c5fd; border-radius:6px; }
  .selected-chip span { font-size:13px; font-weight:600; color:#1d4ed8; }
  .chip-clear { display:flex; align-items:center; justify-content:center; width:18px; height:18px; background:#93c5fd; border:none; border-radius:50%; cursor:pointer; font-size:14px; color:white; line-height:1; }

  /* Bill upload */
  .upload-area { display:flex; flex-direction:column; align-items:center; gap:8px; padding:20px; border:2px dashed #d1d5db; border-radius:8px; cursor:pointer; color:#9ca3af; transition:all .15s; }
  .upload-area:hover { border-color:#2563eb; color:#2563eb; }
  .upload-area span { font-size:13px; }
  .file-input { display:none; }
  .bill-preview { display:flex; align-items:center; gap:12px; padding:12px; background:#f9fafb; border:1px solid #e5e7eb; border-radius:8px; }
  .bill-img { max-height:80px; max-width:120px; border-radius:4px; object-fit:cover; }
  .bill-file-name { display:flex; align-items:center; gap:6px; font-size:13px; color:#374151; }
  .clear-bill-btn { padding:4px 10px; background:#fee2e2; color:#dc2626; border:none; border-radius:4px; cursor:pointer; font-size:12px; }

  /* Actions */
  .form-actions { margin-top:20px; display:flex; justify-content:flex-end; }
  .save-btn { display:flex; align-items:center; gap:8px; padding:10px 24px; background:#2563eb; color:white; border:none; border-radius:8px; font-size:14px; font-weight:600; cursor:pointer; transition:all .15s; }
  .save-btn:hover { background:#1d4ed8; }
  .save-btn:disabled { opacity:.5; cursor:not-allowed; }
  .spinner { width:16px; height:16px; border:2px solid rgba(255,255,255,.3); border-top-color:white; border-radius:50%; animation:spin .6s linear infinite; }
  @keyframes spin { to { transform:rotate(360deg); } }
</style>
