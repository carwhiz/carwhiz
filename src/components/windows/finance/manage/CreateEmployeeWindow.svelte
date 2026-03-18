<!-- ============================================================
     FINANCE > MANAGE > CREATE EMPLOYEE WINDOW
     Purpose: Create a new employee with file uploads
     Window ID: finance-create-employee
     Logic:
       - Employee Name, Ledger Type, Joining Date, Salary, Aadhaar Number
       - File uploads: Aadhaar Card, CV, Other Documents (multiple)
       - On save: create ledger (category=Employee), create employee, upload files
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';

  // ---- Form state ----
  let employee_name = '';
  let ledger_type_id = '';
  let joining_date = '';
  let salary: string = '';
  let aadhaar_number = '';

  // ---- File state ----
  let aadhaarFile: File | null = null;
  let aadhaarInputEl: HTMLInputElement;
  let cvFile: File | null = null;
  let cvInputEl: HTMLInputElement;
  let otherDocs: { file: File; name: string }[] = [];
  let otherDocInputEl: HTMLInputElement;

  // ---- Master data ----
  let ledgerTypes: { id: string; name: string }[] = [];

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  onMount(() => {
    loadLedgerTypes();
  });

  async function loadLedgerTypes() {
    const { data } = await supabase.from('ledger_types').select('id, name').order('sort_order');
    ledgerTypes = (data as { id: string; name: string }[]) || [];
  }

  function handleAadhaarFile() {
    const files = aadhaarInputEl?.files;
    if (files && files.length > 0) aadhaarFile = files[0];
  }

  function clearAadhaarFile() {
    aadhaarFile = null;
    if (aadhaarInputEl) aadhaarInputEl.value = '';
  }

  function handleCvFile() {
    const files = cvInputEl?.files;
    if (files && files.length > 0) cvFile = files[0];
  }

  function clearCvFile() {
    cvFile = null;
    if (cvInputEl) cvInputEl.value = '';
  }

  function handleOtherDocs() {
    const files = otherDocInputEl?.files;
    if (files) {
      for (let i = 0; i < files.length; i++) {
        otherDocs = [...otherDocs, { file: files[i], name: files[i].name }];
      }
    }
    if (otherDocInputEl) otherDocInputEl.value = '';
  }

  function removeOtherDoc(idx: number) {
    otherDocs = otherDocs.filter((_, i) => i !== idx);
  }

  async function uploadFile(file: File, prefix: string): Promise<string | null> {
    const fileExt = file.name.split('.').pop();
    const fileName = `${prefix}/${crypto.randomUUID()}.${fileExt}`;
    const { error } = await supabase.storage.from('employee-files').upload(fileName, file);
    if (error) throw new Error('Upload failed: ' + error.message);
    return fileName;
  }

  async function handleSave() {
    if (!employee_name.trim()) { saveError = 'Employee Name is required'; return; }
    if (!ledger_type_id) { saveError = 'Ledger Type is required'; return; }

    saving = true;
    saveError = '';
    saveSuccess = '';

    try {
      // 1. Get Employee ledger category
      const { data: catData } = await supabase
        .from('ledger_categories')
        .select('id')
        .eq('name', 'Employee')
        .single();

      // 2. Create ledger entry
      const { data: ledgerData, error: ledgerErr } = await supabase.from('ledger').insert({
        ledger_name: employee_name.trim(),
        ledger_type_id,
        ledger_category_id: catData?.id || null,
        reference_type: 'employee',
        opening_balance: 0,
        status: 'active',
        created_by: $authStore.user?.id || null,
      }).select('id').single();

      if (ledgerErr || !ledgerData) {
        saveError = ledgerErr?.message || 'Failed to create ledger';
        saving = false;
        return;
      }

      // 3. Upload files
      let aadhaar_file_path: string | null = null;
      let cv_file_path: string | null = null;

      if (aadhaarFile) {
        aadhaar_file_path = await uploadFile(aadhaarFile, 'aadhaar');
      }
      if (cvFile) {
        cv_file_path = await uploadFile(cvFile, 'cv');
      }

      // 4. Insert employee
      const { data: empData, error: empErr } = await supabase.from('employees').insert({
        employee_name: employee_name.trim(),
        ledger_id: ledgerData.id,
        ledger_type_id,
        joining_date: joining_date || null,
        salary: salary ? parseFloat(salary) : null,
        aadhaar_number: aadhaar_number.trim() || null,
        aadhaar_file_path,
        cv_file_path,
        created_by: $authStore.user?.id || null,
      }).select('id').single();

      if (empErr || !empData) {
        saveError = empErr?.message || 'Failed to create employee';
        saving = false;
        return;
      }

      // 5. Update ledger reference_id
      await supabase.from('ledger').update({ reference_id: empData.id, updated_by: $authStore.user?.id || null }).eq('id', ledgerData.id);

      // 6. Upload other documents
      for (const doc of otherDocs) {
        const docPath = await uploadFile(doc.file, 'documents');
        if (docPath) {
          await supabase.from('employee_documents').insert({
            employee_id: empData.id,
            file_name: doc.name,
            file_path: docPath,
            file_type: doc.file.type || 'application/octet-stream',
          });
        }
      }

      saveSuccess = 'Employee created successfully!';

      // Reset form
      employee_name = ''; ledger_type_id = ''; joining_date = ''; salary = ''; aadhaar_number = '';
      aadhaarFile = null; cvFile = null; otherDocs = [];
      if (aadhaarInputEl) aadhaarInputEl.value = '';
      if (cvInputEl) cvInputEl.value = '';

      setTimeout(() => (saveSuccess = ''), 3000);
    } catch (err: any) {
      saveError = err.message || 'An error occurred';
    } finally {
      saving = false;
    }
  }

  function handleCancel() {
    windowStore.close('finance-create-employee');
  }
