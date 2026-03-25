<!-- Salary Structure Modal Component -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '../../../lib/supabaseClient';
  import { authStore } from '../../../stores/authStore';

  export let employee: any;

  const dispatch = createEventDispatcher();

  let loading = false;
  let baseSalary = 0;
  let bonus = 0;
  let deductions = 0;
  let netSalary = 0;
  let error = '';

  async function loadCurrentSalary() {
    const { data, error: err } = await supabase
      .from('employee_salaries')
      .select('*')
      .eq('user_id', employee.id)
      .eq('is_active', true)
      .maybeSingle();

    if (err) {
      console.error('Error loading salary:', err);
    } else if (data) {
      baseSalary = data.base_salary;
      bonus = data.bonus;
      deductions = data.deductions;
      calculateNet();
    }
  }

  function calculateNet() {
    netSalary = baseSalary + bonus - deductions;
  }

  async function saveSalaryStructure() {
    error = '';
    if (!baseSalary || baseSalary < 0) {
      error = 'Base salary must be greater than 0';
      return;
    }

    loading = true;

    try {
      // First, mark old record as inactive
      await supabase
        .from('employee_salaries')
        .update({ is_active: false, updated_by: $authStore.user?.id })
        .eq('user_id', employee.id)
        .eq('is_active', true);

      // Then insert new salary record
      const { error: insertErr } = await supabase
        .from('employee_salaries')
        .insert({
          user_id: employee.id,
          base_salary: baseSalary,
          bonus: bonus,
          deductions: deductions,
          effective_from: new Date().toISOString().split('T')[0],
          is_active: true,
          created_by: $authStore.user?.id,
          updated_by: $authStore.user?.id,
        });

      if (insertErr) {
        error = insertErr.message;
        loading = false;
        return;
      }

      dispatch('saved');
    } catch (err: any) {
      error = err.message;
      loading = false;
    }
  }

  loadCurrentSalary();
</script>

<div class="modal-overlay" on:click={() => dispatch('close')}>
  <div class="modal" on:click|stopPropagation>
    <div class="modal-header">
      <h3>Edit Salary Structure</h3>
      <button class="close-btn" on:click={() => dispatch('close')}>×</button>
    </div>

    <div class="modal-body">
      <div class="form-group">
        <label for="base-salary">Base Salary (₹)</label>
        <input
          id="base-salary"
          type="number"
          bind:value={baseSalary}
          on:change={calculateNet}
          min="0"
          step="100"
          placeholder="Enter base salary"
        />
      </div>

      <div class="form-group">
        <label for="bonus">Bonus / Allowance (₹)</label>
        <input
          id="bonus"
          type="number"
          bind:value={bonus}
          on:change={calculateNet}
          min="0"
          step="100"
          placeholder="Enter bonus (optional)"
        />
      </div>

      <div class="form-group">
        <label for="deductions">Deductions (₹)</label>
        <input
          id="deductions"
          type="number"
          bind:value={deductions}
          on:change={calculateNet}
          min="0"
          step="100"
          placeholder="Enter deductions (optional)"
        />
      </div>

      <div class="form-group net-salary-display">
        <label>Net Salary (₹)</label>
        <div class="net-value">
          {netSalary.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </div>
      </div>

      {#if error}
        <div class="error-msg">{error}</div>
      {/if}
    </div>

    <div class="modal-footer">
      <button class="btn-cancel" on:click={() => dispatch('close')}>Cancel</button>
      <button class="btn-save" on:click={saveSalaryStructure} disabled={loading}>
        {loading ? 'Saving...' : 'Save Salary Structure'}
      </button>
    </div>
  </div>
</div>

<style>
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
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
    width: 90%;
    max-width: 400px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
  }

  .modal-header {
    padding: 16px 20px;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 24px;
    cursor: pointer;
    color: #6b7280;
    padding: 0;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-btn:hover {
    color: #111827;
  }

  .modal-body {
    padding: 16px 20px;
    overflow-y: auto;
    flex: 1;
  }

  .form-group {
    margin-bottom: 16px;
  }

  .form-group label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #6b7280;
    margin-bottom: 4px;
  }

  .form-group input {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
    box-sizing: border-box;
  }

  .form-group input:focus {
    border-color: #f59e0b;
  }

  .net-salary-display {
    background: #f9fafb;
    padding: 12px;
    border-radius: 6px;
  }

  .net-value {
    font-size: 18px;
    font-weight: 700;
    color: #16a34a;
    font-family: 'Courier New', monospace;
  }

  .error-msg {
    background: #fee2e2;
    color: #dc2626;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 12px;
    margin-top: 12px;
  }

  .modal-footer {
    padding: 12px 20px;
    border-top: 1px solid #e5e7eb;
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    flex-shrink: 0;
  }

  .btn-cancel {
    padding: 8px 16px;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    color: #6b7280;
    transition: all 0.15s;
  }

  .btn-cancel:hover {
    background: #f9fafb;
  }

  .btn-save {
    padding: 8px 16px;
    background: #16a34a;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    transition: all 0.15s;
  }

  .btn-save:hover:not(:disabled) {
    background: #15803d;
  }

  .btn-save:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
</style>
