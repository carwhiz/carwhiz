<!-- ============================================================
     PRODUCTS > MANAGE > EDIT PRODUCT WINDOW
     Purpose: Edit an existing product's details
     Window ID: products-edit-product-{productId}
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import SearchableDropdown from '../../../shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../../shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../../shared/EditMasterDataPopup.svelte';

  export let productId = '';

  // ---- Form state ----
  let product_name = '';
  let product_type = '';
  let applicability = '';
  let vehicle_id = '';
  let unit_id = '';
  let unit_qty = '';
  let current_cost = '';
  let sales_price = '';
  let first_level_discount = '';
  let second_level_discount = '';
  let third_level_discount = '';
  let barcode = '';
  let part_number = '';
  let brand_id = '';
  let expiry_date = '';
  let minimum_stock = '';
  let maximum_stock = '';
  let reorder_level = '';
  let existing_file_path = '';

  // ---- Master data ----
  let units: { id: string; name: string }[] = [];
  let vehicles: { id: string; name: string }[] = [];
  let brands: { id: string; name: string }[] = [];

  // ---- Popup state ----
  let addPopupOpen = false;
  let addPopupTable = 'units';
  let addPopupTitle = 'Add Unit';
  let editPopupOpen = false;
  let editPopupTable = 'units';
  let editPopupTitle = 'Edit Unit';
  let editPopupItemId = '';
  let editPopupItemName = '';

  // ---- State ----
  let loading = true;
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  $: showApplicability = product_type === 'product';
  $: showVehicle = product_type === 'product' && applicability === 'specific';
  $: showPricingFields = product_type === 'product' || product_type === 'consumable';

  onMount(() => {
    loadProduct();
    loadUnits();
    loadVehicles();
    loadBrands();
  });

  async function loadProduct() {
    loading = true;
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .eq('id', productId)
      .maybeSingle();

    if (error || !data) {
      saveError = error?.message || 'Product not found';
      loading = false;
      return;
    }

    product_name = data.product_name || '';
    product_type = data.product_type || '';
    applicability = data.applicability || '';
    vehicle_id = data.vehicle_id || '';
    unit_id = data.unit_id || '';
    unit_qty = data.unit_qty?.toString() || '';
    current_cost = data.current_cost?.toString() || '';
    sales_price = data.sales_price?.toString() || '';
    first_level_discount = data.first_level_discount?.toString() || '';
    second_level_discount = data.second_level_discount?.toString() || '';
    third_level_discount = data.third_level_discount?.toString() || '';
    barcode = data.barcode || '';
    part_number = data.part_number || '';
    brand_id = data.brand_id || '';
    expiry_date = data.expiry_date || '';
    minimum_stock = data.minimum_stock?.toString() || '';
    maximum_stock = data.maximum_stock?.toString() || '';
    reorder_level = data.reorder_level?.toString() || '';
    existing_file_path = data.file_path || '';
    loading = false;
  }

  async function loadUnits() {
    const { data } = await supabase.from('units').select('id, name').order('name');
    units = (data as { id: string; name: string }[]) || [];
  }

  async function loadVehicles() {
    const { data } = await supabase.from('vehicles').select('id, model_name').order('model_name');
    vehicles = (data || []).map((v: any) => ({ id: v.id, name: v.model_name }));
  }

  async function loadBrands() {
    const { data } = await supabase.from('brands').select('id, name').order('name');
    brands = (data as { id: string; name: string }[]) || [];
  }

  function handleAddUnit() { addPopupTable = 'units'; addPopupTitle = 'Add Unit'; addPopupOpen = true; }
  function handleAddBrand() { addPopupTable = 'brands'; addPopupTitle = 'Add Brand'; addPopupOpen = true; }
  function handleMasterCreated() { addPopupOpen = false; if (addPopupTable === 'units') loadUnits(); else loadBrands(); }

  function handleEditUnit(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'units'; editPopupTitle = 'Edit Unit'; editPopupItemId = e.detail.id; editPopupItemName = e.detail.name; editPopupOpen = true;
  }
  function handleEditBrand(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'brands'; editPopupTitle = 'Edit Brand'; editPopupItemId = e.detail.id; editPopupItemName = e.detail.name; editPopupOpen = true;
  }
  function handleMasterUpdated() { editPopupOpen = false; if (editPopupTable === 'units') loadUnits(); else loadBrands(); }

  async function handleSave() {
    if (!product_name.trim()) { saveError = 'Product Name is required'; return; }
    if (!product_type) { saveError = 'Product Type is required'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const updateData: Record<string, any> = {
      product_name: product_name.trim(),
      product_type,
      applicability: product_type === 'product' ? applicability || null : null,
      vehicle_id: showVehicle && vehicle_id ? vehicle_id : null,
      unit_id: unit_id || null,
      unit_qty: unit_qty ? parseFloat(unit_qty) : null,
      current_cost: current_cost ? parseFloat(current_cost) : null,
      sales_price: sales_price ? parseFloat(sales_price) : null,
      first_level_discount: first_level_discount ? parseFloat(first_level_discount) : null,
      second_level_discount: second_level_discount ? parseFloat(second_level_discount) : null,
      third_level_discount: third_level_discount ? parseFloat(third_level_discount) : null,
      barcode: barcode.trim() || null,
      part_number: part_number.trim() || null,
      brand_id: brand_id || null,
      expiry_date: expiry_date || null,
      minimum_stock: minimum_stock ? parseFloat(minimum_stock) : 0,
      maximum_stock: maximum_stock ? parseFloat(maximum_stock) : 0,
      reorder_level: reorder_level ? parseFloat(reorder_level) : 0,
      updated_at: new Date().toISOString(),
      updated_by: $authStore.user?.id || null,
    };

    const { error } = await supabase.from('products').update(updateData).eq('id', productId);
    saving = false;

    if (error) { saveError = error.message; return; }

    saveSuccess = 'Product updated successfully!';
    setTimeout(() => (saveSuccess = ''), 3000);
  }

  function handleCancel() {
    windowStore.close('products-edit-product-' + productId);
  }
</script>

<div class="edit-product-window">
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Edit Product</h2>
    </div>
  </div>

  <div class="form-body">
    {#if loading}
      <div class="status-msg">Loading product...</div>
    {:else}
      {#if saveError}
        <div class="msg msg-error">{saveError}</div>
      {/if}
      {#if saveSuccess}
        <div class="msg msg-success">{saveSuccess}</div>
      {/if}

      <div class="form-card">
        <!-- Product Name + Type -->
        <div class="form-row two-col">
          <div class="field">
            <label for="ep-name">Product Name</label>
            <input id="ep-name" type="text" bind:value={product_name} placeholder="Enter product name" />
          </div>
          <div class="field">
            <label for="ep-type">Product Type</label>
            <select id="ep-type" bind:value={product_type}>
              <option value="">Select type...</option>
              <option value="product">Product</option>
              <option value="service">Service</option>
              <option value="consumable">Consumable</option>
            </select>
          </div>
        </div>

        <!-- Applicability -->
        {#if showApplicability}
          <div class="form-row two-col">
            <div class="field">
              <label for="ep-app">Applicability</label>
              <select id="ep-app" bind:value={applicability}>
                <option value="">Select...</option>
                <option value="universal">Universal</option>
                <option value="specific">Specific</option>
              </select>
            </div>
            {#if showVehicle}
              <div class="field">
                <SearchableDropdown items={vehicles} bind:value={vehicle_id} placeholder="Select Vehicle" label="Vehicle" on:add={() => {}} />
              </div>
            {:else}
              <div class="field"></div>
            {/if}
          </div>
        {/if}

        {#if showPricingFields}
          <!-- Part Number + Barcode -->
          <div class="form-row two-col">
            <div class="field">
              <label for="ep-pn">Part Number</label>
              <input id="ep-pn" type="text" bind:value={part_number} placeholder="Enter part number" />
            </div>
            <div class="field">
              <label for="ep-bc">Barcode</label>
              <input id="ep-bc" type="text" bind:value={barcode} placeholder="Enter barcode" />
            </div>
          </div>

          <!-- Expiry + Brand -->
          <div class="form-row two-col">
            <div class="field">
              <label for="ep-exp">Expiry Date</label>
              <input id="ep-exp" type="date" bind:value={expiry_date} />
            </div>
            <div class="field">
              <SearchableDropdown items={brands} bind:value={brand_id} placeholder="Select Brand" label="Brand" on:add={handleAddBrand} on:edit={handleEditBrand} />
            </div>
          </div>

          <!-- Unit + Unit Qty -->
          <div class="form-row two-col">
            <div class="field">
              <SearchableDropdown items={units} bind:value={unit_id} placeholder="Select Unit" label="Unit" on:add={handleAddUnit} on:edit={handleEditUnit} />
            </div>
            <div class="field">
              <label for="ep-uq">Unit Quantity</label>
              <input id="ep-uq" type="number" step="0.01" bind:value={unit_qty} placeholder="0" />
            </div>
          </div>

          <!-- Cost + Sales Price -->
          <div class="form-row two-col">
            <div class="field">
              <label for="ep-cost">Current Cost</label>
              <input id="ep-cost" type="number" step="0.01" bind:value={current_cost} placeholder="0.00" />
            </div>
            <div class="field">
              <label for="ep-sp">Sales Price</label>
              <input id="ep-sp" type="number" step="0.01" bind:value={sales_price} placeholder="0.00" />
            </div>
          </div>

          <!-- Discounts -->
          <div class="form-row three-col">
            <div class="field">
              <label for="ep-d1">First Level Discount %</label>
              <input id="ep-d1" type="number" step="0.01" bind:value={first_level_discount} placeholder="0" />
            </div>
            <div class="field">
              <label for="ep-d2">Second Level Discount %</label>
              <input id="ep-d2" type="number" step="0.01" bind:value={second_level_discount} placeholder="0" />
            </div>
            <div class="field">
              <label for="ep-d3">Third Level Discount %</label>
              <input id="ep-d3" type="number" step="0.01" bind:value={third_level_discount} placeholder="0" />
            </div>
          </div>

          <!-- Stock Levels -->
          <div class="form-row two-col">
            <div class="field">
              <label for="ep-reorder">Reorder Level</label>
              <input id="ep-reorder" type="number" step="0.01" bind:value={reorder_level} placeholder="0" />
            </div>
            <div class="field">
              <label for="ep-min">Minimum Stock</label>
              <input id="ep-min" type="number" step="0.01" bind:value={minimum_stock} placeholder="0" />
            </div>
          </div>
          <div class="form-row two-col">
            <div class="field">
              <label for="ep-max">Maximum Stock</label>
              <input id="ep-max" type="number" step="0.01" bind:value={maximum_stock} placeholder="0" />
            </div>
            <div class="field"></div>
          </div>

          <!-- Existing file -->
          {#if existing_file_path}
            <div class="form-row">
              <div class="field">
                <label>Attached File</label>
                <span class="existing-file">📎 {existing_file_path}</span>
              </div>
            </div>
          {/if}
        {/if}
      </div>
    {/if}
  </div>

  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    {#if showPricingFields && !loading}
      <button class="btn-save" on:click={handleSave} disabled={saving}>
        {saving ? 'Saving...' : 'Update'}
      </button>
    {/if}
  </div>
</div>

{#if addPopupOpen}
  <AddMasterDataPopup title={addPopupTitle} tableName={addPopupTable} on:close={() => (addPopupOpen = false)} on:created={handleMasterCreated} />
{/if}
{#if editPopupOpen}
  <EditMasterDataPopup title={editPopupTitle} tableName={editPopupTable} itemId={editPopupItemId} itemName={editPopupItemName} on:close={() => (editPopupOpen = false)} on:updated={handleMasterUpdated} />
{/if}

<style>
  .edit-product-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .form-header { display:flex; align-items:center; justify-content:space-between; padding:14px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#C41E3A; color:#C41E3A; }
  .form-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .form-body { flex:1; overflow-y:auto; padding:24px; width:100%; box-sizing:border-box; }
  .status-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }
  .msg { padding:10px 14px; border-radius:6px; font-size:13px; font-weight:500; margin-bottom:16px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; }
  .form-card { background:white; border:1px solid #e5e7eb; border-radius:12px; padding:24px; display:flex; flex-direction:column; gap:18px; max-width:800px; }
  .form-row { display:flex; gap:16px; }
  .two-col > .field { flex:1; }
  .three-col > .field { flex:1; }
  .field { display:flex; flex-direction:column; }
  .field label { font-size:12px; font-weight:600; color:#374151; margin-bottom:4px; }
  .field input[type="text"], .field input[type="number"], .field input[type="date"], .field select { padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; background:white; }
  .field input:focus, .field select:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,0.1); }
  .existing-file { font-size:13px; color:#374151; padding:6px 0; }
  .form-footer { display:flex; justify-content:flex-end; gap:10px; padding:14px 20px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-cancel { padding:9px 20px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:8px; font-size:14px; font-weight:500; color:#6b7280; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .btn-save { padding:9px 28px; background:#C41E3A; border:none; border-radius:8px; font-size:14px; font-weight:600; color:white; cursor:pointer; transition:background .15s; }
  .btn-save:hover { background:#C41E3A; }
  .btn-save:disabled { opacity:0.6; cursor:not-allowed; }
  @media (max-width:700px) { .two-col, .three-col { flex-direction:column; } }
</style>
