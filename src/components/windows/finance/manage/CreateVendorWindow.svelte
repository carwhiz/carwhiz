<!-- ============================================================
     FINANCE > MANAGE > CREATE VENDOR WINDOW
     Purpose: Full form to create a new vendor
     Window ID: finance-create-vendor
     Logic:
       - Multiple phone numbers (add/remove)
       - Auto-create ledger with type=Payables on save
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';

  // ---- Form state ----
  let name = '';
  let state = '';
  let district = '';
  let place = '';
  let pin_code = '';
  let address_detail = '';
  let email = '';
  let phones: string[] = [''];

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  function addPhone() { phones = [...phones, '']; }
  function removePhone(i: number) { phones = phones.filter((_, idx) => idx !== i); }

  async function handleSave() {
    if (!name.trim()) { saveError = 'Name is required'; return; }

    const validPhones = phones.map(p => p.trim()).filter(p => p);

    saving = true;
    saveError = '';
    saveSuccess = '';

    // 1. Get Payables ledger type
    const { data: ltData, error: ltErr } = await supabase
      .from('ledger_types')
      .select('id')
      .eq('name', 'Payables')
      .single();

    if (ltErr || !ltData) {
      saving = false;
      saveError = 'Could not find Payables ledger type';
      return;
    }

    // 2. Create ledger entry
    const { data: ledgerData, error: ledgerErr } = await supabase
      .from('ledger')
      .insert({
        ledger_name: name.trim(),
        ledger_type_id: ltData.id,
        reference_type: 'vendor',
        opening_balance: 0,
        status: 'active',
        created_by: $authStore.user?.id || null,
      })
      .select('id')
      .single();

    if (ledgerErr || !ledgerData) {
      saving = false;
      saveError = 'Failed to create ledger: ' + (ledgerErr?.message || '');
      return;
    }

    // 3. Create vendor
    const { data: vendorData, error: vendorErr } = await supabase
      .from('vendors')
      .insert({
        name: name.trim(),
        state: state.trim() || null,
        district: district.trim() || null,
        place: place.trim() || null,
        pin_code: pin_code.trim() || null,
        address_detail: address_detail.trim() || null,
        email: email.trim() || null,
        ledger_id: ledgerData.id,
        created_by: $authStore.user?.id || null,
      })
      .select('id')
      .single();

    if (vendorErr || !vendorData) {
      saving = false;
      saveError = 'Failed to create vendor: ' + (vendorErr?.message || '');
      return;
    }

    // 4. Update ledger reference_id
    await supabase.from('ledger').update({ reference_id: vendorData.id, updated_by: $authStore.user?.id || null }).eq('id', ledgerData.id);

    // 5. Save phones
    if (validPhones.length > 0) {
      const phoneRows = validPhones.map(phone => ({ vendor_id: vendorData.id, phone }));
      await supabase.from('vendor_phones').insert(phoneRows);
    }

    saving = false;
    saveSuccess = 'Vendor saved successfully!';

    // Reset
    name = ''; state = ''; district = ''; place = '';
    pin_code = ''; address_detail = ''; email = '';
    phones = [''];

    setTimeout(() => (saveSuccess = ''), 3000);
  }

  function handleCancel() {
    windowStore.close('finance-create-vendor');
  }
</script>

