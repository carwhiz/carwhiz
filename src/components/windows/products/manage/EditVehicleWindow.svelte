<!-- ============================================================
     PRODUCTS > MANAGE > EDIT VEHICLE WINDOW
     Purpose: Full-page form to edit an existing vehicle
     Section: Products > Manage > Edit Vehicle
     Window ID: products-edit-vehicle-{vehicleId}
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import SearchableDropdown from '../../../shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../../shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../../shared/EditMasterDataPopup.svelte';

  export let vehicleId: string = '';

  // ---- Master data lists ----
  let makes: { id: string; name: string }[] = [];
  let generations: { id: string; name: string }[] = [];
  let generationTypes: { id: string; name: string }[] = [];
  let variants: { id: string; name: string }[] = [];
  let gearboxes: { id: string; name: string }[] = [];
  let fuelTypes: { id: string; name: string }[] = [];
  let bodySides: { id: string; name: string }[] = [];

  // ---- Form state ----
  let model_name = '';
  let make_id = '';
  let generation_id = '';
  let generation_type_id = '';
  let variant_id = '';
  let gearbox_id = '';
  let fuel_type_id = '';
  let body_side_id = '';

  let loading = true;
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  // ---- Popup state ----
  let popupOpen = false;
  let popupTitle = '';
  let popupTable = '';
  let popupTarget = '';

  const masterReloadMap: Record<string, () => void> = {
    makes: () => loadMasterData('makes', v => (makes = v)),
    generations: () => loadMasterData('generations', v => (generations = v)),
    generation_types: () => loadMasterData('generation_types', v => (generationTypes = v)),
    variants: () => loadMasterData('variants', v => (variants = v)),
    gearboxes: () => loadMasterData('gearboxes', v => (gearboxes = v)),
    fuel_types: () => loadMasterData('fuel_types', v => (fuelTypes = v)),
    body_sides: () => loadMasterData('body_sides', v => (bodySides = v)),
  };

  function openAddPopup(table: string, title: string) {
    popupTable = table;
    popupTitle = title;
    popupTarget = table;
    popupOpen = true;
  }

  function handlePopupCreated() {
    popupOpen = false;
    if (popupTarget && masterReloadMap[popupTarget]) {
      masterReloadMap[popupTarget]();
    }
  }

  // ---- Edit popup state ----
  let editPopupOpen = false;
  let editPopupTitle = '';
  let editPopupTable = '';
  let editPopupItemId = '';
  let editPopupItemName = '';
  let editPopupTarget = '';

  function openEditPopup(table: string, title: string, item: { id: string; name: string }) {
    editPopupTable = table;
    editPopupTitle = title;
    editPopupItemId = item.id;
    editPopupItemName = item.name;
    editPopupTarget = table;
    editPopupOpen = true;
  }

  function handleEditPopupUpdated() {
    editPopupOpen = false;
    if (editPopupTarget && masterReloadMap[editPopupTarget]) {
      masterReloadMap[editPopupTarget]();
    }
  }

  async function loadMasterData(
    table: string,
    setter: (items: { id: string; name: string }[]) => void
  ) {
    const { data } = await supabase.from(table).select('id, name').order('name');
    setter((data as { id: string; name: string }[]) || []);
  }

  async function loadVehicle() {
    loading = true;
    const { data, error } = await supabase
      .from('vehicles')
      .select('*')
      .eq('id', vehicleId)
      .single();

    if (data) {
      model_name = data.model_name || '';
      make_id = data.make_id || '';
      generation_id = data.generation_id || '';
      generation_type_id = data.generation_type_id || '';
      variant_id = data.variant_id || '';
      gearbox_id = data.gearbox_id || '';
      fuel_type_id = data.fuel_type_id || '';
      body_side_id = data.body_side_id || '';
    }
    loading = false;
  }

  onMount(() => {
    loadMasterData('makes', v => (makes = v));
    loadMasterData('generations', v => (generations = v));
    loadMasterData('generation_types', v => (generationTypes = v));
    loadMasterData('variants', v => (variants = v));
    loadMasterData('gearboxes', v => (gearboxes = v));
    loadMasterData('fuel_types', v => (fuelTypes = v));
    loadMasterData('body_sides', v => (bodySides = v));
    loadVehicle();
  });

  async function handleSave() {
    if (!model_name.trim()) {
      saveError = 'Model Name is required';
      return;
    }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const { error } = await supabase
      .from('vehicles')
      .update({
        model_name: model_name.trim(),
        make_id: make_id || null,
        generation_id: generation_id || null,
        generation_type_id: generation_type_id || null,
        variant_id: variant_id || null,
        gearbox_id: gearbox_id || null,
        fuel_type_id: fuel_type_id || null,
        body_side_id: body_side_id || null,
        updated_at: new Date().toISOString(),
        updated_by: $authStore.user?.id || null,
      })
      .eq('id', vehicleId);

    saving = false;

    if (error) {
      saveError = error.message;
      return;
    }

    saveSuccess = 'Vehicle updated successfully!';
    setTimeout(() => (saveSuccess = ''), 3000);
  }

  function handleCancel() {
    windowStore.close('products-edit-vehicle-' + vehicleId);
  }
