<!-- ============================================================
     FINANCE > MANAGE > CREATE LEDGER WINDOW
     Purpose: Create a new ledger entry
     Window ID: finance-create-ledger
     Logic:
       - Ledger Name + Ledger Type always shown
       - If type = Expense or Operational Expense → show Expense Category dropdown
       - If type = Bank → show Bank Account Number field
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import SearchableDropdown from '../../../shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../../shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../../shared/EditMasterDataPopup.svelte';

  // ---- Form state ----
  let ledger_name = '';
  let ledger_type_id = '';
  let ledger_category_id = '';
  let expense_category_id = '';
  let bank_account_number = '';
  let opening_balance: string = '';

  // ---- Master data ----
  let ledgerTypes: { id: string; name: string }[] = [];
  let ledgerCategories: { id: string; name: string }[] = [];
  let expenseCategories: { id: string; name: string }[] = [];

  // ---- Popup state ----
  let addPopupOpen = false;
  let editPopupOpen = false;
  let editPopupItemId = '';
  let editPopupItemName = '';

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  // ---- Computed ----
  $: selectedTypeName = ledgerTypes.find(t => t.id === ledger_type_id)?.name || '';
  $: showExpenseCategory = selectedTypeName === 'Expense' || selectedTypeName === 'Operational Expense';
  $: showBankAccount = selectedTypeName === 'Bank';

  // Reset conditional fields when type changes
  $: if (!showExpenseCategory) expense_category_id = '';
  $: if (!showBankAccount) bank_account_number = '';

  onMount(() => {
    loadLedgerTypes();
    loadLedgerCategories();
    loadExpenseCategories();
  });

  async function loadLedgerTypes() {
    const { data } = await supabase.from('ledger_types').select('id, name').order('sort_order');
    ledgerTypes = (data as { id: string; name: string }[]) || [];
  }

  async function loadLedgerCategories() {
    const { data } = await supabase.from('ledger_categories').select('id, name').order('sort_order');
    ledgerCategories = (data as { id: string; name: string }[]) || [];
  }

  async function loadExpenseCategories() {
    const { data } = await supabase.from('expense_categories').select('id, name').order('name');
    expenseCategories = (data as { id: string; name: string }[]) || [];
  }

  function handleAddExpenseCategory() {
    addPopupOpen = true;
  }

  function handleExpenseCategoryCreated() {
    addPopupOpen = false;
    loadExpenseCategories();
  }

  function handleEditExpenseCategory(e: CustomEvent<{ id: string; name: string }>) {
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleExpenseCategoryUpdated() {
    editPopupOpen = false;
    loadExpenseCategories();
  }

  async function handleSave() {
    if (!ledger_name.trim()) { saveError = 'Ledger Name is required'; return; }
    if (!ledger_type_id) { saveError = 'Ledger Type is required'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    const row: Record<string, any> = {
      ledger_name: ledger_name.trim(),
      ledger_type_id,
      ledger_category_id: ledger_category_id || null,
      expense_category_id: showExpenseCategory && expense_category_id ? expense_category_id : null,
      bank_account_number: showBankAccount && bank_account_number.trim() ? bank_account_number.trim() : null,
      opening_balance: opening_balance ? parseFloat(opening_balance) : 0,
      status: 'active',
      created_by: $authStore.user?.id || null,
    };

    const { error } = await supabase.from('ledger').insert(row);
    saving = false;

    if (error) { saveError = error.message; return; }

    saveSuccess = 'Ledger created successfully!';
    ledger_name = ''; ledger_type_id = ''; ledger_category_id = '';
    expense_category_id = ''; bank_account_number = ''; opening_balance = '';

    setTimeout(() => (saveSuccess = ''), 3000);
  }

  function handleCancel() {
    windowStore.close('finance-create-ledger');
  }
</script>

<div class="create-window">
  <!-- Header -->
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Create Ledger</h2>
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
      <!-- Ledger Name + Ledger Type -->
      <div class="form-row two-col">
        <div class="field">
          <label for="l-name">Ledger Name</label>
          <input id="l-name" type="text" bind:value={ledger_name} placeholder="Enter ledger name" />
        </div>
        <div class="field">
          <label for="l-type">Ledger Type</label>
          <select id="l-type" bind:value={ledger_type_id}>
            <option value="">Select type...</option>
            {#each ledgerTypes as lt (lt.id)}
              <option value={lt.id}>{lt.name}</option>
            {/each}
          </select>
        </div>
      </div>

      <!-- Ledger Category + Opening Balance -->
      <div class="form-row two-col">
        <div class="field">
          <label for="l-cat">Ledger Category</label>
          <select id="l-cat" bind:value={ledger_category_id}>
            <option value="">Select category...</option>
            {#each ledgerCategories as lc (lc.id)}
              <option value={lc.id}>{lc.name}</option>
            {/each}
          </select>
        </div>
        <div class="field">
          <label for="l-bal">Opening Balance</label>
          <input id="l-bal" type="number" step="0.01" bind:value={opening_balance} placeholder="0.00" />
        </div>
      </div>

      <!-- Expense Category (conditional) -->
      {#if showExpenseCategory}
        <div class="form-row two-col">
          <div class="field">
            <SearchableDropdown
              items={expenseCategories}
              bind:value={expense_category_id}
              placeholder="Select Expense Category"
              label="Expense Category"
              on:add={handleAddExpenseCategory}
              on:edit={handleEditExpenseCategory}
            />
          </div>
          <div class="field"></div>
        </div>
      {/if}

      <!-- Bank Account Number (conditional) -->
      {#if showBankAccount}
        <div class="form-row two-col">
          <div class="field">
            <label for="l-bank">Bank Account Number</label>
            <input id="l-bank" type="text" bind:value={bank_account_number} placeholder="Enter account number" />
          </div>
          <div class="field"></div>
        </div>
      {/if}
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

<!-- Add Expense Category Popup -->
{#if addPopupOpen}
  <AddMasterDataPopup
    title="Add Expense Category"
    tableName="expense_categories"
    on:close={() => (addPopupOpen = false)}
    on:created={handleExpenseCategoryCreated}
  />
{/if}

<!-- Edit Expense Category Popup -->
{#if editPopupOpen}
  <EditMasterDataPopup
    title="Edit Expense Category"
    tableName="expense_categories"
    itemId={editPopupItemId}
    itemName={editPopupItemName}
    on:close={() => (editPopupOpen = false)}
    on:updated={handleExpenseCategoryUpdated}
  />
{/if}

<style>
  .create-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }

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
  .field input[type="text"], .field input[type="number"], .field select { padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; background:white; }
  .field input:focus, .field select:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,.1); }

  .form-footer { display:flex; justify-content:flex-end; gap:10px; padding:14px 20px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-cancel { padding:9px 20px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:8px; font-size:14px; font-weight:500; color:#6b7280; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .btn-save { padding:9px 28px; background:#C41E3A; border:none; border-radius:8px; font-size:14px; font-weight:600; color:white; cursor:pointer; transition:background .15s; }
  .btn-save:hover { background:#C41E3A; }
  .btn-save:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:700px) { .two-col { flex-direction:column; } }
</style>
