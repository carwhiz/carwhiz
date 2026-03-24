<!-- ============================================================
     HR > REPORTS > ATTENDANCE REPORT
     Purpose: Shows attendance records as a table with filters
     Window ID: hr-attendance-report
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface PunchRecord {
    id: string;
    user_id: string;
    date: string;
    check_in: string | null;
    check_out: string | null;
    punch_order: number;
    user_email: string;
    user_name: string;
  }

  let records: PunchRecord[] = [];
  let loading = true;

  // Filters
  let fromDate = '';
  let toDate = '';
  let userSearch = '';

  $: filtered = applyFilters(records, fromDate, toDate, userSearch);
  $: totalPunches = filtered.length;
  $: totalHoursMs = filtered.reduce((sum, r) => sum + calcPunchMs(r.check_in, r.check_out), 0);
  $: totalHoursFormatted = formatMs(totalHoursMs);

  onMount(() => {
    setDefaultDates();
    loadAttendance();
  });

  function setDefaultDates() {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    fromDate = `${y}-${m}-01`;
    toDate = now.toISOString().split('T')[0];
  }

  function formatDate(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt + 'T00:00:00');
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    return `${dd}/${mm}/${d.getFullYear()}`;
  }

  function formatTime(dt: string | null): string {
    if (!dt) return '—';
    const d = new Date(dt);
    let h = d.getHours();
    const min = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return `${h}:${min} ${ampm}`;
  }

  function formatMs(ms: number): string {
    if (ms <= 0) return '—';
    const hrs = Math.floor(ms / 3600000);
    const mins = Math.floor((ms % 3600000) / 60000);
    return `${hrs}h ${mins}m`;
  }

  function calcPunchMs(checkIn: string | null, checkOut: string | null): number {
    if (!checkIn || !checkOut) return 0;
    return new Date(checkOut).getTime() - new Date(checkIn).getTime();
  }

  async function loadAttendance() {
    loading = true;
    const { data } = await supabase
      .from('attendance')
      .select('id, user_id, date, check_in, check_out, punch_order, users:user_id(email, user_name)')
      .order('date', { ascending: false })
      .order('punch_order', { ascending: true });
    records = (data || []).map((r: any) => ({
      ...r,
      punch_order: r.punch_order || 1,
      user_email: r.users?.email || '—',
      user_name: r.users?.user_name || '',
    }));
    loading = false;
  }

  function applyFilters(list: PunchRecord[], from: string, to: string, search: string) {
    let result = list;
    if (from) result = result.filter(r => r.date >= from);
    if (to) result = result.filter(r => r.date <= to);
    if (search.trim()) {
      const q = search.toLowerCase().trim();
      result = result.filter(r => r.user_email.toLowerCase().includes(q) || r.user_name.toLowerCase().includes(q));
    }
    return result;
  }

  function getStatus(record: PunchRecord): string {
    if (!record.check_in) return 'absent';
    if (!record.check_out) return 'working';
    return 'complete';
  }

  function clearFilters() {
    setDefaultDates();
    userSearch = '';
  }
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={() => windowStore.close('hr-attendance-report')} title="Close">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Attendance Report</h2>
    </div>
    <button class="btn-refresh" on:click={loadAttendance}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
      Refresh
    </button>
  </div>

  <!-- Summary Cards -->
  <div class="summary-row">
    <div class="s-card"><span class="s-label">Punches</span><span class="s-val">{totalPunches}</span></div>
    <div class="s-card red"><span class="s-label">Total Hours</span><span class="s-val">{totalHoursFormatted}</span></div>
  </div>

  <!-- Filters -->
  <div class="filters-row">
    <input type="date" bind:value={fromDate} />
    <input type="date" bind:value={toDate} />
    <input type="text" placeholder="Search user..." bind:value={userSearch} />
    <button class="btn-clear" on:click={clearFilters}>Clear</button>
  </div>

  <!-- Table -->
  {#if loading}
    <div class="loading">Loading...</div>
  {:else if filtered.length === 0}
    <div class="empty">No attendance records found</div>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>User</th>
            <th>Punch #</th>
            <th>Check In</th>
            <th>Check Out</th>
            <th>Hours</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {#each filtered as record (record.id)}
            <tr class="punch-row">
              <td>{formatDate(record.date)}</td>
              <td class="user-col">{record.user_name || record.user_email}</td>
              <td class="num">{record.punch_order}</td>
              <td class="num">{formatTime(record.check_in)}</td>
              <td class="num">{formatTime(record.check_out)}</td>
              <td class="num">{formatMs(calcPunchMs(record.check_in, record.check_out))}</td>
              <td>
                {@const status = getStatus(record)}
                {#if status === 'complete'}
                  <span class="badge done">Complete</span>
                {:else if status === 'working'}
                  <span class="badge active">Working</span>
                {:else}
                  <span class="badge absent">Absent</span>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .report-window { padding: 20px; height: 100%; overflow-y: auto; background: #f9fafb; }
  .report-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .header-left { display: flex; align-items: center; gap: 10px; }
  .back-btn { background: none; border: none; cursor: pointer; color: #6b7280; padding: 4px; border-radius: 6px; display: flex; align-items: center; }
  .back-btn:hover { background: #f3f4f6; }
  h2 { font-size: 18px; font-weight: 700; color: #111827; margin: 0; }
  .btn-refresh { display: flex; align-items: center; gap: 5px; background: #f3f4f6; border: 1px solid #e5e7eb; padding: 6px 12px; border-radius: 8px; font-size: 12px; cursor: pointer; color: #374151; font-weight: 500; }
  .btn-refresh:hover { background: #e5e7eb; }

  .summary-row { display: flex; gap: 12px; margin-bottom: 14px; flex-wrap: wrap; }
  .s-card { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 12px 18px; display: flex; flex-direction: column; gap: 2px; min-width: 120px; }
  .s-card.green { border-left: 3px solid #22c55e; }
  .s-card.blue { border-left: 3px solid #3b82f6; }
  .s-card.red { border-left: 3px solid #C41E3A; }
  .s-label { font-size: 11px; color: #6b7280; font-weight: 500; text-transform: uppercase; letter-spacing: 0.5px; }
  .s-val { font-size: 20px; font-weight: 700; color: #111827; }

  .filters-row { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; align-items: center; }
  .filters-row input[type="date"],
  .filters-row input[type="text"] { padding: 6px 10px; border: 1px solid #d1d5db; border-radius: 8px; font-size: 13px; background: white; }
  .btn-clear { padding: 6px 12px; border: 1px solid #d1d5db; border-radius: 8px; background: white; font-size: 12px; cursor: pointer; color: #6b7280; }
  .btn-clear:hover { background: #f3f4f6; }

  .loading, .empty { text-align: center; padding: 40px; color: #9ca3af; font-size: 14px; }

  .table-wrap { overflow-x: auto; border-radius: 10px; border: 1px solid #e5e7eb; background: white; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  thead { background: #f9fafb; }
  th { text-align: left; padding: 10px 14px; font-weight: 600; color: #374151; border-bottom: 1px solid #e5e7eb; border-right: 1px solid #e5e7eb; white-space: nowrap; }
  td { padding: 10px 14px; border-bottom: 1px solid #f3f4f6; border-right: 1px solid #e5e7eb; color: #111827; white-space: nowrap; }
  .num { font-variant-numeric: tabular-nums; }

  .badge { padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
  .badge.done { background: #dcfce7; color: #166534; }
  .badge.active { background: #dbeafe; color: #1e40af; }
  .badge.absent { background: #fee2e2; color: #991b1b; }

  .punch-row { cursor: default; }
  .punch-row:hover td { background: #fffbf5; }
  .user-col { font-weight: 600; }
</style>
