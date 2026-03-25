<!-- Salary Payment Modal Component -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '../../../lib/supabaseClient';
  import { authStore } from '../../../stores/authStore';

  export let employee: any;

  const dispatch = createEventDispatcher();

  let loading = false;
  let paymentDate = new Date().toISOString().split('T')[0];
  let paymentTime = new Date().toTimeString().substring(0, 5);
  let totalSalary = employee.net_salary || 0;
  let amountPaid = totalSalary;
  let paymentMethod = 'bank_transfer';
  let description = '';
  let error = '';
  let success = '';

  const paymentMethods = [
    { value: 'bank_transfer', label: 'Bank Transfer' },
    { value: 'cash', label: 'Cash' },
    { value: 'check', label: 'Check' },
    { value: 'upi', label: 'UPI' },
  ];

  function validatePayment(): boolean {
    error = '';
    if (!paymentDate) {
      error = 'Please select payment date';
      return false;
    }
    if (!paymentTime) {
      error = 'Please select payment time';
      return false;
    }
    if (amountPaid <= 0) {
      error = 'Amount must be greater than 0';
      return false;
    }
    if (amountPaid > totalSalary) {
      error = 'Cannot pay more than total salary';
      return false;
    }
    return true;
  }

  async function processPayment() {
    if (!validatePayment()) return;

    loading = true;
    error = '';
    success = '';

    try {
      // Combine date and time for payment_time
      const paymentDateTime = `${paymentDate}T${paymentTime}:00`;

      // Call the RPC function to process salary payment
      const { data, error: rpcError } = await supabase.rpc('fn_process_salary_payment', {
        p_user_id: employee.id,
        p_payment_date: paymentDate,
        p_total_salary: totalSalary,
        p_amount_paid: amountPaid,
        p_payment_method: paymentMethod,
        p_description: description || `Salary payment for ${paymentDate}`,
        p_created_by: $authStore.user?.id,
      });

      if (rpcError) {
        error = rpcError.message;
        loading = false;
        return;
      }

      if (data && data.success) {
        success = `✓ Salary payment of ₹${amountPaid.toLocaleString('en-IN')} processed successfully!`;
        setTimeout(() => {
          dispatch('processed');
        }, 1000);
      } else {
        error = data?.message || 'Failed to process payment';
      }
    } catch (err: any) {
      error = err.message;
    }

    loading = false;
  }
</script>

<div class="modal-overlay" on:click={() => dispatch('close')}>
  <div class="modal" on:click|stopPropagation>
    <div class="modal-header">
      <h3>💳 Pay Salary</h3>
      <button class="close-btn" on:click={() => dispatch('close')}>×</button>
    </div>

    <div class="modal-body">
      <div class="employee-info">
        <div class="info-label">Employee</div>
        <div class="info-value">{employee.user_name || employee.email}</div>
      </div>

      <div class="salary-info">
        <div class="info-item">
          <span class="label">Total Salary</span>
          <span class="value">₹{totalSalary.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
        </div>
        <div class="info-item">
          <span class="label">Paid This Month</span>
          <span class="value">₹{employee.paid_this_month.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
        </div>
        <div class="info-item">
          <span class="label">Remaining</span>
          <span class="value remaining">₹{employee.remaining_salary.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
        </div>
      </div>

      <div class="form-group">
        <label for="pay-date">Payment Date *</label>
        <input
          id="pay-date"
          type="date"
          bind:value={paymentDate}
        />
      </div>

      <div class="form-group">
        <label for="pay-time">Payment Time *</label>
        <input
          id="pay-time"
          type="time"
          bind:value={paymentTime}
        />
      </div>

      <div class="form-group">
        <label for="amount">Amount to Pay (₹) *</label>
        <input
          id="amount"
          type="number"
          bind:value={amountPaid}
          min="0"
          max={totalSalary}
          step="100"
          placeholder="Enter amount"
        />
        {#if amountPaid < totalSalary}
          <div class="hint">Partial payment - Remaining: ₹{(totalSalary - amountPaid).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
        {/if}
      </div>

      <div class="form-group">
        <label for="method">Payment Method</label>
        <select id="method" bind:value={paymentMethod}>
          {#each paymentMethods as method}
            <option value={method.value}>{method.label}</option>
          {/each}
        </select>
      </div>

      <div class="form-group">
        <label for="description">Description / Comments</label>
        <textarea
          id="description"
          bind:value={description}
          placeholder="Optional: Reference number, notes, etc."
          rows="3"
        />
      </div>

      {#if error}
        <div class="error-msg">{error}</div>
      {/if}

      {#if success}
        <div class="success-msg">{success}</div>
      {/if}
    </div>

    <div class="modal-footer">
      <button class="btn-cancel" on:click={() => dispatch('close')}>Cancel</button>
      <button class="btn-pay" on:click={processPayment} disabled={loading}>
        {loading ? 'Processing...' : `Pay ₹${amountPaid.toLocaleString('en-IN')}`}
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
    max-width: 450px;
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

  .employee-info {
    background: #f9fafb;
    padding: 12px;
    border-radius: 6px;
    margin-bottom: 12px;
  }

  .info-label {
    font-size: 11px;
    color: #6b7280;
    margin-bottom: 4px;
  }

  .info-value {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
  }

  .salary-info {
    display: flex;
    flex-direction: column;
    gap: 8px;
    background: #eff6ff;
    padding: 12px;
    border-radius: 6px;
    margin-bottom: 16px;
  }

  .info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 13px;
  }

  .info-item .label {
    color: #6b7280;
    font-weight: 500;
  }

  .info-item .value {
    font-weight: 600;
    color: #111827;
    font-family: 'Courier New', monospace;
  }

  .info-item .value.remaining {
    color: #dc2626;
  }

  .form-group {
    margin-bottom: 14px;
  }

  .form-group label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #6b7280;
    margin-bottom: 4px;
  }

  .form-group input,
  .form-group select,
  .form-group textarea {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
    box-sizing: border-box;
    font-family: inherit;
  }

  .form-group input:focus,
  .form-group select:focus,
  .form-group textarea:focus {
    border-color: #f59e0b;
  }

  .form-group textarea {
    resize: vertical;
  }

  .hint {
    font-size: 11px;
    color: #9ca3af;
    margin-top: 2px;
  }

  .error-msg {
    background: #fee2e2;
    color: #dc2626;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 12px;
    margin-top: 12px;
  }

  .success-msg {
    background: #dcfce7;
    color: #16a34a;
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

  .btn-pay {
    padding: 8px 16px;
    background: #2563eb;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    transition: all 0.15s;
  }

  .btn-pay:hover:not(:disabled) {
    background: #1d4ed8;
  }

  .btn-pay:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
</style>
