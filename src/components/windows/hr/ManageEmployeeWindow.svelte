<!-- ============================================================
     HR > MANAGE > MANAGE EMPLOYEE WINDOW
     Purpose: Comprehensive employee management with detailed files
     Window ID: hr-manage-employee
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../lib/supabaseClient';
  import { authStore } from '../../../stores/authStore';

  interface Employee {
    id: string;
    email: string;
    user_name: string;
    phone_number: string;
    role: string;
    created_at: string;
    date_of_birth?: string;
    blood_group?: string;
    education?: string;
    joining_date?: string;
    driving_license_number?: string;
    aadhar_number?: string;
    bank_account_number?: string;
    bank_name?: string;
    basic_salary?: number;
    resident_location?: string;
    cv_document_url?: string;
  }

  interface EmployeeFile {
    id: string;
    user_id: string;
    nationality: string;
    resident_id: string;
    health_card_number: string;
    health_card_expiry: string;
    sponsorship_status: boolean;
    employment_status: string;
    driving_licence_number: string;
    driving_licence_expiry: string;
    contract_expiry: string;
    whatsapp: string;
    email: string;
  }

  let employees: Employee[] = [];
  let selectedEmployee: Employee | null = null;
  let employeeFile: EmployeeFile | null = null;
  let loading = true;
  let saving = false;
  let error = '';
  let successMessage = '';
  
  // Ledger balance for employee
  let employeeLiable = 0; // Amount we owe to employee (positive Dr balance)
  let employeeReceivable = 0; // Amount employee owes us (negative Cr balance)
  
  // Search
  let searchQuery = '';

  // Edit states
  let editingNationality = false;

  $: filteredEmployees = employees.filter(e => {
    const matchSearch = !searchQuery || 
      (e.user_name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      e.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      e.id.toLowerCase().includes(searchQuery.toLowerCase());
    
    return matchSearch;
  });

  onMount(() => {
    loadEmployees();
  });

  async function loadEmployees() {
    loading = true;
    error = '';
    const { data, error: dbErr } = await supabase
      .rpc('get_employees_extended');

    loading = false;
    if (dbErr) {
      error = dbErr.message;
      return;
    }
    employees = (data as Employee[]) || [];
  }

  async function selectEmployee(emp: Employee) {
    selectedEmployee = emp;
    
    // Load ledger balance for employee
    const { data: ledger } = await supabase
      .from('ledger')
      .select('id, opening_balance')
      .eq('reference_type', 'employees')
      .eq('status', 'active')
      .maybeSingle();
    
    if (ledger) {
      // Fetch ledger entries for this employee
      const { data: entries } = await supabase
        .from('ledger_entries')
        .select('debit, credit')
        .eq('ledger_id', ledger.id);
      
      const opening = ledger.opening_balance || 0;
      const totalDebit = (entries || []).reduce((sum, e) => sum + (e.debit || 0), 0);
      const totalCredit = (entries || []).reduce((sum, e) => sum + (e.credit || 0), 0);
      const balance = opening + totalDebit - totalCredit;
      
      // Positive balance (Dr) = We owe employee | Negative (Cr) = Employee owes us
      if (balance > 0) {
        employeeLiable = balance;
        employeeReceivable = 0;
      } else if (balance < 0) {
        employeeLiable = 0;
        employeeReceivable = Math.abs(balance);
      } else {
        employeeLiable = 0;
        employeeReceivable = 0;
      }
    } else {
      employeeLiable = 0;
      employeeReceivable = 0;
    }
    
    // TODO: Load employee file from database when table is created
    employeeFile = {
      id: '',
      user_id: emp.id,
      nationality: '',
      resident_id: '',
      health_card_number: '',
      health_card_expiry: '',
      sponsorship_status: false,
      employment_status: 'Job (With Finger)',
      driving_licence_number: '',
      driving_licence_expiry: '',
      contract_expiry: '',
      whatsapp: emp.phone_number || '',
      email: emp.email
    };
  }

  function getDaysRemaining(expiryDate: string): number {
    if (!expiryDate) return 0;
    const today = new Date();
    const expiry = new Date(expiryDate);
    const diff = expiry.getTime() - today.getTime();
    return Math.ceil(diff / (1000 * 60 * 60 * 24));
  }

  function formatDate(dateStr: string): string {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    return `${dd}/${mm}/${d.getFullYear()}`;
  }

  function formatDateInput(dateStr: string): string {
    if (!dateStr) return '';
    return dateStr.split('T')[0];
  }

  async function handleFileUpload(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file || !selectedEmployee?.id) return;
    
    // Validate file
    const maxSize = 5 * 1024 * 1024; // 5MB
    const allowedTypes = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
    
    if (!allowedTypes.includes(file.type)) {
      error = 'Invalid file type. Please upload PDF or Word document.';
      return;
    }
    
    if (file.size > maxSize) {
      error = 'File size exceeds 5MB limit.';
      return;
    }
    
    saving = true;
    error = '';
    
    const filePath = `cvs/${selectedEmployee.id}/${Date.now()}_${file.name}`;
    
    // Upload to Supabase Storage
    const { data, error: uploadErr } = await supabase.storage
      .from('documents')
      .upload(filePath, file, { upsert: true });
    
    if (uploadErr) {
      saving = false;
      error = `Upload failed: ${uploadErr.message}`;
      return;
    }
    
    // Get public URL
    const { data: urlData } = supabase.storage
      .from('documents')
      .getPublicUrl(filePath);
    
    // Update selectedEmployee with the file URL
    selectedEmployee.cv_document_url = urlData.publicUrl;
    
    // Save to database
    const { error: dbErr } = await supabase
      .from('users')
      .update({
        cv_document_url: selectedEmployee.cv_document_url,
        updated_by: $authStore.user?.id
      })
      .eq('id', selectedEmployee.id);
    
    saving = false;
    if (dbErr) {
      error = `Failed to save file reference: ${dbErr.message}`;
      return;
    }
    
    successMessage = 'CV uploaded successfully!';
    setTimeout(() => successMessage = '', 3000);
  }

  async function saveNationality() {
    if (!selectedEmployee?.id) return;
    
    saving = true;
    error = '';
    
    const { error: dbErr } = await supabase
      .from('users')
      .update({
        date_of_birth: selectedEmployee.date_of_birth || null,
        blood_group: selectedEmployee.blood_group || null,
        education: selectedEmployee.education || null,
        joining_date: selectedEmployee.joining_date || null,
        driving_license_number: selectedEmployee.driving_license_number || null,
        aadhar_number: selectedEmployee.aadhar_number || null,
        bank_account_number: selectedEmployee.bank_account_number || null,
        bank_name: selectedEmployee.bank_name || null,
        basic_salary: selectedEmployee.basic_salary || null,
        resident_location: selectedEmployee.resident_location || null,
        cv_document_url: selectedEmployee.cv_document_url || null,
        updated_by: $authStore.user?.id
      })
      .eq('id', selectedEmployee.id);
    
    saving = false;
    if (dbErr) {
      error = `Failed to save: ${dbErr.message}`;
      return;
    }
    
    // Update in local array
    const idx = employees.findIndex(e => e.id === selectedEmployee.id);
    if (idx >= 0) {
      employees[idx] = { ...selectedEmployee };
    }
    
    successMessage = 'Employee details saved successfully!';
    setTimeout(() => successMessage = '', 3000);
  }
