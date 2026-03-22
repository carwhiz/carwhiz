<!-- ============================================================
     FINANCE > MANAGE > JOB CARD WINDOW
     Purpose: Step-wizard to create job cards
     Window ID: finance-job-card
     Steps: 1) Customer  2) Vehicle  3) Products/Services  4) Assign Job
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import { canUserCreateResource } from '../../../../lib/services/permissionService';

  let step = 1;
  let permDenied = false;

  // ---- Step 1: Customer ----
  let customerSearch = '';
  let customers: any[] = [];
  let filteredCustomers: any[] = [];
  let selectedCustomer: any = null;
  let showCustomerDropdown = false;
  let showCreateCustomer = false;
  let newCustName = '';
  let newCustPlace = '';
  let newCustGender = '';
  let newCustPhones: string[] = [''];
  let custSaving = false;
  let custError = '';
  let selectedVehicleNumber: string | null = null;

  // ---- Step 2: Vehicle ----
  let vehicleSearch = '';
  let vehicles: any[] = [];
  let customerVehicles: any[] = [];
  let customerVehicleNumbers: any[] = [];
  let filteredVehicles: any[] = [];
  let selectedVehicle: any = null;
  let showVehicleDropdown = false;
  let showCreateVehicle = false;
  let allMakes: any[] = [];
  let allGenerations: any[] = [];
  let allGenTypes: any[] = [];
  let allVariants: any[] = [];
  let allGearboxes: any[] = [];
  let allFuelTypes: any[] = [];
  let allBodySides: any[] = [];
  let newVehModelName = '';
  let newVehMakeId = '';
  let newVehGenId = '';
  let newVehGenTypeId = '';
  let newVehVariantId = '';
  let newVehGearboxId = '';
  let newVehFuelTypeId = '';
  let newVehBodySideId = '';
  let vehSaving = false;
  let vehError = '';

  // ---- Step 3: Products/Services ----
  let productSearch = '';
  let allProducts: any[] = [];
  let filteredProducts: any[] = [];
  let showProductDropdown = false;
  let showCreateProduct = false;
  let newProdName = '';
  let newProdType: 'product' | 'service' | 'consumable' = 'product';
  let newProdPrice = '';
  let prodSaving = false;
  let prodError = '';

  interface JobItem {
    item_type: string;
    item_id: string;
    name: string;
    qty: number;
    price: number;
    discount: number;
    total: number;
    notes: string;
  }
  let items: JobItem[] = [];
  $: grandTotal = items.reduce((s, i) => s + i.total, 0);

  // ---- Step 4: Assign ----
  let users: any[] = [];
  let assignedUserId = '';
  let description = '';
  let details = '';
  let expectedDate = '';
  let priority = 'Normal';

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let savedJobCardNo = '';
  let showSuccess = false;

  onMount(async () => {
    const userId = $authStore.user?.id;
    if (userId) {
      const allowed = await canUserCreateResource(userId, 'finance-job-card');
      if (!allowed) { permDenied = true; return; }
    }
    await Promise.all([
      loadCustomers(),
      loadVehicles(),
      loadProducts(),
      loadUsers(),
      loadVehicleMasterData(),
    ]);
  });

  // ---- Data loaders ----
  async function loadCustomers() {
    const { data } = await supabase.from('customers').select('id, name, place, ledger_id, customer_vehicle_numbers(vehicle_number), customer_phones(phone)').order('name');
    customers = (data || []).map((c: any) => ({
      ...c,
      vehicle_numbers: (c.customer_vehicle_numbers || []).map((v: any) => v.vehicle_number).filter(Boolean),
      phone_numbers: (c.customer_phones || []).map((p: any) => p.phone).filter(Boolean)
    }));
  }

  async function loadVehicles() {
    const { data } = await supabase
      .from('vehicles')
      .select('id, model_name, makes(name), generations(name), generation_types(name), variants(name), gearboxes(name), fuel_types(name), body_sides(name)')
      .order('model_name');
    vehicles = (data || []).map((v: any) => ({
      ...v,
      make_name: v.makes?.name || '',
      generation_name: v.generations?.name || '',
      gen_type_name: v.generation_types?.name || '',
      variant_name: v.variants?.name || '',
      gearbox_name: v.gearboxes?.name || '',
      fuel_type_name: v.fuel_types?.name || '',
      body_side_name: v.body_sides?.name || ''
    }));
  }

  async function loadProducts() {
    const { data } = await supabase
      .from('products')
      .select('id, product_name, product_type, sales_price, units(name)')
      .order('product_name');
    allProducts = (data || []).map((p: any) => ({ ...p, unit_name: p.units?.name || '' }));
  }

  async function loadUsers() {
    const { data } = await supabase.from('users').select('id, email, user_name, phone_number, role, created_at').order('email');
    users = data || [];
  }

  async function loadVehicleMasterData() {
    const tables = [
      { table: 'makes', setter: (d: any[]) => allMakes = d },
      { table: 'generations', setter: (d: any[]) => allGenerations = d },
      { table: 'generation_types', setter: (d: any[]) => allGenTypes = d },
      { table: 'variants', setter: (d: any[]) => allVariants = d },
      { table: 'gearboxes', setter: (d: any[]) => allGearboxes = d },
      { table: 'fuel_types', setter: (d: any[]) => allFuelTypes = d },
      { table: 'body_sides', setter: (d: any[]) => allBodySides = d },
    ];
    for (const t of tables) {
      const { data } = await supabase.from(t.table).select('id, name').order('name');
      t.setter(data || []);
    }
  }

  // ---- Step 1: Customer ----
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
    // Load and filter vehicles for this customer
    loadCustomerVehicles(c.id);
  }

  function clearCustomer() {
    selectedCustomer = null;
    customerSearch = '';
    selectedVehicleNumber = null;
    selectedVehicle = null;
    vehicleSearch = '';
    customerVehicleNumbers = [];
  }

  async function loadCustomerVehicles(customerId: string) {
    // Load customer vehicle numbers
    const { data: vehicleNumbers } = await supabase
      .from('customer_vehicle_numbers')
      .select('id, vehicle_number')
      .eq('customer_id', customerId);
    
    customerVehicleNumbers = vehicleNumbers || [];
    customerVehicles = vehicles;
  }

  function updateCustomerVehicles() {
    // Show all vehicles
    customerVehicles = vehicles;
  }

  async function saveInlineCustomer() {
    if (!newCustName.trim()) { custError = 'Name is required'; return; }
    custSaving = true;
    custError = '';

    const { data: ltData } = await supabase.from('ledger_types').select('id').eq('name', 'Receivables').single();
    if (!ltData) { custError = 'Receivables ledger type not found'; custSaving = false; return; }

    const { data: ledgerData, error: ledgerErr } = await supabase.from('ledger').insert({
      ledger_name: newCustName.trim(),
      ledger_type_id: ltData.id,
      reference_type: 'customer',
      opening_balance: 0,
      status: 'active',
      created_by: $authStore.user?.id || null,
    }).select('id').single();

    if (ledgerErr || !ledgerData) { custError = 'Failed to create ledger'; custSaving = false; return; }

    const { data: custData, error: custErr } = await supabase.from('customers').insert({
      name: newCustName.trim(),
      place: newCustPlace.trim() || null,
      gender: newCustGender || null,
      ledger_id: ledgerData.id,
      created_by: $authStore.user?.id || null,
    }).select('id, name, place, ledger_id').single();

    if (custErr || !custData) { custError = 'Failed to create customer'; custSaving = false; return; }

    await supabase.from('ledger').update({ reference_id: custData.id, updated_by: $authStore.user?.id || null }).eq('id', ledgerData.id);

    const validPhones = newCustPhones.map(p => p.trim()).filter(p => p);
    if (validPhones.length > 0 && custData.id) {
      await supabase.from('customer_phones').insert(validPhones.map(p => ({ customer_id: custData.id, phone: p })));
    }

    await loadCustomers();
    selectedCustomer = custData;
    customerSearch = custData.name;
    showCreateCustomer = false;
    newCustName = ''; newCustPlace = ''; newCustGender = ''; newCustPhones = [''];
    custSaving = false;
  }

  // ---- Step 2: Vehicle ----
  function handleVehicleSearch() {
    const q = vehicleSearch.toLowerCase().trim();
    const src = customerVehicles.length > 0 ? customerVehicles : vehicles;
    if (!q) { filteredVehicles = []; showVehicleDropdown = false; return; }
    filteredVehicles = src.filter(v =>
      v.model_name.toLowerCase().includes(q) || (v.make_name || '').toLowerCase().includes(q)
    ).slice(0, 10);
    showVehicleDropdown = filteredVehicles.length > 0;
  }

  function selectVehicle(v: any) {
    selectedVehicle = v;
    vehicleSearch = v.model_name + (v.make_name ? ` (${v.make_name})` : '');
    showVehicleDropdown = false;
  }

  function clearVehicle() {
    selectedVehicle = null;
    vehicleSearch = '';
  }

  async function saveInlineVehicle() {
    if (!newVehModelName.trim()) { vehError = 'Model name is required'; return; }
    vehSaving = true;
    vehError = '';

    const { data, error } = await supabase.from('vehicles').insert({
      model_name: newVehModelName.trim(),
      make_id: newVehMakeId || null,
      generation_id: newVehGenId || null,
      generation_type_id: newVehGenTypeId || null,
      variant_id: newVehVariantId || null,
      gearbox_id: newVehGearboxId || null,
      fuel_type_id: newVehFuelTypeId || null,
      body_side_id: newVehBodySideId || null,
      created_by: $authStore.user?.id || null,
    }).select('id, model_name').single();

    if (error || !data) { vehError = 'Failed to create vehicle: ' + (error?.message || ''); vehSaving = false; return; }

    await loadVehicles();
    updateCustomerVehicles();
    selectedVehicle = data;
    vehicleSearch = data.model_name;
    showCreateVehicle = false;
    newVehModelName = ''; newVehMakeId = ''; newVehGenId = ''; newVehGenTypeId = '';
    newVehVariantId = ''; newVehGearboxId = ''; newVehFuelTypeId = ''; newVehBodySideId = '';
    vehSaving = false;
  }

  // ---- Step 3: Products/Services ----
  function handleProductSearch() {
    const q = productSearch.toLowerCase().trim();
    if (!q) { filteredProducts = []; showProductDropdown = false; return; }
    filteredProducts = allProducts.filter(p =>
      p.product_name.toLowerCase().includes(q)
    ).slice(0, 10);
    showProductDropdown = filteredProducts.length > 0;
  }

  function addProduct(p: any) {
    const existing = items.findIndex(i => i.item_id === p.id);
    if (existing >= 0) {
      items[existing].qty += 1;
      recalcItem(existing);
    } else {
      items = [...items, {
        item_type: p.product_type || 'product',
        item_id: p.id,
        name: p.product_name,
        qty: 1,
        price: p.sales_price || 0,
        discount: 0,
        total: p.sales_price || 0,
        notes: '',
      }];
    }
    productSearch = '';
    showProductDropdown = false;
  }

  function removeItem(idx: number) {
    items = items.filter((_, i) => i !== idx);
  }

  function recalcItem(idx: number) {
    const it = items[idx];
    it.total = (it.qty * it.price) - it.discount;
    items = [...items];
  }

  function handleItemQtyChange(idx: number, val: string) {
    items[idx].qty = parseFloat(val) || 0;
    recalcItem(idx);
  }
  function handleItemPriceChange(idx: number, val: string) {
    items[idx].price = parseFloat(val) || 0;
    recalcItem(idx);
  }
  function handleItemDiscountChange(idx: number, val: string) {
    items[idx].discount = parseFloat(val) || 0;
    recalcItem(idx);
  }

  async function saveInlineProduct() {
    if (!newProdName.trim()) { prodError = 'Product name is required'; return; }
    prodSaving = true;
    prodError = '';

    const { data, error } = await supabase.from('products').insert({
      product_name: newProdName.trim(),
      product_type: newProdType,
      sales_price: parseFloat(newProdPrice) || 0,
      created_by: $authStore.user?.id || null,
    }).select('id, product_name, product_type, sales_price').single();

    if (error || !data) { prodError = 'Failed to create product: ' + (error?.message || ''); prodSaving = false; return; }

    await loadProducts();
    addProduct({ ...data, unit_name: '' });
    showCreateProduct = false;
    newProdName = ''; newProdType = 'product'; newProdPrice = '';
    prodSaving = false;
  }

  // ---- Navigation ----
  $: canNext = step === 1 ? (!!selectedCustomer && !!selectedVehicleNumber)
             : step === 2 ? !!selectedVehicle
             : step === 3 ? items.length > 0
             : false;

  function nextStep() {
    if (canNext && step < 4) step++;
  }

  function prevStep() {
    if (step > 1) step--;
  }

  function goToStep(s: number) {
    if (s === 1) { step = 1; return; }
    if (s === 2 && selectedCustomer && selectedVehicleNumber) { step = 2; return; }
    if (s === 3 && selectedCustomer && selectedVehicleNumber && selectedVehicle) { step = 3; return; }
    if (s === 4 && selectedCustomer && selectedVehicleNumber && selectedVehicle && items.length > 0) { step = 4; return; }
  }

  // ---- Save Job Card ----
  async function handleSaveJobCard() {
    if (!selectedCustomer) { saveError = 'Customer is required'; return; }
    if (!selectedVehicleNumber) { saveError = 'Vehicle number is required'; return; }
    if (!selectedVehicle) { saveError = 'Vehicle is required'; return; }
    if (items.length === 0) { saveError = 'At least one item is required'; return; }
    if (!assignedUserId) { saveError = 'Assigned user is required'; return; }
    if (!description.trim()) { saveError = 'Description is required'; return; }
    if (!expectedDate) { saveError = 'Expected date is required'; return; }

    saving = true;
    saveError = '';

    // Generate job card number: JC-DD-MM-YYYY-HH:MM AM/PM - (vehicle_number)
    const now = new Date();
    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const year = now.getFullYear();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const ampm = now.getHours() >= 12 ? 'PM' : 'AM';
    const displayHours = now.getHours() % 12 || 12;
    
    const jobCardNo = `JC-${day}${month}${year}${String(displayHours).padStart(2, '0')}${minutes}-${selectedVehicleNumber}`;

    const { data: jc, error: jcErr } = await supabase.from('job_cards').insert({
      job_card_no: jobCardNo,
      customer_id: selectedCustomer.id,
      vehicle_id: selectedVehicle.id,
      vehicle_number: selectedVehicleNumber,
      assigned_user_id: assignedUserId,
      status: 'Open',
      priority,
      description: description.trim(),
      details: details.trim() || null,
      expected_date: expectedDate || null,
      created_by: $authStore.user?.id || null,
    }).select('id, job_card_no').single();

    if (jcErr || !jc) {
      saving = false;
      saveError = 'Failed to create job card: ' + (jcErr?.message || '');
      return;
    }

    // Save items
    // NOTE: Stock is NOT reduced here. Job cards are work orders only.
    // Stock reduction happens only when the job card is converted to a sale,
    // following the sales logic: products reduce qty, services reduce component stock.
    const itemRows = items.map(it => ({
      job_card_id: jc.id,
      item_type: it.item_type,
      item_id: it.item_id,
      name: it.name,
      qty: it.qty,
      price: it.price,
      discount: it.discount,
      total: it.total,
      notes: it.notes || null,
      created_by: $authStore.user?.id || null,
    }));

    const { error: itemsErr } = await supabase.from('job_card_items').insert(itemRows);
    if (itemsErr) {
      saving = false;
      saveError = 'Job card created but failed to save items: ' + itemsErr.message;
      return;
    }

    // Log creation
    await supabase.from('job_card_logs').insert({
      job_card_id: jc.id,
      action: 'Created',
      from_status: null,
      to_status: 'Open',
      note: 'Job card created',
      action_by: $authStore.user?.id || null,
      created_by: $authStore.user?.id || null,
    });

    saving = false;
    savedJobCardNo = jc.job_card_no;
    showSuccess = true;
  }

  function handleNewJobCard() {
    step = 1;
    selectedCustomer = null;
    customerSearch = '';
    selectedVehicleNumber = null;
    selectedVehicle = null;
    vehicleSearch = '';
    items = [];
    assignedUserId = '';
    description = '';
    details = '';
    expectedDate = '';
    priority = 'Normal';
    saveError = '';
    savedJobCardNo = '';
    showSuccess = false;
  }

  async function handlePrint() {
    const printContent = document.getElementById('job-card-print');
    if (!printContent) return;
    
    // Load logo as base64
    let logoBase64 = '';
    try {
      const response = await fetch('/logo.jpeg');
      const blob = await response.blob();
      logoBase64 = await new Promise((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result);
        reader.readAsDataURL(blob);
      });
    } catch (e) {
      console.log('Logo loading failed, continuing without it');
    }
    
    const win = window.open('', '_blank');
    if (!win) return;
    win.document.write(`
      <html><head><title>Job Card - ${savedJobCardNo}</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; font-size: 13px; margin: 0; }
        .logo-header { text-align: center; margin-bottom: 20px; border-bottom: 2px solid #333; padding-bottom: 10px; }
        .logo-header img { max-height: 80px; max-width: 200px; }
        h2 { margin: 10px 0; text-align: center; }
        .job-info { text-align: center; margin: 10px 0; font-weight: bold; font-size: 14px; }
        .cards-row { display: flex; gap: 20px; margin: 15px 0; }
        .card { flex: 1; border: 1px solid #333; padding: 12px; }
        .card-title { font-weight: bold; margin-bottom: 8px; border-bottom: 1px solid #333; padding-bottom: 4px; }
        .card-item { display: flex; margin: 6px 0; }
        .card-label { font-weight: 600; min-width: 90px; }
        .card-value { flex: 1; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: left; font-size: 12px; }
        th { background: #f5f5f5; font-weight: bold; }
        .sig { margin-top: 20px; border-top: 1px solid #333; width: 150px; text-align: center; padding-top: 4px; }
      </style></head><body>
      <div class="logo-header">
        ${logoBase64 ? `<img src="${logoBase64}" alt="CarWhizz Logo" />` : ''}
      </div>
      <h2>Job Card</h2>
      <div class="job-info">${savedJobCardNo}</div>
      <div class="cards-row">
        <div class="card">
          <div class="card-title">Customer Details</div>
          <div class="card-item"><span class="card-label">Name:</span><span class="card-value">${selectedCustomer?.name || '—'}</span></div>
          <div class="card-item"><span class="card-label">Location:</span><span class="card-value">${selectedCustomer?.place || '—'}</span></div>
          <div class="card-item"><span class="card-label">Phone:</span><span class="card-value">${selectedCustomer?.phone_numbers && selectedCustomer.phone_numbers.length > 0 ? selectedCustomer.phone_numbers.join(', ') : '—'}</span></div>
        </div>
        <div class="card">
          <div class="card-title">Vehicle Details</div>
          <div class="card-item"><span class="card-label">Number:</span><span class="card-value">${selectedVehicleNumber || '—'}</span></div>
          <div class="card-item"><span class="card-label">Model:</span><span class="card-value">${selectedVehicle?.model_name || '—'}</span></div>
          <div class="card-item"><span class="card-label">Make:</span><span class="card-value">${selectedVehicle?.make_name || '—'}</span></div>
          <div class="card-item"><span class="card-label">Variant:</span><span class="card-value">${selectedVehicle?.variant_name || '—'}</span></div>
          <div class="card-item"><span class="card-label">Fuel Type:</span><span class="card-value">${selectedVehicle?.fuel_type_name || '—'}</span></div>
          <div class="card-item"><span class="card-label">Body Side:</span><span class="card-value">${selectedVehicle?.body_side_name || '—'}</span></div>
        </div>
      </div>
      <div class="card" style="margin: 15px 0;">
        <div class="card-title">Description</div>
        <div style="padding: 8px; line-height: 1.5;">${description || '—'}</div>
      </div>
      <div style="border: 1px solid #333; padding: 10px; margin: 15px 0;">
        <div style="margin: 6px 0;"><strong>Assigned To:</strong> ${users.find(u => u.id === assignedUserId)?.user_name || users.find(u => u.id === assignedUserId)?.email || ''}</div>
        <div style="margin: 6px 0;"><strong>Priority:</strong> ${priority}</div>
        ${details ? `<div style="margin: 6px 0;"><strong>Notes:</strong> ${details}</div>` : ''}
        <div style="margin: 6px 0;"><strong>Date:</strong> ${new Date().toLocaleDateString('en-IN')}</div>
        ${expectedDate ? `<div style="margin: 6px 0;"><strong>Expected Date:</strong> ${expectedDate}</div>` : ''}
      </div>
      ${printContent.innerHTML}</body></html>
    `);
    win.document.close();
    setTimeout(() => win.print(), 500);
  }
