<!-- ============================================================
     PRODUCTS > MANAGE > VEHICLES WINDOW
     Purpose: Vehicle listing page with table and Create button
     Section: Products > Manage > Vehicles
     Window ID: products-vehicles
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface VehicleRow {
    id: string;
    model_name: string;
    makes: { name: string } | null;
    generations: { name: string } | null;
    generation_types: { name: string } | null;
    variants: { name: string } | null;
    gearboxes: { name: string } | null;
    fuel_types: { name: string } | null;
    body_sides: { name: string } | null;
    created_at: string;
  }

  let vehicles: VehicleRow[] = [];
  let loading = true;
  let error = '';
  let searchQuery = '';

  $: filteredVehicles = searchQuery
    ? vehicles.filter(v =>
        v.model_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (v.makes?.name || '').toLowerCase().includes(searchQuery.toLowerCase())
      )
    : vehicles;

  onMount(() => {
    loadVehicles();
  });

  async function loadVehicles() {
    loading = true;
    error = '';

    const { data, error: dbError } = await supabase
      .from('vehicles')
      .select(`
        id, model_name, created_at,
        makes ( name ),
        generations ( name ),
        generation_types ( name ),
        variants ( name ),
        gearboxes ( name ),
        fuel_types ( name ),
        body_sides ( name )
      `)
      .order('created_at', { ascending: false });

    loading = false;

    if (dbError) {
      error = dbError.message;
      return;
    }

    vehicles = (data as unknown as VehicleRow[]) || [];
  }

  function openCreateVehicle() {
    windowStore.open('products-create-vehicle', 'Create Vehicle');
  }

  function openEditVehicle(vehicleId: string) {
    windowStore.open('products-edit-vehicle-' + vehicleId, 'Edit Vehicle');
  }

  async function deleteVehicle(vehicleId: string, modelName: string) {
    if (!confirm(`Are you sure you want to delete vehicle "${modelName}"? This action cannot be undone.`)) return;

    const { error: delErr } = await supabase
      .from('vehicles')
      .delete()
      .eq('id', vehicleId);

    if (delErr) {
      alert(`Error deleting vehicle: ${delErr.message}`);
    } else {
      loadVehicles();
    }
  }

  // Expose reload for external calls (after create/edit)
  export { loadVehicles };
</script>

<div class="vehicles-window">
  <!-- Top Controls -->
  <div class="top-controls">
    <div class="title-area">
      <h2>Vehicles</h2>
      <span class="record-count">{vehicles.length} record{vehicles.length !== 1 ? 's' : ''}</span>
    </div>
    <div class="actions-area">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
        </svg>
        <input type="text" bind:value={searchQuery} placeholder="Search vehicles..." />
      </div>
      <button class="btn-create" on:click={openCreateVehicle}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        Create Vehicle
      </button>
    </div>
  </div>

  <!-- Table Section -->
  <div class="table-container">
    {#if loading}
      <div class="table-status">Loading vehicles...</div>
    {:else if error}
      <div class="table-status error">{error}</div>
    {:else if filteredVehicles.length === 0}
      <div class="table-status">
        {searchQuery ? 'No vehicles match your search' : 'No vehicles created yet'}
      </div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Model Name</th>
            <th>Make</th>
            <th>Generation</th>
            <th>Gen. Type</th>
            <th>Variant</th>
            <th>Gearbox</th>
            <th>Fuel Type</th>
            <th>Body Side</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredVehicles as vehicle, i (vehicle.id)}
            <tr>
              <td class="num">{i + 1}</td>
              <td class="model">{vehicle.model_name}</td>
              <td>{vehicle.makes?.name || '—'}</td>
              <td>{vehicle.generations?.name || '—'}</td>
              <td>{vehicle.generation_types?.name || '—'}</td>
              <td>{vehicle.variants?.name || '—'}</td>
              <td>{vehicle.gearboxes?.name || '—'}</td>
              <td>{vehicle.fuel_types?.name || '—'}</td>
              <td>{vehicle.body_sides?.name || '—'}</td>
              <td class="actions">
                <button class="btn-edit" on:click={() => openEditVehicle(vehicle.id)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                  </svg>
                  Edit
                </button>
                <button class="btn-delete" on:click={() => deleteVehicle(vehicle.id, vehicle.model_name)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                    <path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/>
                  </svg>
                  Delete
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>

<style>
  .vehicles-window {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #fafafa;
    box-sizing: border-box;
  }

  /* ---- Top Controls ---- */
  .top-controls {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
    box-sizing: border-box;
  }

  .title-area {
    display: flex;
    align-items: baseline;
    gap: 10px;
  }

  .title-area h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 700;
    color: #111827;
  }

  .record-count {
    font-size: 12px;
    color: #9ca3af;
    font-weight: 500;
  }

  .actions-area {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
  }

  .search-box svg {
    color: #9ca3af;
    flex-shrink: 0;
  }

  .search-box input {
    border: none;
    background: none;
    outline: none;
    font-size: 13px;
    width: 180px;
    color: #374151;
  }

  .btn-create {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background: #C41E3A;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
    white-space: nowrap;
  }

  .btn-create:hover {
    background: #C41E3A;
  }

  /* ---- Table ---- */
  .table-container {
    flex: 1;
    overflow: auto;
    padding: 0;
    width: 100%;
    box-sizing: border-box;
  }

  .table-status {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 200px;
    color: #9ca3af;
    font-size: 14px;
  }

  .table-status.error {
    color: #ef4444;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    box-sizing: border-box;
  }

  thead {
    position: sticky;
    top: 0;
    z-index: 2;
  }

  th {
    background: #f9fafb;
    padding: 10px 12px;
    text-align: left;
    font-weight: 600;
    color: #6b7280;
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    border-bottom: 1px solid #e5e7eb;
    border-right: 1px solid #e5e7eb;
    white-space: nowrap;
  }

  td {
    padding: 10px 12px;
    color: #374151;
    border-bottom: 1px solid #f3f4f6;
    border-right: 1px solid #e5e7eb;
    white-space: nowrap;
  }

  tr:hover td {
    background: #fffbf5;
  }

  .num {
    color: #9ca3af;
    width: 40px;
  }

  .model {
    font-weight: 600;
    color: #111827;
  }

  .actions {
    width: 150px;
    display: flex;
    gap: 8px;
  }

  .btn-edit {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 5px 10px;
    background: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 5px;
    font-size: 12px;
    font-weight: 500;
    color: #C41E3A;
    cursor: pointer;
    transition: all 0.15s;
  }

  .btn-edit:hover {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
  }

  .btn-delete {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 5px 10px;
    background: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 5px;
    font-size: 12px;
    font-weight: 500;
    color: #ef4444;
    cursor: pointer;
    transition: all 0.15s;
  }

  .btn-delete:hover {
    background: #ef4444;
    color: white;
    border-color: #ef4444;
  }
</style>
