<!-- ============================================================
     HR > MANAGE > MANAGE SHIFT WINDOW
     Purpose: Manage employee shifts and schedules
     Window ID: hr-manage-shift
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
  }

  interface RegularShift {
    id: string;
    start_time: string;
    end_time: string;
    start_buffer: number;
    end_buffer: number;
    overlaps_next_day: boolean;
    date_from: string;
    date_to: string;
    created_at: string;
  }

  let activeTab: 'regular' | 'special' = 'regular';
  let employees: Employee[] = [];
  let regularShifts: RegularShift[] = [];
  let loading = true;
  let error = '';
  let successMessage = '';
  
  // Modal state
  let showModal = false;
  let modalMode: 'create' | 'edit' = 'create';
  let selectedEmployee: Employee | null = null;
  let formData = {
    start_hour: '09',
    start_minute: '00',
    start_period: 'AM',
    start_buffer: 3,
    end_hour: '05',
    end_minute: '00',
    end_period: 'PM',
    end_buffer: 3,
    overlaps_next_day: false,
  };

  onMount(() => {
    loadEmployees();
    loadRegularShifts();
  });

  async function loadEmployees() {
    loading = true;
    error = '';
    
    const { data, error: dbErr } = await supabase
      .from('users')
      .select('id, email, user_name, phone_number, role')
      .eq('is_employee', true)
      .order('user_name');

    if (dbErr) {
      error = dbErr.message;
    } else {
      employees = (data as Employee[]) || [];
    }
    loading = false;
  }

  async function loadRegularShifts() {
    const { data, error: dbErr } = await supabase
      .from('shifts')
      .select('*')
      .order('date_from');

    if (!dbErr) {
      regularShifts = (data as RegularShift[]) || [];
    }
  }

  function openModal(emp?: Employee) {
    selectedEmployee = emp || null;
    showModal = true;
    formData = {
      start_hour: '09',
      start_minute: '00',
      start_period: 'AM',
      start_buffer: 3,
      end_hour: '05',
      end_minute: '00',
      end_period: 'PM',
      end_buffer: 3,
      overlaps_next_day: false,
    };
  }

  function closeModal() {
    showModal = false;
    selectedEmployee = null;
  }

  function calculateWorkingHours() {
    // Convert start time to 24-hour format in minutes
    let startHour = parseInt(formData.start_hour);
    const startMinute = parseInt(formData.start_minute);
    if (formData.start_period === 'PM' && startHour !== 12) startHour += 12;
    if (formData.start_period === 'AM' && startHour === 12) startHour = 0;
    
    // Convert end time to 24-hour format in minutes
    let endHour = parseInt(formData.end_hour);
    const endMinute = parseInt(formData.end_minute);
    if (formData.end_period === 'PM' && endHour !== 12) endHour += 12;
    if (formData.end_period === 'AM' && endHour === 12) endHour = 0;

    let startTotalMinutes = startHour * 60 + startMinute;
    let endTotalMinutes = endHour * 60 + endMinute;

    // If end time is earlier than start time, assume it's next day
    if (endTotalMinutes <= startTotalMinutes) {
      endTotalMinutes += 24 * 60;
    }

    const diffMinutes = endTotalMinutes - startTotalMinutes;
    const hours = Math.floor(diffMinutes / 60);
    const minutes = diffMinutes % 60;

    return { hours, minutes };
  }

  $: workingHours = calculateWorkingHours();

  async function saveShift() {
    if (!$authStore.user?.id) {
      error = 'User not authenticated. Please log in.';
      return;
    }

    const startTime = `${formData.start_hour}:${formData.start_minute}`;
    const endTime = `${formData.end_hour}:${formData.end_minute}`;

    const { error: dbErr } = await supabase.from('shifts').insert({
      start_time: startTime,
      end_time: endTime,
      start_buffer: formData.start_buffer,
      end_buffer: formData.end_buffer,
      overlaps_next_day: formData.overlaps_next_day,
      created_by: $authStore.user.id,
    });

    if (dbErr) {
      error = dbErr.message;
      return;
    }

    successMessage = 'Shift configured successfully!';
    setTimeout(() => successMessage = '', 3000);
    closeModal();
    loadRegularShifts();
  }
</script>