</script>

<div class="jc-window">
  {#if permDenied}
    <div class="perm-denied"><p>You do not have permission to create job cards.</p></div>
  {:else if showSuccess}
    <!-- ===== SUCCESS SCREEN ===== -->
    <div class="success-screen">
      <div class="success-card">
        <svg viewBox="0 0 24 24" fill="none" stroke="#16a34a" stroke-width="2" width="60" height="60"><circle cx="12" cy="12" r="10"/><polyline points="9 12 11 14 15 10"/></svg>
        <h2>Job Card Created!</h2>
        <p class="jc-no">{savedJobCardNo}</p>
        <div class="success-actions">
          <button class="btn-primary" on:click={handlePrint}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>
            Print
          </button>
          <button class="btn-secondary" on:click={handleNewJobCard}>New Job Card</button>
          <button class="btn-ghost" on:click={() => windowStore.close('finance-job-card')}>Close</button>
        </div>
      </div>

      <!-- Hidden print content (items table only) -->
      <div id="job-card-print" style="display:none;">
        <h3>Items</h3>
        <table>
          <thead><tr><th>#</th><th>Type</th><th>Item</th><th>Qty</th><th>Price</th><th>Discount</th><th>Total</th><th>Notes</th></tr></thead>
          <tbody>
            {#each items as it, idx}
              <tr><td>{idx+1}</td><td>{it.item_type}</td><td>{it.name}</td><td>{it.qty}</td><td>₹{it.price.toFixed(2)}</td><td>₹{it.discount.toFixed(2)}</td><td>₹{it.total.toFixed(2)}</td><td>{it.notes || ''}</td></tr>
            {/each}
          </tbody>
        </table>
        <div style="margin-top: 10px; font-weight: bold;">Grand Total: ₹{grandTotal.toFixed(2)}</div>
        <div style="margin-top: 30px; border-top: 1px solid #333; width: 150px; text-align: center; padding-top: 4px;">Signature</div>
      </div>
    </div>
  {:else}
    <!-- ===== STEP INDICATOR ===== -->
    <div class="step-bar">
      {#each [
        { n: 1, label: 'Customer' },
        { n: 2, label: 'Vehicle' },
        { n: 3, label: 'Products / Services' },
        { n: 4, label: 'Assign Job' },
      ] as s}
        <button
          class="step-dot"
          class:active={step === s.n}
          class:done={step > s.n}
          on:click={() => goToStep(s.n)}
        >
          <span class="dot">{step > s.n ? '✓' : s.n}</span>
          <span class="step-label">{s.label}</span>
        </button>
        {#if s.n < 4}<div class="step-line" class:filled={step > s.n}></div>{/if}
      {/each}
    </div>

    {#if saveError}
      <div class="msg msg-error">{saveError}</div>
    {/if}

    <div class="step-body">
      <!-- ===== STEP 1: CUSTOMER ===== -->
      {#if step === 1}
        <div class="step-content">
          <h3>Select or Create Customer</h3>
          {#if !showCreateCustomer}
            <div class="search-box">
              <input type="text" placeholder="Search customers by name or place..." bind:value={customerSearch} on:input={handleCustomerSearch} on:focus={handleCustomerSearch} />
              {#if showCustomerDropdown}
                <div class="dropdown">
                  {#each filteredCustomers as c}
                    <button class="dd-item" on:click={() => selectCustomer(c)}>
                      <strong>{c.name}</strong>{#if c.place} <span class="sub">— {c.place}</span>{/if}
                      {#if c.phone_numbers && c.phone_numbers.length > 0}
                        <div style="font-size: 11px; color: #666; margin-top: 4px;">Phones: {c.phone_numbers.join(', ')}</div>
                      {/if}
                      {#if c.vehicle_numbers && c.vehicle_numbers.length > 0}
                        <div style="font-size: 11px; color: #666; margin-top: 2px;">Vehicles: {c.vehicle_numbers.join(', ')}</div>
                      {/if}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            {#if selectedCustomer}
              <div class="selected-chip">
                <div>
                  <span>{selectedCustomer.name}</span>
                  {#if selectedCustomer.place}<span class="sub"> — {selectedCustomer.place}</span>{/if}
                  {#if selectedCustomer.phone_numbers && selectedCustomer.phone_numbers.length > 0}
                    <div style="font-size: 11px; color: #666; margin-top: 4px;">Phones: {selectedCustomer.phone_numbers.join(', ')}</div>
                  {/if}
                  {#if selectedCustomer.vehicle_numbers && selectedCustomer.vehicle_numbers.length > 0}
                    <div style="font-size: 11px; color: #666; margin-top: 2px;">Vehicles: {selectedCustomer.vehicle_numbers.join(', ')}</div>
                  {/if}
                </div>
                <button class="chip-clear" on:click={clearCustomer}>×</button>
              </div>

              {#if customerVehicleNumbers && customerVehicleNumbers.length > 0}
                <div class="vehicle-numbers-section">
                  <label>Select Vehicle Number:</label>
                  <div class="vehicle-numbers-list">
                    {#each customerVehicleNumbers as vn}
                      <button
                        class="vehicle-number-btn"
                        class:selected={selectedVehicleNumber === vn.vehicle_number}
                        on:click={() => selectedVehicleNumber = vn.vehicle_number}
                      >
                        {vn.vehicle_number}
                      </button>
                    {/each}
                  </div>
                  {#if selectedVehicleNumber}
                    <div class="selected-vn">Selected: <strong>{selectedVehicleNumber}</strong></div>
                  {/if}
                </div>
              {:else}
                <div class="note-info">No vehicle numbers found for this customer.</div>
              {/if}
            {/if}

            {#if !selectedCustomer}
              <button class="btn-inline-create" on:click={() => showCreateCustomer = true}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                Create New Customer
              </button>
            {/if}
          {:else}
            <!-- Inline customer form -->
            <div class="inline-form">
              <h4>New Customer</h4>
              {#if custError}<div class="form-error">{custError}</div>{/if}
              <div class="form-grid">
                <div class="form-field">
                  <label>Name *</label>
                  <input type="text" bind:value={newCustName} placeholder="Customer name" />
                </div>
                <div class="form-field">
                  <label>Place</label>
                  <input type="text" bind:value={newCustPlace} placeholder="City / Town" />
                </div>
                <div class="form-field">
                  <label>Gender</label>
                  <select bind:value={newCustGender}>
                    <option value="">Select</option>
                    <option value="Male">Male</option>
                    <option value="Female">Female</option>
                    <option value="Other">Other</option>
                  </select>
                </div>
              </div>
              <div class="form-field">
                <label>Phone Numbers</label>
                {#each newCustPhones as phone, i}
                  <div class="phone-row">
                    <input type="text" bind:value={newCustPhones[i]} placeholder="Phone number" />
                    {#if newCustPhones.length > 1}
                      <button class="btn-remove-sm" on:click={() => newCustPhones = newCustPhones.filter((_, idx) => idx !== i)}>×</button>
                    {/if}
                  </div>
                {/each}
                <button class="btn-add-sm" on:click={() => newCustPhones = [...newCustPhones, '']}>+ Add Phone</button>
              </div>
              <div class="form-actions">
                <button class="btn-primary" on:click={saveInlineCustomer} disabled={custSaving}>{custSaving ? 'Saving...' : 'Save Customer'}</button>
                <button class="btn-ghost" on:click={() => { showCreateCustomer = false; custError = ''; }}>Cancel</button>
              </div>
            </div>
          {/if}
        </div>

      <!-- ===== STEP 2: VEHICLE ===== -->
      {:else if step === 2}
        <div class="step-content">
          <h3>Select Vehicle Model / Details</h3>
          <p class="step-note">Vehicle Number selected: <strong>{selectedVehicleNumber || 'N/A'}</strong></p>
          {#if !showCreateVehicle}
            <div class="search-box">
              <input type="text" placeholder="Search vehicles by model or make..." bind:value={vehicleSearch} on:input={handleVehicleSearch} on:focus={handleVehicleSearch} />
              {#if showVehicleDropdown}
                <div class="dropdown">
                  {#each filteredVehicles as v}
                    <button class="dd-item vehicle-item" on:click={() => selectVehicle(v)}>
                      <strong>{v.model_name}</strong>
                      {#if v.make_name || v.generation_name || v.variant_name || v.fuel_type_name || v.gearbox_name || v.body_side_name}
                        <div class="vehicle-details">
                          {#if v.make_name}<span class="tag">{v.make_name}</span>{/if}
                          {#if v.generation_name}<span class="tag">{v.generation_name}</span>{/if}
                          {#if v.gen_type_name}<span class="tag">{v.gen_type_name}</span>{/if}
                          {#if v.variant_name}<span class="tag">{v.variant_name}</span>{/if}
                          {#if v.fuel_type_name}<span class="tag">{v.fuel_type_name}</span>{/if}
                          {#if v.gearbox_name}<span class="tag">{v.gearbox_name}</span>{/if}
                          {#if v.body_side_name}<span class="tag">{v.body_side_name}</span>{/if}
                        </div>
                      {/if}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            {#if selectedVehicle}
              <div class="selected-card">
                <div class="card-main">
                  <strong>{selectedVehicle.model_name}</strong>
                  <button class="chip-clear" on:click={clearVehicle}>×</button>
                </div>
                <div class="card-details">
                  {#if selectedVehicle.make_name}<span class="detail-tag">{selectedVehicle.make_name}</span>{/if}
                  {#if selectedVehicle.generation_name}<span class="detail-tag">{selectedVehicle.generation_name}</span>{/if}
                  {#if selectedVehicle.gen_type_name}<span class="detail-tag">{selectedVehicle.gen_type_name}</span>{/if}
                  {#if selectedVehicle.variant_name}<span class="detail-tag">{selectedVehicle.variant_name}</span>{/if}
                  {#if selectedVehicle.fuel_type_name}<span class="detail-tag">{selectedVehicle.fuel_type_name}</span>{/if}
                  {#if selectedVehicle.gearbox_name}<span class="detail-tag">{selectedVehicle.gearbox_name}</span>{/if}
                  {#if selectedVehicle.body_side_name}<span class="detail-tag">{selectedVehicle.body_side_name}</span>{/if}
                </div>
              </div>
            {/if}

            {#if !selectedVehicle}
              <button class="btn-inline-create" on:click={() => showCreateVehicle = true}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                Create New Vehicle
              </button>
            {/if}
          {:else}
            <div class="inline-form">
              <h4>New Vehicle</h4>
              {#if vehError}<div class="form-error">{vehError}</div>{/if}
              <div class="form-grid">
                <div class="form-field">
                  <label>Model Name *</label>
                  <input type="text" bind:value={newVehModelName} placeholder="Vehicle model name" />
                </div>
                <div class="form-field">
                  <label>Make</label>
                  <select bind:value={newVehMakeId}>
                    <option value="">Select</option>
                    {#each allMakes as m}<option value={m.id}>{m.name}</option>{/each}
                  </select>
                </div>
                <div class="form-field">
                  <label>Generation</label>
                  <select bind:value={newVehGenId}>
                    <option value="">Select</option>
                    {#each allGenerations as g}<option value={g.id}>{g.name}</option>{/each}
                  </select>
                </div>
                <div class="form-field">
                  <label>Type</label>
                  <select bind:value={newVehGenTypeId}>
                    <option value="">Select</option>
                    {#each allGenTypes as t}<option value={t.id}>{t.name}</option>{/each}
                  </select>
                </div>
                <div class="form-field">
                  <label>Variant</label>
                  <select bind:value={newVehVariantId}>
                    <option value="">Select</option>
                    {#each allVariants as v}<option value={v.id}>{v.name}</option>{/each}
                  </select>
                </div>
                <div class="form-field">
                  <label>Gearbox</label>
                  <select bind:value={newVehGearboxId}>
                    <option value="">Select</option>
                    {#each allGearboxes as g}<option value={g.id}>{g.name}</option>{/each}
                  </select>
                </div>
                <div class="form-field">
                  <label>Fuel Type</label>
                  <select bind:value={newVehFuelTypeId}>
                    <option value="">Select</option>
                    {#each allFuelTypes as f}<option value={f.id}>{f.name}</option>{/each}
                  </select>
                </div>
                <div class="form-field">
                  <label>Body Side</label>
                  <select bind:value={newVehBodySideId}>
                    <option value="">Select</option>
                    {#each allBodySides as b}<option value={b.id}>{b.name}</option>{/each}
                  </select>
                </div>
              </div>
              <div class="form-actions">
                <button class="btn-primary" on:click={saveInlineVehicle} disabled={vehSaving}>{vehSaving ? 'Saving...' : 'Save Vehicle'}</button>
                <button class="btn-ghost" on:click={() => { showCreateVehicle = false; vehError = ''; }}>Cancel</button>
              </div>
            </div>
          {/if}
        </div>

      <!-- ===== STEP 3: PRODUCTS / SERVICES ===== -->
      {:else if step === 3}
        <div class="step-content">
          <h3>Add Products / Services</h3>
          {#if !showCreateProduct}
            <div class="search-box">
              <input type="text" placeholder="Search products / services..." bind:value={productSearch} on:input={handleProductSearch} on:focus={handleProductSearch} />
              {#if showProductDropdown}
                <div class="dropdown">
                  {#each filteredProducts as p}
                    <button class="dd-item" on:click={() => addProduct(p)}>
                      <strong>{p.product_name}</strong>
                      <span class="type-tag" class:service={p.product_type === 'service'} class:consumable={p.product_type === 'consumable'}>{p.product_type}</span>
                      <span class="sub">₹{(p.sales_price || 0).toFixed(2)}</span>
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            <button class="btn-inline-create" on:click={() => showCreateProduct = true}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
              Create New Product / Service
            </button>
          {:else}
            <div class="inline-form">
              <h4>New Product / Service</h4>
              {#if prodError}<div class="form-error">{prodError}</div>{/if}
              <div class="form-grid">
                <div class="form-field">
                  <label>Name *</label>
                  <input type="text" bind:value={newProdName} placeholder="Product or service name" />
                </div>
                <div class="form-field">
                  <label>Type</label>
                  <select bind:value={newProdType}>
                    <option value="product">Product</option>
                    <option value="service">Service</option>
                    <option value="consumable">Consumable</option>
                  </select>
                </div>
                <div class="form-field">
                  <label>Price</label>
                  <input type="number" bind:value={newProdPrice} placeholder="Sales price" step="0.01" />
                </div>
              </div>
              <div class="form-actions">
                <button class="btn-primary" on:click={saveInlineProduct} disabled={prodSaving}>{prodSaving ? 'Saving...' : 'Save'}</button>
                <button class="btn-ghost" on:click={() => { showCreateProduct = false; prodError = ''; }}>Cancel</button>
              </div>
            </div>
          {/if}

          <!-- Items table -->
          {#if items.length > 0}
            <div class="items-table-wrap">
              <table class="items-table">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Name</th>
                    <th class="num">Qty</th>
                    <th class="num">Price</th>
                    <th class="num">Discount</th>
                    <th class="num">Total</th>
                    <th>Notes</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {#each items as it, idx}
                    <tr>
                      <td><span class="type-tag" class:service={it.item_type === 'service'} class:consumable={it.item_type === 'consumable'}>{it.item_type}</span></td>
                      <td>{it.name}</td>
                      <td class="num"><input type="number" class="tbl-input" value={it.qty} on:input={(e) => handleItemQtyChange(idx, e.currentTarget.value)} min="0.001" step="1" /></td>
                      <td class="num"><input type="number" class="tbl-input" value={it.price} on:input={(e) => handleItemPriceChange(idx, e.currentTarget.value)} min="0" step="0.01" /></td>
                      <td class="num"><input type="number" class="tbl-input" value={it.discount} on:input={(e) => handleItemDiscountChange(idx, e.currentTarget.value)} min="0" step="0.01" /></td>
                      <td class="num total-cell">₹{it.total.toFixed(2)}</td>
                      <td><input type="text" class="tbl-input notes-input" bind:value={it.notes} placeholder="Notes" /></td>
                      <td><button class="btn-remove" on:click={() => removeItem(idx)}>×</button></td>
                    </tr>
                  {/each}
                </tbody>
                <tfoot>
                  <tr><td colspan="5" class="num"><strong>Grand Total</strong></td><td class="num total-cell"><strong>₹{grandTotal.toFixed(2)}</strong></td><td colspan="2"></td></tr>
                </tfoot>
              </table>
            </div>
          {:else}
            <div class="empty-items">No items added yet. Search and add at least 1 product or service.</div>
          {/if}
        </div>

      <!-- ===== STEP 4: ASSIGN JOB ===== -->
      {:else if step === 4}
        <div class="step-content">
          <h3>Assign Job</h3>
          <div class="form-grid">
            <div class="form-field">
              <label>Assign To *</label>
              <select bind:value={assignedUserId}>
                <option value="">Select user</option>
                {#each users as u}
                  <option value={u.id}>{u.user_name || u.email}</option>
                {/each}
              </select>
            </div>
            <div class="form-field">
              <label>Priority</label>
              <select bind:value={priority}>
                <option value="Low">Low</option>
                <option value="Normal">Normal</option>
                <option value="High">High</option>
                <option value="Urgent">Urgent</option>
              </select>
            </div>
            <div class="form-field">
              <label>Expected Date *</label>
              <input type="date" bind:value={expectedDate} required />
            </div>
          </div>
          <div class="form-field full-width">
            <label>Description *</label>
            <textarea bind:value={description} rows="3" placeholder="Job description (required)"></textarea>
          </div>
          <div class="form-field full-width">
            <label>Additional Notes</label>
            <textarea bind:value={details} rows="2" placeholder="Additional notes (optional)"></textarea>
          </div>

          <!-- Summary -->
          <div class="summary-box">
            <h4>Summary</h4>
            <div class="summary-row"><span>Customer:</span> <strong>{selectedCustomer?.name || '—'}</strong></div>
            <div class="summary-row"><span>Vehicle:</span> <strong>{selectedVehicle?.model_name || '—'}</strong></div>
            <div class="summary-row"><span>Items:</span> <strong>{items.length}</strong></div>
            <div class="summary-row"><span>Total:</span> <strong>₹{grandTotal.toFixed(2)}</strong></div>
          </div>
        </div>
      {/if}
    </div>

    <!-- ===== FOOTER NAV ===== -->
    <div class="step-footer">
      <button class="btn-ghost" on:click={prevStep} disabled={step === 1}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="15 18 9 12 15 6"/></svg>
        Back
      </button>
      <div class="step-info">Step {step} of 4</div>
      {#if step < 4}
        <button class="btn-primary" on:click={nextStep} disabled={!canNext}>
          Next
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="9 18 15 12 9 6"/></svg>
        </button>
      {:else}
        <button class="btn-primary save-btn" on:click={handleSaveJobCard} disabled={saving || !assignedUserId || !description.trim() || !expectedDate}>
          {#if saving}Saving...{:else}
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>
            Save Job Card
          {/if}
        </button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .jc-window { display: flex; flex-direction: column; height: 100%; background: #fafafa; }
  .perm-denied { display: flex; align-items: center; justify-content: center; height: 100%; color: #991b1b; font-size: 15px; font-weight: 500; }

  /* Step Bar */
  .step-bar { display: flex; align-items: center; justify-content: center; padding: 16px 24px; background: white; border-bottom: 1px solid #e5e7eb; gap: 0; }
  .step-dot { display: flex; flex-direction: column; align-items: center; gap: 4px; background: none; border: none; cursor: pointer; padding: 0; }
  .dot { width: 32px; height: 32px; border-radius: 50%; background: #e5e7eb; color: #6b7280; font-size: 14px; font-weight: 600; display: flex; align-items: center; justify-content: center; transition: all 0.2s; }
  .step-dot.active .dot { background: #C41E3A; color: white; }
  .step-dot.done .dot { background: #16a34a; color: white; }
  .step-label { font-size: 11px; color: #6b7280; white-space: nowrap; }
  .step-dot.active .step-label { color: #C41E3A; font-weight: 600; }
  .step-dot.done .step-label { color: #16a34a; }
  .step-line { flex: 1; height: 2px; background: #e5e7eb; max-width: 60px; margin: 0 4px; margin-bottom: 18px; }
  .step-line.filled { background: #16a34a; }

  /* Step Body */
  .step-body { flex: 1; overflow-y: auto; padding: 20px 24px; }
  .step-content h3 { font-size: 16px; font-weight: 700; color: #111827; margin-bottom: 16px; }

  /* Search box */
  .search-box { position: relative; margin-bottom: 12px; }
  .search-box input { width: 100%; padding: 10px 14px; border: 1px solid #d1d5db; border-radius: 8px; font-size: 14px; outline: none; box-sizing: border-box; }
  .search-box input:focus { border-color: #C41E3A; box-shadow: 0 0 0 3px rgba(196, 30, 58, 0.1); }
  .dropdown { position: absolute; top: 100%; left: 0; right: 0; background: white; border: 1px solid #d1d5db; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); z-index: 50; max-height: 200px; overflow-y: auto; }
  .dd-item { display: flex; align-items: center; gap: 8px; width: 100%; padding: 10px 14px; border: none; background: none; cursor: pointer; font-size: 13px; text-align: left; }
  .dd-item:hover { background: #f3f4f6; }
  .dd-item .sub { color: #6b7280; font-size: 12px; }

  /* Vehicle item in dropdown */
  .dd-item.vehicle-item { flex-direction: column; align-items: flex-start; gap: 6px; padding: 12px 14px; }
  .vehicle-numbers { display: flex; flex-wrap: wrap; gap: 4px; width: 100%; margin-bottom: 4px; }
  .vehicle-number-tag { display: inline-block; padding: 3px 8px; background: #fef3c7; color: #92400e; border-radius: 4px; font-size: 11px; font-weight: 600; border: 1px solid #f59e0b; }
  .vehicle-details { display: flex; flex-wrap: wrap; gap: 6px; width: 100%; }
  .vehicle-details .tag { display: inline-block; padding: 2px 8px; background: #dbeafe; color: #1d4ed8; border-radius: 4px; font-size: 11px; font-weight: 600; }

  /* Selected card with vehicle numbers */
  .vehicle-numbers-selected { margin-top: 8px; padding-top: 8px; border-top: 1px solid #d1f4e3; }
  .vehicle-numbers-selected label { font-size: 11px; font-weight: 700; color: #166534; display: block; margin-bottom: 4px; }
  .vehicle-number-tag-selected { display: inline-block; padding: 4px 10px; background: #fef3c7; color: #92400e; border-radius: 4px; font-size: 12px; font-weight: 600; border: 1px solid #f59e0b; margin-right: 6px; }

  /* Selected card */
  .selected-card { background: #ecfdf5; border: 1px solid #86efac; border-radius: 10px; padding: 12px 14px; margin-bottom: 12px; display: flex; flex-direction: column; gap: 8px; }
  .card-main { display: flex; align-items: center; justify-content: space-between; font-weight: 600; color: #166534; }
  .card-details { display: flex; flex-wrap: wrap; gap: 6px; }
  .detail-tag { display: inline-block; padding: 3px 10px; background: #86efac; color: #166534; border-radius: 6px; font-size: 12px; font-weight: 600; }
  .chip-clear { background: none; border: none; color: #dc2626; cursor: pointer; font-size: 18px; font-weight: 700; padding: 0 4px; }

  /* Inline create button */
  .btn-inline-create { display: inline-flex; align-items: center; gap: 6px; padding: 8px 16px; background: white; border: 1px dashed #C41E3A; border-radius: 8px; color: #C41E3A; font-size: 13px; font-weight: 600; cursor: pointer; transition: background 0.15s; }
  .btn-inline-create:hover { background: #fef2f2; }

  /* Inline form */
  .inline-form { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 16px; margin-bottom: 12px; }
  .inline-form h4 { font-size: 14px; font-weight: 700; margin-bottom: 12px; color: #111827; }
  .form-error { background: #fef2f2; color: #dc2626; padding: 8px 12px; border-radius: 6px; font-size: 13px; margin-bottom: 10px; }
  .form-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px; margin-bottom: 12px; }
  .form-field { display: flex; flex-direction: column; gap: 4px; }
  .form-field.full-width { grid-column: 1 / -1; margin-bottom: 12px; }
  .form-field label { font-size: 12px; font-weight: 600; color: #374151; }
  .form-field input, .form-field select, .form-field textarea { padding: 8px 10px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 13px; outline: none; box-sizing: border-box; }
  .form-field input:focus, .form-field select:focus, .form-field textarea:focus { border-color: #C41E3A; box-shadow: 0 0 0 3px rgba(196, 30, 58, 0.1); }
  .form-field textarea { resize: vertical; font-family: inherit; }
  .phone-row { display: flex; gap: 6px; margin-bottom: 4px; }
  .phone-row input { flex: 1; }
  .btn-remove-sm { background: none; border: none; color: #dc2626; font-size: 18px; font-weight: 700; cursor: pointer; padding: 0 6px; }
  .btn-add-sm { background: none; border: none; color: #C41E3A; font-size: 12px; font-weight: 600; cursor: pointer; padding: 4px 0; }
  .form-actions { display: flex; gap: 8px; margin-top: 8px; }

  /* Items table */
  .items-table-wrap { margin-top: 16px; overflow-x: auto; }
  .items-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .items-table th { background: #f9fafb; padding: 8px 10px; text-align: left; font-weight: 600; color: #374151; border-bottom: 2px solid #e5e7eb; white-space: nowrap; }
  .items-table td { padding: 6px 10px; border-bottom: 1px solid #f3f4f6; vertical-align: middle; }
  .items-table .num { text-align: right; }
  .items-table tfoot td { border-top: 2px solid #e5e7eb; background: #f9fafb; padding: 8px 10px; }
  .tbl-input { width: 70px; padding: 4px 6px; border: 1px solid #d1d5db; border-radius: 4px; font-size: 13px; text-align: right; }
  .tbl-input:focus { border-color: #C41E3A; outline: none; }
  .notes-input { width: 100px; text-align: left; }
  .total-cell { font-weight: 600; color: #111827; }
  .btn-remove { background: none; border: none; color: #dc2626; font-size: 18px; font-weight: 700; cursor: pointer; }
  .empty-items { text-align: center; color: #9ca3af; padding: 24px; font-size: 14px; }

  /* Type tags */
  .type-tag { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; background: #dbeafe; color: #1d4ed8; text-transform: capitalize; }
  .type-tag.service { background: #f3e8ff; color: #7c3aed; }
  .type-tag.consumable { background: #dcfce7; color: #16a34a; }

  /* Summary box */
  .summary-box { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 16px; margin-top: 16px; }
  .summary-box h4 { font-size: 14px; font-weight: 700; margin-bottom: 10px; }
  .summary-row { display: flex; justify-content: space-between; padding: 4px 0; font-size: 13px; border-bottom: 1px solid #f3f4f6; }
  .summary-row:last-child { border-bottom: none; }

  /* Footer */
  .step-footer { display: flex; align-items: center; justify-content: space-between; padding: 12px 24px; background: white; border-top: 1px solid #e5e7eb; flex-shrink: 0; }
  .step-info { font-size: 12px; color: #6b7280; }

  /* Buttons */
  .btn-primary { display: inline-flex; align-items: center; gap: 6px; padding: 8px 20px; background: #C41E3A; color: white; border: none; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; transition: background 0.15s; }
  .btn-primary:hover:not(:disabled) { background: #a71830; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-secondary { padding: 8px 20px; background: #f3f4f6; color: #374151; border: 1px solid #d1d5db; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; }
  .btn-secondary:hover { background: #e5e7eb; }
  .btn-ghost { display: inline-flex; align-items: center; gap: 4px; padding: 8px 16px; background: none; border: none; color: #6b7280; font-size: 13px; font-weight: 500; cursor: pointer; }
  .btn-ghost:hover { color: #111827; }
  .btn-ghost:disabled { opacity: 0.4; cursor: not-allowed; }

  /* Messages */
  .msg { padding: 10px 16px; border-radius: 8px; font-size: 13px; margin: 8px 24px 0; }
  .msg-error { background: #fef2f2; color: #dc2626; border: 1px solid #fca5a5; }

  /* Success screen */
  .success-screen { flex: 1; display: flex; align-items: center; justify-content: center; }
  .success-card { text-align: center; background: white; padding: 40px; border-radius: 16px; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
  .success-card h2 { margin: 12px 0 4px; font-size: 22px; color: #111827; }
  .jc-no { font-size: 28px; font-weight: 800; color: #C41E3A; margin-bottom: 20px; font-family: monospace; }
  .success-actions { display: flex; gap: 10px; justify-content: center; }

  /* Selected Customer Chip */
  .selected-chip {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    background: linear-gradient(135deg, #f0fdf4 0%, #ecfdf5 100%);
    border: 2px solid #86efac;
    border-radius: 10px;
    margin-bottom: 16px;
    font-weight: 600;
    color: #166534;
  }
  .selected-chip span { display: flex; align-items: center; gap: 4px; }
  .selected-chip .sub { color: #059669; font-size: 13px; font-weight: 500; }
  .selected-chip .chip-clear { font-size: 24px; color: #dc2626; background: none; border: none; cursor: pointer; padding: 0 8px; transition: transform 0.2s; }
  .selected-chip .chip-clear:hover { transform: scale(1.2); }

  /* Vehicle Numbers Section */
  .vehicle-numbers-section {
    padding: 16px;
    background: #f8fafc;
    border: 1.5px solid #cbd5e1;
    border-radius: 10px;
    margin-bottom: 16px;
  }
  .vehicle-numbers-section label {
    display: block;
    font-size: 13px;
    font-weight: 700;
    color: #334155;
    margin-bottom: 12px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .vehicle-numbers-list {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 12px;
  }
  .vehicle-number-btn {
    padding: 8px 14px;
    background: white;
    border: 2px solid #cbd5e1;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 600;
    color: #475569;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .vehicle-number-btn:hover {
    background: #f1f5f9;
    border-color: #94a3b8;
  }
  .vehicle-number-btn.selected {
    background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
    border-color: #f59e0b;
    color: #92400e;
    box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.1);
  }
  .selected-vn {
    padding: 10px 12px;
    background: #fef3c7;
    border: 1px solid #f59e0b;
    border-radius: 6px;
    font-size: 12px;
    color: #92400e;
    font-weight: 600;
  }
  .selected-vn strong {
    color: #c2410c;
    font-weight: 700;
  }

  /* Note info message */
  .note-info {
    padding: 12px 14px;
    background: #f0fdf4;
    border: 1px solid #86efac;
    border-radius: 6px;
    font-size: 13px;
    color: #166534;
    font-weight: 500;
  }
</style>
