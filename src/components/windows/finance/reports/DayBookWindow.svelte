<!-- ============================================================
     FINANCE > REPORTS > DAY BOOK
     Purpose: Chronological journal of all ledger entries
     Shows all debit/credit entries date-wise
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface DayBookEntry {
    id: string;
    entry_date: string;
    created_at: string;
    debit: number;
    credit: number;
    narration: string;
    reference_type: string | null;
    reference_id: string | null;
    ledger_name: string;
  }

  let entries: DayBookEntry[] = [];
  let loading = true;
  let fromDate = '';
  let toDate = '';
  let searchQuery = '';

  $: filteredEntries = entries.filter(e => {
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      if (!e.ledger_name.toLowerCase().includes(q) && !(e.narration || '').toLowerCase().includes(q)) return false;
    }
    return true;
  });

  $: totalDebit = filteredEntries.reduce((s, e) => s + (e.debit || 0), 0);
  $: totalCredit = filteredEntries.reduce((s, e) => s + (e.credit || 0), 0);

  onMount(() => {
    // Default: current financial year (April 1 to March 31)
    const now = new Date();
    const fy = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
    fromDate = `${fy}-04-01`;
    toDate = `${fy + 1}-03-31`;
    loadEntries();
  });

  function formatDate(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt + 'T00:00:00');
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const yyyy = d.getFullYear();
    return `${dd}/${mm}/${yyyy}`;
  }

  function formatDateTime(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const yyyy = d.getFullYear();
    let h = d.getHours();
    const min = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return `${dd}/${mm}/${yyyy} ${h}:${min} ${ampm}`;
  }

  function formatAmt(val: number): string {
    if (!val || val === 0) return '';
    return '₹' + val.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  async function loadEntries() {
    loading = true;
    let query = supabase
      .from('ledger_entries')
      .select('id, entry_date, created_at, debit, credit, narration, reference_type, reference_id, ledger:ledger_id(ledger_name)')
      .order('entry_date', { ascending: true })
      .order('created_at', { ascending: true });

    if (fromDate) query = query.gte('entry_date', fromDate);
    if (toDate) query = query.lte('entry_date', toDate);

    const { data } = await query;
    entries = (data || []).map((e: any) => ({
      ...e,
      ledger_name: e.ledger?.ledger_name || '—',
    }));
    loading = false;
  }

  function applyFilters() {
    loadEntries();
  }

  function handleBack() {
    windowStore.close('finance-day-book');
  }

  // Group entries by date for display
  $: groupedByDate = (() => {
    const groups: { date: string; items: DayBookEntry[]; totalDr: number; totalCr: number }[] = [];
    let currentDate = '';
    let currentGroup: typeof groups[0] | null = null;
    for (const e of filteredEntries) {
      if (e.entry_date !== currentDate) {
        currentDate = e.entry_date;
        currentGroup = { date: currentDate, items: [], totalDr: 0, totalCr: 0 };
        groups.push(currentGroup);
      }
      currentGroup!.items.push(e);
      currentGroup!.totalDr += e.debit || 0;
      currentGroup!.totalCr += e.credit || 0;
    }
    return groups;
  })();
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Day Book</h2>
    </div>
    <div class="header-right">
      <span class="record-count">{filteredEntries.length} entries</span>
    </div>
  </div>

  <div class="filters-bar">
    <div class="filter-group">
      <label for="db-from">From</label>
      <input id="db-from" type="date" bind:value={fromDate} on:change={applyFilters} />
    </div>
    <div class="filter-group">
      <label for="db-to">To</label>
      <input id="db-to" type="date" bind:value={toDate} on:change={applyFilters} />
    </div>
    <div class="filter-group search-group">
      <label for="db-search">Search</label>
      <input id="db-search" type="text" placeholder="Ledger or narration..." bind:value={searchQuery} />
    </div>
  </div>

  <div class="table-wrap">
    {#if loading}
      <div class="status-msg">Loading day book...</div>
    {:else if filteredEntries.length === 0}
      <div class="status-msg">No entries found for the selected period.</div>
    {:else}
      {#each groupedByDate as group}
        <div class="date-group">
          <div class="date-header">{formatDate(group.date)}</div>
          <table>
            <thead>
              <tr>
                <th>Ledger Account</th>
                <th>Narration</th>
                <th>Ref Type</th>
                <th class="amt">Debit (Dr)</th>
                <th class="amt">Credit (Cr)</th>
              </tr>
            </thead>
            <tbody>
              {#each group.items as entry (entry.id)}
                <tr>
                  <td class="ledger-name">{entry.ledger_name}</td>
                  <td class="narration">{entry.narration || '—'}</td>
                  <td><span class="ref-badge">{entry.reference_type || '—'}</span></td>
                  <td class="amt dr">{formatAmt(entry.debit)}</td>
                  <td class="amt cr">{formatAmt(entry.credit)}</td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr>
                <td colspan="3" class="day-total-label">Day Total</td>
                <td class="amt dr">{formatAmt(group.totalDr)}</td>
                <td class="amt cr">{formatAmt(group.totalCr)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      {/each}
    {/if}
  </div>

  <div class="grand-total-bar">
    <span class="gt-label">Grand Total</span>
    <span class="gt-dr">{formatAmt(totalDebit)} Dr</span>
    <span class="gt-cr">{formatAmt(totalCredit)} Cr</span>
    {#if Math.abs(totalDebit - totalCredit) < 0.01}
      <span class="gt-balanced">✓ Balanced</span>
    {:else}
      <span class="gt-diff">Difference: {formatAmt(Math.abs(totalDebit - totalCredit))}</span>
    {/if}
  </div>
</div>

<style>
  .report-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .header-right { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .record-count { font-size:12px; color:#9ca3af; }

  .filters-bar { display:flex; align-items:flex-end; gap:12px; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; flex-wrap:wrap; }
  .filter-group { display:flex; flex-direction:column; gap:3px; }
  .search-group { flex:1; min-width:150px; }
  .filter-group label { font-size:11px; font-weight:600; color:#6b7280; }
  .filter-group input { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; }
  .filter-group input:focus { border-color:#f59e0b; }

  .table-wrap { flex:1; overflow:auto; padding:0 18px 12px; width:100%; box-sizing:border-box; }
  .date-group { margin-top:16px; }
  .date-header { font-size:13px; font-weight:700; color:#1e40af; background:#eff6ff; padding:6px 12px; border-radius:6px 6px 0 0; border:1px solid #bfdbfe; border-bottom:none; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  thead th { background:#f9fafb; padding:8px 12px; text-align:left; font-weight:600; color:#374151; border-bottom:2px solid #e5e7eb; border-right:1px solid #e5e7eb; }
  tbody td { padding:7px 12px; border-bottom:1px solid #f3f4f6; border-right:1px solid #e5e7eb; color:#111827; }
  tbody tr:hover { background:#fffbeb; }
  tfoot td { padding:8px 12px; font-weight:700; background:#f9fafb; border-top:2px solid #e5e7eb; }
  .ledger-name { font-weight:600; }
  .narration { color:#6b7280; font-size:12px; }
  .ref-badge { display:inline-block; padding:2px 6px; background:#f3f4f6; border-radius:4px; font-size:11px; font-weight:500; color:#374151; }
  .amt { text-align:right; font-family:'Courier New',monospace; white-space:nowrap; }
  .dr { color:#dc2626; }
  .cr { color:#16a34a; }
  .day-total-label { text-align:right; font-weight:700; color:#374151; }

  .grand-total-bar { display:flex; align-items:center; justify-content:center; gap:24px; padding:14px 18px; background:white; border-top:2px solid #e5e7eb; flex-shrink:0; }
  .gt-label { font-size:14px; font-weight:700; color:#111827; }
  .gt-dr { font-size:14px; font-weight:700; color:#dc2626; font-family:'Courier New',monospace; }
  .gt-cr { font-size:14px; font-weight:700; color:#16a34a; font-family:'Courier New',monospace; }
  .gt-balanced { font-size:12px; font-weight:700; color:#16a34a; background:#dcfce7; padding:3px 10px; border-radius:4px; }
  .gt-diff { font-size:12px; font-weight:700; color:#dc2626; background:#fee2e2; padding:3px 10px; border-radius:4px; }

  .status-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }
</style>