</script>

<div class="employee-management">
  <!-- Left Section: Search & Filter -->
  <div class="left-panel">
    <div class="search-panel">
      <input
        type="text"
        placeholder="Search by Name or ID"
        bind:value={searchQuery}
        class="filter-input"
      />
    </div>

    <!-- Employee List -->
    <div class="employee-list">
      <table class="list-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Position</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredEmployees as emp (emp.id)}
            <tr
              class="list-row"
              class:active={selectedEmployee?.id === emp.id}
              on:click={() => selectEmployee(emp)}
            >
              <td>{emp.id.substring(0, 8).toUpperCase()}</td>
              <td>{emp.user_name || emp.email}</td>
              <td>{emp.role}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Right Section: Employee Files -->
  <div class="right-panel">
    {#if !selectedEmployee}
      <div class="empty-state"></div>
    {:else if employeeFile}
      <div class="form-container">
        <div class="form-header">
          <div class="header-main">
            <h3>{selectedEmployee.user_name || selectedEmployee.email}</h3>
            <p>{selectedEmployee.email}</p>
          </div>
          
          <div class="header-balance">
            {#if employeeLiable > 0}
              <div class="balance-item liable">
                <span class="label">Liable to Pay</span>
                <span class="amount">₹{employeeLiable.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
              </div>
            {/if}
            
            {#if employeeReceivable > 0}
              <div class="balance-item receivable">
                <span class="label">To Receive</span>
                <span class="amount">₹{employeeReceivable.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
              </div>
            {/if}
            
            {#if employeeLiable === 0 && employeeReceivable === 0}
              <div class="balance-item settled">
                <span class="label">Balance</span>
                <span class="amount">₹0.00</span>
              </div>
            {/if}
          </div>
        </div>

        {#if error}
          <div class="alert alert-error">{error}</div>
        {/if}
        
        {#if successMessage}
          <div class="alert alert-success">{successMessage}</div>
        {/if}

        <div class="form-content">
          <!-- Basic Information -->
          <div class="form-section">
            <h4>Basic Information</h4>
            <div class="form-row">
              <div class="form-group">
                <label>Employee Name</label>
                <input type="text" value={selectedEmployee.user_name || ''} class="form-input" readonly />
              </div>
              <div class="form-group">
                <label>Email</label>
                <input type="email" value={selectedEmployee.email} class="form-input" readonly />
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Phone</label>
                <input type="tel" value={selectedEmployee.phone_number || ''} class="form-input" readonly />
              </div>
              <div class="form-group">
                <label>Role</label>
                <input type="text" value={selectedEmployee.role} class="form-input" readonly />
              </div>
            </div>
          </div>

          <!-- Personal Information -->
          <div class="form-section">
            <h4>Personal Information</h4>
            <div class="form-row">
              <div class="form-group">
                <label>Date of Birth</label>
                <input 
                  type="date" 
                  bind:value={selectedEmployee.date_of_birth}
                  class="form-input"
                />
              </div>
              <div class="form-group">
                <label>Blood Group</label>
                <select bind:value={selectedEmployee.blood_group} class="form-select">
                  <option value="">Select Blood Group</option>
                  <option value="O+">O+</option>
                  <option value="O-">O-</option>
                  <option value="A+">A+</option>
                  <option value="A-">A-</option>
                  <option value="B+">B+</option>
                  <option value="B-">B-</option>
                  <option value="AB+">AB+</option>
                  <option value="AB-">AB-</option>
                </select>
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Aadhar Number</label>
                <input 
                  type="text" 
                  bind:value={selectedEmployee.aadhar_number}
                  placeholder="Enter Aadhar number"
                  class="form-input"
                />
              </div>
              <div class="form-group">
                <label>Resident Location</label>
                <input 
                  type="text" 
                  bind:value={selectedEmployee.resident_location}
                  placeholder="Enter resident location"
                  class="form-input"
                />
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Education</label>
                <textarea 
                  bind:value={selectedEmployee.education}
                  placeholder="Enter education details"
                  class="form-input"
                  style="min-height: 60px; resize: vertical;"
                ></textarea>
              </div>
            </div>
          </div>

          <!-- Employment Information -->
          <div class="form-section">
            <h4>Employment Information</h4>
            <div class="form-row">
              <div class="form-group">
                <label>Joining Date</label>
                <input 
                  type="date" 
                  bind:value={selectedEmployee.joining_date}
                  class="form-input"
                />
              </div>
              <div class="form-group">
                <label>Basic Salary</label>
                <input 
                  type="number" 
                  bind:value={selectedEmployee.basic_salary}
                  placeholder="Enter basic salary"
                  step="0.01"
                  class="form-input"
                />
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Driving License Number</label>
                <input 
                  type="text" 
                  bind:value={selectedEmployee.driving_license_number}
                  placeholder="Enter driving license number"
                  class="form-input"
                />
              </div>
            </div>
          </div>

          <!-- Bank Information -->
          <div class="form-section">
            <h4>Bank Information</h4>
            <div class="form-row">
              <div class="form-group">
                <label>Bank Name</label>
                <input 
                  type="text" 
                  bind:value={selectedEmployee.bank_name}
                  placeholder="Enter bank name"
                  class="form-input"
                />
              </div>
              <div class="form-group">
                <label>Bank Account Number</label>
                <input 
                  type="text" 
                  bind:value={selectedEmployee.bank_account_number}
                  placeholder="Enter account number"
                  class="form-input"
                />
              </div>
            </div>
          </div>

          <!-- Documents -->
          <div class="form-section">
            <h4>Documents</h4>
            <div class="form-row">
              <div class="form-group">
                <label>CV / Resume</label>
                <div class="file-input-wrapper">
                  <input 
                    type="file" 
                    id="cv-upload"
                    on:change={handleFileUpload}
                    accept=".pdf,.doc,.docx"
                    class="file-input"
                  />
                  <label for="cv-upload" class="file-label">📤 Upload CV</label>
                  {#if selectedEmployee.cv_document_url}
                    <p class="file-info">✓ CV Uploaded</p>
                  {/if}
                </div>
              </div>
            </div>
          </div>

          <!-- Form Actions -->
          <div class="form-actions">
            <button class="btn-save-form" on:click={saveNationality} disabled={saving}>
              {saving ? '⏳ Saving...' : '💾 Save Changes'}
            </button>
            <button class="btn-clear-form" on:click={() => {
              selectedEmployee = null;
              employeeFile = null;
            }} disabled={saving}>✕ Clear</button>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>

<style>
  .employee-management {
    width: 100%;
    height: 100%;
    display: flex;
    background: #f5f5f5;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
      'Ubuntu', 'Cantarell', sans-serif;
  }

  /* ===== LEFT PANEL ===== */
  .left-panel {
    width: 35%;
    background: white;
    border-right: 1px solid #e0e0e0;
    display: flex;
    flex-direction: column;
  }

  .search-panel {
    padding: 16px 20px;
    border-bottom: 1px solid #e0e0e0;
    flex-shrink: 0;
  }

  .filter-input {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 13px;
    background: #fafafa;
  }

  .filter-input:focus {
    outline: none;
    border-color: #ff8c00;
    background: white;
  }

  .employee-list {
    flex: 1;
    overflow-y: auto;
    padding: 0;
  }

  .list-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }

  .list-table thead {
    position: sticky;
    top: 0;
    background: #f9f9f9;
  }

  .list-table th {
    padding: 10px 16px;
    text-align: left;
    font-weight: 600;
    color: #666;
    border-bottom: 1px solid #e0e0e0;
    font-size: 11px;
  }

  .list-row {
    cursor: pointer;
    border-bottom: 1px solid #f0f0f0;
    transition: background 0.2s;
  }

  .list-row:hover {
    background: #f9f9f9;
  }

  .list-row.active {
    background: #1abc9c;
  }

  .list-row.active td {
    color: white;
    font-weight: 600;
  }

  .list-row td {
    padding: 10px 16px;
    color: #333;
  }

  /* ===== RIGHT PANEL ===== */
  .right-panel {
    flex: 1;
    background: white;
    padding: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .empty-state {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    background: white;
  }

  .files-header {
    background: linear-gradient(135deg, #1abc9c 0%, #16a085 100%);
    color: white;
    padding: 20px;
    display: flex;
    align-items: center;
    gap: 16px;
    flex-shrink: 0;
  }

  .files-header svg {
    width: 32px;
    height: 32px;
  }

  .header-info h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
  }

  .header-info p {
    margin: 4px 0 0 0;
    font-size: 13px;
    opacity: 0.9;
  }

  .files-content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
    background: white;
  }

  /* ===== FORM STYLES ===== */
  .form-container {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: white;
  }

  .form-header {
    background: linear-gradient(135deg, #1abc9c 0%, #16a085 100%);
    color: white;
    padding: 20px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
  }

  .header-main {
    flex: 1;
  }

  .form-header h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
  }

  .form-header p {
    margin: 4px 0 0 0;
    font-size: 13px;
    opacity: 0.9;
  }

  .header-balance {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
    justify-content: flex-end;
  }

  .balance-item {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    padding: 8px 12px;
    background: rgba(255, 255, 255, 0.15);
    border-radius: 4px;
    backdrop-filter: blur(10px);
    min-width: 130px;
    text-align: right;
  }

  .balance-item .label {
    font-size: 11px;
    font-weight: 500;
    opacity: 0.85;
    text-transform: uppercase;
    letter-spacing: 0.02em;
  }

  .balance-item .amount {
    font-size: 14px;
    font-weight: 700;
    margin-top: 4px;
    font-family: 'Courier New', monospace;
  }

  .balance-item.liable .label {
    color: #ffc107;
  }

  .balance-item.liable .amount {
    color: #fff9e6;
  }

  .balance-item.receivable .label {
    color: #4caf50;
  }

  .balance-item.receivable .amount {
    color: #e8f5e9;
  }

  .balance-item.settled .label {
    color: #b0bec5;
  }

  .balance-item.settled .amount {
    color: #eceff1;
  }

  .form-content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
  }

  .form-section {
    margin-bottom: 24px;
    padding-bottom: 20px;
    border-bottom: 1px solid #e0e0e0;
  }

  .form-section:last-of-type {
    border-bottom: none;
  }

  .form-section h4 {
    margin: 0 0 16px 0;
    font-size: 14px;
    font-weight: 600;
    color: #333;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-bottom: 12px;
  }

  .form-row:last-child {
    margin-bottom: 0;
  }

  .form-group {
    display: flex;
    flex-direction: column;
  }

  .form-group label {
    font-size: 12px;
    font-weight: 600;
    color: #666;
    margin-bottom: 6px;
  }

  .form-input,
  .form-select {
    padding: 10px 12px;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    font-size: 13px;
    font-family: inherit;
    background: #fafafa;
    color: #333;
    transition: all 0.2s;
  }

  .form-input:focus,
  .form-select:focus {
    outline: none;
    border-color: #1abc9c;
    background: white;
    box-shadow: 0 0 0 2px rgba(26, 188, 156, 0.1);
  }

  .form-input[readonly] {
    background: #f0f0f0;
    color: #999;
    cursor: not-allowed;
  }

  textarea.form-input {
    font-family: inherit;
    resize: vertical;
    min-height: 60px;
  }

  .file-input-wrapper {
    position: relative;
  }

  .file-input {
    display: none;
  }

  .file-label {
    display: inline-block;
    padding: 10px 16px;
    background: #1abc9c;
    color: white;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .file-label:hover {
    background: #16a085;
  }

  .file-info {
    margin-top: 8px;
    font-size: 12px;
    color: #16a085;
    font-weight: 600;
  }

  .alert {
    padding: 12px 16px;
    margin: 12px 16px 0 16px;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 500;
  }

  .alert-error {
    background: #fee;
    color: #c00;
    border-left: 4px solid #c00;
  }

  .alert-success {
    background: #efe;
    color: #060;
    border-left: 4px solid #060;
  }

  .toggle-group-form {
    flex-direction: row;
    align-items: flex-end;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    font-size: 13px;
    color: #333;
  }

  .form-checkbox {
    width: 18px;
    height: 18px;
    cursor: pointer;
    accent-color: #1abc9c;
  }

  .form-actions {
    display: flex;
    gap: 12px;
    margin-top: 20px;
    padding-top: 20px;
    border-top: 1px solid #e0e0e0;
    flex-shrink: 0;
  }

  .btn-save-form,
  .btn-clear-form {
    padding: 10px 16px;
    border: none;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    flex: 1;
  }

  .btn-save-form {
    background: #1abc9c;
    color: white;
  }

  .btn-save-form:hover {
    background: #16a085;
  }

  .btn-save-form:disabled,
  .btn-clear-form:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .btn-save-form:disabled:hover {
    background: #1abc9c;
  }

  .btn-clear-form:disabled:hover {
    background: #e74c3c;
  }

  .btn-clear-form {
    background: #e0e0e0;
    color: #666;
  }

  .btn-clear-form:hover {
    background: #d0d0d0;
  }

  .info-card {
    background: white;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    padding: 16px;
    display: flex;
    flex-direction: column;
  }

  .info-card.contact-card {
    grid-column: 1 / -1;
  }

  .card-title {
    font-weight: 600;
    font-size: 13px;
    color: #333;
    margin-bottom: 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid #f0f0f0;
  }

  .info-icon {
    width: 20px;
    height: 20px;
    color: #ff8c00;
    margin-bottom: 8px;
  }

  .card-content {
    flex: 1;
  }

  .card-input {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    font-size: 13px;
    margin-bottom: 8px;
  }

  .card-input:focus {
    outline: none;
    border-color: #1abc9c;
    box-shadow: 0 0 0 2px rgba(26, 188, 156, 0.1);
  }

  .readonly-input {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #e0e0e0;
    border-radius: 4px;
    font-size: 13px;
    background: #fafafa;
    color: #666;
    margin-bottom: 8px;
  }

  .label {
    font-size: 12px;
    color: #666;
    font-weight: 500;
    margin-bottom: 4px;
  }

  .value {
    font-size: 14px;
    color: #333;
    font-weight: 600;
    margin-bottom: 8px;
  }

  .value.orange {
    color: #ff8c00;
  }

  .info-text {
    font-size: 11px;
    color: #ff8c00;
    display: flex;
    align-items: center;
    margin: 4px 0 8px 0;
  }

  /* ===== BUTTONS ===== */
  .btn-save,
  .btn-edit-action,
  .btn-update {
    background: #1abc9c;
    color: white;
    border: none;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
    width: 100%;
    margin-top: 8px;
  }

  .btn-save:hover,
  .btn-edit-action:hover,
  .btn-update:hover {
    background: #16a085;
  }

  .btn-edit {
    background: #1abc9c;
    color: white;
    border: none;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    width: 100%;
    margin-top: 8px;
  }

  .btn-edit:hover {
    background: #16a085;
  }

  .btn-upload {
    background: #ff8c00;
    color: white;
    border: none;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    width: 100%;
    margin-top: 8px;
  }

  .btn-upload:hover {
    background: #ff7c00;
  }

  .file-upload {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid #f0f0f0;
  }

  .file-upload input[type='file'] {
    display: none;
  }

  /* ===== TOGGLE & RADIO ===== */
  .toggle-group {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    background: #f9f9f9;
    border-radius: 4px;
  }

  .toggle-label {
    font-size: 13px;
    font-weight: 600;
    color: #1abc9c;
    flex: 1;
  }

  .toggle-switch {
    width: 40px;
    height: 24px;
    cursor: pointer;
  }

  .radio-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .radio-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    font-size: 12px;
    color: #333;
  }

  .radio-label input[type='radio'] {
    cursor: pointer;
    accent-color: #1abc9c;
  }

  /* ===== CONTACT CARD ===== */
  .contact-form,
  .contact-content {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .contact-field {
    margin-bottom: 12px;
  }

  .contact-field label {
    font-size: 12px;
    color: #666;
    font-weight: 500;
    display: block;
    margin-bottom: 4px;
  }

  .contact-field .value {
    color: #ff8c00;
    font-size: 13px;
    margin: 0;
  }

  /* ===== SCROLLBAR ===== */
  ::-webkit-scrollbar {
    width: 8px;
  }

  ::-webkit-scrollbar-track {
    background: #f1f1f1;
  }

  ::-webkit-scrollbar-thumb {
    background: #ccc;
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: #999;
  }
</style>