<div class="create-window">
  <!-- Header -->
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Create Vendor</h2>
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
      <!-- Name + Email -->
      <div class="form-row two-col">
        <div class="field">
          <label for="v-name">Name</label>
          <input id="v-name" type="text" bind:value={name} placeholder="Vendor name" />
        </div>
        <div class="field">
          <label for="v-email">Email</label>
          <input id="v-email" type="text" bind:value={email} placeholder="Email address" />
        </div>
      </div>

      <!-- State + District -->
      <div class="form-row two-col">
        <div class="field">
          <label for="v-state">State</label>
          <input id="v-state" type="text" bind:value={state} placeholder="State" />
        </div>
        <div class="field">
          <label for="v-district">District</label>
          <input id="v-district" type="text" bind:value={district} placeholder="District" />
        </div>
      </div>

      <!-- Place + Pin Code -->
      <div class="form-row two-col">
        <div class="field">
          <label for="v-place">Place</label>
          <input id="v-place" type="text" bind:value={place} placeholder="Place" />
        </div>
        <div class="field">
          <label for="v-pin">Pin Code</label>
          <input id="v-pin" type="text" bind:value={pin_code} placeholder="Pin code" />
        </div>
      </div>

      <!-- Address Detail -->
      <div class="form-row">
        <div class="field" style="flex:1">
          <label for="v-addr">Address Detail</label>
          <textarea id="v-addr" bind:value={address_detail} placeholder="Full address details" rows="3"></textarea>
        </div>
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
        {#each phones as phone, i}
          <div class="multi-row">
            <input type="text" bind:value={phones[i]} placeholder="Phone number" />
            {#if phones.length > 1}
              <button class="remove-btn" on:click={() => removePhone(i)} type="button" title="Remove">&times;</button>
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
      {saving ? 'Saving...' : 'Save'}
    </button>
  </div>
</div>

<style>
  .create-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }

  .form-header { display:flex; align-items:center; justify-content:space-between; padding:14px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#F97316; color:#EA580C; }
  .form-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }

  .form-body { flex:1; overflow-y:auto; padding:24px; }
  .msg { padding:10px 14px; border-radius:6px; font-size:13px; font-weight:500; margin-bottom:16px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; }

  .form-card { background:white; border:1px solid #e5e7eb; border-radius:12px; padding:24px; display:flex; flex-direction:column; gap:18px; max-width:700px; }
  .form-row { display:flex; gap:16px; }
  .two-col > .field { flex:1; }
  .field { display:flex; flex-direction:column; }
  .field label { font-size:12px; font-weight:600; color:#374151; margin-bottom:4px; }
  .field input[type="text"], .field textarea { padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; background:white; font-family:inherit; }
  .field input:focus, .field textarea:focus { border-color:#F97316; box-shadow:0 0 0 3px rgba(249,115,22,.1); }
  .field textarea { resize:vertical; }

  .multi-section { display:flex; flex-direction:column; gap:8px; }
  .multi-header { display:flex; align-items:center; justify-content:space-between; }
  .multi-header label { font-size:12px; font-weight:600; color:#374151; }
  .add-btn { display:inline-flex; align-items:center; gap:4px; padding:5px 12px; background:white; border:1px solid #F97316; border-radius:6px; color:#F97316; font-size:12px; font-weight:600; cursor:pointer; transition:all .15s; }
  .add-btn:hover { background:#F97316; color:white; }
  .multi-row { display:flex; align-items:center; gap:8px; }
  .multi-row input { flex:1; padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; }
  .multi-row input:focus { border-color:#F97316; box-shadow:0 0 0 3px rgba(249,115,22,.1); }
  .remove-btn { display:flex; align-items:center; justify-content:center; width:30px; height:30px; background:#fef2f2; border:1px solid #fecaca; border-radius:6px; color:#ef4444; font-size:18px; cursor:pointer; line-height:1; transition:all .15s; }
  .remove-btn:hover { background:#ef4444; color:white; border-color:#ef4444; }

  .form-footer { display:flex; justify-content:flex-end; gap:10px; padding:14px 20px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-cancel { padding:9px 20px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:8px; font-size:14px; font-weight:500; color:#6b7280; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .btn-save { padding:9px 28px; background:#F97316; border:none; border-radius:8px; font-size:14px; font-weight:600; color:white; cursor:pointer; transition:background .15s; }
  .btn-save:hover { background:#EA580C; }
  .btn-save:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:700px) { .two-col { flex-direction:column; } }
</style>