<div class="window">
  <!-- Tab Navigation -->
  <div class="tab-nav">
    <button 
      class="tab" 
      class:active={activeTab === 'regular'}
      on:click={() => activeTab = 'regular'}
    >
      🟢 Regular Shift
    </button>
    <button 
      class="tab" 
      class:active={activeTab === 'special'}
      on:click={() => activeTab = 'special'}
      disabled
    >
      📅 Special Shift (Soon)
    </button>
  </div>

  <!-- Content Area -->
  <div class="content">
    {#if error}
      <div class="alert alert-error">{error}</div>
    {/if}
    
    {#if successMessage}
      <div class="alert alert-success">{successMessage}</div>
    {/if}

    {#if activeTab === 'regular'}
      <!-- Regular Shift Tab -->
      <div class="tab-content">
        <div class="section-header">
          <h3>Configure Regular Shifts for Employees</h3>
          <button class="btn-add-shift" on:click={() => openModal()}>+ Add Regular Shift</button>
        </div>

        <!-- Employees Table -->
        <div class="section">
          <h4>Employees</h4>
          <div class="table-wrapper">
            {#if loading}
              <div class="message">Loading employees...</div>
            {:else if employees.length === 0}
              <div class="message">No employees found.</div>
            {:else}
              <table class="employees-table">
                <thead>
                  <tr>
                    <th>Full Name</th>
                    <th>Email</th>
                    <th>Phone</th>
                    <th>Role</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each employees as emp (emp.id)}
                    <tr>
                      <td>{emp.user_name}</td>
                      <td>{emp.email}</td>
                      <td>{emp.phone_number || '—'}</td>
                      <td>{emp.role || '—'}</td>
                      <td>
                        <button class="btn-action" on:click={() => openModal(emp)}>+ Assign</button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            {/if}
          </div>
        </div>

        <!-- Regular Shifts Table -->
        <div class="section">
          <h4>Regular Shifts</h4>
          <div class="table-wrapper">
            {#if regularShifts.length === 0}
              <div class="message">No regular shifts configured yet.</div>
            {:else}
              <table class="shifts-table">
                <thead>
                  <tr>
                    <th>Start Time</th>
                    <th>End Time</th>
                    <th>Start Buffer (Hrs)</th>
                    <th>End Buffer (Hrs)</th>
                    <th>Overlaps Next Day</th>
                  </tr>
                </thead>
                <tbody>
                  {#each regularShifts as shift (shift.id)}
                    <tr>
                      <td>{shift.start_time}</td>
                      <td>{shift.end_time}</td>
                      <td class="center">{shift.start_buffer}</td>
                      <td class="center">{shift.end_buffer}</td>
                      <td class="center">{shift.overlaps_next_day ? '✓' : '—'}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            {/if}
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>

<!-- Modal: Configure Regular Shift -->
{#if showModal}
  <div class="modal-overlay" on:click={closeModal}>
    <div class="modal" on:click|stopPropagation>
      <div class="modal-header">
        <h3>Configure Regular Shift</h3>
      </div>

      <div class="modal-body">
        <div class="form-group">
          <label>Shift Start Time</label>
          <div class="time-input">
            <select bind:value={formData.start_hour} class="input-sm">
              {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                <option value={h}>{h}</option>
              {/each}
            </select>
            <span>:</span>
            <select bind:value={formData.start_minute} class="input-sm">
              {#each ['00', '15', '30', '45'] as m}
                <option value={m}>{m}</option>
              {/each}
            </select>
            <select bind:value={formData.start_period} class="input-sm">
              <option value="AM">AM</option>
              <option value="PM">PM</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label for="start-buffer">Start Time Buffer (Hours)</label>
          <input
            id="start-buffer"
            type="number"
            bind:value={formData.start_buffer}
            min="0"
            max="12"
            class="form-input"
          />
        </div>

        <div class="form-group">
          <label>Shift End Time</label>
          <div class="time-input">
            <select bind:value={formData.end_hour} class="input-sm">
              {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                <option value={h}>{h}</option>
              {/each}
            </select>
            <span>:</span>
            <select bind:value={formData.end_minute} class="input-sm">
              {#each ['00', '15', '30', '45'] as m}
                <option value={m}>{m}</option>
              {/each}
            </select>
            <select bind:value={formData.end_period} class="input-sm">
              <option value="AM">AM</option>
              <option value="PM">PM</option>
            </select>
          </div>
        </div>

        <div class="form-group working-hours-display">
          <label>Working Hours</label>
          <div class="working-hours-value">
            {workingHours.hours}h {workingHours.minutes}m
          </div>
        </div>

        <div class="form-group">
          <label for="end-buffer">End Time Buffer (Hours)</label>
          <input
            id="end-buffer"
            type="number"
            bind:value={formData.end_buffer}
            min="0"
            max="12"
            class="form-input"
          />
        </div>

        <div class="form-group checkbox">
          <label>
            <input type="checkbox" bind:checked={formData.overlaps_next_day} />
            <span>Shift Overlaps to Next Day</span>
          </label>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" on:click={closeModal}>Cancel</button>
        <button class="btn-save" on:click={saveShift}>Save</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .window {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    background: #f5f5f5;
  }

  .tab-nav {
    display: flex;
    gap: 0;
    background: white;
    border-bottom: 1px solid #e0e0e0;
    flex-shrink: 0;
  }

  .tab {
    padding: 12px 20px;
    border: none;
    background: transparent;
    color: #666;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border-bottom: 3px solid transparent;
    transition: all 0.2s;
  }

  .tab:hover:not(:disabled) {
    color: #333;
    background: #f9f9f9;
  }

  .tab.active {
    color: #1abc9c;
    border-bottom-color: #1abc9c;
  }

  .tab:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
  }

  .tab-content {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .alert {
    padding: 12px 16px;
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

  .section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }

  .section-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #333;
  }

  .btn-add-shift {
    padding: 8px 16px;
    background: #1abc9c;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-add-shift:hover {
    background: #16a085;
  }

  .section {
    background: white;
    border-radius: 6px;
    padding: 16px;
  }

  .section h4 {
    margin: 0 0 12px 0;
    font-size: 13px;
    font-weight: 600;
    color: #333;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .table-wrapper {
    overflow-x: auto;
  }

  .message {
    padding: 20px;
    text-align: center;
    color: #999;
    font-size: 13px;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }

  th {
    background: #f9fafb;
    padding: 10px;
    text-align: left;
    font-weight: 600;
    color: #666;
    border-bottom: 1px solid #e5e7eb;
    white-space: nowrap;
  }

  td {
    padding: 10px;
    border-bottom: 1px solid #f0f0f0;
    color: #333;
  }

  td.center {
    text-align: center;
  }

  .btn-action {
    padding: 5px 12px;
    background: #1abc9c;
    color: white;
    border: none;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-action:hover {
    background: #16a085;
  }

  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .modal {
    background: white;
    border-radius: 8px;
    max-width: 500px;
    width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  }

  .modal-header {
    background: linear-gradient(135deg, #1abc9c 0%, #16a085 100%);
    color: white;
    padding: 16px 20px;
    flex-shrink: 0;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
  }

  .modal-body {
    padding: 20px;
  }

  .form-group {
    margin-bottom: 16px;
  }

  .form-group label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #666;
    margin-bottom: 6px;
    text-transform: uppercase;
    letter-spacing: 0.02em;
  }

  .form-input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    font-size: 13px;
    box-sizing: border-box;
  }

  .form-input:focus {
    outline: none;
    border-color: #1abc9c;
    box-shadow: 0 0 0 2px rgba(26, 188, 156, 0.1);
  }

  .time-input {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .input-sm {
    padding: 8px 10px;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    font-size: 12px;
  }

  .input-sm:focus {
    outline: none;
    border-color: #1abc9c;
  }

  .form-group.checkbox label {
    display: flex;
    align-items: center;
    gap: 8px;
    text-transform: none;
    letter-spacing: normal;
    cursor: pointer;
  }

  .form-group.checkbox input {
    margin: 0;
  }

  .form-group.working-hours-display {
    background: #f0fdfb;
    border: 1px solid #d1f5ee;
    border-radius: 4px;
    padding: 12px;
    margin-bottom: 16px;
  }

  .form-group.working-hours-display label {
    margin-bottom: 8px;
  }

  .working-hours-value {
    font-size: 18px;
    font-weight: 700;
    color: #1abc9c;
    padding: 8px 0;
  }

  .modal-footer {
    display: flex;
    gap: 12px;
    padding: 16px 20px;
    border-top: 1px solid #e0e0e0;
    flex-shrink: 0;
  }

  .btn-cancel,
  .btn-save {
    flex: 1;
    padding: 10px 16px;
    border: none;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-cancel {
    background: #e5e7eb;
    color: #333;
  }

  .btn-cancel:hover {
    background: #d1d5db;
  }

  .btn-save {
    background: #1abc9c;
    color: white;
  }

  .btn-save:hover {
    background: #16a085;
  }
</style>
