<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../lib/supabaseClient';
  import { authStore } from '../../stores/authStore';
  import { setMobilePage } from '../../stores/mobilePageStore';
  import MobilePageWrapper from '../../components/shared/MobilePageWrapper.svelte';

  interface JobCard {
    id: string;
    job_card_no: string;
    status: string;
    priority: string;
    description: string;
    created_at: string;
    vehicle_id: string;
    customer_id: string;
    customer_name?: string;
    customer_place?: string;
    customer_gender?: string;
    vehicle_model?: string;
    vehicle_make?: string;
    vehicle_generation?: string;
    vehicle_type?: string;
    vehicle_variant?: string;
    vehicle_gearbox?: string;
    vehicle_fuel?: string;
    vehicle_body?: string;
    vehicle_numbers?: string[];
  }

  let jobs: JobCard[] = [];
  let loading = true;
  let error: string | null = null;
  let selectedStatus = 'all';

  const statusOptions = [
    { value: 'all', label: 'All Active Jobs' },
    { value: 'Open', label: 'Open' },
    { value: 'In Progress', label: 'In Progress' }
  ];

  async function loadJobs() {
    loading = true;
    error = null;

    try {
      const userId = $authStore.user?.id;
      if (!userId) {
        error = 'No user logged in';
        jobs = [];
        loading = false;
        return;
      }

      let query = supabase
        .from('job_cards')
        .select(`
          id, 
          job_card_no, 
          status, 
          priority, 
          description, 
          created_at, 
          vehicle_id, 
          customer_id,
          vehicle_number,
          customers(name, place, gender),
          vehicles(model_name, makes(name), generations(name), generation_types(name), variants(name), gearboxes(name), fuel_types(name), body_sides(name))
        `)
        .eq('assigned_user_id', userId)
        .in('status', ['Open', 'In Progress'])
        .order('created_at', { ascending: false });

      if (selectedStatus !== 'all') {
        query = query.eq('status', selectedStatus);
      }

      const { data: jobsList, error: queryError } = await query;

      if (queryError) {
        error = queryError.message;
        jobs = [];
        return;
      }

      jobs = (jobsList || []).map((j: any) => ({
        id: j.id,
        job_card_no: j.job_card_no,
        status: j.status,
        priority: j.priority,
        description: j.description,
        created_at: j.created_at,
        vehicle_id: j.vehicle_id,
        customer_id: j.customer_id,
        customer_name: j.customers?.name || 'N/A',
        customer_place: j.customers?.place || 'N/A',
        customer_gender: j.customers?.gender || 'N/A',
        vehicle_model: j.vehicles?.model_name || 'N/A',
        vehicle_make: j.vehicles?.makes?.name || 'N/A',
        vehicle_generation: j.vehicles?.generations?.name || 'N/A',
        vehicle_type: j.vehicles?.generation_types?.name || 'N/A',
        vehicle_variant: j.vehicles?.variants?.name || 'N/A',
        vehicle_gearbox: j.vehicles?.gearboxes?.name || 'N/A',
        vehicle_fuel: j.vehicles?.fuel_types?.name || 'N/A',
        vehicle_body: j.vehicles?.body_sides?.name || 'N/A',
        vehicle_number: j.vehicle_number || 'N/A'
      }));
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load jobs';
      jobs = [];
    } finally {
      loading = false;
    }
  }

  async function openJobDetail(jobId: string) {
    setMobilePage('job-detail', 'Job Card Details', jobId);
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  function formatDateTime(dateStr: string): string {
    return new Date(dateStr).toLocaleString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function getStatusColor(status: string): string {
    switch (status) {
      case 'Open':
        return '#FF6B6B';
      case 'In Progress':
        return '#4ECDC4';
      case 'Closed':
        return '#95E1D3';
      case 'Billed':
        return '#A8E6CF';
      default:
        return '#CCCCCC';
    }
  }

  function getPriorityBgColor(priority: string): string {
    switch (priority?.toLowerCase()) {
      case 'low':
        return '#E8F5E9';
      case 'normal':
        return '#E3F2FD';
      case 'high':
        return '#FFF3E0';
      case 'urgent':
        return '#FFEBEE';
      default:
        return '#F5F5F5';
    }
  }

  function handleStatusChange(e: Event) {
    const target = e.target as HTMLSelectElement;
    selectedStatus = target.value;
    loadJobs();
  }

  onMount(() => {
    setMobilePage('my-jobs', 'My Jobs');
    loadJobs();
  });
</script>

<MobilePageWrapper>
  <div class="my-jobs-content">
    <div class="filters">
      <select value={selectedStatus} on:change={handleStatusChange} class="status-filter">
        {#each statusOptions as option}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </div>

    {#if loading}
      <div class="loading">Loading jobs...</div>
    {:else if error}
      <div class="error">{error}</div>
    {:else if jobs.length === 0}
      <div class="empty-state">
        <p>No active jobs found</p>
      </div>
    {:else}
      <div class="jobs-list">
        {#each jobs as job (job.id)}
          <div class="job-card">
            <div class="job-header">
              <div class="job-no">{job.job_card_no}</div>
              <div class="status-badge" style="background-color: {getStatusColor(job.status)}">
                {job.status}
              </div>
            </div>
            {#if job.vehicle_number && job.vehicle_number !== 'N/A'}
              <div class="vehicle-number-display">
                <strong>Vehicle #:</strong> {job.vehicle_number}
              </div>
            {/if}
            <button 
              class="manage-btn" 
              on:click={() => openJobDetail(job.id)}
              type="button"
            >
              View & Manage
            </button>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</MobilePageWrapper>

<style>
  .my-jobs-content {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #f5f5f5;
  }

  .filters {
    padding: 12px 16px;
    background: white;
    border-bottom: 1px solid #e0e0e0;
  }

  .status-filter {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    background: white;
  }

  .loading,
  .error,
  .empty-state {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
    text-align: center;
  }

  .error {
    color: #d32f2f;
    background: #ffebee;
  }

  .empty-state p {
    color: #999;
    font-size: 14px;
  }

  .jobs-list {
    flex: 1;
    overflow-y: auto;
    padding: 12px;
  }

  .job-card {
    background: white;
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 12px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    border: none;
    width: 100%;
    text-align: left;
    font-family: inherit;
  }

  .job-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }

  .job-no {
    font-weight: 600;
    font-size: 16px;
    color: #333;
  }

  .status-badge {
    padding: 4px 12px;
    border-radius: 12px;
    color: white;
    font-size: 12px;
    font-weight: 600;
  }

  .vehicle-numbers {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-bottom: 12px;
  }

  .vehicle-number {
    display: inline-block;
    padding: 4px 8px;
    background: #fff3cd;
    color: #856404;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    border: 1px solid #ffc107;
  }

  .manage-btn {
    width: 100%;
    padding: 10px 16px;
    background: #4CAF50;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .manage-btn:hover {
    background: #45a049;
  }

  .manage-btn:active {
    background: #3d8b40;
  }

  .info-row {
    display: flex;
    justify-content: space-between;
    font-size: 13px;
  }

  .label {
    color: #666;
    font-weight: 500;
  }

  .value {
    color: #333;
    font-weight: 600;
  }

  .priority-low {
    color: #4CAF50;
    background: #E8F5E9;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
  }

  .priority-normal {
    color: #2196F3;
    background: #E3F2FD;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
  }

  .priority-high {
    color: #FF9800;
    background: #FFF3E0;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
  }

  .priority-urgent {
    color: #F44336;
    background: #FFEBEE;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
  }

  .description {
    color: #555;
    font-size: 13px;
    margin-top: 4px;
    line-height: 1.4;
    max-height: 3em;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .section-header {
    margin-top: 12px;
    margin-bottom: 8px;
    font-weight: 600;
    font-size: 13px;
    color: #1a1a1a;
    text-transform: uppercase;
    border-bottom: 1px solid #e0e0e0;
    padding-bottom: 6px;
  }

  /* Job Detail Modal Styles */
  .job-detail-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: flex-end;
    z-index: 1000;
    padding: 16px;
  }

  .job-detail-modal {
    background: white;
    border-radius: 16px 16px 0 0;
    max-height: 90vh;
    overflow-y: auto;
    width: 100%;
    display: flex;
    flex-direction: column;
  }

  .detail-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 16px;
    border-bottom: 1px solid #e0e0e0;
    position: sticky;
    top: 0;
    background: white;
    z-index: 10;
  }

  .detail-title-section {
    display: flex;
    align-items: center;
    gap: 12px;
    flex: 1;
  }

  .detail-title-section h2 {
    margin: 0;
    font-size: 20px;
    color: #333;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 24px;
    cursor: pointer;
    color: #666;
    padding: 0;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .detail-loading,
  .detail-content {
    padding: 16px;
    flex: 1;
  }

  .detail-loading {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .info-section {
    margin-bottom: 20px;
  }

  .info-section h3 {
    margin: 0 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #666;
    text-transform: uppercase;
  }

  .info-item {
    display: flex;
    justify-content: space-between;
    padding: 8px 0;
    border-bottom: 1px solid #f0f0f0;
  }

  .info-item:last-child {
    border-bottom: none;
  }

  .info-item .label {
    color: #999;
    font-size: 13px;
  }

  .info-item .value {
    color: #333;
    font-size: 13px;
    font-weight: 500;
  }

  .item-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    background: #f9f9f9;
    border-radius: 6px;
    margin-bottom: 8px;
  }

  .item-info {
    flex: 1;
  }

  .item-name {
    font-weight: 600;
    font-size: 13px;
    color: #333;
  }

  .item-details {
    font-size: 12px;
    color: #999;
    margin-top: 4px;
  }

  .item-total {
    font-weight: 600;
    font-size: 13px;
    color: #f97316;
  }

  .add-note-section {
    display: flex;
    gap: 8px;
    margin-bottom: 12px;
  }

  .note-input {
    flex: 1;
    padding: 8px 12px;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 13px;
    font-family: inherit;
  }

  .add-note-btn {
    padding: 8px 16px;
    background: #f97316;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .add-note-btn:hover {
    background: #ea580c;
  }

  .add-note-btn:disabled {
    background: #ccc;
    cursor: not-allowed;
  }

  .notes-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .note-item {
    background: #f9f9f9;
    padding: 12px;
    border-radius: 6px;
  }

  .note-meta {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
  }

  .note-user {
    font-size: 12px;
    font-weight: 600;
    color: #666;
  }

  .note-time {
    font-size: 11px;
    color: #999;
  }

  .note-text {
    font-size: 13px;
    color: #333;
    line-height: 1.4;
  }

  .empty-notes {
    text-align: center;
    color: #999;
    font-size: 13px;
    padding: 12px;
  }

  .action-buttons {
    display: flex;
    gap: 12px;
    padding: 16px;
    border-top: 1px solid #e0e0e0;
    flex-wrap: wrap;
  }

  .btn {
    flex: 1;
    min-width: 120px;
    padding: 12px;
    border: none;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-primary {
    background: #f97316;
    color: white;
  }

  .btn-primary:hover {
    background: #ea580c;
  }

  .btn-success {
    background: #22c55e;
    color: white;
  }

  .btn-success:hover {
    background: #16a34a;
  }
</style>
