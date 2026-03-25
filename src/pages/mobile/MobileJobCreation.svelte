<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '../../lib/supabaseClient';
  import { authStore } from '../../stores/authStore';
  import { setMobilePage } from '../../stores/mobilePageStore';
  import { canUserCreateResource } from '../../lib/services/permissionService';
  import { printJobCard } from '../../utils/jobCardPrint';
  import SearchableDropdown from '../../components/shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../components/shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../components/shared/EditMasterDataPopup.svelte';

  let currentStep = 1;
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
  let newCustVehicleNumbers: string[] = [''];
  let custSaving = false;
  let custError = '';
  let selectedVehicleNumber: string | null = null;

  // ---- Step 2: Vehicle ----
  let vehicleSearch = '';
  let vehicles: any[] = [];
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

  // ---- Vehicle Master Data Popups ----
  let addPopupOpen = false;
  let addPopupTable = '';
  let addPopupTitle = '';
  let editPopupOpen = false;
  let editPopupTable = '';
  let editPopupTitle = '';
  let editPopupItemId = '';
  let editPopupItemName = '';

  // ---- Step 3: Products/Services ----
  let productSearch = '';
  let allProducts: any[] = [];
  let filteredProducts: any[] = [];
  let showProductDropdown = false;
  let showCreateProduct = false;
  let newProdName = '';
  let newProdType: 'product' | 'service' | 'consumable' = 'product';
  let newProdApplicability = '';
  let newProdVehicleId = '';
  let newProdPartNumber = '';
  let newProdBarcode = '';
  let newProdExpiryDate = '';
  let newProdBrandId = '';
  let newProdUnitId = '';
  let newProdUnitQty = '';
  let newProdCurrentCost = '';
  let newProdPrice = '';
  let newProdD1 = '';
  let newProdD2 = '';
  let newProdD3 = '';
  let newProdOpeningStock = '';
  let newProdMinStock = '';
  let newProdMaxStock = '';
  let newProdReorderLevel = '';
  let allUnits: any[] = [];
  let allBrands: any[] = [];
  
  // Service-specific fields
  let newProdLaborCharge = '';
  let newProdAdditionalCharges = '';
  interface ServiceComponent {
    component_product_id: string;
    product_name: string;
    qty: number;
    cost: number;
  }
  let newProdServiceComponents: ServiceComponent[] = [];
  let consumableProducts: any[] = [];
  let componentSearch = '';
  let filteredComponents: any[] = [];
  let showComponentDropdown = false;
  
  let prodSaving = false;
  let prodError = '';
  
  $: newProdComponentsCost = newProdServiceComponents.reduce((sum, c) => sum + (c.qty * c.cost), 0);
  $: newProdServiceTotalCost = newProdComponentsCost + (parseFloat(newProdLaborCharge) || 0) + (parseFloat(newProdAdditionalCharges) || 0);

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

  // ---- Step 4: Assign & Finalize ----
  let users: any[] = [];
  let assignedUserId = '';
  let description = '';
  let details = '';
  let expectedDate = '';
  let priority = 'Normal';

  // ---- Photo Upload ----
  interface UploadedImage {
    id: string;
    file: File;
    preview: string;
    uploading: boolean;
  }
  let uploadedImages: UploadedImage[] = [];
  let savedImages: any[] = [];
  let cameraInput: HTMLInputElement | undefined;
  let galleryInput: HTMLInputElement | undefined;
  let showCameraPreview = false;
  let cameraStream: MediaStream | null = null;
  let videoElement: HTMLVideoElement | undefined;
  let canvasElement: HTMLCanvasElement | undefined;
  let isMobile = false;

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let savedJobCardNo = '';
  let showSuccess = false;

  onMount(async () => {
    const userId = $authStore.user?.id;
    if (userId) {
      const allowed = await canUserCreateResource(userId, 'finance-job-card');
      if (!allowed) {
        permDenied = true;
        return;
      }
    }

    isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);

    await Promise.all([
      loadCustomers(),
      loadVehicles(),
      loadProducts(),
      loadUsers(),
      loadVehicleMasterData(),
      loadUnits(),
      loadBrands(),
      loadConsumableProducts(),
    ]);
  });

  onDestroy(() => {
    stopCamera();
  });

  // ---- Mobile & Camera Detection ----
  function detectMobile(): boolean {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }

  async function openCamera() {
    if (detectMobile()) {
      if (cameraInput) {
        cameraInput.value = '';
        cameraInput.click();
      }
    } else {
      await startDesktopCamera();
    }
  }

  async function startDesktopCamera() {
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        alert('Your browser does not support camera access.');
        return;
      }

      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false
      });

      cameraStream = stream;
      showCameraPreview = true;

      await new Promise(resolve => setTimeout(resolve, 100));

      if (videoElement) {
        videoElement.srcObject = stream;
        videoElement.play().catch(err => console.error('Play error:', err));
      }
    } catch (err: any) {
      alert('Error accessing camera: ' + err.message);
    }
  }

  function capturePhoto() {
    if (!canvasElement || !videoElement) return;

    const ctx = canvasElement.getContext('2d');
    if (!ctx) return;

    canvasElement.width = videoElement.videoWidth;
    canvasElement.height = videoElement.videoHeight;
    ctx.drawImage(videoElement, 0, 0);

    // Stop camera immediately after capture (synchronous)
    stopCamera();

    // Process image asynchronously
    canvasElement.toBlob((blob) => {
      if (!blob) return;

      const file = new File([blob], `photo-${Date.now()}.jpg`, { type: 'image/jpeg' });

      const reader = new FileReader();
      reader.onload = (evt) => {
        uploadedImages = [...uploadedImages, {
          id: Math.random().toString(36),
          file,
          preview: evt.target?.result as string,
          uploading: false
        }];
      };
      reader.readAsDataURL(blob);
    }, 'image/jpeg', 0.95);
  }

  function stopCamera() {
    if (cameraStream) {
      cameraStream.getTracks().forEach(track => track.stop());
      cameraStream = null;
    }
    if (videoElement) {
      videoElement.srcObject = null;
      videoElement.pause();
    }
    showCameraPreview = false;
  }

  function openGallery() {
    if (galleryInput) {
      galleryInput.value = '';
      galleryInput.click();
    }
  }

  function handleImageSelect(e: any) {
    const files = Array.from(e.target.files || []) as File[];
    for (const file of files) {
      if (!file.type.startsWith('image/')) {
        alert('Please select image files only');
        continue;
      }
      if (file.size > 5 * 1024 * 1024) {
        alert(`${file.name} is too large (max 5MB)`);
        continue;
      }
      const reader = new FileReader();
      reader.onload = (evt) => {
        uploadedImages = [...uploadedImages, {
          id: Math.random().toString(36),
          file,
          preview: evt.target?.result as string,
          uploading: false
        }];
      };
      reader.readAsDataURL(file);
    }
    e.target.value = '';
  }

  function removeUploadedImage(id: string) {
    uploadedImages = uploadedImages.filter(img => img.id !== id);
  }

  // ---- Data Loaders ----
  async function loadCustomers() {
    const { data, error } = await supabase
      .from('customers')
      .select('id, name, place, gender, ledger_id, customer_vehicle_numbers(vehicle_number), customer_phones(phone)')
      .order('name', { ascending: true });

    if (!error && data) {
      customers = data;
    } else if (error) {
      console.error('Error loading customers:', error);
    }
  }

  async function loadVehicles() {
    const { data, error } = await supabase
      .from('vehicles')
      .select('id, model_name, makes(name), generations(name), generation_types(name), variants(name), gearboxes(name), fuel_types(name), body_sides(name)')
      .order('model_name', { ascending: true });

    if (!error && data) {
      vehicles = data;
    }
  }

  async function loadProducts() {
    const { data, error } = await supabase
      .from('products')
      .select('id, product_name, product_type, sales_price, units(name)')
      .order('product_name', { ascending: true });

    if (!error && data) {
      allProducts = data;
    }
  }

  async function loadUsers() {
    const { data, error } = await supabase
      .from('users')
      .select('id, email, user_name, phone_number, role')
      .order('user_name', { ascending: true });

    if (!error && data) {
      users = data;
    }
  }

  async function loadVehicleMasterData() {
    const promises = [
      supabase.from('makes').select('id, name'),
      supabase.from('generations').select('id, name'),
      supabase.from('generation_types').select('id, name'),
      supabase.from('variants').select('id, name'),
      supabase.from('gearboxes').select('id, name'),
      supabase.from('fuel_types').select('id, name'),
      supabase.from('body_sides').select('id, name'),
    ];

    const results = await Promise.all(promises);
    if (results[0].data) allMakes = [...results[0].data];
    if (results[1].data) allGenerations = [...results[1].data];
    if (results[2].data) allGenTypes = [...results[2].data];
    if (results[3].data) allVariants = [...results[3].data];
    if (results[4].data) allGearboxes = [...results[4].data];
    if (results[5].data) allFuelTypes = [...results[5].data];
    if (results[6].data) allBodySides = [...results[6].data];
  }

  // ---- Vehicle Master Data Handlers ----
  function handleAddMake() {
    addPopupTable = 'makes';
    addPopupTitle = 'Add Make';
    addPopupOpen = true;
  }

  function handleEditMake(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'makes';
    editPopupTitle = 'Edit Make';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleAddGeneration() {
    addPopupTable = 'generations';
    addPopupTitle = 'Add Generation';
    addPopupOpen = true;
  }

  function handleEditGeneration(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'generations';
    editPopupTitle = 'Edit Generation';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleAddType() {
    addPopupTable = 'generation_types';
    addPopupTitle = 'Add Type';
    addPopupOpen = true;
  }

  function handleEditType(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'generation_types';
    editPopupTitle = 'Edit Type';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleAddVariant() {
    addPopupTable = 'variants';
    addPopupTitle = 'Add Variant';
    addPopupOpen = true;
  }

  function handleEditVariant(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'variants';
    editPopupTitle = 'Edit Variant';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleAddGearbox() {
    addPopupTable = 'gearboxes';
    addPopupTitle = 'Add Gearbox';
    addPopupOpen = true;
  }

  function handleEditGearbox(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'gearboxes';
    editPopupTitle = 'Edit Gearbox';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleAddFuelType() {
    addPopupTable = 'fuel_types';
    addPopupTitle = 'Add Fuel Type';
    addPopupOpen = true;
  }

  function handleEditFuelType(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'fuel_types';
    editPopupTitle = 'Edit Fuel Type';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleAddBodySide() {
    addPopupTable = 'body_sides';
    addPopupTitle = 'Add Body Side';
    addPopupOpen = true;
  }

  function handleEditBodySide(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'body_sides';
    editPopupTitle = 'Edit Body Side';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  // Generic handlers for popup completion
  async function handleMasterCreated(e: CustomEvent) {
    addPopupOpen = false;
    const createdItem = e.detail;
    try {
      console.log(`New ${addPopupTable} created, reloading...`);
      await loadVehicleMasterData();
      console.log('Vehicle master data reloaded successfully');
      
      // Auto-select the newly created item
      if (createdItem && createdItem.id) {
        if (addPopupTable === 'makes') newVehMakeId = createdItem.id;
        else if (addPopupTable === 'generations') newVehGenId = createdItem.id;
        else if (addPopupTable === 'generation_types') newVehGenTypeId = createdItem.id;
        else if (addPopupTable === 'variants') newVehVariantId = createdItem.id;
        else if (addPopupTable === 'gearboxes') newVehGearboxId = createdItem.id;
        else if (addPopupTable === 'fuel_types') newVehFuelTypeId = createdItem.id;
        else if (addPopupTable === 'body_sides') newVehBodySideId = createdItem.id;
      }
    } catch (err) {
      console.error('Error reloading master data:', err);
    }
  }

  async function handleMasterUpdated() {
    editPopupOpen = false;
    try {
      console.log(`${editPopupTable} updated, reloading...`);
      await loadVehicleMasterData();
      console.log('Vehicle master data reloaded successfully');
    } catch (err) {
      console.error('Error reloading master data:', err);
    }
  }

  async function loadUnits() {
    const { data, error } = await supabase.from('units').select('id, name').order('name');
    if (!error && data) {
      allUnits = data;
    }
  }

  async function loadBrands() {
    const { data, error } = await supabase.from('brands').select('id, name').order('name');
    if (!error && data) {
      allBrands = data;
    }
  }

  async function loadConsumableProducts() {
    const { data, error } = await supabase
      .from('products')
      .select('id, product_name, current_cost, unit_qty')
      .in('product_type', ['consumable', 'product'])
      .order('product_name');
    if (!error && data) {
      consumableProducts = (data || []).map((p: any) => ({
        ...p,
        unit_qty: p.unit_qty || 1,
      }));
    }
  }

  function searchServiceComponents() {
    const q = componentSearch.toLowerCase().trim();
    if (!q) {
      filteredComponents = [];
      showComponentDropdown = false;
      return;
    }
    filteredComponents = consumableProducts.filter(p =>
      p.product_name.toLowerCase().includes(q) &&
      !newProdServiceComponents.some(c => c.component_product_id === p.id)
    ).slice(0, 10);
    showComponentDropdown = filteredComponents.length > 0;
  }

  function addServiceComponent(p: any) {
    const perPieceCost = (p.current_cost || 0) / (p.unit_qty || 1);
    newProdServiceComponents = [...newProdServiceComponents, {
      component_product_id: p.id,
      product_name: p.product_name,
      qty: 1,
      cost: perPieceCost,
    }];
    componentSearch = '';
    showComponentDropdown = false;
  }

  function removeServiceComponent(idx: number) {
    newProdServiceComponents = newProdServiceComponents.filter((_, i) => i !== idx);
  }

  function updateServiceComponentQty(idx: number, val: string) {
    newProdServiceComponents[idx].qty = parseFloat(val) || 1;
    newProdServiceComponents = [...newProdServiceComponents];
  }

  async function loadCustomerVehicles(customerId: string) {
    const { data, error } = await supabase
      .from('customer_vehicle_numbers')
      .select('vehicle_number')
      .eq('customer_id', customerId);

    if (error) {
      console.error('Error loading vehicle numbers:', error);
      customerVehicleNumbers = [];
      return;
    }

    if (data) {
      customerVehicleNumbers = data;
      console.log('Loaded vehicle numbers:', data);
    } else {
      customerVehicleNumbers = [];
    }
  }

  // ---- Customer Management ----
  function handleCustomerSearch() {
    filteredCustomers = customers.filter(c =>
      c.name.toLowerCase().includes(customerSearch.toLowerCase()) ||
      c.place.toLowerCase().includes(customerSearch.toLowerCase())
    );
  }

  async function selectCustomer(c: any) {
    selectedCustomer = c;
    // Use vehicle numbers directly from the customer object that was already loaded with relationships
    if (c.customer_vehicle_numbers && Array.isArray(c.customer_vehicle_numbers)) {
      customerVehicleNumbers = c.customer_vehicle_numbers;
    } else {
      // Fallback: load them if for some reason they weren't included
      await loadCustomerVehicles(c.id);
    }
    if (customerVehicleNumbers.length === 1) {
      selectedVehicleNumber = customerVehicleNumbers[0].vehicle_number;
    } else {
      selectedVehicleNumber = null;
    }
    showCustomerDropdown = false;
    customerSearch = '';
  }

  async function saveInlineCustomer() {
    if (!newCustName.trim()) {
      custError = 'Customer name is required';
      return;
    }
    custSaving = true;
    custError = '';

    // Get ledger_type_id for 'Receivables'
    const { data: ledgerType, error: typeErr } = await supabase
      .from('ledger_types')
      .select('id')
      .eq('name', 'Receivables')
      .single();

    if (typeErr || !ledgerType) {
      custError = 'Failed to find Receivables ledger type';
      custSaving = false;
      return;
    }

    // Create ledger entry
    const { data: ledger, error: ledgerErr } = await supabase
      .from('ledger')
      .insert({
        ledger_name: newCustName.trim(),
        ledger_type_id: ledgerType.id,
        reference_type: 'customer',
        created_by: $authStore.user?.id || null,
      })
      .select('id')
      .single();

    if (ledgerErr || !ledger) {
      custError = 'Failed to create ledger: ' + (ledgerErr?.message || '');
      custSaving = false;
      return;
    }

    // Create customer
    const { data: cust, error: custErr } = await supabase
      .from('customers')
      .insert({
        name: newCustName.trim(),
        place: newCustPlace.trim() || null,
        gender: newCustGender || null,
        ledger_id: ledger.id,
        created_by: $authStore.user?.id || null,
      })
      .select('id, name, place, gender, ledger_id')
      .single();

    if (custErr || !cust) {
      custError = 'Failed to create customer: ' + (custErr?.message || '');
      custSaving = false;
      return;
    }

    // Add phones
    const phoneRows = newCustPhones
      .filter(p => p.trim())
      .map(p => ({
        customer_id: cust.id,
        phone: p.trim(),
      }));

    if (phoneRows.length > 0) {
      const { error: phoneErr } = await supabase.from('customer_phones').insert(phoneRows);
      if (phoneErr) {
        custError = 'Warning: Failed to save phone numbers: ' + (phoneErr?.message || '');
        console.error('Phone insert error:', phoneErr);
      }
    }

    // Add vehicle numbers
    const vehicleRows = newCustVehicleNumbers
      .filter(v => v.trim())
      .map(v => ({
        customer_id: cust.id,
        vehicle_number: v.trim(),
      }));

    if (vehicleRows.length > 0) {
      const { error: vehicleErr } = await supabase.from('customer_vehicle_numbers').insert(vehicleRows);
      if (vehicleErr) {
        custError = 'Warning: Failed to save vehicle numbers: ' + (vehicleErr?.message || '');
        console.error('Vehicle insert error:', vehicleErr);
      }
    }

    await loadCustomers();
    // Find the newly created customer in the list and set it as selected (will have related data loaded)
    const newCust = customers.find(c => c.id === cust.id);
    if (newCust) {
      await selectCustomer(newCust);
    } else {
      // Manual fallback if not found in list for some reason
      const fallbackCustomer = { ...cust, customer_vehicle_numbers: vehicleRows };
      await selectCustomer(fallbackCustomer);
    }
    
    showCreateCustomer = false;
    newCustName = '';
    newCustPlace = '';
    newCustGender = '';
    newCustPhones = [''];
    newCustVehicleNumbers = [''];
    custSaving = false;
  }

  function addNewCustPhone() {
    newCustPhones = [...newCustPhones, ''];
  }
  function removeNewCustPhone(idx: number) {
    newCustPhones = newCustPhones.filter((_, i) => i !== idx);
  }

  function addNewCustVehicleNumber() {
    newCustVehicleNumbers = [...newCustVehicleNumbers, ''];
  }
  function removeNewCustVehicleNumber(idx: number) {
    newCustVehicleNumbers = newCustVehicleNumbers.filter((_, i) => i !== idx);
  }

  // ---- Vehicle Management ----
  function handleVehicleSearch() {
    filteredVehicles = vehicles.filter(v =>
      v.model_name.toLowerCase().includes(vehicleSearch.toLowerCase())
    );
  }

  function selectVehicle(v: any) {
    selectedVehicle = v;
    showVehicleDropdown = false;
    vehicleSearch = '';
  }

  async function saveInlineVehicle() {
    if (!newVehModelName.trim()) {
      vehError = 'Vehicle model name is required';
      return;
    }
    vehSaving = true;
    vehError = '';

    const { data: veh, error: vehErr } = await supabase
      .from('vehicles')
      .insert({
        model_name: newVehModelName.trim(),
        make_id: newVehMakeId || null,
        generation_id: newVehGenId || null,
        generation_type_id: newVehGenTypeId || null,
        variant_id: newVehVariantId || null,
        gearbox_id: newVehGearboxId || null,
        fuel_type_id: newVehFuelTypeId || null,
        body_side_id: newVehBodySideId || null,
        created_by: $authStore.user?.id || null,
      })
      .select('id, model_name, makes(name), generations(name), generation_types(name), variants(name), gearboxes(name), fuel_types(name), body_sides(name)')
      .single();

    if (vehErr || !veh) {
      vehError = 'Failed to create vehicle: ' + (vehErr?.message || '');
      vehSaving = false;
      return;
    }

    vehicles = [...vehicles, veh];
    selectedVehicle = veh;
    showCreateVehicle = false;
    newVehModelName = '';
    newVehMakeId = '';
    newVehGenId = '';
    newVehGenTypeId = '';
    newVehVariantId = '';
    newVehGearboxId = '';
    newVehFuelTypeId = '';
    newVehBodySideId = '';
    vehSaving = false;
  }

  // ---- Product/Service Management ----
  function handleProductSearch() {
    filteredProducts = allProducts.filter(p =>
      p.product_name.toLowerCase().includes(productSearch.toLowerCase())
    );
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
    if (!newProdName.trim()) {
      prodError = 'Product name is required';
      return;
    }
    if (!newProdType) {
      prodError = 'Product type is required';
      return;
    }
    prodSaving = true;
    prodError = '';

    const isService = newProdType === 'service';

    try {
      const { data, error } = await supabase.rpc('create_product', {
        p_product_name: newProdName.trim(),
        p_product_type: newProdType,
        p_applicability: newProdType === 'product' ? newProdApplicability || null : null,
        p_vehicle_id: newProdType === 'product' && newProdApplicability === 'specific' && newProdVehicleId ? newProdVehicleId : null,
        p_unit_id: isService ? null : (newProdUnitId || null),
        p_unit_qty: isService ? null : (newProdUnitQty ? parseFloat(newProdUnitQty) : null),
        p_current_cost: isService ? newProdServiceTotalCost : (newProdCurrentCost ? parseFloat(newProdCurrentCost) : null),
        p_sales_price: newProdPrice ? parseFloat(newProdPrice) : null,
        p_first_level_discount: newProdD1 ? parseFloat(newProdD1) : null,
        p_second_level_discount: newProdD2 ? parseFloat(newProdD2) : null,
        p_third_level_discount: newProdD3 ? parseFloat(newProdD3) : null,
        p_barcode: isService ? null : (newProdBarcode.trim() || null),
        p_part_number: isService ? null : (newProdPartNumber.trim() || null),
        p_brand_id: isService ? null : (newProdBrandId || null),
        p_expiry_date: isService ? null : (newProdExpiryDate || null),
        p_file_path: null,
        p_created_by: $authStore.user?.id || null,
        p_current_stock: isService ? 0 : (newProdOpeningStock ? parseFloat(newProdOpeningStock) : 0),
        p_minimum_stock: isService ? 0 : (newProdMinStock ? parseFloat(newProdMinStock) : 0),
        p_maximum_stock: isService ? 0 : (newProdMaxStock ? parseFloat(newProdMaxStock) : 0),
        p_reorder_level: isService ? 0 : (newProdReorderLevel ? parseFloat(newProdReorderLevel) : 0),
        p_labor_charge: isService ? (parseFloat(newProdLaborCharge) || 0) : 0,
        p_additional_charges: isService ? (parseFloat(newProdAdditionalCharges) || 0) : 0,
      });

      if (error) {
        prodError = 'Failed to create product: ' + error.message;
        prodSaving = false;
        return;
      }

      // Save service components if service type
      if (isService && data?.id && newProdServiceComponents.length > 0) {
        const comps = newProdServiceComponents.map(c => ({
          product_id: data.id,
          component_product_id: c.component_product_id,
          qty: c.qty,
          created_by: $authStore.user?.id || null,
        }));
        const { error: compErr } = await supabase.from('product_components').insert(comps);
        if (compErr) {
          prodError = 'Product saved but failed to save components: ' + compErr.message;
          prodSaving = false;
          return;
        }
      }

      await loadProducts();
      addProduct({ ...data, unit_name: '' });
      showCreateProduct = false;
      
      // Reset all fields
      newProdName = '';
      newProdType = 'product';
      newProdApplicability = '';
      newProdVehicleId = '';
      newProdPartNumber = '';
      newProdBarcode = '';
      newProdExpiryDate = '';
      newProdBrandId = '';
      newProdUnitId = '';
      newProdUnitQty = '';
      newProdCurrentCost = '';
      newProdPrice = '';
      newProdD1 = '';
      newProdD2 = '';
      newProdD3 = '';
      newProdOpeningStock = '';
      newProdMinStock = '';
      newProdMaxStock = '';
      newProdReorderLevel = '';
      newProdLaborCharge = '';
      newProdAdditionalCharges = '';
      newProdServiceComponents = [];
      componentSearch = '';
      filteredComponents = [];
      showComponentDropdown = false;
      prodSaving = false;
    } catch (err: any) {
      prodError = err.message || 'Failed to create product';
      prodSaving = false;
    }
  }

  // ---- Photo Upload ----
  async function uploadImagesToStorage(jobCardId: string) {
    // Upload all images in parallel for better performance
    const uploadPromises = uploadedImages.map(async (imgObj) => {
      imgObj.uploading = true;
      try {
        const fileName = `${jobCardId}/${Date.now()}-${imgObj.file.name}`;
        const { error: uploadErr } = await supabase.storage
          .from('job-card-photos')
          .upload(fileName, imgObj.file, { upsert: false });

        if (uploadErr) {
          console.error('Upload error:', uploadErr);
          imgObj.uploading = false;
          return null;
        }

        const { data: publicUrlData } = supabase.storage
          .from('job-card-photos')
          .getPublicUrl(fileName);

        const { error: dbErr } = await supabase.from('job_card_photos').insert({
          job_card_id: jobCardId,
          file_url: publicUrlData.publicUrl,
          file_name: imgObj.file.name,
          uploaded_by: $authStore.user?.id || null,
          created_by: $authStore.user?.id || null,
        });

        if (dbErr) {
          console.error('DB error:', dbErr);
          imgObj.uploading = false;
          return null;
        }

        imgObj.uploading = false;
        return {
          id: imgObj.id,
          file_url: publicUrlData.publicUrl,
          file_name: imgObj.file.name
        };
      } catch (err) {
        console.error('Upload exception:', err);
        imgObj.uploading = false;
        return null;
      }
    });

    const results = await Promise.all(uploadPromises);
    const successful = results.filter(r => r !== null);
    savedImages = [...savedImages, ...successful];
    uploadedImages = [];
    return savedImages.length;
  }

  // ---- Navigation ----
  $: canNext = currentStep === 1 ? (!!selectedCustomer && !!selectedVehicleNumber)
             : currentStep === 2 ? !!selectedVehicle
             : currentStep === 3 ? items.length > 0
             : false;

  function nextStep() {
    if (canNext && currentStep < 4) currentStep++;
  }

  function prevStep() {
    if (currentStep > 1) currentStep--;
  }

  // ---- Save Job Card ----
  async function handleSaveJobCard() {
    if (!selectedCustomer) { saveError = 'Customer is required'; return; }
    if (!selectedVehicleNumber) { saveError = 'Vehicle number is required'; return; }
    if (!selectedVehicle) { saveError = 'Vehicle is required'; return; }
    if (items.length === 0) { saveError = 'At least one item is required'; return; }
    if (!assignedUserId) { saveError = 'Assigned user is required'; return; }
    if (!description.trim()) { saveError = 'Body Inspection is required'; return; }
    if (!expectedDate) { saveError = 'Expected date is required'; return; }

    saving = true;
    saveError = '';

    // Generate job card number
    const now = new Date();
    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const year = String(now.getFullYear());
    const datePrefix = `${day}${month}${year}`;

    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

    const { data: todayCards, error: queryErr } = await supabase
      .from('job_cards')
      .select('id', { count: 'exact' })
      .gte('created_at', startOfDay.toISOString())
      .lt('created_at', endOfDay.toISOString());

    const sequenceNumber = (todayCards?.length || 0) + 1;
    const jobCardNo = `${datePrefix}${sequenceNumber}`;

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

    await supabase.from('job_card_logs').insert({
      job_card_id: jc.id,
      action: 'Created',
      from_status: null,
      to_status: 'Open',
      note: 'Job card created',
      action_by: $authStore.user?.id || null,
      created_by: $authStore.user?.id || null,
    });

    if (uploadedImages.length > 0) {
      await uploadImagesToStorage(jc.id);
    }

    saving = false;
    savedJobCardNo = jc.job_card_no;
    showSuccess = true;
  }

  function handleNewJobCard() {
    stopCamera();
    currentStep = 1;
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
    uploadedImages = [];
    savedImages = [];
    saveError = '';
    savedJobCardNo = '';
    showSuccess = false;
  }

  // ---- Print ----
  async function handlePrint() {
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
      console.log('Logo loading failed');
    }

    // Prepare data for print utility
    const printData = {
      jobCardNumber: savedJobCardNo,
      createdByUser: $authStore.user?.user_name || 'N/A',
      customerName: selectedCustomer?.name || '',
      vehicleInfo: `${selectedVehicleNumber} - ${selectedVehicle?.model_name || ''}`,
      totalAmount: grandTotal,
      items: items,
      description: description,
      details: details,
      assignedToUser: users.find((u: any) => u.id === assignedUserId)?.user_name || 'N/A',
      priority: priority,
      expectedDate: expectedDate,
      savedImages: savedImages,
      logoBase64: logoBase64 || null
    };

    printJobCard(printData);
  }

  function goBack() {
    stopCamera();
    setMobilePage('my-jobs', 'My Jobs');
  }
</script>

{#if permDenied}
  <div class="permission-denied">
    <p>You don't have permission to create job cards.</p>
  </div>
{:else if showSuccess}
  <div class="success-screen">
    <div class="success-card">
      <div class="success-icon">✓</div>
      <div class="success-title">Job Card Created!</div>
      <div class="success-number">Job #: {savedJobCardNo}</div>
      <div class="success-buttons">
        <button class="btn-primary" on:click={handlePrint}>Print</button>
        <button class="btn-secondary" on:click={handleNewJobCard}>New Job Card</button>
        <button class="btn-secondary" on:click={goBack}>Done</button>
      </div>
    </div>
  </div>
{:else}
  <div class="mobile-job-creation">
    <!-- Step Indicator -->
    <div class="step-indicator">
      <div class="step" class:active={currentStep === 1}>1</div>
      <div class="step" class:active={currentStep === 2}>2</div>
      <div class="step" class:active={currentStep === 3}>3</div>
      <div class="step" class:active={currentStep === 4}>4</div>
    </div>

    <!-- Step 1: Customer -->
    {#if currentStep === 1}
      <div class="step-content">
        <h2>Customer & Vehicle Number</h2>

        {#if !selectedCustomer}
          <div class="search-box">
            <input
              type="text"
              placeholder="Search customer..."
              bind:value={customerSearch}
              on:input={handleCustomerSearch}
              on:focus={() => (showCustomerDropdown = true)}
            />
          </div>

          {#if showCustomerDropdown && filteredCustomers.length > 0}
            <div class="dropdown">
              {#each filteredCustomers as cust (cust.id)}
                <div class="dropdown-item" on:click={() => selectCustomer(cust)}>
                  <div class="item-name">{cust.name}</div>
                  <div class="item-meta">{cust.place}</div>
                </div>
              {/each}
            </div>
          {/if}

          <button class="btn-link" on:click={() => (showCreateCustomer = true)}>
            + Create New Customer
          </button>

          {#if custError}
            <div class="error-msg">{custError}</div>
          {/if}

          {#if showCreateCustomer}
            <div class="form-section">
              <h3>Create Customer</h3>
              <input type="text" placeholder="Customer Name" bind:value={newCustName} />
              <input type="text" placeholder="Place/Location" bind:value={newCustPlace} />
              <select bind:value={newCustGender}>
                <option value="">Select Gender</option>
                <option value="Male">Male</option>
                <option value="Female">Female</option>
                <option value="Other">Other</option>
              </select>

              <div class="phone-inputs">
                <label>Phone Numbers</label>
                {#each newCustPhones as phone, idx (idx)}
                  <div class="input-row">
                    <input type="tel" placeholder="Phone" bind:value={newCustPhones[idx]} />
                    {#if newCustPhones.length > 1}
                      <button class="btn-remove-phone" on:click={() => removeNewCustPhone(idx)}>×</button>
                    {/if}
                  </div>
                {/each}
                <button class="btn-small" on:click={addNewCustPhone}>+ Add Phone</button>
              </div>

              <div class="vehicle-inputs">
                <label>Vehicle Numbers</label>
                {#each newCustVehicleNumbers as vn, idx (idx)}
                  <div class="input-row">
                    <input type="text" placeholder="Vehicle Number" bind:value={newCustVehicleNumbers[idx]} />
                    {#if newCustVehicleNumbers.length > 1}
                      <button class="btn-remove-vehicle" on:click={() => removeNewCustVehicleNumber(idx)}>×</button>
                    {/if}
                  </div>
                {/each}
                <button class="btn-small" on:click={addNewCustVehicleNumber}>+ Add Vehicle Number</button>
              </div>

              <div class="button-group">
                <button class="btn-primary" disabled={custSaving} on:click={saveInlineCustomer}>
                  {custSaving ? 'Saving...' : 'Save Customer'}
                </button>
                <button class="btn-secondary" on:click={() => (showCreateCustomer = false)}>Cancel</button>
              </div>
            </div>
          {/if}
        {:else}
          <div class="selected-item">
            <div class="selected-name">{selectedCustomer.name}</div>
            <div class="selected-meta">{selectedCustomer.place}</div>
            <button class="btn-link" on:click={() => (selectedCustomer = null)}>Change</button>
          </div>

          <div class="selection-group">
            <label>Vehicle Number</label>
            <select bind:value={selectedVehicleNumber}>
              <option value={null}>Select vehicle number...</option>
              {#each customerVehicleNumbers as vn (vn.vehicle_number)}
                <option value={vn.vehicle_number}>{vn.vehicle_number}</option>
              {/each}
            </select>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Step 2: Vehicle -->
    {#if currentStep === 2}
      <div class="step-content">
        <h2>Select Vehicle</h2>

        {#if !selectedVehicle}
          <div class="search-box">
            <input
              type="text"
              placeholder="Search vehicle..."
              bind:value={vehicleSearch}
              on:input={handleVehicleSearch}
              on:focus={() => (showVehicleDropdown = true)}
            />
          </div>

          {#if showVehicleDropdown && filteredVehicles.length > 0}
            <div class="dropdown">
              {#each filteredVehicles as veh (veh.id)}
                <div class="dropdown-item" on:click={() => selectVehicle(veh)}>
                  <div class="item-name">{veh.model_name}</div>
                  <div class="item-meta">
                    {veh.makes?.[0]?.name || 'N/A'} • {veh.variants?.[0]?.name || 'N/A'}
                  </div>
                </div>
              {/each}
            </div>
          {/if}

          <button class="btn-link" on:click={() => (showCreateVehicle = true)}>
            + Create New Vehicle
          </button>

          {#if vehError}
            <div class="error-msg">{vehError}</div>
          {/if}

          {#if showCreateVehicle}
            <div class="form-section">
              <h3>Create Vehicle</h3>
              <input type="text" placeholder="Model Name" bind:value={newVehModelName} />

              <SearchableDropdown
                items={allMakes}
                bind:value={newVehMakeId}
                placeholder="Select or type..."
                label="Make"
                on:add={() => handleAddMake()}
                on:edit={(e) => handleEditMake(e)}
              />

              <SearchableDropdown
                items={allGenerations}
                bind:value={newVehGenId}
                placeholder="Select or type..."
                label="Generation"
                on:add={() => handleAddGeneration()}
                on:edit={(e) => handleEditGeneration(e)}
              />

              <SearchableDropdown
                items={allGenTypes}
                bind:value={newVehGenTypeId}
                placeholder="Select or type..."
                label="Type"
                on:add={() => handleAddType()}
                on:edit={(e) => handleEditType(e)}
              />

              <SearchableDropdown
                items={allVariants}
                bind:value={newVehVariantId}
                placeholder="Select or type..."
                label="Variant"
                on:add={() => handleAddVariant()}
                on:edit={(e) => handleEditVariant(e)}
              />

              <SearchableDropdown
                items={allFuelTypes}
                bind:value={newVehFuelTypeId}
                placeholder="Select or type..."
                label="Fuel Type"
                on:add={() => handleAddFuelType()}
                on:edit={(e) => handleEditFuelType(e)}
              />

              <SearchableDropdown
                items={allGearboxes}
                bind:value={newVehGearboxId}
                placeholder="Select or type..."
                label="Gearbox"
                on:add={() => handleAddGearbox()}
                on:edit={(e) => handleEditGearbox(e)}
              />

              <SearchableDropdown
                items={allBodySides}
                bind:value={newVehBodySideId}
                placeholder="Select or type..."
                label="Body Side"
                on:add={() => handleAddBodySide()}
                on:edit={(e) => handleEditBodySide(e)}
              />

              <div class="button-group">
                <button class="btn-primary" disabled={vehSaving} on:click={saveInlineVehicle}>
                  {vehSaving ? 'Saving...' : 'Save Vehicle'}
                </button>
                <button class="btn-secondary" on:click={() => (showCreateVehicle = false)}>Cancel</button>
              </div>

              {#if addPopupOpen}
                <AddMasterDataPopup
                  tableName={addPopupTable}
                  title={addPopupTitle}
                  on:created={handleMasterCreated}
                  on:close={() => addPopupOpen = false}
                />
              {/if}

              {#if editPopupOpen}
                <EditMasterDataPopup
                  tableName={editPopupTable}
                  title={editPopupTitle}
                  itemId={editPopupItemId}
                  itemName={editPopupItemName}
                  on:updated={handleMasterUpdated}
                  on:close={() => editPopupOpen = false}
                />
              {/if}
            </div>
          {/if}
        {:else}
          <div class="selected-item">
            <div class="selected-name">{selectedVehicle.model_name}</div>
            <div class="selected-meta">
              {selectedVehicle.makes?.[0]?.name || 'N/A'} • {selectedVehicle.variants?.[0]?.name || 'N/A'}
            </div>
            <button class="btn-link" on:click={() => (selectedVehicle = null)}>Change</button>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Step 3: Products/Services -->
    {#if currentStep === 3}
      <div class="step-content">
        <h2>Add Products & Services</h2>

        <div class="search-box">
          <input
            type="text"
            placeholder="Search product..."
            bind:value={productSearch}
            on:input={handleProductSearch}
            on:focus={() => (showProductDropdown = true)}
          />
        </div>

        {#if showProductDropdown && filteredProducts.length > 0}
          <div class="dropdown">
            {#each filteredProducts as prod (prod.id)}
              <div class="dropdown-item" on:click={() => addProduct(prod)}>
                <div class="item-name">{prod.product_name}</div>
                <div class="item-meta">₹{prod.sales_price} • {prod.product_type}</div>
              </div>
            {/each}
          </div>
        {/if}

        <button class="btn-link" on:click={() => (showCreateProduct = true)}>
          + Create New Product
        </button>

        {#if prodError}
          <div class="error-msg">{prodError}</div>
        {/if}

        {#if showCreateProduct}
          <div class="form-section">
            <h3>Create Product/Service</h3>
            {#if prodError}<div class="form-error">{prodError}</div>{/if}
            
            <!-- Name + Type -->
            <input type="text" placeholder="Product Name" bind:value={newProdName} />
            <select bind:value={newProdType}>
              <option value="product">Product</option>
              <option value="service">Service</option>
              <option value="consumable">Consumable</option>
            </select>

            <!-- ===== SERVICE FIELDS ===== -->
            {#if newProdType === 'service'}
              <div style="margin-top: 1rem; border-top: 1px solid #ddd; padding-top: 1rem;">
                <label style="font-weight: 600; display: block; margin-bottom: 0.5rem;">Consumable Products</label>
                <input 
                  type="text" 
                  placeholder="Search consumable products..." 
                  bind:value={componentSearch}
                  on:input={searchServiceComponents}
                  on:focus={searchServiceComponents}
                />
                {#if showComponentDropdown}
                  <div style="border: 1px solid #ddd; border-radius: 4px; margin-top: 0.5rem; max-height: 200px; overflow-y: auto;">
                    {#each filteredComponents as p (p.id)}
                      <button 
                        on:click={() => addServiceComponent(p)}
                        style="display: flex; align-items: center; width: 100%; padding: 0.5rem 1rem; min-height: 48px; text-align: left; border: none; background: white; cursor: pointer; border-bottom: 1px solid #eee; font-size: 1rem;"
                      >
                        {p.product_name} - ₹{((p.current_cost || 0) / (p.unit_qty || 1)).toFixed(2)}/pc
                      </button>
                    {/each}
                  </div>
                {/if}

                {#if newProdServiceComponents.length > 0}
                  <div style="margin-top: 1rem;">
                    {#each newProdServiceComponents as comp, idx (comp.component_product_id)}
                      <div style="background: #f5f5f5; padding: 0.75rem; margin-bottom: 0.5rem; border-radius: 4px; display: flex; justify-content: space-between; align-items: center;">
                        <div style="flex: 1;">
                          <div style="font-weight: 500;">{comp.product_name}</div>
                          <div style="font-size: 0.9rem; color: #666;">
                            Qty: 
                            <input 
                              type="number" 
                              min="1" 
                              step="1"
                              value={comp.qty}
                              on:input={(e) => updateServiceComponentQty(idx, e.target.value)}
                              style="width: 80px; padding: 0.5rem; margin: 0 0.5rem; min-height: 48px; text-align: center; border: 1px solid #ccc; border-radius: 6px; font-size: 1rem;"
                            /> × ₹{comp.cost.toFixed(2)} = ₹{(comp.qty * comp.cost).toFixed(2)}
                          </div>
                        </div>
                        <button on:click={() => removeServiceComponent(idx)} style="background: #fee2e2; color: #dc2626; border: none; min-width: 48px; min-height: 48px; display: flex; align-items: center; justify-content: center; border-radius: 6px; cursor: pointer; font-size: 1.2rem; font-weight: bold;">×</button>
                      </div>
                    {/each}
                    <div style="background: #f9f9f9; padding: 0.5rem; border-radius: 4px; font-weight: 600; text-align: right;">
                      Components Cost: ₹{newProdComponentsCost.toFixed(2)}
                    </div>
                  </div>
                {:else}
                  <div style="background: #f5f5f5; padding: 0.75rem; border-radius: 4px; margin-top: 0.5rem; color: #666;">
                    No consumable products added yet
                  </div>
                {/if}

                <div style="margin-top: 1rem;">
                  <label style="font-weight: 600; display: block; margin-bottom: 0.3rem;">Labor Charge</label>
                  <input 
                    type="number" 
                    placeholder="0.00" 
                    bind:value={newProdLaborCharge}
                    step="0.01"
                  />
                </div>

                <div style="margin-top: 0.75rem;">
                  <label style="font-weight: 600; display: block; margin-bottom: 0.3rem;">Additional Charges</label>
                  <input 
                    type="number" 
                    placeholder="0.00" 
                    bind:value={newProdAdditionalCharges}
                    step="0.01"
                  />
                </div>

                <div style="margin-top: 0.75rem; background: #f0f9ff; padding: 0.75rem; border-radius: 4px;">
                  <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
                    <span style="font-weight: 600;">Total Cost (Auto):</span>
                    <span style="font-weight: 600; color: #0066cc;">₹{newProdServiceTotalCost.toFixed(2)}</span>
                  </div>
                </div>
              </div>
            {/if}

            <!-- Applicability (for product type) -->
            {#if newProdType === 'product'}
              <select bind:value={newProdApplicability}>
                <option value="">Applicability</option>
                <option value="universal">Universal</option>
                <option value="specific">Specific</option>
              </select>

              {#if newProdApplicability === 'specific'}
                <select bind:value={newProdVehicleId}>
                  <option value="">Select Vehicle</option>
                  {#each vehicles as v (v.id)}
                    <option value={v.id}>{v.model_name}</option>
                  {/each}
                </select>
              {/if}
            {/if}

            <!-- Product fields (for product/consumable, not service) -->
            {#if newProdType !== 'service'}
              <input type="text" placeholder="Part Number" bind:value={newProdPartNumber} />
              <input type="text" placeholder="Barcode" bind:value={newProdBarcode} />
              <input type="date" placeholder="Expiry Date" bind:value={newProdExpiryDate} />
              
              <select bind:value={newProdBrandId}>
                <option value="">Select Brand</option>
                {#each allBrands as b (b.id)}
                  <option value={b.id}>{b.name}</option>
                {/each}
              </select>

              <select bind:value={newProdUnitId}>
                <option value="">Select Unit</option>
                {#each allUnits as u (u.id)}
                  <option value={u.id}>{u.name}</option>
                {/each}
              </select>

              <input type="number" placeholder="Unit Quantity" bind:value={newProdUnitQty} step="0.01" />
              <input type="number" placeholder="Current Cost" bind:value={newProdCurrentCost} step="0.01" />

              <input type="number" placeholder="Opening Stock" bind:value={newProdOpeningStock} step="0.01" />
              <input type="number" placeholder="Minimum Stock" bind:value={newProdMinStock} step="0.01" />
              <input type="number" placeholder="Maximum Stock" bind:value={newProdMaxStock} step="0.01" />
              <input type="number" placeholder="Reorder Level" bind:value={newProdReorderLevel} step="0.01" />
            {/if}

            <!-- Pricing fields -->
            <input type="number" placeholder="Sales Price" bind:value={newProdPrice} step="0.01" />
            <input type="number" placeholder="D1 %" bind:value={newProdD1} step="0.01" />
            <input type="number" placeholder="D2 %" bind:value={newProdD2} step="0.01" />
            <input type="number" placeholder="D3 %" bind:value={newProdD3} step="0.01" />

            <div class="button-group">
              <button class="btn-primary" disabled={prodSaving} on:click={saveInlineProduct}>
                {prodSaving ? 'Saving...' : 'Save Product'}
              </button>
              <button class="btn-secondary" on:click={() => (showCreateProduct = false)}>Cancel</button>
            </div>
          </div>
        {/if}

        <!-- Items Table -->
        {#if items.length > 0}
          <div class="items-list">
            <h3>Added Items ({items.length})</h3>
            {#each items as item, idx (idx)}
              <div class="item-card">
                <div class="item-header">
                  <div class="item-name">{item.name}</div>
                  <button class="btn-remove" on:click={() => removeItem(idx)}>×</button>
                </div>
                <div class="item-details">
                  <div class="input-group">
                    <label>Qty</label>
                    <input
                      type="number"
                      value={item.qty}
                      on:change={e => handleItemQtyChange(idx, (e.target as HTMLInputElement).value)}
                      step="0.01"
                    />
                  </div>
                  <div class="input-group">
                    <label>Price</label>
                    <input
                      type="number"
                      value={item.price}
                      on:change={e => handleItemPriceChange(idx, (e.target as HTMLInputElement).value)}
                      step="0.01"
                    />
                  </div>
                  <div class="input-group">
                    <label>Discount</label>
                    <input
                      type="number"
                      value={item.discount}
                      on:change={e => handleItemDiscountChange(idx, (e.target as HTMLInputElement).value)}
                      step="0.01"
                    />
                  </div>
                </div>
                <div class="item-total">Total: ₹{item.total.toFixed(2)}</div>
              </div>
            {/each}
            <div class="grand-total">Grand Total: ₹{grandTotal.toFixed(2)}</div>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Step 4: Assign & Photos -->
    {#if currentStep === 4}
      <div class="step-content">
        <h2>Finalize Job Card</h2>

        <div class="form-section">
          <label>Assign To (User)</label>
          <select bind:value={assignedUserId}>
            <option value="">Select user...</option>
            {#each users as user (user.id)}
              <option value={user.id}>{user.user_name}</option>
            {/each}
          </select>

          <label>Priority</label>
          <select bind:value={priority}>
            <option value="Low">Low</option>
            <option value="Normal">Normal</option>
            <option value="High">High</option>
            <option value="Urgent">Urgent</option>
          </select>

          <label>Expected Date</label>
          <input type="date" bind:value={expectedDate} />

          <label>Body Inspection (Required)</label>
          <textarea
            placeholder="Enter body inspection details..."
            bind:value={description}
            rows="4"
          />

          <label>Mechanical Inspection (Optional)</label>
          <textarea
            placeholder="Enter mechanical inspection details..."
            bind:value={details}
            rows="4"
          />
        </div>

        <!-- Photo Upload Section -->
        <div class="photo-section">
          <h3>Upload Photos</h3>
          <div class="photo-buttons">
            <button class="btn-secondary" on:click={openCamera}>
              📷 Camera
            </button>
            <button class="btn-secondary" on:click={openGallery}>
              🖼️ Gallery
            </button>
          </div>

          <input
            type="file"
            accept="image/*"
            capture="environment"
            hidden
            bind:this={cameraInput}
            on:change={handleImageSelect}
          />
          <input
            type="file"
            accept="image/*"
            multiple
            hidden
            bind:this={galleryInput}
            on:change={handleImageSelect}
          />

          {#if showCameraPreview}
            <div class="camera-preview">
              <video bind:this={videoElement} autoplay playsinline />
              <canvas bind:this={canvasElement} hidden />
              <div class="camera-controls">
                <button class="btn-primary" on:click={capturePhoto}>📸 Capture</button>
                <button class="btn-secondary" on:click={stopCamera}>Stop</button>
              </div>
            </div>
          {/if}

          {#if uploadedImages.length > 0}
            <div class="uploaded-images">
              <h4>Uploaded Images ({uploadedImages.length})</h4>
              <div class="image-grid">
                {#each uploadedImages as img (img.id)}
                  <div class="image-item">
                    <img src={img.preview} alt="preview" />
                    <button
                      class="btn-remove-image"
                      on:click={() => removeUploadedImage(img.id)}
                      title="Remove"
                    >
                      ×
                    </button>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>

        <!-- Order Summary -->
        <div class="order-summary">
          <h3>Order Summary</h3>
          <div class="summary-row">
            <span>Products/Services:</span>
            <span class="amount">₹{items.reduce((sum, item) => sum + (item.price * item.qty || 0), 0).toFixed(2)}</span>
          </div>
          <div class="summary-row">
            <span>Items Count:</span>
            <span>{items.length}</span>
          </div>
          <div class="summary-total">
            <span>Total Amount:</span>
            <span class="total-amount">₹{grandTotal.toFixed(2)}</span>
          </div>
        </div>

        {#if saveError}
          <div class="error-msg">{saveError}</div>
        {/if}
      </div>
    {/if}

    <!-- Navigation Buttons -->
    <div class="nav-buttons">
      {#if currentStep > 1}
        <button class="btn-secondary" on:click={prevStep}>← Back</button>
      {:else}
        <button class="btn-secondary" on:click={goBack}>Cancel</button>
      {/if}

      {#if currentStep < 4}
        <button class="btn-primary" disabled={!canNext} on:click={nextStep}>
          Next →
        </button>
      {:else}
        <button class="btn-primary" disabled={saving} on:click={handleSaveJobCard}>
          {saving ? 'Saving...' : 'Create Job Card'}
        </button>
      {/if}
    </div>
  </div>
{/if}



<style>
  .permission-denied {
    padding: 2rem;
    text-align: center;
    color: var(--status-error, #C41E3A);
  }

  .mobile-job-creation {
    display: flex;
    flex-direction: column;
    min-height: 100%;
    background: #f9fafb;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  .step-indicator {
    display: flex;
    justify-content: space-around;
    padding: 1.25rem 1rem;
    background: #ffffff;
    border-bottom: 1px solid #e5e7eb;
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }

  .step {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f3f4f6;
    color: #6b7280;
    font-weight: 600;
    font-size: 1.1rem;
    transition: all 0.3s ease;
    border: 2px solid transparent;
  }

  .step.active {
    background: #C41E3A;
    color: #ffffff;
    box-shadow: 0 4px 6px rgba(196, 30, 58, 0.25);
    transform: scale(1.05);
  }

  .step-content {
    flex: 1;
    padding: 1.25rem;
    padding-bottom: 2rem;
    background: #ffffff;
    margin: 0.75rem;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    border: 1px solid #f3f4f6;
    position: relative;
    z-index: 1;
  }

  .step-content h2 {
    margin-bottom: 1.25rem;
    font-size: 1.25rem;
    font-weight: 700;
    color: #111827;
    letter-spacing: -0.025em;
  }

  .step-content h3 {
    margin-top: 1rem;
    margin-bottom: 0.75rem;
    font-size: 1.05rem;
    font-weight: 600;
    color: #374151;
  }

  .search-box {
    margin-bottom: 1rem;
  }

  .search-box input, select, textarea {
    width: 100%;
    padding: 1rem 1.25rem;
    border: 2px solid #e5e7eb;
    border-radius: 10px;
    font-size: 1rem;
    color: #111827;
    background: #ffffff;
    transition: all 0.2s ease;
    -webkit-appearance: none;
    appearance: none;
    min-height: 48px;
    font-family: inherit;
  }

  .search-box input:focus, select:focus, textarea:focus {
    border-color: #C41E3A;
    outline: none;
    box-shadow: 0 0 0 4px rgba(196, 30, 58, 0.1);
    background: #fef9f8;
  }

  .dropdown {
    border: 2px solid #e5e7eb;
    border-radius: 10px;
    background: #ffffff;
    max-height: 300px;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    margin-bottom: 1.25rem;
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.12);
    position: relative;
    z-index: 50;
  }

  .dropdown-item {
    padding: 0.875rem 1rem;
    border-bottom: 1px solid #f3f4f6;
    cursor: pointer;
    transition: background 0.2s ease;
  }

  .dropdown-item:last-child {
    border-bottom: none;
  }

  .dropdown-item:hover {
    background: #f9fafb;
  }

  .item-name {
    font-weight: 600;
    color: #111827;
    word-break: break-word;
    overflow-wrap: break-word;
    line-height: 1.4;
    max-width: 100%;
  }

  .item-meta {
    font-size: 0.85rem;
    color: #6b7280;
    margin-top: 0.25rem;
  }

  .selected-item {
    background: rgba(196, 30, 58, 0.05);
    padding: 1rem 1.25rem;
    border-radius: 8px;
    margin-bottom: 1.25rem;
    border-left: 4px solid #C41E3A;
  }

  .selected-name {
    font-weight: 700;
    font-size: 1.1rem;
    color: #111827;
  }

  .selected-meta {
    font-size: 0.9rem;
    color: #4b5563;
    margin: 0.5rem 0;
  }

  .btn-link {
    background: none;
    border: none;
    color: #C41E3A;
    cursor: pointer;
    font-size: 1rem;
    font-weight: 700;
    padding: 0.75rem 0;
    margin-top: 1rem;
    text-decoration: none;
    display: block;
    width: 100%;
    text-align: left;
    min-height: 48px;
    display: flex;
    align-items: center;
    font-family: inherit;
  }

  .btn-link:hover {
    color: #a01830;
    text-decoration: underline;
  }

  .form-section {
    background: #f9fafb;
    padding: 1.25rem;
    border-radius: 8px;
    margin: 1.25rem 0;
    border: 1px solid #e5e7eb;
  }

  .form-error {
    background: #fef2f2;
    color: #C41E3A;
    border: 1px solid #fecaca;
    padding: 0.75rem 1rem;
    border-radius: 6px;
    margin-bottom: 1rem;
    font-size: 0.9rem;
    font-weight: 500;
  }

  .form-section input,
  .form-section select,
  .form-section textarea {
    width: 100%;
    margin-bottom: 1rem;
    padding: 0.875rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-size: 1rem;
    font-family: inherit;
    color: #111827;
    background: #ffffff;
    transition: all 0.2s ease;
    min-height: 48px;
  }

  .form-section input:focus,
  .form-section select:focus,
  .form-section textarea:focus {
    border-color: #C41E3A;
    outline: none;
    box-shadow: 0 0 0 3px rgba(196, 30, 58, 0.1);
  }

  .form-section textarea {
    resize: vertical;
    min-height: 100px;
  }

  .selection-group {
    margin-bottom: 1.25rem;
  }

  .selection-group label {
    display: block;
    font-weight: 600;
    margin-bottom: 0.5rem;
    color: #374151;
  }

  .selection-group select {
    width: 100%;
    padding: 0.875rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-size: 1rem;
    min-height: 48px;
  }

  .phone-inputs {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .phone-inputs input {
    padding: 1rem 1.25rem;
    border: 2px solid #d1d5db;
    border-radius: 10px;
    min-height: 48px;
    font-size: 1rem;
  }

  .phone-inputs label {
    font-weight: 700;
    font-size: 1rem;
    color: #374151;
    margin-bottom: 0.5rem;
    display: block;
  }

  .vehicle-inputs {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-top: 1.25rem;
  }

  .vehicle-inputs input {
    padding: 1rem 1.25rem;
    border: 2px solid #d1d5db;
    border-radius: 10px;
    min-height: 48px;
    font-size: 1rem;
  }

  .vehicle-inputs label {
    font-weight: 700;
    font-size: 1rem;
    color: #374151;
    margin-bottom: 0.5rem;
    display: block;
  }

  .input-row {
    display: flex;
    gap: 0.75rem;
    align-items: stretch;
    flex-wrap: nowrap;
  }

  .input-row input {
    flex: 1;
    min-width: 0;
    padding: 1rem 1.25rem;
    border: 2px solid #d1d5db;
    border-radius: 10px;
    transition: all 0.2s ease;
    min-height: 48px;
    font-size: 1rem;
  }

  .btn-remove {
    padding: 0.75rem 1rem;
    background: #fee2e2;
    color: #C41E3A;
    border: 2px solid #fecaca;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 700;
    white-space: nowrap;
    transition: all 0.2s ease;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    width: auto;
    flex-shrink: 0;
    font-family: inherit;
  }

  .btn-remove:active {
    transform: scale(0.95);
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
  }

  .items-list {
    margin-top: 1.5rem;
    border-top: 2px solid #e5e7eb;
    padding-top: 1.25rem;
  }

  .item-card {
    background: white;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
  }

  .item-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
    margin-bottom: 1rem;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .item-header span {
    font-weight: 600;
    color: #111827;
  }

  .item-details {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  @media (max-width: 600px) {
    .item-details {
      grid-template-columns: 1fr;
      gap: 1rem;
    }
  }

  .input-group {
    display: flex;
    flex-direction: column;
  }

  .input-group label {
    font-size: 0.85rem;
    font-weight: 700;
    color: #374151;
    margin-bottom: 0.5rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .input-group input {
    padding: 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 1rem;
    transition: all 0.2s;
    min-height: 48px;
    box-sizing: border-box;
    width: 100%;
    -webkit-appearance: none;
    appearance: none;
  }

  .input-group input[type="number"] {
    font-size: 1rem;
  }

  .input-group input:focus {
    border-color: #C41E3A;
    box-shadow: 0 0 0 2px rgba(196, 30, 58, 0.1);
    outline: none;
  }

  .item-total {
    text-align: right;
    font-weight: 700;
    color: #059669;
    font-size: 1.2rem;
    padding-top: 0.75rem;
    border-top: 1px solid #e5e7eb;
    margin-top: 0.75rem;
  }

  .order-summary {
    background: #f9fafb;
    border: 2px solid #e5e7eb;
    border-radius: 10px;
    padding: 1.25rem;
    margin-top: 1.5rem;
    margin-bottom: 1.5rem;
  }

  .order-summary h3 {
    font-size: 1.1rem;
    font-weight: 700;
    color: #111827;
    margin-bottom: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0;
    border-bottom: 1px solid #e5e7eb;
    font-size: 0.95rem;
  }

  .summary-row:last-of-type {
    border-bottom: none;
  }

  .summary-row span {
    color: #6b7280;
    font-weight: 500;
  }

  .summary-row .amount {
    color: #111827;
    font-weight: 700;
    font-size: 1rem;
  }

  .summary-total {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 0;
    margin-top: 0.75rem;
    border-top: 2px solid #C41E3A;
    border-bottom: none;
  }

  .summary-total span {
    color: #111827;
    font-weight: 700;
    font-size: 1.1rem;
  }

  .summary-total .total-amount {
    color: #C41E3A;
    font-size: 1.25rem;
  }

  .grand-total {
    background: #111827;
    color: white;
    padding: 1rem 1.25rem;
    border-radius: 8px;
    text-align: right;
    font-weight: 700;
    font-size: 1.25rem;
    margin-top: 1rem;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  }

  .btn-small {
    padding: 0.9rem 1.25rem;
    background: #111827;
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.95rem;
    font-weight: 700;
    transition: all 0.2s ease;
    min-height: 48px;
    width: 100%;
    font-family: inherit;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .btn-small:active {
    background: #374151;
    transform: scale(0.96);
  }

  .btn-remove {
    background: none;
    border: none;
    color: #C41E3A;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0;
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
  }

  .btn-remove:hover {
    background: #fee2e2;
    border-radius: 50%;
  }

  .photo-section {
    margin-top: 1.5rem;
    padding-top: 1rem;
    border-top: 2px solid #ddd;
  }

  .photo-buttons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .camera-preview {
    position: relative;
    width: 100%;
    margin-bottom: 1rem;
    border-radius: 4px;
    overflow: hidden;
    background: #000;
  }

  .camera-preview video {
    width: 100%;
    height: auto;
    display: block;
  }

  .camera-controls {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.5rem;
    padding: 0.75rem;
    background: rgba(0, 0, 0, 0.8);
  }

  .uploaded-images {
    margin-top: 1rem;
  }

  .uploaded-images h4 {
    margin-bottom: 0.75rem;
    color: #333;
  }

  .image-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(80px, 1fr));
    gap: 0.75rem;
  }

  .image-item {
    position: relative;
    aspect-ratio: 1;
    border-radius: 4px;
    overflow: hidden;
    background: #f0f0f0;
  }

  .image-item img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .btn-remove-image {
    position: absolute;
    top: -5px;
    right: -5px;
    background: #d32f2f;
    color: white;
    border: none;
    border-radius: 50%;
    width: 44px;
    height: 44px;
    cursor: pointer;
    font-size: 1.2rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .error-msg {
    background: #ffebee;
    color: #d32f2f;
    padding: 0.75rem;
    border-radius: 4px;
    margin-top: 0.75rem;
    border-left: 4px solid #d32f2f;
  }

  .button-group {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.5rem;
    margin-top: 1rem;
  }

  .nav-buttons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    padding: 1rem;
    background: white;
    border-top: 1px solid #ddd;
    margin-top: 2rem;
  }

  .btn-primary,
  .btn-secondary {
    padding: 0.75rem 1rem;
    border: none;
    border-radius: 4px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s;
  }

  .btn-primary {
    background: #C41E3A;
    color: white;
    padding: 1rem 1.5rem;
    border: none;
    border-radius: 10px;
    font-size: 1.1rem;
    font-weight: 700;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.25);
    transition: all 0.2s ease;
    width: 100%;
    min-height: 52px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: inherit;
  }

  .btn-primary:active {
    transform: scale(0.97);
    background: #a01830;
    box-shadow: 0 2px 6px rgba(196, 30, 58, 0.2);
  }

  .btn-primary:hover:not(:disabled) {
    background: #a01830;
    box-shadow: 0 6px 16px rgba(196, 30, 58, 0.35);
  }

  .btn-primary:disabled {
    background: #e5e7eb;
    color: #9ca3af;
    box-shadow: none;
    cursor: not-allowed;
  }

  .btn-secondary {
    background: #f3f4f6;
    color: #111827;
    padding: 1rem 1.5rem;
    border: 2px solid #d1d5db;
    border-radius: 10px;
    font-size: 1.1rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.2s ease;
    width: 100%;
    min-height: 52px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: inherit;
  }

  .btn-secondary:active {
    transform: scale(0.97);
    background: #e5e7eb;
    border-color: #9ca3af;
  }

  .btn-secondary:hover {
    background: #e5e7eb;
    border-color: #9ca3af;
  }

  .success-screen {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100vh;
    background: #f9fafb;
    padding: 1rem;
  }

  .success-card {
    background: white;
    padding: 2.5rem 2rem;
    border-radius: 16px;
    text-align: center;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
    border: 1px solid #f3f4f6;
    width: 100%;
    max-width: 400px;
  }

  .success-icon {
    font-size: 4.5rem;
    color: #10b981;
    margin-bottom: 1rem;
    background: #d1fae5;
    width: 100px;
    height: 100px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    margin: 0 auto 1.5rem;
  }

  .success-title {
    font-size: 1.5rem;
    font-weight: bold;
    color: #333;
    margin-bottom: 0.5rem;
  }

  .success-number {
    font-size: 1.2rem;
    color: #1976d2;
    font-weight: bold;
    margin-bottom: 1.5rem;
    font-family: monospace;
  }

  .success-buttons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .success-buttons .btn-secondary {
    grid-column: 1 / -1;
    min-height: 52px;
  }

  .success-buttons button {
    min-height: 52px;
  }
</style>