</script>

<div class="create-window">
  <!-- Header -->
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Create Employee</h2>
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
      <!-- Employee Name + Ledger Type -->
      <div class="form-row two-col">
        <div class="field">
          <label for="e-name">Employee Name</label>
          <input id="e-name" type="text" bind:value={employee_name} placeholder="Enter employee name" />
        </div>
        <div class="field">
          <label for="e-type">Ledger Type</label>
          <select id="e-type" bind:value={ledger_type_id}>
            <option value="">Select type...</option>
            {#each ledgerTypes as lt (lt.id)}
              <option value={lt.id}>{lt.name}</option>
            {/each}
          </select>
        </div>
      </div>

      <!-- Joining Date + Salary -->
      <div class="form-row two-col">
        <div class="field">
          <label for="e-join">Joining Date</label>
          <input id="e-join" type="date" bind:value={joining_date} />
        </div>
        <div class="field">
          <label for="e-salary">Salary</label>
          <input id="e-salary" type="number" step="0.01" bind:value={salary} placeholder="0.00" />
        </div>
      </div>

      <!-- Aadhaar Number -->
      <div class="form-row two-col">
        <div class="field">
          <label for="e-aadhaar">Aadhaar Number</label>
          <input id="e-aadhaar" type="text" bind:value={aadhaar_number} placeholder="Enter Aadhaar number" />
        </div>
        <div class="field"></div>
      </div>

      <!-- Aadhaar Card Upload -->
      <div class="upload-section">
        <label>Aadhaar Card Upload</label>
        <div class="upload-row">
          <input type="file" bind:this={aadhaarInputEl} on:change={handleAadhaarFile} class="file-input" />
          {#if aadhaarFile}
            <div class="file-badge">
              <span>{aadhaarFile.name}</span>
              <button class="file-remove" on:click={clearAadhaarFile}>&times;</button>
            </div>
          {/if}
        </div>
      </div>

      <!-- CV Upload -->
      <div class="upload-section">
        <label>CV Upload</label>
        <div class="upload-row">
          <input type="file" bind:this={cvInputEl} on:change={handleCvFile} class="file-input" />
          {#if cvFile}
            <div class="file-badge">
              <span>{cvFile.name}</span>
              <button class="file-remove" on:click={clearCvFile}>&times;</button>
            </div>
          {/if}
        </div>
      </div>

      <!-- Other Documents (multiple) -->
      <div class="upload-section">
        <label>Other Documents</label>
        <div class="upload-row">
          <input type="file" multiple bind:this={otherDocInputEl} on:change={handleOtherDocs} class="file-input" />
        </div>
        {#if otherDocs.length > 0}
          <div class="doc-list">
            {#each otherDocs as doc, i (i)}
              <div class="doc-item">
                <span class="doc-name">{doc.name}</span>
                <button class="file-remove" on:click={() => removeOtherDoc(i)}>&times;</button>
              </div>
            {/each}
          </div>
        {/if}
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
  .field input[type="text"],
  .field input[type="number"],
  .field input[type="date"],
  .field select { padding:9px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; transition:border-color .15s; background:white; }
  .field input:focus, .field select:focus { border-color:#C41E3A; box-shadow:0 0 0 3px rgba(249,115,22,.1); }

  .upload-section { display:flex; flex-direction:column; gap:6px; }
  .upload-section > label { font-size:12px; font-weight:600; color:#374151; }
  .upload-row { display:flex; align-items:center; gap:10px; }
  .file-input { font-size:13px; color:#374151; }
  .file-badge { display:inline-flex; align-items:center; gap:6px; background:#fff7ed; border:1px solid #fed7aa; border-radius:6px; padding:4px 10px; font-size:12px; color:#C41E3A; }
  .file-remove { background:none; border:none; color:#dc2626; font-size:16px; cursor:pointer; padding:0 2px; line-height:1; }
  .file-remove:hover { color:#991b1b; }

  .doc-list { display:flex; flex-direction:column; gap:4px; margin-top:4px; }
  .doc-item { display:flex; align-items:center; gap:8px; background:#f9fafb; border:1px solid #e5e7eb; border-radius:6px; padding:5px 10px; }
  .doc-name { font-size:12px; color:#374151; flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }

  .form-footer { display:flex; justify-content:flex-end; gap:10px; padding:14px 20px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-cancel { padding:9px 20px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:8px; font-size:14px; font-weight:500; color:#6b7280; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .btn-save { padding:9px 28px; background:#7c3aed; border:none; border-radius:8px; font-size:14px; font-weight:600; color:white; cursor:pointer; transition:background .15s; }
  .btn-save:hover { background:#6d28d9; }
  .btn-save:disabled { opacity:.6; cursor:not-allowed; }

  @media (max-width:700px) { .two-col { flex-direction:column; } }
</style>