</script>

<div class="edit-vehicle-window">
  <!-- Header -->
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Close">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <h2>Edit Vehicle</h2>
    </div>
  </div>

  <!-- Form -->
  <div class="form-body">
    {#if loading}
      <div class="loading-msg">Loading vehicle...</div>
    {:else}
      {#if saveError}
        <div class="msg msg-error">{saveError}</div>
      {/if}
      {#if saveSuccess}
        <div class="msg msg-success">{saveSuccess}</div>
      {/if}

      <div class="fields-grid">
        <div class="field">
          <label>Model Name</label>
          <input type="text" bind:value={model_name} placeholder="Enter model name" />
        </div>
        <div class="field">
          <SearchableDropdown items={makes} bind:value={make_id} placeholder="Select Make" label="Make" on:add={() => openAddPopup('makes', 'Add Make')} on:edit={(e) => openEditPopup('makes', 'Edit Make', e.detail)} />
        </div>
        <div class="field">
          <SearchableDropdown items={generations} bind:value={generation_id} placeholder="Select Generation" label="Generation" on:add={() => openAddPopup('generations', 'Add Generation')} on:edit={(e) => openEditPopup('generations', 'Edit Generation', e.detail)} />
        </div>
        <div class="field">
          <SearchableDropdown items={generationTypes} bind:value={generation_type_id} placeholder="Select Gen. Type" label="Generation Type" on:add={() => openAddPopup('generation_types', 'Add Generation Type')} on:edit={(e) => openEditPopup('generation_types', 'Edit Generation Type', e.detail)} />
        </div>
        <div class="field">
          <SearchableDropdown items={variants} bind:value={variant_id} placeholder="Select Variant" label="Variant" on:add={() => openAddPopup('variants', 'Add Variant')} on:edit={(e) => openEditPopup('variants', 'Edit Variant', e.detail)} />
        </div>
        <div class="field">
          <SearchableDropdown items={gearboxes} bind:value={gearbox_id} placeholder="Select Gearbox" label="Gearbox" on:add={() => openAddPopup('gearboxes', 'Add Gearbox')} on:edit={(e) => openEditPopup('gearboxes', 'Edit Gearbox', e.detail)} />
        </div>
        <div class="field">
          <SearchableDropdown items={fuelTypes} bind:value={fuel_type_id} placeholder="Select Fuel Type" label="Fuel Type" on:add={() => openAddPopup('fuel_types', 'Add Fuel Type')} on:edit={(e) => openEditPopup('fuel_types', 'Edit Fuel Type', e.detail)} />
        </div>
        <div class="field">
          <SearchableDropdown items={bodySides} bind:value={body_side_id} placeholder="Select Body Side" label="Body Side" on:add={() => openAddPopup('body_sides', 'Add Body Side')} on:edit={(e) => openEditPopup('body_sides', 'Edit Body Side', e.detail)} />
        </div>
      </div>
    {/if}
  </div>

  <!-- Footer -->
  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    <button class="btn-save" on:click={handleSave} disabled={saving || loading}>
      {saving ? 'Saving...' : 'Update'}
    </button>
  </div>
</div>

{#if popupOpen}
  <AddMasterDataPopup
    title={popupTitle}
    tableName={popupTable}
    on:close={() => (popupOpen = false)}
    on:created={handlePopupCreated}
  />
{/if}

{#if editPopupOpen}
  <EditMasterDataPopup
    title={editPopupTitle}
    tableName={editPopupTable}
    itemId={editPopupItemId}
    itemName={editPopupItemName}
    on:close={() => (editPopupOpen = false)}
    on:updated={handleEditPopupUpdated}
  />
{/if}

<style>
  .edit-vehicle-window {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #fafafa;
  }

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

  .form-body {
    flex: 1;
    overflow-y: auto;
    padding: 24px;
  }

  .loading-msg {
    text-align: center;
    color: #9ca3af;
    padding: 40px;
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

  .fields-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
  }

  .field label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #374151;
    margin-bottom: 4px;
  }

  .field input[type="text"] {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
    box-sizing: border-box;
    transition: border-color 0.15s;
  }

  .field input[type="text"]:focus {
    border-color: #F97316;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
  }

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

  @media (max-width: 1000px) {
    .fields-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 600px) {
    .fields-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
