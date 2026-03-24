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
  import SearchableDropdown from '../../../shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../../shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../../shared/EditMasterDataPopup.svelte';

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

  // ---- Step 4: Image Upload ----
  interface UploadedImage {
    id: string;
    file: File;
    preview: string;
    uploading: boolean;
  }
  let uploadedImages: UploadedImage[] = [];
  let savedImages: any[] = []; // Images saved to DB
  let cameraInput: HTMLInputElement | undefined;
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
      if (!allowed) { permDenied = true; return; }
    }
    
    // Detect if mobile
    isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    
    await Promise.all([
      loadCustomers(),
      loadVehicles(),
      loadProducts(),
      loadUsers(),
      loadVehicleMasterData(),
    ]);
  });

  // ---- Mobile Detection & Camera ----
  function detectMobile(): boolean {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }

  function openCamera() {
    onCameraClick();
  }

  async function onCameraClick() {
    // Check if mobile
    if (detectMobile()) {
      // Mobile: use native capture
      if (cameraInput) {
        cameraInput.value = '';
        cameraInput.click();
      }
    } else {
      // Desktop: use WebRTC
      await startDesktopCamera();
    }
  }

  async function startDesktopCamera() {
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        alert('Your browser does not support camera access. Please use a modern browser like Chrome, Firefox, or Edge.');
        return;
      }

      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false
      });

      cameraStream = stream;
      showCameraPreview = true;

      // Wait for videoElement to be in DOM
      await new Promise(resolve => setTimeout(resolve, 100));

      if (videoElement) {
        videoElement.srcObject = stream;
        videoElement.play().catch(err => console.error('Play error:', err));
      }
    } catch (err: any) {
      console.error('Camera error:', err);
      if (err.name === 'NotAllowedError') {
        alert('Camera access was denied. Please allow camera access in your browser settings.');
      } else if (err.name === 'NotFoundError') {
        alert('No camera found on this device.');
      } else {
        alert('Error accessing camera: ' + err.message);
      }
    }
  }

  function capturePhoto() {
    if (!canvasElement || !videoElement) return;

    const ctx = canvasElement.getContext('2d');
    if (!ctx) return;

    canvasElement.width = videoElement.videoWidth;
    canvasElement.height = videoElement.videoHeight;
    ctx.drawImage(videoElement, 0, 0);

    canvasElement.toBlob((blob) => {
      if (!blob) return;

      const file = new File([blob], `photo-${Date.now()}.jpg`, { type: 'image/jpeg' });

      // Create preview
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
    showCameraPreview = false;
  }

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
  function handleMasterCreated() {
    addPopupOpen = false;
    // Reload the appropriate table
    if (addPopupTable === 'makes') loadVehicleMasterData().then(() => allMakes = allMakes);
    else if (addPopupTable === 'generations') loadVehicleMasterData().then(() => allGenerations = allGenerations);
    else if (addPopupTable === 'generation_types') loadVehicleMasterData().then(() => allGenTypes = allGenTypes);
    else if (addPopupTable === 'variants') loadVehicleMasterData().then(() => allVariants = allVariants);
    else if (addPopupTable === 'gearboxes') loadVehicleMasterData().then(() => allGearboxes = allGearboxes);
    else if (addPopupTable === 'fuel_types') loadVehicleMasterData().then(() => allFuelTypes = allFuelTypes);
    else if (addPopupTable === 'body_sides') loadVehicleMasterData().then(() => allBodySides = allBodySides);
  }

  function handleMasterUpdated() {
    editPopupOpen = false;
    // Reload the appropriate table
    if (editPopupTable === 'makes') loadVehicleMasterData().then(() => allMakes = allMakes);
    else if (editPopupTable === 'generations') loadVehicleMasterData().then(() => allGenerations = allGenerations);
    else if (editPopupTable === 'generation_types') loadVehicleMasterData().then(() => allGenTypes = allGenTypes);
    else if (editPopupTable === 'variants') loadVehicleMasterData().then(() => allVariants = allVariants);
    else if (editPopupTable === 'gearboxes') loadVehicleMasterData().then(() => allGearboxes = allGearboxes);
    else if (editPopupTable === 'fuel_types') loadVehicleMasterData().then(() => allFuelTypes = allFuelTypes);
    else if (editPopupTable === 'body_sides') loadVehicleMasterData().then(() => allBodySides = allBodySides);
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

  // ---- Image Upload ----
  function handleImageSelect(e: any) {
    const files = Array.from(e.target.files || []) as File[];
    for (const file of files) {
      if (!file.type.startsWith('image/')) {
        alert('Please select image files only');
        continue;
      }
      if (file.size > 5 * 1024 * 1024) { // 5MB limit
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
    e.target.value = ''; // Reset input
  }

  function removeUploadedImage(id: string) {
    uploadedImages = uploadedImages.filter(img => img.id !== id);
  }

  function removeSavedImage(id: string) {
    savedImages = savedImages.filter(img => img.id !== id);
  }

  async function uploadImagesToStorage(jobCardId: string) {
    const uploadResults = [];
    
    for (const imgObj of uploadedImages) {
      imgObj.uploading = true;
      try {
        const fileName = `${jobCardId}/${Date.now()}-${imgObj.file.name}`;
        const { error: uploadErr } = await supabase.storage
          .from('job-card-photos')
          .upload(fileName, imgObj.file, { upsert: false });

        if (uploadErr) {
          console.error('Upload error:', uploadErr);
          continue;
        }

        // Get public URL
        const { data: publicUrlData } = supabase.storage
          .from('job-card-photos')
          .getPublicUrl(fileName);

        // Save metadata to DB
        const { error: dbErr } = await supabase.from('job_card_photos').insert({
          job_card_id: jobCardId,
          file_url: publicUrlData.publicUrl,
          file_name: imgObj.file.name,
          uploaded_by: $authStore.user?.id || null,
          created_by: $authStore.user?.id || null,
        });

        if (dbErr) {
          console.error('DB error:', dbErr);
          continue;
        }

        uploadResults.push({
          id: imgObj.id,
          file_url: publicUrlData.publicUrl,
          file_name: imgObj.file.name
        });
      } catch (err) {
        console.error('Upload exception:', err);
      }
      imgObj.uploading = false;
    }

    savedImages = uploadResults;
    uploadedImages = [];
    return uploadResults.length;
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

    // Generate job card number: DDMMYYYY + sequential number
    // Example: 250320261 (first card), 250320262 (second card), 2503202610 (tenth card)
    const now = new Date();
    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const year = String(now.getFullYear()); // Full 4-digit year
    const datePrefix = `${day}${month}${year}`; // e.g., "250320026" for 25-03-2026

    // Get today's date range for querying
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

    // Query existing job cards created today
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

    // Upload images
    if (uploadedImages.length > 0) {
      await uploadImagesToStorage(jc.id);
    }

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
    uploadedImages = [];
    savedImages = [];
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
      <html>
      <head>
        <title>Job Card - ${savedJobCardNo}</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          
          @page { 
            size: A4; 
            margin: 10mm;
          }
          
          @media print {
            body { margin: 0; padding: 0; }
            .page-break { page-break-after: always; }
          }
          
          body { 
            font-family: Arial, sans-serif; 
            font-size: 12px; 
            line-height: 1.3;
            color: #333;
            background: white;
            width: 100%;
            margin: 0;
            padding: 15px;
          }
          
          .container {
            width: 100%;
            max-width: 800px;
            margin: 0 auto;
            background: white;
          }
          
          .logo-header { 
            text-align: center; 
            margin-bottom: 12px; 
            border-bottom: 2px solid #333; 
            padding-bottom: 8px; 
          }
          .logo-header img { 
            max-height: 60px; 
            max-width: 150px; 
          }
          
          h2 { 
            margin: 6px 0; 
            text-align: center; 
            font-size: 16px; 
            font-weight: bold;
          }
          
          .job-info { 
            text-align: center; 
            margin: 6px 0; 
            font-size: 11px; 
            font-weight: bold;
            word-break: break-all;
          }
          
          /* Two column layout - constrained width */
          .cards-row { 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 8px; 
            margin: 10px 0;
            width: 100%;
          }
          
          .inspection-row { 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 8px; 
            margin: 10px 0;
            width: 100%;
          }
          
          .card { 
            border: 1px solid #333; 
            padding: 8px; 
            background: #fafafa;
            width: 100%;
            overflow: hidden;
            word-wrap: break-word;
          }
          
          .card-title { 
            font-weight: bold; 
            font-size: 10px; 
            margin-bottom: 4px; 
            border-bottom: 1px solid #333; 
            padding-bottom: 2px;
          }
          
          .card-item { 
            display: flex; 
            margin: 2px 0; 
            font-size: 10px;
            width: 100%;
          }
          
          .card-label { 
            font-weight: 600; 
            min-width: 75px;
            flex-shrink: 0;
          }
          
          .card-value { 
            flex: 1; 
            word-break: break-word;
            overflow: hidden;
          }
          
          .info-row { 
            border: 1px solid #333; 
            padding: 8px; 
            margin: 10px 0; 
            background: #fafafa;
            width: 100%;
          }
          
          .info-row .title { 
            font-weight: bold; 
            font-size: 10px; 
            margin-bottom: 6px; 
            border-bottom: 1px solid #333; 
            padding-bottom: 2px;
          }
          
          .info-grid { 
            display: grid; 
            grid-template-columns: repeat(2, 1fr); 
            gap: 6px;
            width: 100%;
          }
          
          .info-item { 
            font-size: 10px;
            word-break: break-word;
            overflow: hidden;
          }
          
          .info-label { 
            font-weight: bold; 
            display: block;
            margin-bottom: 1px;
          }
          
          table { 
            width: 100%; 
            border-collapse: collapse; 
            margin: 10px 0;
            table-layout: fixed;
          }
          
          th, td { 
            border: 1px solid #ccc; 
            padding: 4px 3px; 
            text-align: left; 
            font-size: 10px;
            word-break: break-word;
          }
          
          th { 
            background: #e5e5e5; 
            font-weight: bold;
          }
          
          .images-section { 
            border: 1px solid #333; 
            padding: 8px; 
            margin: 10px 0; 
            background: #fafafa;
            width: 100%;
          }
          
          .images-title { 
            font-weight: bold; 
            font-size: 10px; 
            margin-bottom: 6px; 
            border-bottom: 1px solid #333; 
            padding-bottom: 2px;
          }
          
          .images-grid { 
            display: grid; 
            grid-template-columns: repeat(4, 1fr); 
            gap: 6px; 
            margin-top: 6px;
            width: 100%;
          }
          
          .image-item { 
            border: 1px solid #ccc; 
            padding: 2px; 
            text-align: center;
            word-break: break-word;
          }
          
          .image-item img { 
            max-width: 100%; 
            height: auto; 
            max-height: 100px; 
            margin-bottom: 2px; 
            display: block;
          }
          
          .image-name { 
            font-size: 8px; 
            word-break: break-word; 
            color: #666;
          }
          
          .signature-block {
            margin-top: 15px;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            font-size: 10px;
            width: 100%;
          }
          
          .sig-item {
            text-align: center;
          }
          
          .sig-line {
            height: 40px;
            border-bottom: 1px solid #333;
            margin-bottom: 3px;
          }
          
          /* Ensure no horizontal scroll */
          html, body {
            width: 100%;
            overflow-x: hidden;
          }
        </style>
      </head>
      <body>
      <div class="container">
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
      
      <!-- Row 1: Body Inspection & Mechanical Inspection (Side by Side) -->
      <div class="inspection-row">
        <div class="card">
          <div class="card-title">Body Inspection</div>
          <div style="padding: 6px; line-height: 1.4; min-height: 60px;">${description || '—'}</div>
        </div>
        <div class="card">
          <div class="card-title">Mechanical Inspection</div>
          <div style="padding: 6px; line-height: 1.4; min-height: 60px;">${details || '—'}</div>
        </div>
      </div>
      
      <!-- Row 2: Job Details (Assigned To, Priority, Date) -->
      <div class="info-row">
        <div class="title">Job Details</div>
        <div class="info-grid">
          <div class="info-item"><span class="info-label">Assigned To:</span> ${users.find(u => u.id === assignedUserId)?.user_name || users.find(u => u.id === assignedUserId)?.email || '—'}</div>
          <div class="info-item"><span class="info-label">Priority:</span> ${priority}</div>
          <div class="info-item"><span class="info-label">Date:</span> ${new Date().toLocaleDateString('en-IN')}</div>
          <div class="info-item"><span class="info-label">Expected:</span> ${expectedDate ? (() => { const [y, m, d] = expectedDate.split('-'); return `${d}-${m}-${y}`; })() : '—'}</div>
        </div>
      </div>
      ${savedImages && savedImages.length > 0 ? `
      <div class="images-section">
        <div class="images-title">Images</div>
        <div class="images-grid">
          ${savedImages.map(img => `
            <div class="image-item">
              <img src="${img.file_url}" alt="Job card image" />
              <div class="image-name">${img.file_name || 'Image'}</div>
            </div>
          `).join('')}
        </div>
      </div>
      ` : ''}
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
            Print Estimation
          </button>
          <button class="btn-secondary" on:click={handleNewJobCard}>New Job Card</button>
          <button class="btn-ghost" on:click={() => windowStore.close('finance-job-card')}>Close</button>
        </div>
      </div>

      <!-- Hidden print content (items table only) -->
      <div id="job-card-print" style="display:none;">
        <div style="border: 1px solid #333; padding: 10px; margin: 12px 0; background: #fafafa;">
          <div style="font-weight: bold; font-size: 11px; margin-bottom: 6px; border-bottom: 1px solid #333; padding-bottom: 3px;">Items & Services</div>
          <table style="width: 100%; border-collapse: collapse; margin: 6px 0; font-size: 11px;">
            <thead>
              <tr style="background: #e5e5e5;">
                <th style="border: 1px solid #ccc; padding: 4px; text-align: center; width: 25px;">#</th>
                <th style="border: 1px solid #ccc; padding: 4px;">Type</th>
                <th style="border: 1px solid #ccc; padding: 4px;">Description</th>
                <th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 50px;">Qty</th>
                <th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 60px;">Price</th>
                <th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 60px;">Discount</th>
                <th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 60px;">Total</th>
              </tr>
            </thead>
            <tbody>
              {#each items as it, idx}
                <tr>
                  <td style="border: 1px solid #ccc; padding: 4px; text-align: center;">{idx+1}</td>
                  <td style="border: 1px solid #ccc; padding: 4px; font-size: 10px;">{it.item_type}</td>
                  <td style="border: 1px solid #ccc; padding: 4px;">{it.name}</td>
                  <td style="border: 1px solid #ccc; padding: 4px; text-align: right;">{it.qty}</td>
                  <td style="border: 1px solid #ccc; padding: 4px; text-align: right;">₹{it.price.toFixed(2)}</td>
                  <td style="border: 1px solid #ccc; padding: 4px; text-align: right;">₹{it.discount.toFixed(2)}</td>
                  <td style="border: 1px solid #ccc; padding: 4px; text-align: right; font-weight: bold;">₹{it.total.toFixed(2)}</td>
                </tr>
              {/each}
              <tr style="background: #e5e5e5; font-weight: bold;">
                <td colspan="6" style="border: 1px solid #ccc; padding: 6px; text-align: right;">GRAND TOTAL:</td>
                <td style="border: 1px solid #ccc; padding: 6px; text-align: right; font-size: 12px;">₹{grandTotal.toFixed(2)}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div style="margin-top: 20px; display: grid; grid-template-columns: 1fr 1fr; gap: 20px; font-size: 10px;">
          <div style="text-align: center;">
            <div style="height: 50px; border-bottom: 1px solid #333; margin-bottom: 4px;"></div>
            <div>Authorized By</div>
          </div>
          <div style="text-align: center;">
            <div style="height: 50px; border-bottom: 1px solid #333; margin-bottom: 4px;"></div>
            <div>Customer Signature</div>
          </div>
        </div>
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
                  items={allGearboxes}
                  bind:value={newVehGearboxId}
                  placeholder="Select or type..."
                  label="Gearbox"
                  on:add={() => handleAddGearbox()}
                  on:edit={(e) => handleEditGearbox(e)}
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
                  items={allBodySides}
                  bind:value={newVehBodySideId}
                  placeholder="Select or type..."
                  label="Body Side"
                  on:add={() => handleAddBodySide()}
                  on:edit={(e) => handleEditBodySide(e)}
                />
              </div>
              <div class="form-actions">
                <button class="btn-primary" on:click={saveInlineVehicle} disabled={vehSaving}>{vehSaving ? 'Saving...' : 'Save Vehicle'}</button>
                <button class="btn-ghost" on:click={() => { showCreateVehicle = false; vehError = ''; }}>Cancel</button>
              </div>

              {#if addPopupOpen}
                <AddMasterDataPopup
                  table={addPopupTable}
                  title={addPopupTitle}
                  on:created={handleMasterCreated}
                  on:close={() => addPopupOpen = false}
                />
              {/if}

              {#if editPopupOpen}
                <EditMasterDataPopup
                  table={editPopupTable}
                  title={editPopupTitle}
                  itemId={editPopupItemId}
                  itemName={editPopupItemName}
                  on:updated={handleMasterUpdated}
                  on:close={() => editPopupOpen = false}
                />
              {/if}
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
            <label>Body Inspection *</label>
            <textarea bind:value={description} rows="3" placeholder="Body inspection details (required)"></textarea>
          </div>
          <div class="form-field full-width">
            <label>Mechanical Inspection</label>
            <textarea bind:value={details} rows="2" placeholder="Mechanical inspection details (optional)"></textarea>
          </div>

          <!-- Image Upload Section -->
          <div class="form-field full-width">
            <label>Upload Images</label>
            <div class="image-upload-box">
              <div class="upload-buttons">
                <label class="file-input-label">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>
                  From Gallery
                  <input 
                    type="file" 
                    multiple 
                    accept="image/*" 
                    on:change={handleImageSelect}
                    style="display: none;"
                  />
                </label>
                <button type="button" class="file-input-label camera-btn" on:click={openCamera}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
                  Take Photo
                </button>
                <input 
                  bind:this={cameraInput}
                  id="camera-capture"
                  type="file" 
                  capture="environment"
                  on:change={handleImageSelect}
                  style="display: none;"
                />
              </div>
              <p class="upload-hint">Max 5MB per image, PNG/JPG/JPEG</p>
            </div>

            <!-- Camera Preview (Desktop only) -->
            {#if showCameraPreview}
              <div class="camera-preview-container">
                <div class="camera-preview-card">
                  <h4>Camera</h4>
                  <video 
                    bind:this={videoElement}
                    class="camera-video"
                    autoplay
                    playsinline
                  ></video>
                  <canvas bind:this={canvasElement} style="display: none;"></canvas>
                  <div class="camera-actions">
                    <button type="button" class="btn-primary" on:click={capturePhoto}>
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><circle cx="12" cy="12" r="10"/></svg>
                      Capture
                    </button>
                    <button type="button" class="btn-ghost" on:click={stopCamera}>Close</button>
                  </div>
                </div>
              </div>
            {/if}

            <!-- Uploading images preview -->
            {#if uploadedImages.length > 0}
              <div class="images-preview">
                <h4>Images to Upload ({uploadedImages.length})</h4>
                <div class="preview-grid">
                  {#each uploadedImages as img (img.id)}
                    <div class="preview-item">
                      <div class="preview-img" style="background-image: url({img.preview})"></div>
                      <button 
                        class="preview-remove" 
                        on:click={() => removeUploadedImage(img.id)}
                        disabled={img.uploading}
                      >×</button>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}

            <!-- Saved images display -->
            {#if savedImages.length > 0}
              <div class="images-saved">
                <h4>Uploaded Images ({savedImages.length})</h4>
                <div class="preview-grid">
                  {#each savedImages as img (img.id)}
                    <div class="preview-item">
                      <img src={img.file_url} alt={img.file_name} />
                      <button class="preview-remove" on:click={() => removeSavedImage(img.id)}>×</button>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}
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

  /* Image Upload */
  .image-upload-box { border: 2px dashed #d1d5db; border-radius: 8px; padding: 24px; text-align: center; background: #f9fafb; }
  .upload-buttons { display: flex; gap: 12px; justify-content: center; margin-bottom: 12px; flex-wrap: wrap; }
  .file-input-label { display: flex; flex-direction: column; align-items: center; gap: 8px; cursor: pointer; color: #C41E3A; font-weight: 600; font-size: 14px; transition: all 0.2s; padding: 12px 16px; border: 1px solid #C41E3A; border-radius: 6px; background: white; }
  .file-input-label:hover { background: #fef2f2; transform: translateY(-2px); }
  .file-input-label.camera-btn { background: #fef2f2; }
  .file-input-label.camera-btn:hover { background: white; border-color: #C41E3A; }
  
  button.file-input-label { cursor: pointer; color: #C41E3A; font-weight: 600; font-size: 14px; padding: 12px 16px; border: 1px solid #C41E3A; border-radius: 6px; background: white; transition: all 0.2s; display: flex; flex-direction: column; align-items: center; gap: 8px; }
  button.file-input-label:hover { background: #fef2f2; transform: translateY(-2px); }
  button.file-input-label.camera-btn { background: #fef2f2; }
  button.file-input-label.camera-btn:hover { background: white; }
  
  .upload-hint { font-size: 11px; color: #6b7280; margin: 0; }
  
  .images-preview, .images-saved { margin-top: 12px; }
  .images-preview h4, .images-saved h4 { font-size: 13px; font-weight: 600; margin-bottom: 8px; color: #374151; }
  .preview-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(80px, 1fr)); gap: 8px; }
  .preview-item { position: relative; width: 100%; aspect-ratio: 1 / 1; }
  .preview-img { width: 100%; height: 100%; background-size: cover; background-position: center; border-radius: 6px; border: 1px solid #e5e7eb; }
  .preview-item img { width: 100%; height: 100%; object-fit: cover; border-radius: 6px; border: 1px solid #e5e7eb; }
  .preview-remove { position: absolute; top: -8px; right: -8px; width: 24px; height: 24px; background: #dc2626; color: white; border: none; border-radius: 50%; font-size: 18px; font-weight: 700; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: background 0.2s; }
  .preview-remove:hover:not(:disabled) { background: #b91c1c; }
  .preview-remove:disabled { opacity: 0.6; cursor: not-allowed; }

  /* Camera Preview */
  .camera-preview-container { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0, 0, 0, 0.7); display: flex; align-items: center; justify-content: center; z-index: 1000; }
  .camera-preview-card { background: white; border-radius: 12px; padding: 20px; max-width: 500px; width: 90%; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3); }
  .camera-preview-card h4 { margin: 0 0 12px 0; font-size: 16px; font-weight: 700; }
  .camera-video { width: 100%; height: auto; border-radius: 8px; background: #000; display: block; margin-bottom: 12px; }
  .camera-actions { display: flex; gap: 8px; justify-content: flex-end; }

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
