<!-- ============================================================
     SHARED > EDIT MASTER DATA POPUP
     Purpose: Small popup to edit an existing master data entry
     Props: title, tableName, itemId, itemName, onClose, onUpdated
     ============================================================ -->

<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '../../lib/supabaseClient';
  import { authStore } from '../../stores/authStore';

  export let title: string = 'Edit';
  export let tableName: string = '';
  export let itemId: string = '';
  export let itemName: string = '';

  const dispatch = createEventDispatcher();

  let name = itemName;
  let saving = false;
  let error = '';

  async function handleSave() {
    if (!name.trim()) {
      error = 'Name is required';
      return;
    }

    saving = true;
    error = '';

    const { data, error: dbError } = await supabase
      .from(tableName)
      .update({ name: name.trim(), updated_by: $authStore.user?.id || null })
      .eq('id', itemId)
      .select()
      .single();

    saving = false;

    if (dbError) {
      error = dbError.message.includes('duplicate')
        ? 'This name already exists'
        : dbError.message;
      return;
    }

    dispatch('updated', data);
  }

  function handleClose() {
    dispatch('close');
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') handleClose();
    if (e.key === 'Enter') handleSave();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="popup-overlay" on:click|self={handleClose}>
  <div class="popup-card">
    <div class="popup-header">
      <h3>{title}</h3>
      <button class="close-btn" on:click={handleClose}>&times;</button>
    </div>

    <div class="popup-body">
      <label class="field-label">Name</label>
      <input
        type="text"
        bind:value={name}
        placeholder="Enter name..."
        class="field-input"
        class:error={!!error}
      />
      {#if error}
        <p class="error-text">{error}</p>
      {/if}
    </div>

    <div class="popup-footer">
      <button class="btn-cancel" on:click={handleClose}>Cancel</button>
      <button class="btn-save" on:click={handleSave} disabled={saving}>
        {saving ? 'Saving...' : 'Update'}
      </button>
    </div>
  </div>
</div>

<style>
  .popup-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .popup-card {
    background: white;
    border-radius: 12px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
    width: 360px;
    max-width: 90vw;
    overflow: hidden;
  }

  .popup-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    background: linear-gradient(135deg, #C41E3A, #C41E3A);
    color: white;
  }

  .popup-header h3 {
    margin: 0;
    font-size: 15px;
    font-weight: 600;
  }

  .close-btn {
    background: none;
    border: none;
    color: white;
    font-size: 22px;
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
    opacity: 0.8;
  }

  .close-btn:hover {
    opacity: 1;
  }

  .popup-body {
    padding: 20px;
  }

  .field-label {
    display: block;
    font-size: 13px;
    font-weight: 600;
    color: #374151;
    margin-bottom: 6px;
  }

  .field-input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 14px;
    outline: none;
    transition: border-color 0.15s;
    box-sizing: border-box;
  }

  .field-input:focus {
    border-color: #C41E3A;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
  }

  .field-input.error {
    border-color: #ef4444;
  }

  .error-text {
    color: #ef4444;
    font-size: 12px;
    margin: 6px 0 0;
  }

  .popup-footer {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    padding: 12px 20px 16px;
  }

  .btn-cancel {
    padding: 8px 16px;
    background: #f3f4f6;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
  }

  .btn-cancel:hover {
    background: #e5e7eb;
  }

  .btn-save {
    padding: 8px 20px;
    background: #C41E3A;
    border: none;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 600;
    color: white;
    cursor: pointer;
    transition: background 0.15s;
  }

  .btn-save:hover {
    background: #C41E3A;
  }

  .btn-save:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
</style>
