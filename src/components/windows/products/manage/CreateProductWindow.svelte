<!-- ============================================================
     PRODUCTS > MANAGE > CREATE PRODUCT WINDOW
     Purpose: Full-page form to create a new product
     Section: Products > Manage > Create Product
     Window ID: products-create-product
     Logic:
       - Product Type = product → show applicability
         - Specific → show vehicle dropdown
         - Universal → no vehicle
       - Product Type = consumable → show unit/pricing directly
       - Product Type = service → add consumable components + labor/additional charges
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import SearchableDropdown from '../../../shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../../shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../../shared/EditMasterDataPopup.svelte';

  // ---- Form state ----
  let product_name = '';
  let product_type = '';
  let applicability = '';
  let vehicle_id = '';
  let unit_id = '';
  let unit_qty: string = '';
  let current_cost: string = '';
  let sales_price: string = '';
  let first_level_discount: string = '';
  let second_level_discount: string = '';
  let third_level_discount: string = '';
  let barcode: string = '';
  let part_number: string = '';
  let brand_id = '';
  let expiry_date: string = '';
  let opening_stock: string = '';
  let minimum_stock: string = '';
  let maximum_stock: string = '';
  let reorder_level: string = '';
  let selectedFile: File | null = null;
  let fileInputEl: HTMLInputElement;

  // ---- Service-specific state ----
  let labor_charge: string = '';
  let additional_charges: string = '';
  interface ServiceComponent {
    component_product_id: string;
    product_name: string;
    qty: number;
    cost: number; // per-piece cost of the component
  }
  let serviceComponents: ServiceComponent[] = [];
  let consumableProducts: any[] = [];
  let componentSearch = '';
  let filteredComponents: any[] = [];
  let showComponentDropdown = false;

  // ---- Master data ----
  let units: { id: string; name: string }[] = [];
  let vehicles: { id: string; name: string }[] = [];
  let brands: { id: string; name: string }[] = [];

  // ---- Popup state (add unit / brand) ----
  let addPopupOpen = false;
  let addPopupTable = 'units';
  let addPopupTitle = 'Add Unit';

  // ---- Edit popup state ----
  let editPopupOpen = false;
  let editPopupTable = 'units';
  let editPopupTitle = 'Edit Unit';
  let editPopupItemId = '';
  let editPopupItemName = '';

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  // ---- Computed: what to show ----
  $: showApplicability = product_type === 'product';
  $: showVehicle = product_type === 'product' && applicability === 'specific';
  $: showPricingFields = product_type === 'product' || product_type === 'consumable';
  $: showServiceFields = product_type === 'service';

  // Service auto-calculated total cost
  $: componentsCost = serviceComponents.reduce((sum, c) => sum + (c.qty * c.cost), 0);
  $: serviceTotalCost = componentsCost + (parseFloat(labor_charge) || 0) + (parseFloat(additional_charges) || 0);

  // Discount & profit calculations
  $: baseSalesPrice = parseFloat(sales_price) || 0;
  $: baseCost = showServiceFields ? serviceTotalCost : (parseFloat(current_cost) || 0);
  $: afterD1 = baseSalesPrice * (1 - (parseFloat(first_level_discount) || 0) / 100);
  $: afterD2 = afterD1 * (1 - (parseFloat(second_level_discount) || 0) / 100);
  $: afterD3 = afterD2 * (1 - (parseFloat(third_level_discount) || 0) / 100);
  $: profitD1 = afterD1 - baseCost;
  $: profitD2 = afterD2 - baseCost;
  $: profitD3 = afterD3 - baseCost;

  // Reset dependent fields when product_type changes
  $: if (product_type !== 'product') {
    applicability = '';
    vehicle_id = '';
  }
  $: if (applicability !== 'specific') {
    vehicle_id = '';
  }

  onMount(() => {
    loadUnits();
    loadVehicles();
    loadBrands();
    loadConsumableProducts();
  });

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

  async function loadConsumableProducts() {
    const { data } = await supabase
      .from('products')
      .select('id, product_name, current_cost, unit_qty')
      .in('product_type', ['consumable', 'product'])
      .order('product_name');
    consumableProducts = (data || []).map((p: any) => ({
      ...p,
      unit_qty: p.unit_qty || 1,
    }));
  }

  function searchComponents() {
    const q = componentSearch.toLowerCase().trim();
    if (!q) { filteredComponents = []; showComponentDropdown = false; return; }
    filteredComponents = consumableProducts.filter(p =>
      p.product_name.toLowerCase().includes(q) &&
      !serviceComponents.some(c => c.component_product_id === p.id)
    ).slice(0, 10);
    showComponentDropdown = filteredComponents.length > 0;
  }

  function addComponent(p: any) {
    const perPieceCost = (p.current_cost || 0) / (p.unit_qty || 1);
    serviceComponents = [...serviceComponents, {
      component_product_id: p.id,
      product_name: p.product_name,
      qty: 1,
      cost: perPieceCost,
    }];
    componentSearch = '';
    showComponentDropdown = false;
  }

  function removeComponent(idx: number) {
    serviceComponents = serviceComponents.filter((_, i) => i !== idx);
  }

  function recalcComponentLine(idx: number) {
    serviceComponents = serviceComponents;
  }

  function handleAddUnit() {
    addPopupTable = 'units';
    addPopupTitle = 'Add Unit';
    addPopupOpen = true;
  }

  function handleAddBrand() {
    addPopupTable = 'brands';
    addPopupTitle = 'Add Brand';
    addPopupOpen = true;
  }

  function handleMasterCreated() {
    addPopupOpen = false;
    if (addPopupTable === 'units') loadUnits();
    else loadBrands();
  }

  function handleEditUnit(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'units';
    editPopupTitle = 'Edit Unit';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleEditBrand(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'brands';
    editPopupTitle = 'Edit Brand';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleMasterUpdated() {
    editPopupOpen = false;
    if (editPopupTable === 'units') loadUnits();
    else loadBrands();
  }

  function handleFileSelect() {
    const files = fileInputEl?.files;
    if (files && files.length > 0) {
      selectedFile = files[0];
    }
  }

  function removeFile() {
    selectedFile = null;
    if (fileInputEl) fileInputEl.value = '';
  }

  async function handleSave() {
    // Validate
    if (!product_name.trim()) {
      saveError = 'Product Name is required';
      return;
    }
    if (!product_type) {
      saveError = 'Product Type is required';
      return;
    }
    if (product_type === 'service' && serviceComponents.length === 0) {
      saveError = 'Add at least one consumable product for the service';
      return;
    }

    saving = true;
    saveError = '';
    saveSuccess = '';

    // Upload file if selected
    let file_path: string | null = null;
    if (selectedFile) {
      const fileExt = selectedFile.name.split('.').pop();
      const fileName = `${crypto.randomUUID()}.${fileExt}`;
      const { error: uploadError } = await supabase.storage
        .from('product-files')
        .upload(fileName, selectedFile);

      if (uploadError) {
        saving = false;
        saveError = 'File upload failed: ' + uploadError.message;
        return;
      }
      file_path = fileName;
    }

    const isService = product_type === 'service';

    // Insert product via RPC
    const { data: rpcResult, error } = await supabase.rpc('create_product', {
      p_product_name: product_name.trim(),
      p_product_type: product_type,
      p_applicability: product_type === 'product' ? applicability || null : null,
      p_vehicle_id: showVehicle && vehicle_id ? vehicle_id : null,
      p_unit_id: isService ? null : (unit_id || null),
      p_unit_qty: isService ? null : (unit_qty ? parseFloat(unit_qty) : null),
      p_current_cost: isService ? serviceTotalCost : (current_cost ? parseFloat(current_cost) : null),
      p_sales_price: sales_price ? parseFloat(sales_price) : null,
      p_first_level_discount: first_level_discount ? parseFloat(first_level_discount) : null,
      p_second_level_discount: second_level_discount ? parseFloat(second_level_discount) : null,
      p_third_level_discount: third_level_discount ? parseFloat(third_level_discount) : null,
      p_barcode: isService ? null : (barcode.trim() || null),
      p_part_number: isService ? null : (part_number.trim() || null),
      p_brand_id: isService ? null : (brand_id || null),
      p_expiry_date: isService ? null : (expiry_date || null),
      p_file_path: file_path,
      p_created_by: $authStore.user?.id || null,
      p_current_stock: isService ? 0 : (opening_stock ? parseFloat(opening_stock) : 0),
      p_minimum_stock: isService ? 0 : (minimum_stock ? parseFloat(minimum_stock) : 0),
      p_maximum_stock: isService ? 0 : (maximum_stock ? parseFloat(maximum_stock) : 0),
      p_reorder_level: isService ? 0 : (reorder_level ? parseFloat(reorder_level) : 0),
      p_labor_charge: isService ? (parseFloat(labor_charge) || 0) : 0,
      p_additional_charges: isService ? (parseFloat(additional_charges) || 0) : 0,
    });

    if (error) {
      saving = false;
      saveError = error.message;
      return;
    }

    // Insert service components if service type
    if (isService && rpcResult?.id) {
      const comps = serviceComponents.map(c => ({
        product_id: rpcResult.id,
        component_product_id: c.component_product_id,
        qty: c.qty,
        created_by: $authStore.user?.id || null,
      }));
      const { error: compErr } = await supabase.from('product_components').insert(comps);
      if (compErr) {
        saving = false;
        saveError = 'Product saved but failed to save components: ' + compErr.message;
        return;
      }
    }

    saving = false;
    saveSuccess = 'Product saved successfully!';
    // Reset form
    product_name = '';
    product_type = '';
    applicability = '';
    vehicle_id = '';
    unit_id = '';
    unit_qty = '';
    current_cost = '';
    sales_price = '';
    first_level_discount = '';
    second_level_discount = '';
    third_level_discount = '';
    barcode = '';
    part_number = '';
    brand_id = '';
    expiry_date = '';
    opening_stock = '';
    minimum_stock = '';
    maximum_stock = '';
    reorder_level = '';
    selectedFile = null;
    if (fileInputEl) fileInputEl.value = '';
    labor_charge = '';
    additional_charges = '';
    serviceComponents = [];

    setTimeout(() => (saveSuccess = ''), 3000);
  }

  function handleCancel() {
    windowStore.close('products-create-product');
  }
</script>

<div class="create-product-window">
  <!-- ---- Header ---- -->
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <h2>Create Product</h2>
    </div>
  </div>

  <!-- ---- Form Body ---- -->
  <div class="form-body">
    {#if saveError}
      <div class="msg msg-error">{saveError}</div>
    {/if}
    {#if saveSuccess}
      <div class="msg msg-success">{saveSuccess}</div>
    {/if}

    <div class="form-card">
      <!-- Row 1: Product Name + Product Type -->
      <div class="form-row two-col">
        <div class="field">
          <label for="product-name">Product Name</label>
          <input id="product-name" type="text" bind:value={product_name} placeholder="Enter product name" />
        </div>
        <div class="field">
          <label for="product-type">Product Type</label>
          <select id="product-type" bind:value={product_type}>
            <option value="">Select type...</option>
            <option value="product">Product</option>
            <option value="service">Service</option>
            <option value="consumable">Consumable</option>
          </select>
        </div>
      </div>

      <!-- ======== SERVICE FIELDS ======== -->
      {#if showServiceFields}
        <!-- Service Name already captured in product_name -->

        <!-- Components section: Add consumable products -->
        <div class="service-section">
          <div class="section-label">Consumable Products</div>

          <div class="component-search-wrap">
            <input
              type="text"
              bind:value={componentSearch}
              on:input={searchComponents}
              on:focus={searchComponents}
              placeholder="Search consumable products..."
              class="component-search"
            />
            {#if showComponentDropdown}
              <div class="component-dropdown">
                {#each filteredComponents as p (p.id)}
                  <button class="dd-item" on:click={() => addComponent(p)}>
                    <span>{p.product_name}</span>
                    <span class="dd-cost">₹{((p.current_cost || 0) / (p.unit_qty || 1)).toFixed(2)}/pc</span>
                  </button>
                {/each}
              </div>
            {/if}
          </div>

          {#if serviceComponents.length > 0}
            <table class="comp-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Product</th>
                  <th>Qty</th>
                  <th>Cost/pc</th>
                  <th>Total</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {#each serviceComponents as comp, idx (comp.component_product_id)}
                  <tr>
                    <td>{idx + 1}</td>
                    <td>{comp.product_name}</td>
                    <td>
                      <input
                        type="number"
                        min="1"
                        step="1"
                        bind:value={comp.qty}
                        on:input={() => recalcComponentLine(idx)}
                        class="comp-qty-input"
                      />
                    </td>
                    <td>₹{comp.cost.toFixed(2)}</td>
                    <td>₹{(comp.qty * comp.cost).toFixed(2)}</td>
                    <td>
                      <button class="comp-remove" on:click={() => removeComponent(idx)} title="Remove">&times;</button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {:else}
            <div class="comp-empty">No consumable products added yet</div>
          {/if}

          <div class="comp-subtotal">
            <span>Components Cost:</span>
            <span>₹{componentsCost.toFixed(2)}</span>
          </div>
        </div>

        <!-- Labor + Additional Charges -->
        <div class="form-row two-col">
          <div class="field">
            <label for="labor-charge">Labor Charge</label>
            <input id="labor-charge" type="number" step="0.01" bind:value={labor_charge} placeholder="0.00" />
          </div>
          <div class="field">
            <label for="additional-charges">Additional Charges</label>
            <input id="additional-charges" type="number" step="0.01" bind:value={additional_charges} placeholder="0.00" />
          </div>
        </div>

        <!-- Total Cost (auto-calculated) + Sales Price -->
        <div class="form-row two-col">
          <div class="field">
            <label>Total Cost (Auto)</label>
            <div class="auto-cost">₹{serviceTotalCost.toFixed(2)}</div>
          </div>
          <div class="field">
            <label for="svc-sales-price">Sales Price</label>
            <input id="svc-sales-price" type="number" step="0.01" bind:value={sales_price} placeholder="0.00" />
          </div>
        </div>

        <!-- Discount fields -->
        <div class="form-row three-col">
          <div class="field">
            <label for="svc-d1">First Level Discount %</label>
            <input id="svc-d1" type="number" step="0.01" bind:value={first_level_discount} placeholder="0" />
            {#if baseSalesPrice > 0}
              <div class="discount-info">
                <span>Price: ₹{afterD1.toFixed(2)}</span>
                <span class="profit-tag" class:loss={profitD1 < 0}>Profit: ₹{profitD1.toFixed(2)}</span>
              </div>
            {/if}
          </div>
          <div class="field">
            <label for="svc-d2">Second Level Discount %</label>
            <input id="svc-d2" type="number" step="0.01" bind:value={second_level_discount} placeholder="0" />
            {#if baseSalesPrice > 0 && parseFloat(second_level_discount) > 0}
              <div class="discount-info">
                <span>Price: ₹{afterD2.toFixed(2)}</span>
                <span class="profit-tag" class:loss={profitD2 < 0}>Profit: ₹{profitD2.toFixed(2)}</span>
              </div>
            {/if}
          </div>
          <div class="field">
            <label for="svc-d3">Third Level Discount %</label>
            <input id="svc-d3" type="number" step="0.01" bind:value={third_level_discount} placeholder="0" />
            {#if baseSalesPrice > 0 && parseFloat(third_level_discount) > 0}
              <div class="discount-info">
                <span>Price: ₹{afterD3.toFixed(2)}</span>
                <span class="profit-tag" class:loss={profitD3 < 0}>Profit: ₹{profitD3.toFixed(2)}</span>
              </div>
            {/if}
          </div>
        </div>
      {/if}

      <!-- Applicability (only for product type) -->
      {#if showApplicability}
        <div class="form-row two-col">
          <div class="field">
            <label for="applicability">Applicability</label>
            <select id="applicability" bind:value={applicability}>
              <option value="">Select...</option>
              <option value="universal">Universal</option>
              <option value="specific">Specific</option>
            </select>
          </div>

          <!-- Vehicle (only for specific) -->
          {#if showVehicle}
            <div class="field">
              <SearchableDropdown
                items={vehicles}
                bind:value={vehicle_id}
                placeholder="Select Vehicle"
                label="Vehicle"
                on:add={() => {}}
              />
            </div>
          {:else}
            <div class="field"></div>
          {/if}
        </div>
      {/if}

      <!-- Pricing fields (product or consumable) -->
      {#if showPricingFields}
        <!-- Part Number + Barcode -->
        <div class="form-row two-col">
          <div class="field">
            <label for="part-number">Part Number</label>
            <input id="part-number" type="text" bind:value={part_number} placeholder="Enter part number" />
          </div>
          <div class="field">
            <label for="barcode">Barcode</label>
            <input id="barcode" type="text" bind:value={barcode} placeholder="Enter barcode" />
          </div>
        </div>

        <!-- Expiry Date + Brand -->
        <div class="form-row two-col">
          <div class="field">
            <label for="expiry-date">Expiry Date</label>
            <input id="expiry-date" type="date" bind:value={expiry_date} />
          </div>

          <div class="field">
            <SearchableDropdown
              items={brands}
              bind:value={brand_id}
              placeholder="Select Brand"
              label="Brand"
              on:add={handleAddBrand}
              on:edit={handleEditBrand}
            />
          </div>
        </div>

        <!-- Unit + Unit Qty -->
        <div class="form-row two-col">
          <div class="field">
            <SearchableDropdown
              items={units}
              bind:value={unit_id}
              placeholder="Select Unit"
              label="Unit"
              on:add={handleAddUnit}
              on:edit={handleEditUnit}
            />
          </div>
          <div class="field">
            <label for="unit-qty">Unit Quantity</label>
            <input id="unit-qty" type="number" step="0.01" bind:value={unit_qty} placeholder="0" />
          </div>
        </div>

        <!-- Cost + Sales Price -->
        <div class="form-row two-col">
          <div class="field">
            <label for="current-cost">Current Cost</label>
            <input id="current-cost" type="number" step="0.01" bind:value={current_cost} placeholder="0.00" />
          </div>
          <div class="field">
            <label for="sales-price">Sales Price</label>
            <input id="sales-price" type="number" step="0.01" bind:value={sales_price} placeholder="0.00" />
          </div>
        </div>

        <!-- Discount fields -->
        <div class="form-row three-col">
          <div class="field">
            <label for="d1">First Level Discount %</label>
            <input id="d1" type="number" step="0.01" bind:value={first_level_discount} placeholder="0" />
            {#if baseSalesPrice > 0}
              <div class="discount-info">
                <span>Price: ₹{afterD1.toFixed(2)}</span>
                <span class="profit-tag" class:loss={profitD1 < 0}>Profit: ₹{profitD1.toFixed(2)}</span>
              </div>
            {/if}
          </div>
          <div class="field">
            <label for="d2">Second Level Discount %</label>
            <input id="d2" type="number" step="0.01" bind:value={second_level_discount} placeholder="0" />
            {#if baseSalesPrice > 0 && parseFloat(second_level_discount) > 0}
              <div class="discount-info">
                <span>Price: ₹{afterD2.toFixed(2)}</span>
                <span class="profit-tag" class:loss={profitD2 < 0}>Profit: ₹{profitD2.toFixed(2)}</span>
              </div>
            {/if}
          </div>
          <div class="field">
            <label for="d3">Third Level Discount %</label>
            <input id="d3" type="number" step="0.01" bind:value={third_level_discount} placeholder="0" />
            {#if baseSalesPrice > 0 && parseFloat(third_level_discount) > 0}
              <div class="discount-info">
                <span>Price: ₹{afterD3.toFixed(2)}</span>
                <span class="profit-tag" class:loss={profitD3 < 0}>Profit: ₹{profitD3.toFixed(2)}</span>
              </div>
            {/if}
          </div>
        </div>

        <!-- Stock Levels -->
        <div class="form-row two-col">
          <div class="field">
            <label for="opening-stock">Opening Stock</label>
            <input id="opening-stock" type="number" step="0.01" bind:value={opening_stock} placeholder="0" />
          </div>
          <div class="field">
            <label for="reorder-level">Reorder Level</label>
            <input id="reorder-level" type="number" step="0.01" bind:value={reorder_level} placeholder="0" />
          </div>
        </div>

        <div class="form-row two-col">
          <div class="field">
            <label for="min-stock">Minimum Stock</label>
            <input id="min-stock" type="number" step="0.01" bind:value={minimum_stock} placeholder="0" />
          </div>
          <div class="field">
            <label for="max-stock">Maximum Stock</label>
            <input id="max-stock" type="number" step="0.01" bind:value={maximum_stock} placeholder="0" />
          </div>
        </div>

        <!-- File Upload -->
        <div class="form-row">
          <div class="field file-field">
            <label>Product File / Image</label>
            <div class="file-upload-area">
              <input
                bind:this={fileInputEl}
                type="file"
                on:change={handleFileSelect}
                class="file-input-hidden"
                id="product-file"
              />
              <label for="product-file" class="file-upload-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                  <polyline points="17 8 12 3 7 8"/>
                  <line x1="12" y1="3" x2="12" y2="15"/>
                </svg>
                Choose File
              </label>
              {#if selectedFile}
                <div class="file-info">
                  <span class="file-name">{selectedFile.name}</span>
                  <span class="file-size">({(selectedFile.size / 1024).toFixed(1)} KB)</span>
                  <button class="file-remove" on:click={removeFile}>&times;</button>
                </div>
              {:else}
                <span class="file-hint">No file selected — any file type allowed</span>
              {/if}
            </div>
          </div>
        </div>
      {/if}
    </div>
  </div>

  <!-- ---- Footer ---- -->
  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    {#if showPricingFields || showServiceFields}
      <button class="btn-save" on:click={handleSave} disabled={saving}>
        {saving ? 'Saving...' : 'Save'}
      </button>
    {/if}
  </div>
</div>

<!-- Add Unit Popup -->
{#if addPopupOpen}
  <AddMasterDataPopup
    title={addPopupTitle}
    tableName={addPopupTable}
    on:close={() => (addPopupOpen = false)}
    on:created={handleMasterCreated}
  />
{/if}

<!-- Edit Popup -->
{#if editPopupOpen}
  <EditMasterDataPopup
    title={editPopupTitle}
    tableName={editPopupTable}
    itemId={editPopupItemId}
    itemName={editPopupItemName}
    on:close={() => (editPopupOpen = false)}
    on:updated={handleMasterUpdated}
  />
{/if}

<style>
  .create-product-window {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #fafafa;
  }

  /* ---- Header ---- */
  .form-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 20px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .back-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: #f3f4f6;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    cursor: pointer;
    color: #374151;
    transition: all 0.15s;
  }

  .back-btn:hover {
    background: #fff7ed;
    border-color: #F97316;
    color: #EA580C;
  }

  .form-header h2 {
    margin: 0;
    font-size: 17px;
    font-weight: 700;
    color: #111827;
  }

  /* ---- Body ---- */
  .form-body {
    flex: 1;
    overflow-y: auto;
    padding: 24px;
  }

  .msg {
    padding: 10px 14px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    margin-bottom: 16px;
  }

  .msg-error {
    background: #fef2f2;
    color: #dc2626;
    border: 1px solid #fecaca;
  }

  .msg-success {
    background: #f0fdf4;
    color: #16a34a;
    border: 1px solid #bbf7d0;
  }

  .form-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 18px;
    max-width: 800px;
  }

  .form-row {
    display: flex;
    gap: 16px;
  }

  .two-col > .field {
    flex: 1;
  }

  .three-col > .field {
    flex: 1;
  }

  .field {
    display: flex;
    flex-direction: column;
  }

  .field label {
    font-size: 12px;
    font-weight: 600;
    color: #374151;
    margin-bottom: 4px;
  }

  .field input[type="text"],
  .field input[type="number"],
  .field select {
    padding: 9px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
    transition: border-color 0.15s;
    background: white;
  }

  .field input:focus,
  .field select:focus {
    border-color: #F97316;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
  }

  /* ---- File Upload ---- */
  .file-field {
    flex: 1;
  }

  .file-upload-area {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .file-input-hidden {
    display: none;
  }

  .file-upload-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 14px;
    background: white;
    border: 1px solid #F97316;
    border-radius: 6px;
    color: #F97316;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }

  .file-upload-btn:hover {
    background: #F97316;
    color: white;
  }

  .file-info {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
  }

  .file-name {
    font-size: 13px;
    font-weight: 500;
    color: #374151;
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .file-size {
    font-size: 11px;
    color: #9ca3af;
  }

  .file-remove {
    background: none;
    border: none;
    color: #ef4444;
    font-size: 16px;
    cursor: pointer;
    padding: 0 2px;
    line-height: 1;
  }

  .file-hint {
    font-size: 12px;
    color: #9ca3af;
  }

  /* ---- Footer ---- */
  .form-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding: 14px 20px;
    background: white;
    border-top: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .btn-cancel {
    padding: 9px 20px;
    background: #f3f4f6;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
  }

  .btn-cancel:hover {
    background: #e5e7eb;
  }

  .btn-save {
    padding: 9px 28px;
    background: #F97316;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    color: white;
    cursor: pointer;
    transition: background 0.15s;
  }

  .btn-save:hover {
    background: #EA580C;
  }

  .btn-save:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  @media (max-width: 700px) {
    .two-col,
    .three-col {
      flex-direction: column;
    }
  }

  /* ---- Service Section ---- */
  .service-section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .section-label {
    font-size: 13px;
    font-weight: 700;
    color: #374151;
  }

  .component-search-wrap {
    position: relative;
  }

  .component-search {
    width: 100%;
    padding: 9px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
    transition: border-color 0.15s;
    box-sizing: border-box;
  }

  .component-search:focus {
    border-color: #F97316;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
  }

  .component-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0 0 8px 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    z-index: 20;
    max-height: 200px;
    overflow-y: auto;
  }

  .dd-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    padding: 8px 12px;
    border: none;
    background: none;
    font-size: 13px;
    cursor: pointer;
    text-align: left;
    color: #374151;
  }

  .dd-item:hover {
    background: #fff7ed;
  }

  .dd-cost {
    font-size: 11px;
    color: #9ca3af;
  }

  .comp-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }

  .comp-table th {
    background: #f9fafb;
    padding: 8px 10px;
    text-align: left;
    font-weight: 600;
    color: #6b7280;
    border-bottom: 1px solid #e5e7eb;
    font-size: 11px;
    text-transform: uppercase;
  }

  .comp-table td {
    padding: 8px 10px;
    border-bottom: 1px solid #f3f4f6;
    color: #374151;
  }

  .comp-qty-input {
    width: 60px;
    padding: 5px 6px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 13px;
    text-align: center;
    outline: none;
  }

  .comp-qty-input:focus {
    border-color: #F97316;
  }

  .comp-remove {
    background: none;
    border: none;
    color: #ef4444;
    font-size: 18px;
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
  }

  .comp-empty {
    padding: 16px;
    text-align: center;
    color: #9ca3af;
    font-size: 13px;
    background: #f9fafb;
    border-radius: 6px;
  }

  .comp-subtotal {
    display: flex;
    justify-content: space-between;
    padding: 8px 10px;
    background: #fff7ed;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 600;
    color: #EA580C;
  }

  .auto-cost {
    padding: 9px 10px;
    background: #f0fdf4;
    border: 1px solid #bbf7d0;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 700;
    color: #16a34a;
  }

  /* ---- Discount Info ---- */
  .discount-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 4px;
    padding: 4px 8px;
    background: #f9fafb;
    border-radius: 4px;
    font-size: 11px;
    color: #6b7280;
  }

  .profit-tag {
    font-weight: 700;
    color: #16a34a;
  }

  .profit-tag.loss {
    color: #dc2626;
  }
</style>
