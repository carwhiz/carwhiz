<!-- ============================================================
     FINANCE > MANAGE > EDIT CUSTOMER WINDOW
     Purpose: Edit an existing customer's details
     Window ID: finance-edit-customer-{customerId}
     Logic:
       - Load existing customer data
       - Allow editing name, place, gender
       - Manage phone numbers (add/remove)
       - Manage vehicle numbers (add/remove)
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';

  export let customerId = '';

  // ---- Form state ----
  let name = '';
  let place = '';
  let gender = '';
  let phones: { id: string; phone: string }[] = [];
  let vehicleNumbers: { id: string; vehicle_number: string }[] = [];
  let newPhones: string[] = [];
  let newVehicleNumbers: string[] = [];

  // ---- Save state ----
  let loading = true;
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  onMount(() => { loadCustomer(); });

  async function loadCustomer() {
    if (!customerId) { saveError = 'No customer ID provided'; return; }

    const { data, error } = await supabase
      .from('customers')
      .select(`
        id, name, place, gender,
        customer_phones ( id, phone ),
        customer_vehicle_numbers ( id, vehicle_number )
      `)
      .eq('id', customerId)
      .single();

    loading = false;

    if (error) {
      saveError = 'Failed to load customer: ' + error.message;
      return;
    }

    if (data) {
      name = data.name;
      place = data.place || '';
      gender = data.gender || '';
      phones = data.customer_phones || [];
      vehicleNumbers = data.customer_vehicle_numbers || [];
    }
  }

  function addPhone() { newPhones = [...newPhones, '']; }
  function removePhone(i: number) { newPhones = newPhones.filter((_, idx) => idx !== i); }
  function removeExistingPhone(id: string) { phones = phones.filter(p => p.id !== id); }

  function addVehicleNumber() { newVehicleNumbers = [...newVehicleNumbers, '']; }
  function removeVehicleNumber(i: number) { newVehicleNumbers = newVehicleNumbers.filter((_, idx) => idx !== i); }
  function removeExistingVehicle(id: string) { vehicleNumbers = vehicleNumbers.filter(v => v.id !== id); }

  async function handleSave() {
    if (!name.trim()) { saveError = 'Name is required'; return; }

    const validNewPhones = newPhones.map(p => p.trim()).filter(p => p);
    const validNewVehicles = newVehicleNumbers.map(v => v.trim()).filter(v => v);

    saving = true;
    saveError = '';
    saveSuccess = '';

    // 1. Update customer basic info
    const { error: updateErr } = await supabase
      .from('customers')
      .update({
        name: name.trim(),
        place: place.trim() || null,
        gender: gender || null,
        updated_by: $authStore.user?.id || null,
      })
      .eq('id', customerId);

    if (updateErr) {
      saving = false;
      saveError = 'Failed to update customer: ' + updateErr.message;
      return;
    }

    // 2. Delete removed phones
    const removedPhoneIds = phones.filter(p => !phones.some(existing => existing.id === p.id)).map(p => p.id);
    for (const phoneId of removedPhoneIds) {
      await supabase.from('customer_phones').delete().eq('id', phoneId);
    }

    // 3. Add new phones
    if (validNewPhones.length > 0) {
      const phoneRows = validNewPhones.map(phone => ({ customer_id: customerId, phone }));
      await supabase.from('customer_phones').insert(phoneRows);
    }

    // 4. Delete removed vehicles
    const removedVehicleIds = vehicleNumbers.filter(v => !vehicleNumbers.some(existing => existing.id === v.id)).map(v => v.id);
    for (const vehicleId of removedVehicleIds) {
      await supabase.from('customer_vehicle_numbers').delete().eq('id', vehicleId);
    }

    // 5. Add new vehicle numbers
    if (validNewVehicles.length > 0) {
      const vRows = validNewVehicles.map(vehicle_number => ({ customer_id: customerId, vehicle_number }));
      await supabase.from('customer_vehicle_numbers').insert(vRows);
    }

    saving = false;
    saveSuccess = 'Customer updated successfully!';
    newPhones = [];
    newVehicleNumbers = [];

    setTimeout(() => {
      saveSuccess = '';
      window.dispatchEvent(new CustomEvent('customersUpdated', { detail: { customerId } }));
      windowStore.close(`finance-edit-customer-${customerId}`);
    }, 1500);
  }

  function handleCancel() {
    windowStore.close(`finance-edit-customer-${customerId}`);
  }
</script>

