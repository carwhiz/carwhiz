<!-- ============================================================
     PRODUCTS > MANAGE > CREATE VEHICLE WINDOW
     Purpose: Full-page form to create new vehicles
     Section: Products > Manage > Create Vehicle
     Window ID: products-create-vehicle
     Layout: 5 vehicle entries per row, each with all fields
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import SearchableDropdown from '../../../shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../../shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../../shared/EditMasterDataPopup.svelte';

  // ---- Master data lists ----
  let makes: { id: string; name: string }[] = [];
  let generations: { id: string; name: string }[] = [];
  let generationTypes: { id: string; name: string }[] = [];
  let variants: { id: string; name: string }[] = [];
  let gearboxes: { id: string; name: string }[] = [];
  let fuelTypes: { id: string; name: string }[] = [];
  let bodySides: { id: string; name: string }[] = [];

  // ---- Vehicle entry form ----
  interface VehicleEntry {
    model_name: string;
    make_id: string;
    generation_id: string;
    generation_type_id: string;
    variant_id: string;
    gearbox_id: string;
    fuel_type_id: string;
    body_side_id: string;
  }

  function emptyEntry(): VehicleEntry {
    return {
      model_name: '',
      make_id: '',
      generation_id: '',
      generation_type_id: '',
      variant_id: '',
      gearbox_id: '',
      fuel_type_id: '',
      body_side_id: '',
    };
  }

  let entries: VehicleEntry[] = [emptyEntry()];

  function addEntry() {
    entries = [...entries, emptyEntry()];
  }

  function removeEntry(index: number) {
    if (entries.length <= 1) return;
    entries = entries.filter((_, i) => i !== index);
  }

  // ---- Popup state ----
  let popupOpen = false;
  let popupTitle = '';
  let popupTable = '';
  let popupTarget: keyof typeof masterReloadMap | '' = '';

  const masterReloadMap = {
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
    popupTarget = table as keyof typeof masterReloadMap;
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
    if (editPopupTarget && masterReloadMap[editPopupTarget as keyof typeof masterReloadMap]) {
      masterReloadMap[editPopupTarget as keyof typeof masterReloadMap]();
    }
  }

  // ---- Load master data ----
  async function loadMasterData(
    table: string,
    setter: (items: { id: string; name: string }[]) => void
  ) {
    const { data } = await supabase.from(table).select('id, name').order('name');
    setter((data as { id: string; name: string }[]) || []);
  }

  onMount(() => {
    loadMasterData('makes', v => (makes = v));
    loadMasterData('generations', v => (generations = v));
    loadMasterData('generation_types', v => (generationTypes = v));
    loadMasterData('variants', v => (variants = v));
    loadMasterData('gearboxes', v => (gearboxes = v));
    loadMasterData('fuel_types', v => (fuelTypes = v));
    loadMasterData('body_sides', v => (bodySides = v));
  });

  // ---- Save ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  async function handleSave() {
    // Validate: at least model_name required on non-empty entries
    const validEntries = entries.filter(e => e.model_name.trim());
    if (validEntries.length === 0) {
      saveError = 'At least one vehicle with a Model Name is required';
      return;
    }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const rows = validEntries.map(e => ({
      model_name: e.model_name.trim(),
      make_id: e.make_id || null,
      generation_id: e.generation_id || null,
      generation_type_id: e.generation_type_id || null,
      variant_id: e.variant_id || null,
      gearbox_id: e.gearbox_id || null,
      fuel_type_id: e.fuel_type_id || null,
      body_side_id: e.body_side_id || null,
      created_by: $authStore.user?.id || null,
    }));

    const { error } = await supabase.from('vehicles').insert(rows);
    saving = false;

    if (error) {
      saveError = error.message;
      return;
    }

    saveSuccess = `${rows.length} vehicle${rows.length > 1 ? 's' : ''} saved successfully!`;
    entries = [emptyEntry()];

    // Refresh vehicles listing if open
    setTimeout(() => {
      saveSuccess = '';
    }, 3000);
  }

  function handleCancel() {
    windowStore.close('products-create-vehicle');
  }
</script>

