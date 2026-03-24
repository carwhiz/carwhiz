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
  let labor_charge = '';
  let additional_charges = '';
  let existing_file_path = '';
  let opening_stock = '';

  // ---- File upload state ----
  let selectedFile: File | null = null;
  let fileInputEl: HTMLInputElement;

  // ---- Service-specific state ----
  interface ServiceComponent {
    id?: string; // DB ID for existing components
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

  onMount(() => {
    loadProduct();
    loadUnits();
    loadVehicles();
    loadBrands();
    loadConsumableProducts();
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
    opening_stock = data.current_stock?.toString() || '';
    minimum_stock = data.minimum_stock?.toString() || '';
    maximum_stock = data.maximum_stock?.toString() || '';
    reorder_level = data.reorder_level?.toString() || '';
    labor_charge = data.labor_charge?.toString() || '';
    additional_charges = data.additional_charges?.toString() || '';
    existing_file_path = data.file_path || '';
    loading = false;

    // Load service components if this is a service
    if (data.product_type === 'service') {
      await loadServiceComponents();
    }
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

  async function loadConsumableProducts() {
    const { data } = await supabase
      .from('products')
      .select('id, product_name, product_type, current_cost, unit_qty')
      .in('product_type', ['product', 'consumable'])
      .order('product_name');
    consumableProducts = (data || []);
  }

  async function loadServiceComponents() {
    const { data } = await supabase
      .from('product_components')
      .select('*, component_product:component_product_id(product_name, current_cost, unit_qty)')
      .eq('product_id', productId);

    if (data) {
      serviceComponents = data.map((pc: any) => ({
        id: pc.id,
        component_product_id: pc.component_product_id,
        product_name: pc.component_product?.product_name || 'Unknown',
        qty: pc.qty,
        cost: pc.component_product?.current_cost || 0,
      }));
    }
  }

  function searchComponents(e?: Event) {
    if (e) showComponentDropdown = true;
    const search = componentSearch.toLowerCase();
    filteredComponents = consumableProducts.filter(p =>
      p.product_name.toLowerCase().includes(search) &&
      !serviceComponents.some(c => c.component_product_id === p.id)
    );
  }

  function addComponent(product: any) {
    const costPerPiece = (product.current_cost || 0) / (product.unit_qty || 1);
    serviceComponents = [...serviceComponents, {
      component_product_id: product.id,
      product_name: product.product_name,
      qty: 1,
      cost: costPerPiece,
    }];
    componentSearch = '';
    showComponentDropdown = false;
    filteredComponents = [];
  }

  function removeComponent(idx: number) {
    serviceComponents = serviceComponents.filter((_, i) => i !== idx);
  }

  function recalcComponentLine(idx: number) {
    serviceComponents = serviceComponents;
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
    if (!product_name.trim()) { saveError = 'Product Name is required'; return; }
    if (!product_type) { saveError = 'Product Type is required'; return; }

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
      current_stock: product_type === 'service' ? 0 : (opening_stock ? parseFloat(opening_stock) : 0),
      minimum_stock: minimum_stock ? parseFloat(minimum_stock) : 0,
      maximum_stock: maximum_stock ? parseFloat(maximum_stock) : 0,
      reorder_level: reorder_level ? parseFloat(reorder_level) : 0,
      labor_charge: labor_charge ? parseFloat(labor_charge) : 0,
      additional_charges: additional_charges ? parseFloat(additional_charges) : 0,
      ...(file_path && { file_path }),
      updated_at: new Date().toISOString(),
      updated_by: $authStore.user?.id || null,
    };

    const { error } = await supabase.from('products').update(updateData).eq('id', productId);

    if (error) {
      saveError = error.message;
      saving = false;
      return;
    }

    // Handle service components if this is a service
    if (product_type === 'service') {
      // Delete old components
      const { error: deleteErr } = await supabase
        .from('product_components')
        .delete()
        .eq('product_id', productId);

      if (deleteErr) {
        saveError = 'Error updating components: ' + deleteErr.message;
        saving = false;
        return;
      }

      // Insert new components
      if (serviceComponents.length > 0) {
        const comps = serviceComponents.map(c => ({
          product_id: productId,
          component_product_id: c.component_product_id,
          qty: c.qty,
          created_by: $authStore.user?.id || null,
          updated_by: $authStore.user?.id || null,
        }));

        const { error: insertErr } = await supabase
          .from('product_components')
          .insert(comps);

        if (insertErr) {
          saveError = 'Error saving components: ' + insertErr.message;
          saving = false;
          return;
        }
      }
    }

    saving = false;
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

        <!-- ======== SERVICE FIELDS (show first for services) ======== -->
        {#if showServiceFields}
          <!-- Service Components Search -->
          <div class="form-section">
            <label>Service Components</label>
            <div class="component-search-box">
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
              <label for="ep-lc">Labor Charge</label>
              <input id="ep-lc" type="number" step="0.01" bind:value={labor_charge} placeholder="0.00" />
            </div>
            <div class="field">
              <label for="ep-ac">Additional Charges</label>
              <input id="ep-ac" type="number" step="0.01" bind:value={additional_charges} placeholder="0.00" />
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

          <!-- Discount fields with profit display -->
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

        <!-- ======== PRODUCT/CONSUMABLE FIELDS ======== -->
        <!-- Applicability (only for product type) -->
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

            <!-- Vehicle (only for specific) -->
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
              {#if baseSalesPrice > 0}
                <div class="discount-info">
                  <span>Price: ₹{afterD1.toFixed(2)}</span>
                  <span class="profit-tag" class:loss={profitD1 < 0}>Profit: ₹{profitD1.toFixed(2)}</span>
                </div>
              {/if}
            </div>
            <div class="field">
              <label for="ep-d2">Second Level Discount %</label>
              <input id="ep-d2" type="number" step="0.01" bind:value={second_level_discount} placeholder="0" />
              {#if baseSalesPrice > 0 && parseFloat(second_level_discount) > 0}
                <div class="discount-info">
                  <span>Price: ₹{afterD2.toFixed(2)}</span>
                  <span class="profit-tag" class:loss={profitD2 < 0}>Profit: ₹{profitD2.toFixed(2)}</span>
                </div>
              {/if}
            </div>
            <div class="field">
              <label for="ep-d3">Third Level Discount %</label>
              <input id="ep-d3" type="number" step="0.01" bind:value={third_level_discount} placeholder="0" />
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
              <label for="ep-opening-stock">Opening Stock</label>
              <input id="ep-opening-stock" type="number" step="0.01" bind:value={opening_stock} placeholder="0" />
            </div>
            <div class="field">
              <label for="ep-reorder">Reorder Level</label>
              <input id="ep-reorder" type="number" step="0.01" bind:value={reorder_level} placeholder="0" />
            </div>
          </div>
          <div class="form-row two-col">
            <div class="field">
              <label for="ep-min">Minimum Stock</label>
              <input id="ep-min" type="number" step="0.01" bind:value={minimum_stock} placeholder="0" />
            </div>
            <div class="field">
              <label for="ep-max">Maximum Stock</label>
              <input id="ep-max" type="number" step="0.01" bind:value={maximum_stock} placeholder="0" />
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
                  id="ep-product-file"
                />
                <label for="ep-product-file" class="file-upload-btn">
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
                {:else if existing_file_path}
                  <div class="file-info">
                    <span class="file-name">📎 {existing_file_path}</span>
                  </div>
                {:else}
                  <span class="file-hint">No file selected — any file type allowed</span>
                {/if}
              </div>
            </div>
          </div>
        {/if}
      </div>
    {/if}
  </div>

  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    {#if !loading}
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
  .form-section { display:flex; flex-direction:column; gap:12px; }
  .form-section > label { font-size:12px; font-weight:600; color:#374151; }
  .component-search-box { position:relative; }
  .component-search { width:100%; padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; box-sizing:border-box; transition:border-color .15s; }
  .component-search:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,0.1); }
  .component-dropdown { position:absolute; top:100%; left:0; right:0; background:white; border:1px solid #d1d5db; border-top:none; border-radius:0 0 6px 6px; max-height:200px; overflow-y:auto; z-index:10; box-shadow:0 4px 6px rgba(0,0,0,0.1); }
  .dd-item { display:flex; justify-content:space-between; align-items:center; width:100%; padding:8px 10px; background:white; border:none; text-align:left; cursor:pointer; font-size:13px; color:#374151; transition:background .15s; }
  .dd-item:hover { background:#f9fafb; }
  .dd-cost { font-size:12px; color:#6b7280; margin-left:8px; }
  .comp-table { width:100%; border-collapse:collapse; font-size:13px; margin-top:12px; border:1px solid #e5e7eb; border-radius:6px; overflow:hidden; }
  .comp-table thead { background:#f9fafb; }
  .comp-table th, .comp-table td { padding:10px; text-align:left; border-bottom:1px solid #e5e7eb; }
  .comp-table th { font-weight:600; color:#374151; }
  .comp-table td { color:#6b7280; }
  .comp-table tbody tr:hover { background:#f9fafb; }
  .comp-qty-input { width:60px; padding:6px; border:1px solid #d1d5db; border-radius:4px; font-size:13px; text-align:center; }
  .comp-remove { width:24px; height:24px; padding:0; background:white; border:1px solid #fecaca; border-radius:4px; color:#dc2626; cursor:pointer; font-weight:bold; transition:all .15s; }
  .comp-remove:hover { background:#fef2f2; }
  .comp-empty { text-align:center; padding:16px; color:#9ca3af; font-size:13px; background:#f9fafb; border-radius:6px; }
  .comp-subtotal { display:flex; justify-content:space-between; align-items:center; padding:12px; background:#f9fafb; border-radius:6px; font-size:13px; font-weight:600; color:#374151; margin-top:12px; }
  .auto-cost { padding:10px; background:#f0fdf4; border:1px solid #bbf7d0; border-radius:6px; font-size:14px; font-weight:600; color:#16a34a; }
  .discount-info { display:flex; flex-direction:column; gap:4px; margin-top:6px; font-size:12px; }
  .discount-info span { color:#6b7280; }
  .profit-tag { font-weight:600; color:#16a34a; }
  .profit-tag.loss { color:#dc2626; }
  .file-field { }
  .file-upload-area { display:flex; flex-direction:column; gap:12px; padding:16px; background:#f9fafb; border:2px dashed #d1d5db; border-radius:8px; }
  .file-input-hidden { display:none; }
  .file-upload-btn { display:inline-flex; align-items:center; justify-content:center; gap:6px; padding:10px 14px; background:white; border:1px solid #d1d5db; border-radius:6px; font-size:13px; font-weight:600; color:#374151; cursor:pointer; transition:all .15s; }
  .file-upload-btn:hover { border-color:#C41E3A; color:#C41E3A; background:#fff7ed; }
  .file-info { display:flex; align-items:center; gap:8px; padding:8px; background:white; border-radius:4px; font-size:12px; }
  .file-name { color:#374151; font-weight:600; }
  .file-size { color:#6b7280; }
  .file-remove { background:none; border:none; color:#dc2626; cursor:pointer; font-weight:bold; padding:0; width:20px; height:20px; display:flex; align-items:center; justify-content:center; }
  .file-remove:hover { color:#991b1b; }
  .file-hint { color:#9ca3af; font-size:12px; }
  @media (max-width:700px) { .two-col, .three-col { flex-direction:column; } }

</style>