{#if loading}
  <div class="loading-container">
    <div class="spinner"></div>
    <p>Loading customer...</p>
  </div>
{:else}
  <div class="edit-window">
    <!-- Header -->
    <div class="form-header">
      <div class="header-left">
        <button class="back-btn" on:click={handleCancel} title="Back">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>Edit Customer</h2>
      </div>
    </div>

    <!-- Body -->
    <div class="form-body">
      {#if saveError}
        <div class="msg msg-error">{saveError}</div>
      {/if}
      {#if saveSuccess}
        <div class="msg msg-success">{saveSuccess}</div>
      {/if}

      <div class="form-card">
        <!-- Name + Gender -->
        <div class="form-row two-col">
          <div class="field">
            <label for="cust-name">Name</label>
            <input id="cust-name" type="text" bind:value={name} placeholder="Customer name" />
          </div>
          <div class="field">
            <label for="cust-gender">Gender</label>
            <select id="cust-gender" bind:value={gender}>
              <option value="">Select...</option>
              <option value="male">Male</option>
              <option value="female">Female</option>
              <option value="other">Other</option>
            </select>
          </div>
        </div>

        <!-- Place -->
        <div class="form-row two-col">
          <div class="field">
            <label for="cust-place">Place</label>
            <input id="cust-place" type="text" bind:value={place} placeholder="Enter place" />
          </div>
          <div class="field"></div>
        </div>

        <!-- Phone Numbers -->
        <div class="multi-section">
          <div class="multi-header">
            <label>Phone Numbers</label>
            <button class="add-btn" on:click={addPhone} type="button">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
              Add Phone
            </button>
          </div>

          <!-- Existing phones -->
          {#each phones as phone}
            <div class="multi-row existing">
              <input type="text" value={phone.phone} disabled />
              <button class="remove-btn" on:click={() => removeExistingPhone(phone.id)} type="button" title="Remove">&times;</button>
            </div>
          {/each}

          <!-- New phones -->
          {#each newPhones as phone, i}
            <div class="multi-row">
              <input type="text" bind:value={newPhones[i]} placeholder="Phone number" />
              {#if newPhones.length > 0}
                <button class="remove-btn" on:click={() => removePhone(i)} type="button" title="Remove">&times;</button>
              {/if}
            </div>
          {/each}
        </div>

        <!-- Vehicle Numbers -->
        <div class="multi-section">
          <div class="multi-header">
            <label>Vehicle Numbers</label>
            <button class="add-btn" on:click={addVehicleNumber} type="button">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
              Add Vehicle Number
            </button>
          </div>

          <!-- Existing vehicles -->
          {#each vehicleNumbers as vehicle}
            <div class="multi-row existing">
              <input type="text" value={vehicle.vehicle_number} disabled />
              <button class="remove-btn" on:click={() => removeExistingVehicle(vehicle.id)} type="button" title="Remove">&times;</button>
            </div>
          {/each}

          <!-- New vehicles -->
          {#each newVehicleNumbers as vn, i}
            <div class="multi-row">
              <input type="text" bind:value={newVehicleNumbers[i]} placeholder="Vehicle number" />
              {#if newVehicleNumbers.length > 0}
                <button class="remove-btn" on:click={() => removeVehicleNumber(i)} type="button" title="Remove">&times;</button>
              {/if}
            </div>
          {/each}
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="form-footer">
      <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
      <button class="btn-save" on:click={handleSave} disabled={saving}>
        {saving ? 'Saving...' : 'Update'}
      </button>
    </div>
  </div>
{/if}

<style>
  .loading-container { width:100%; height:100%; display:flex; align-items:center; justify-content:center; flex-direction:column; gap:16px; background:#fafafa; }
  .spinner { width:36px; height:36px; border:3px solid #e5e7eb; border-top-color:#C41E3A; border-radius:50%; animation:spin .6s linear infinite; }
  @keyframes spin { to { transform:rotate(360deg); } }

  .edit-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }

  .form-header { display:flex; align-items:center; justify-content:space-between; padding:14px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#C41E3A; color:#C41E3A; }
  .form-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }

  .form-body { flex:1; overflow-y:auto; padding:24px; width:100%; box-sizing:border-box; }
  .msg { padding:10px 14px; border-radius:6px; font-size:13px; font-weight:500; margin-bottom:16px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; }

  .form-card { background:white; border:1px solid #e5e7eb; border-radius:12px; padding:24px; display:flex; flex-direction:column; gap:18px; max-width:700px; }
  .form-row { display:flex; gap:16px; }
  .two-col > .field { flex:1; }
  .field { display:flex; flex-direction:column; }
  .field label { font-size:12px; font-weight:600; color:#374151; margin-bottom:4px; }
  .field input[type="text"], .field select { padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; background:white; }
  .field input:focus, .field select:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,.1); }

  /* Multi-input sections */
  .multi-section { display:flex; flex-direction:column; gap:8px; }
  .multi-header { display:flex; align-items:center; justify-content:space-between; }
  .multi-header label { font-size:12px; font-weight:600; color:#374151; }
  .add-btn { display:inline-flex; align-items:center; gap:4px; padding:5px 12px; background:white; border:1px solid #C41E3A; border-radius:6px; color:#C41E3A; font-size:12px; font-weight:600; cursor:pointer; transition:all .15s; }
  .add-btn:hover { background:#C41E3A; color:white; }
  .multi-row { display:flex; align-items:center; gap:8px; }
  .multi-row input { flex:1; padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; }
  .multi-row input:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,.1); }
  .multi-row.existing input { background:#f9fafb; cursor:not-allowed; }
  .multi-row.existing input:focus { box-shadow:none; border-color:#d1d5db; }
  .remove-btn { display:flex; align-items:center; justify-content:center; width:30px; height:30px; background:#fef2f2; border:1px solid #fecaca; border-radius:6px; color:#ef4444; font-size:18px; cursor:pointer; line-height:1; transition:all .15s; }
  .remove-btn:hover { background:#ef4444; color:white; border-color:#ef4444; }

  .form-footer { display:flex; justify-content:flex-end; gap:10px; padding:14px 20px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-cancel { padding:9px 20px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:8px; font-size:14px; font-weight:500; color:#6b7280; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .btn-save { padding:9px 28px; background:#C41E3A; border:none; border-radius:8px; font-size:14px; font-weight:600; color:white; cursor:pointer; transition:background .15s; }
  .btn-save:hover { background:#C41E3A; }
  .btn-save:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:700px) { .two-col { flex-direction:column; } }
</style>
