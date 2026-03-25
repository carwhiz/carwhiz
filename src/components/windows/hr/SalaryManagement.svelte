<!-- ============================================================
     HR > SALARY MANAGEMENT
     Purpose: Manage employee salaries, structure, and payments
     Shows employee list with salary info and payment tracking
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../lib/supabaseClient';
  import { authStore } from '../../../stores/authStore';
  import { windowStore } from '../../../stores/windowStore';
  import SalaryStructureModal from './SalaryStructureModal.svelte';
  import SalaryPaymentModal from './SalaryPaymentModal.svelte';
  import PaymentHistoryModal from './PaymentHistoryModal.svelte';

  interface Employee {
    id: string;
    email: string;
    base_salary: number;
    bonus: number;
    deductions: number;
    net_salary: number;
    paid_this_month: number;
    remaining_salary: number;
    payment_count: number;
    last_payment_date: string | null;
  }

  let employees: Employee[] = [];
  let loading = true;
  let selectedMonth = new Date().toISOString().split('T')[0].substring(0, 7);
  let searchQuery = '';
  let selectedEmployee: Employee | null = null;
  let showSalaryStructureModal = false;
  let showPaymentModal = false;
  let showPaymentHistory = false;

  // Summary stats
  let monthlyTotalSalary = 0;
  let monthlyTotalPaid = 0;
  let pendingLiability = 0;

  onMount(() => {
    loadEmployees();
  });

  async function loadEmployees() {
    loading = true;
    const { data, error } = await supabase
      .from('vw_employee_salary_summary')
      .select('*')
      .order('email');

    if (error) {
      console.error('Error loading employees:', error);
    } else {
      employees = data || [];
      calculateSummary();
    }
    loading = false;
  }

  function calculateSummary() {
    monthlyTotalSalary = employees.reduce((sum, e) => sum + (e.net_salary || 0), 0);
    monthlyTotalPaid = employees.reduce((sum, e) => sum + (e.paid_this_month || 0), 0);
    pendingLiability = monthlyTotalSalary - monthlyTotalPaid;
  }

  function formatCurrency(val: number): string {
    if (!val) return '₹0.00';
    return '₹' + val.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function formatDate(dateStr: string | null): string {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
  }

  function openSalaryStructure(emp: Employee) {
    selectedEmployee = emp;
    showSalaryStructureModal = true;
  }

  function openPaymentModal(emp: Employee) {
    selectedEmployee = emp;
    showPaymentModal = true;
  }

  function openPaymentHistory(emp: Employee) {
    selectedEmployee = emp;
    showPaymentHistory = true;
  }

  function closeSalaryStructure() {
    showSalaryStructureModal = false;
    selectedEmployee = null;
  }

  function closePaymentModal() {
    showPaymentModal = false;
    selectedEmployee = null;
  }

  function closePaymentHistory() {
    showPaymentHistory = false;
    selectedEmployee = null;
  }

  async function onSalaryStructureSaved() {
    closeSalaryStructure();
    await loadEmployees();
  }

  async function onPaymentProcessed() {
    closePaymentModal();
    await loadEmployees();
  }

  $: filteredEmployees = employees.filter(e => {
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      if (!e.email.toLowerCase().includes(q)) return false;
    }
    return true;
  });
</script>

