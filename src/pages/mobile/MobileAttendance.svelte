<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../lib/supabaseClient';
  import { authStore } from '../../stores/authStore';
  import { navigateTo } from '../../routes/navigation';
  import { setMobilePage } from '../../stores/mobilePageStore';
  import MobilePageWrapper from '../../components/shared/MobilePageWrapper.svelte';

  interface AttendanceRecord {
    id: string;
    check_in: string;
    check_out: string | null;
    punch_order: number;
    date: string;
  }

  interface AttendanceSummary {
    date: string;
    check_in_count: number;
    total_hours: number;
    status: string;
  }

  let attendanceRecords: AttendanceRecord[] = [];
  let attendanceSummary: AttendanceSummary[] = [];
  let loading = true;
  let error = '';
  let selectedDate = new Date().toISOString().split('T')[0];
  let currentMonth = new Date().toISOString().slice(0, 7);

  async function loadAttendance() {
    if (!$authStore.user) return;

    try {
      loading = true;
      error = '';

      // Load attendance for selected date using RPC
      const { data: records, error: recordsError } = await supabase.rpc(
        'fn_get_user_attendance',
        { p_date: selectedDate }
      );

      if (recordsError) {
        console.error('Error loading attendance records:', recordsError);
        error = `Failed to load attendance: ${recordsError.message}`;
        attendanceRecords = [];
      } else {
        attendanceRecords = records || [];
      }
    } catch (err) {
      console.error('Attendance load error:', err);
      error = `Error: ${err instanceof Error ? err.message : 'Unknown error'}`;
    } finally {
      loading = false;
    }
  }

  async function loadMonthlySummary() {
    if (!$authStore.user) return;

    try {
      const [year, month] = currentMonth.split('-');
      const { data, error: summaryError } = await supabase.rpc(
        'fn_get_attendance_summary',
        { p_year: parseInt(year), p_month: parseInt(month) }
      );

      if (summaryError) {
        console.error('Error loading summary:', summaryError);
      } else {
        attendanceSummary = data || [];
      }
    } catch (err) {
      console.error('Summary load error:', err);
    }
  }

  function formatTime(timestamp: string | null): string {
    if (!timestamp) return '--:--';
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: true
    });
  }

  function calculateWorkedHours(record: AttendanceRecord): string {
    if (!record.check_out) return 'Ongoing';
    const checkIn = new Date(record.check_in);
    const checkOut = new Date(record.check_out);
    const hours = (checkOut.getTime() - checkIn.getTime()) / 3600000;
    return hours.toFixed(2) + ' hrs';
  }

  function goBack() {
    navigateTo('mobile');
  }

  onMount(() => {
    setMobilePage('attendance', 'Attendance');
    loadAttendance();
    loadMonthlySummary();
  });
</script>

<MobilePageWrapper>
  <div class="attendance-content">
    {#if error}
      <div class="error-message">
        <p>{error}</p>
      </div>
    {/if}

    <div class="content">
      <!-- Today's Attendance -->
      <div class="section">
        <h2>Today's Attendance</h2>
        <div class="date-selector">
          <input type="date" bind:value={selectedDate} on:change={loadAttendance} />
        </div>

        {#if loading}
          <div class="loading">Loading attendance...</div>
        {:else if attendanceRecords.length === 0}
          <div class="empty-state">
            <p>No attendance records for this date</p>
          </div>
        {:else}
          <div class="attendance-list">
            {#each attendanceRecords as record (record.id)}
              <div class="attendance-item">
                <div class="punch-info">
                  <div class="punch-number">Punch #{record.punch_order}</div>
                  <div class="times">
                    <span class="check-in">
                      🕐 In: {formatTime(record.check_in)}
                    </span>
                    <span class="check-out">
                      🕑 Out: {formatTime(record.check_out)}
                    </span>
                  </div>
                </div>
                <div class="worked-hours">
                  {calculateWorkedHours(record)}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Monthly Summary -->
      <div class="section">
        <h2>Monthly Summary</h2>
        <div class="month-selector">
          <input type="month" bind:value={currentMonth} on:change={loadMonthlySummary} />
        </div>

        {#if attendanceSummary.length === 0}
          <div class="empty-state">
            <p>No attendance data for this month</p>
          </div>
        {:else}
          <div class="summary-list">
            {#each attendanceSummary.slice(0, 15) as summary (summary.date)}
              <div class="summary-item">
                <div class="date-status">
                  <span class="date">{new Date(summary.date).toLocaleDateString('en-IN')}</span>
                  <span class="status {summary.status.toLowerCase()}">{summary.status}</span>
                </div>
                <div class="summary-details">
                  <span class="punches">Punches: {summary.check_in_count}</span>
                  <span class="hours">Hours: {summary.total_hours?.toFixed(1) || '0'}</span>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  </div>
</MobilePageWrapper>

<style>
  .attendance-content {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #f5f5f5;
  }

  .content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
  }

  .section {
    background: white;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .section h2 {
    margin: 0 0 15px 0;
    color: #333;
    font-size: 18px;
  }

  .date-selector,
  .month-selector {
    margin-bottom: 15px;
  }

  input[type='date'],
  input[type='month'] {
    padding: 8px 12px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    width: 100%;
    max-width: 200px;
  }

  .loading,
  .empty-state {
    text-align: center;
    padding: 40px 20px;
    color: #999;
  }

  .error-message {
    background: #fee;
    border: 1px solid #fcc;
    color: #c33;
    padding: 15px;
    margin: 20px;
    border-radius: 4px;
  }

  .attendance-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .attendance-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 15px;
    background: #f9f9f9;
    border-left: 4px solid #C41E3A;
    border-radius: 4px;
  }

  .punch-info {
    flex: 1;
  }

  .punch-number {
    font-weight: bold;
    color: #333;
    margin-bottom: 5px;
  }

  .times {
    display: flex;
    gap: 20px;
    font-size: 13px;
    color: #666;
  }

  .check-in,
  .check-out {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .worked-hours {
    text-align: right;
    font-weight: bold;
    color: #C41E3A;
    width: 80px;
  }

  .summary-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .summary-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    background: #f9f9f9;
    border-radius: 4px;
  }

  .date-status {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .date {
    font-weight: bold;
    color: #333;
    min-width: 100px;
  }

  .status {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: bold;
    text-transform: uppercase;
  }

  .status.present {
    background: #e8f5e9;
    color: #2e7d32;
  }

  .status.absent {
    background: #ffebee;
    color: #c62828;
  }

  .status.checked\ in {
    background: #e3f2fd;
    color: #1565c0;
  }

  .summary-details {
    display: flex;
    gap: 20px;
    font-size: 13px;
    color: #666;
  }

  .punches,
  .hours {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .logs-section {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
  }

  .logs-section h4 {
    margin: 0 0 1rem 0;
    color: #1f2937;
  }

  .no-logs {
    text-align: center;
    color: #9ca3af;
    padding: 2rem 0;
    margin: 0;
  }

  .logs-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .log-entry {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem;
    background: #f9fafb;
    border-radius: 4px;
    font-size: 0.9rem;
  }

  .log-type {
    font-weight: 600;
    color: #1f2937;
  }

  .log-time {
    color: #6b7280;
  }
</style>