<div class="create-vehicle-window">
  <!-- ---- Header ---- -->
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back to Vehicles">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <h2>Create Vehicle</h2>
    </div>
    <button class="add-entry-btn" on:click={addEntry}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
        <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
      </svg>
      Add Entry
    </button>
  </div>

  <!-- ---- Form Section (5 per row grid) ---- -->
  <div class="form-body">
    {#if saveError}
      <div class="msg msg-error">{saveError}</div>
    {/if}
    {#if saveSuccess}
      <div class="msg msg-success">{saveSuccess}</div>
    {/if}

    <div class="entries-grid">
      {#each entries as entry, i}
        <div class="entry-card">
          <div class="entry-header">
            <span class="entry-num">#{i + 1}</span>
            {#if entries.length > 1}
              <button class="remove-entry" on:click={() => removeEntry(i)} title="Remove entry">&times;</button>
            {/if}
          </div>

          <!-- Model Name -->
          <div class="field">
            <label>Model Name</label>
            <input type="text" bind:value={entry.model_name} placeholder="Enter model name" />
          </div>

          <!-- Make -->
          <div class="field">
            <SearchableDropdown
              items={makes}
              bind:value={entry.make_id}
              placeholder="Select Make"
              label="Make"
              on:add={() => openAddPopup('makes', 'Add Make')}
              on:edit={(e) => openEditPopup('makes', 'Edit Make', e.detail)}
            />
          </div>

          <!-- Generation -->
          <div class="field">
            <SearchableDropdown
              items={generations}
              bind:value={entry.generation_id}
              placeholder="Select Generation"
              label="Generation"
              on:add={() => openAddPopup('generations', 'Add Generation')}
              on:edit={(e) => openEditPopup('generations', 'Edit Generation', e.detail)}
            />
          </div>

          <!-- Generation Type -->
          <div class="field">
            <SearchableDropdown
              items={generationTypes}
              bind:value={entry.generation_type_id}
              placeholder="Select Gen. Type"
              label="Generation Type"
              on:add={() => openAddPopup('generation_types', 'Add Generation Type')}
              on:edit={(e) => openEditPopup('generation_types', 'Edit Generation Type', e.detail)}
            />
          </div>

          <!-- Variant -->
          <div class="field">
            <SearchableDropdown
              items={variants}
              bind:value={entry.variant_id}
              placeholder="Select Variant"
              label="Variant"
              on:add={() => openAddPopup('variants', 'Add Variant')}
              on:edit={(e) => openEditPopup('variants', 'Edit Variant', e.detail)}
            />
          </div>

          <!-- Gearbox -->
          <div class="field">
            <SearchableDropdown
              items={gearboxes}
              bind:value={entry.gearbox_id}
              placeholder="Select Gearbox"
              label="Gearbox"
              on:add={() => openAddPopup('gearboxes', 'Add Gearbox')}
              on:edit={(e) => openEditPopup('gearboxes', 'Edit Gearbox', e.detail)}
            />
          </div>

          <!-- Fuel Type -->
          <div class="field">
            <SearchableDropdown
              items={fuelTypes}
              bind:value={entry.fuel_type_id}
              placeholder="Select Fuel Type"
              label="Fuel Type"
              on:add={() => openAddPopup('fuel_types', 'Add Fuel Type')}
              on:edit={(e) => openEditPopup('fuel_types', 'Edit Fuel Type', e.detail)}
            />
          </div>

          <!-- Body Side -->
          <div class="field">
            <SearchableDropdown
              items={bodySides}
              bind:value={entry.body_side_id}
              placeholder="Select Body Side"
              label="Body Side"
              on:add={() => openAddPopup('body_sides', 'Add Body Side')}
              on:edit={(e) => openEditPopup('body_sides', 'Edit Body Side', e.detail)}
            />
          </div>
        </div>
      {/each}
    </div>
  </div>

  <!-- ---- Bottom Actions ---- -->
  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    <button class="btn-save" on:click={handleSave} disabled={saving}>
      {saving ? 'Saving...' : 'Save'}
    </button>
  </div>
</div>

<!-- ---- Add Master Data Popup ---- -->
{#if popupOpen}
  <AddMasterDataPopup
    title={popupTitle}
    tableName={popupTable}
    on:close={() => (popupOpen = false)}
    on:created={handlePopupCreated}
  />
{/if}

<!-- ---- Edit Master Data Popup ---- -->
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
  .create-vehicle-window {
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

  .add-entry-btn {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 7px 14px;
    background: white;
    border: 1px solid #F97316;
    border-radius: 6px;
    color: #F97316;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }

  .add-entry-btn:hover {
    background: #F97316;
    color: white;
  }

  /* ---- Form Body ---- */
  .form-body {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
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

  .entries-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
  }

  .entry-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 10px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    transition: box-shadow 0.15s;
  }

  .entry-card:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  }

  .entry-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .entry-num {
    font-size: 13px;
    font-weight: 700;
    color: #F97316;
  }

  .remove-entry {
    width: 22px;
    height: 22px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 4px;
    color: #ef4444;
    font-size: 16px;
    line-height: 1;
    cursor: pointer;
    padding: 0;
  }

  .remove-entry:hover {
    background: #ef4444;
    color: white;
    border-color: #ef4444;
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

  .field input[type="text"] {
    padding: 8px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
    transition: border-color 0.15s;
  }

  .field input[type="text"]:focus {
    border-color: #F97316;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
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

  /* ---- Responsive: fewer columns if narrow ---- */
  @media (max-width: 1200px) {
    .entries-grid {
      grid-template-columns: repeat(3, 1fr);
    }
  }

  @media (max-width: 900px) {
    .entries-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 600px) {
    .entries-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