<div class="salary-management">
  <div class="header">
    <h2>💰 Salary Management</h2>
    <div class="header-controls">
      <input
        type="month"
        bind:value={selectedMonth}
        class="month-selector"
      />
      <input
        type="text"
        placeholder="Search employee..."
        bind:value={searchQuery}
        class="search-input"
      />
    </div>
  </div>

  <!-- Summary Cards -->
  <div class="summary-cards">
    <div class="card">
      <div class="card-label">Monthly Salary Expense</div>
      <div class="card-value">{formatCurrency(monthlyTotalSalary)}</div>
      <div class="card-subtext">Total liability</div>
    </div>
    <div class="card">
      <div class="card-label">Total Paid</div>
      <div class="card-value">{formatCurrency(monthlyTotalPaid)}</div>
      <div class="card-subtext">This month</div>
    </div>
    <div class="card pending">
      <div class="card-label">Pending Liability</div>
      <div class="card-value">{formatCurrency(pendingLiability)}</div>
      <div class="card-subtext">Remaining to pay</div>
    </div>
  </div>

  <!-- Employee Table -->
  <div class="table-section">
    {#if loading}
      <div class="status-msg">Loading employees...</div>
    {:else if filteredEmployees.length === 0}
      <div class="status-msg">No employees found.</div>
    {:else}
      <table class="employees-table">
        <thead>
          <tr>
            <th>Employee</th>
            <th class="amt">Net Salary</th>
            <th class="amt">Paid (Month)</th>
            <th class="amt">Remaining</th>
            <th class="center">Payments</th>
            <th class="center">Last Payment</th>
            <th class="actions">Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredEmployees as emp (emp.id)}
            <tr>
              <td class="emp-name">{emp.user_name || emp.email}</td>
              <td class="amt">{formatCurrency(emp.net_salary)}</td>
              <td class="amt paid">{formatCurrency(emp.paid_this_month)}</td>
              <td class="amt remaining" class:critical={emp.remaining_salary > 0}>
                {formatCurrency(emp.remaining_salary)}
              </td>
              <td class="center">{emp.payment_count}</td>
              <td class="center date-cell">{formatDate(emp.last_payment_date)}</td>
              <td class="actions">
                <button class="action-btn edit" on:click={() => openSalaryStructure(emp)} title="Edit Salary">
                  ✎
                </button>
                <button class="action-btn pay" on:click={() => openPaymentModal(emp)} title="Pay Salary">
                  ₹
                </button>
                <button class="action-btn history" on:click={() => openPaymentHistory(emp)} title="Payment History">
                  📋
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>

  <!-- Modals -->
  {#if showSalaryStructureModal && selectedEmployee}
    <SalaryStructureModal employee={selectedEmployee} on:saved={onSalaryStructureSaved} on:close={closeSalaryStructure} />
  {/if}

  {#if showPaymentModal && selectedEmployee}
    <SalaryPaymentModal employee={selectedEmployee} on:processed={onPaymentProcessed} on:close={closePaymentModal} />
  {/if}

  {#if showPaymentHistory && selectedEmployee}
    <PaymentHistoryModal employee={selectedEmployee} on:close={closePaymentHistory} />
  {/if}
</div>

<style>
  .salary-management {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #fafafa;
    overflow: hidden;
  }

  .header {
    padding: 16px 20px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .header h2 {
    margin: 0 0 12px 0;
    font-size: 18px;
    font-weight: 700;
    color: #111827;
  }

  .header-controls {
    display: flex;
    gap: 12px;
    align-items: center;
  }

  .month-selector {
    padding: 6px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
  }

  .month-selector:focus {
    border-color: #f59e0b;
  }

  .search-input {
    flex: 1;
    max-width: 250px;
    padding: 6px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
  }

  .search-input:focus {
    border-color: #f59e0b;
  }

  .summary-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 12px;
    padding: 12px 20px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .card {
    padding: 12px;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    text-align: center;
  }

  .card.pending {
    background: #fef3c7;
    border-color: #f59e0b;
  }

  .card-label {
    font-size: 12px;
    color: #6b7280;
    margin-bottom: 4px;
  }

  .card-value {
    font-size: 16px;
    font-weight: 700;
    color: #111827;
    font-family: 'Courier New', monospace;
  }

  .card-subtext {
    font-size: 11px;
    color: #9ca3af;
    margin-top: 2px;
  }

  .table-section {
    flex: 1;
    overflow: auto;
    padding: 12px 20px;
  }

  .status-msg {
    padding: 20px;
    text-align: center;
    color: #9ca3af;
    font-size: 13px;
  }

  .employees-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    background: white;
  }

  thead th {
    background: #f9fafb;
    padding: 10px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 2px solid #e5e7eb;
    white-space: nowrap;
  }

  tbody td {
    padding: 10px;
    border-bottom: 1px solid #f3f4f6;
    color: #111827;
  }

  tbody tr:hover {
    background: #fffbeb;
  }

  .emp-name {
    font-weight: 500;
  }

  .amt {
    text-align: right;
    font-family: 'Courier New', monospace;
    font-weight: 500;
  }

  .amt.paid {
    color: #16a34a;
  }

  .amt.remaining {
    color: #9ca3af;
  }

  .amt.remaining.critical {
    color: #dc2626;
    font-weight: 600;
  }

  .center {
    text-align: center;
  }

  .date-cell {
    font-size: 12px;
    color: #6b7280;
  }

  .actions {
    text-align: center;
    white-space: nowrap;
  }

  .action-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    margin: 0 2px;
    border: 1px solid #d1d5db;
    background: white;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    transition: all 0.15s;
  }

  .action-btn:hover {
    background: #f3f4f6;
  }

  .action-btn.edit {
    color: #2563eb;
    border-color: #2563eb;
  }

  .action-btn.edit:hover {
    background: #eff6ff;
  }

  .action-btn.pay {
    color: #16a34a;
    border-color: #16a34a;
  }

  .action-btn.pay:hover {
    background: #f0fdf4;
  }

  .action-btn.history {
    color: #7c3aed;
    border-color: #7c3aed;
  }

  .action-btn.history:hover {
    background: #f5f3ff;
  }
</style>
