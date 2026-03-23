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

  interface DayGroup {
    date: string;
    user_id: string;
    user_email: string;
    user_name: string;
    punches: PunchRecord[];
    totalMs: number;
    totalHours: string;
    firstIn: string | null;
    lastOut: string | null;
    status: 'complete' | 'working' | 'absent';
  }

  let records: PunchRecord[] = [];
  let loading = true;

  // Filters
  let fromDate = '';
  let toDate = '';
  let userSearch = '';

  $: grouped = groupByUserDate(applyFilters(records, fromDate, toDate, userSearch));
  $: totalDays = grouped.length;
  $: totalComplete = grouped.filter(g => g.status === 'complete').length;
  $: totalWorking = grouped.filter(g => g.status === 'working').length;
  $: grandTotalMs = grouped.reduce((sum, g) => sum + g.totalMs, 0);
  $: grandTotalHours = formatMs(grandTotalMs);

  // Expand/collapse
  let expandedKey = '';

  function toggleExpand(key: string) {
    expandedKey = expandedKey === key ? '' : key;
  }

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

  function groupByUserDate(list: PunchRecord[]): DayGroup[] {
    const map = new Map<string, PunchRecord[]>();
    for (const r of list) {
      const key = `${r.user_id}_${r.date}`;
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(r);
    }
    const groups: DayGroup[] = [];
    for (const [, punches] of map) {
      const sorted = punches.sort((a, b) => a.punch_order - b.punch_order);
      let totalMs = 0;
      for (const p of sorted) {
        totalMs += calcPunchMs(p.check_in, p.check_out);
      }
      const firstIn = sorted.find(p => p.check_in)?.check_in || null;
      const lastCompleted = [...sorted].reverse().find(p => p.check_out);
      const lastOut = lastCompleted?.check_out || null;
      const hasOpen = sorted.some(p => p.check_in && !p.check_out);
      groups.push({
        date: sorted[0].date,
        user_id: sorted[0].user_id,
        user_email: sorted[0].user_email,
        user_name: sorted[0].user_name,
        punches: sorted,
        totalMs,
        totalHours: formatMs(totalMs),
        firstIn,
        lastOut,
        status: hasOpen ? 'working' : (firstIn ? 'complete' : 'absent'),
      });
    }
    // Sort by date desc, then user
    groups.sort((a, b) => b.date.localeCompare(a.date) || a.user_email.localeCompare(b.user_email));
    return groups;
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
    <div class="s-card"><span class="s-label">Days</span><span class="s-val">{totalDays}</span></div>
    <div class="s-card green"><span class="s-label">Complete</span><span class="s-val">{totalComplete}</span></div>
    <div class="s-card blue"><span class="s-label">Working</span><span class="s-val">{totalWorking}</span></div>
    <div class="s-card red"><span class="s-label">Total Hours</span><span class="s-val">{grandTotalHours}</span></div>
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
  {:else if grouped.length === 0}
    <div class="empty">No attendance records found</div>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>User</th>
            <th>Punches</th>
            <th>First In</th>
            <th>Last Out</th>
            <th>Total Hours</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {#each grouped as g}
            {@const key = `${g.user_id}_${g.date}`}
            <tr class="group-row" class:expanded={expandedKey === key} on:click={() => toggleExpand(key)}>
              <td>{formatDate(g.date)}</td>
              <td class="user-col">{g.user_name || g.user_email}</td>
              <td class="num">{g.punches.length}</td>
              <td class="num">{formatTime(g.firstIn)}</td>
              <td class="num">{formatTime(g.lastOut)}</td>
              <td class="num total-hrs">{g.totalHours}</td>
              <td>
                {#if g.status === 'complete'}
                  <span class="badge done">Complete</span>
                {:else if g.status === 'working'}
                  <span class="badge active">Working</span>
                {:else}
                  <span class="badge absent">Absent</span>
                {/if}
              </td>
            </tr>
            {#if expandedKey === key && g.punches.length > 0}
              <tr class="detail-row">
                <td colspan="7">
                  <div class="punch-details">
                    <table class="punch-table">
                      <thead>
                        <tr><th>#</th><th>Check In</th><th>Check Out</th><th>Hours</th></tr>
                      </thead>
                      <tbody>
                        {#each g.punches as p, pi}
                          <tr>
                            <td>{pi + 1}</td>
                            <td>{formatTime(p.check_in)}</td>
                            <td>{p.check_out ? formatTime(p.check_out) : '—'}</td>
                            <td>{calcPunchMs(p.check_in, p.check_out) > 0 ? formatMs(calcPunchMs(p.check_in, p.check_out)) : '—'}</td>
                          </tr>
                        {/each}
                      </tbody>
                    </table>
                  </div>
                </td>
              </tr>
            {/if}
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

  .group-row { cursor: pointer; }
  .group-row:hover td { background: #fffbf5; }
  .group-row.expanded td { background: #fef3c7; }
  .user-col { font-weight: 600; }
  .total-hrs { font-weight: 700; color: #C41E3A; }

  .detail-row td { padding: 0; background: #fafafa; }
  .punch-details { padding: 8px 14px 12px; }
  .punch-table { width: auto; min-width: 350px; border-collapse: collapse; font-size: 12px; background: white; border: 1px solid #e5e7eb; border-radius: 6px; overflow: hidden; }
  .punch-table th { background: #f3f4f6; padding: 6px 12px; font-size: 11px; text-transform: uppercase; color: #6b7280; border-bottom: 1px solid #e5e7eb; text-align: left; }
  .punch-table td { padding: 6px 12px; border-bottom: 1px solid #f3f4f6; color: #374151; }
</style>
