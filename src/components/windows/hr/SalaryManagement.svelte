<!-- Salary Management Window -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../lib/supabaseClient';

  interface Employee {
    id: string;
    user_name: string;
    email: string;
  }

  interface AttendanceRecord {
    user_id: string;
    date: string;
    check_in: string | null;
    check_out: string | null;
  }

  interface ShiftInfo {
    start_time: string;
    end_time: string;
    start_buffer: number;
    end_buffer: number;
    working_hours: number;
    overlaps_next_day: boolean;
  }

  interface LeaveInfo {
    leave_type: 'weekday' | 'date';
    weekday: number | null;
    leave_date: string | null;
    title: string;
  }

  interface DayData {
    date: string;
    checkIn: string | null;
    checkOut: string | null;
    workedHours: number;
    shift: ShiftInfo | null;
    isLeave: boolean;
    leaveName: string;
    lateIn: number;   // minutes late
    overtime: number;  // minutes overtime
    isAbsent: boolean; // shift assigned, no leave, no attendance
  }

  interface EmployeeRow {
    employee: Employee;
    days: DayData[];
    totalWorked: number;
    totalExpected: number;
    totalLate: number;
    totalOvertime: number;
    leaveDays: number;
    absentDays: number;
    expectedDays: number;
    workedDays: number;
  }

  let dateFrom = '';
  let dateTo = '';
  let loading = false;
  let employees: Employee[] = [];
  let employeeRows: EmployeeRow[] = [];
  let dates: string[] = [];

  // Lookup maps
  let attendanceMap: Map<string, AttendanceRecord> = new Map();
  let specialShiftMap: Map<string, ShiftInfo> = new Map();
  let regularShiftMap: Map<string, ShiftInfo> = new Map();
  let leavesByEmployee: Map<string, LeaveInfo[]> = new Map();

  onMount(() => {
    // Default: current month 1st to today
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    dateFrom = `${y}-${m}-01`;
    dateTo = `${y}-${m}-${String(now.getDate()).padStart(2, '0')}`;
    loadData();
  });

  function getDateRange(from: string, to: string): string[] {
    const result: string[] = [];
    const d = new Date(from);
    const end = new Date(to);
    while (d <= end) {
      result.push(d.toISOString().split('T')[0]);
      d.setDate(d.getDate() + 1);
    }
    return result;
  }

  async function loadData() {
    if (!dateFrom || !dateTo) return;
    loading = true;

    dates = getDateRange(dateFrom, dateTo);

    // Load all data in parallel
    const [empRes, attRes, specRes, regRes, leaveRes] = await Promise.all([
      supabase.from('users').select('id, user_name, email').eq('is_employee', true).order('user_name'),
      supabase.from('attendance').select('user_id, date, check_in, check_out')
        .gte('date', dateFrom).lte('date', dateTo),
      supabase.from('special_shifts').select('employee_id, shift_date, start_time, end_time, start_buffer, end_buffer, working_hours, overlaps_next_day')
        .gte('shift_date', dateFrom).lte('shift_date', dateTo),
      supabase.from('shifts').select('employee_id, start_time, end_time, start_buffer, end_buffer, working_hours, overlaps_next_day'),
      supabase.from('official_leaves').select('employee_id, leave_type, weekday, leave_date, title'),
    ]);

    if (empRes.error) console.error('Employees error:', empRes.error);
    if (attRes.error) console.error('Attendance error:', attRes.error);
    if (specRes.error) console.error('Special shifts error:', specRes.error);
    if (regRes.error) console.error('Regular shifts error:', regRes.error);
    if (leaveRes.error) console.error('Leaves error:', leaveRes.error);

    employees = (empRes.data || []) as Employee[];

    // Build attendance map: key = "userId|date"
    attendanceMap = new Map();
    for (const a of (attRes.data || []) as AttendanceRecord[]) {
      attendanceMap.set(`${a.user_id}|${a.date}`, a);
    }

    // Build special shift map: key = "employeeId|date"
    specialShiftMap = new Map();
    for (const s of (specRes.data || []) as any[]) {
      specialShiftMap.set(`${s.employee_id}|${s.shift_date}`, {
        start_time: s.start_time,
        end_time: s.end_time,
        start_buffer: s.start_buffer,
        end_buffer: s.end_buffer,
        working_hours: s.working_hours,
        overlaps_next_day: s.overlaps_next_day,
      });
    }

    // Build regular shift map: key = "employeeId"
    regularShiftMap = new Map();
    for (const s of (regRes.data || []) as any[]) {
      regularShiftMap.set(s.employee_id, {
        start_time: s.start_time,
        end_time: s.end_time,
        start_buffer: s.start_buffer,
        end_buffer: s.end_buffer,
        working_hours: s.working_hours,
        overlaps_next_day: s.overlaps_next_day,
      });
    }

    // Build leaves map: key = "employeeId" → array of leaves
    leavesByEmployee = new Map();
    for (const l of (leaveRes.data || []) as any[]) {
      const list = leavesByEmployee.get(l.employee_id) || [];
      list.push({
        leave_type: l.leave_type,
        weekday: l.weekday,
        leave_date: l.leave_date,
        title: l.title,
      });
      leavesByEmployee.set(l.employee_id, list);
    }

    // Build rows
    employeeRows = employees.map(emp => {
      let totalWorked = 0;
      let totalExpected = 0;
      let totalLate = 0;
      let totalOvertime = 0;
      let leaveDays = 0;
      let absentDays = 0;
      let expectedDays = 0;
      let workedDays = 0;
      const today = new Date().toISOString().split('T')[0];

      const days: DayData[] = dates.map(date => {
        // 1. Get shift: special first, then regular
        const shift = specialShiftMap.get(`${emp.id}|${date}`) || regularShiftMap.get(emp.id) || null;

        // 2. Check leave
        const empLeaves = leavesByEmployee.get(emp.id) || [];
        const dateObj = new Date(date);
        const dayOfWeek = dateObj.getDay(); // 0=Sun
        const leave = empLeaves.find(l => {
          if (l.leave_type === 'date' && l.leave_date === date) return true;
          if (l.leave_type === 'weekday' && l.weekday === dayOfWeek) return true;
          return false;
        });
        const isLeave = !!leave;
        const leaveName = leave?.title || '';

        if (isLeave) leaveDays++;

        // 3. Get attendance
        const att = attendanceMap.get(`${emp.id}|${date}`);
        const checkIn = att?.check_in || null;
        const checkOut = att?.check_out || null;

        // 4. Calculate worked hours
        let workedHours = 0;
        if (checkIn && checkOut) {
          const inTime = new Date(checkIn).getTime();
          const outTime = new Date(checkOut).getTime();
          workedHours = Math.max(0, (outTime - inTime) / 3600000);
        }

        // 5. Calculate late in (minutes)
        let lateIn = 0;
        if (shift && checkIn && !isLeave) {
          const shiftStartParts = shift.start_time.split(':');
          const shiftStartMin = parseInt(shiftStartParts[0]) * 60 + parseInt(shiftStartParts[1]) + shift.start_buffer;
          const inDate = new Date(checkIn);
          const actualMin = inDate.getHours() * 60 + inDate.getMinutes();
          lateIn = Math.max(0, actualMin - shiftStartMin);
        }

        // 6. Calculate overtime (minutes)
        let overtime = 0;
        if (shift && workedHours > 0 && !isLeave) {
          const overtimeHours = workedHours - shift.working_hours;
          overtime = Math.max(0, Math.round(overtimeHours * 60));
        }

        // 7. Check absent: has shift, no leave, no attendance, date not in future
        const isAbsent = !!shift && !isLeave && !checkIn && date <= today;
        if (isAbsent) absentDays++;

        // Accumulate totals
        totalWorked += workedHours;
        if (shift && !isLeave) {
          totalExpected += shift.working_hours;
          expectedDays++;
        }
        if (checkIn) workedDays++;
        totalLate += lateIn;
        totalOvertime += overtime;

        return { date, checkIn, checkOut, workedHours, shift, isLeave, leaveName, lateIn, overtime, isAbsent };
      });

      return { employee: emp, days, totalWorked, totalExpected, totalLate, totalOvertime, leaveDays, absentDays, expectedDays, workedDays };
    });

    loading = false;
  }

  function formatTime(iso: string | null): string {
    if (!iso) return '-';
    const d = new Date(iso);
    let h = d.getHours();
    const m = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return `${h}:${m} ${ampm}`;
  }

  function formatHours(h: number): string {
    if (h === 0) return '-';
    const hrs = Math.floor(h);
    const mins = Math.round((h - hrs) * 60);
    if (mins === 0) return `${hrs}h`;
    return `${hrs}h ${mins}m`;
  }

  function formatMins(m: number): string {
    if (m === 0) return '-';
    const hrs = Math.floor(m / 60);
    const mins = m % 60;
    if (hrs === 0) return `${mins}m`;
    return `${hrs}h ${mins}m`;
  }

  function formatDateLabel(dateStr: string): string {
    const d = new Date(dateStr);
    return `${d.getDate()}/${d.getMonth() + 1}`;
  }

  function getDayName(dateStr: string): string {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[new Date(dateStr).getDay()];
  }
</script>

<div class="container">
  <div class="header">
    <h2>💰 Salary Management</h2>
    <div class="date-range">
      <label>
        From
        <input type="date" bind:value={dateFrom} />
      </label>
      <label>
        To
        <input type="date" bind:value={dateTo} />
      </label>
      <button class="btn-load" on:click={loadData} disabled={loading}>
        {loading ? 'Loading...' : 'Load'}
      </button>
    </div>
  </div>

  <div class="content">
    {#if loading}
      <div class="loading">Loading attendance data...</div>
    {:else if employeeRows.length === 0}
      <div class="empty">Select a date range and click Load to view salary data.</div>
    {:else}
      <div class="table-wrapper">
        <table>
          <thead>
            <tr class="header-row-1">
              <th class="sticky-col col-employee" rowspan="2">Employee</th>
              {#each dates as date}
                <th colspan="5" class="date-header {new Date(date).getDay() === 0 ? 'sunday' : ''}">
                  <div class="date-label">{formatDateLabel(date)}</div>
                  <div class="day-name">{getDayName(date)}</div>
                </th>
              {/each}
              <th colspan="8" class="totals-header">Totals</th>
            </tr>
            <tr class="header-row-2">
              {#each dates as _}
                <th class="sub-header">In</th>
                <th class="sub-header">Out</th>
                <th class="sub-header">Worked</th>
                <th class="sub-header">Late</th>
                <th class="sub-header">OT</th>
              {/each}
              <th class="sub-header total-sub">Exp Days</th>
              <th class="sub-header total-sub">Wkd Days</th>
              <th class="sub-header total-sub">Worked</th>
              <th class="sub-header total-sub">Expected</th>
              <th class="sub-header total-sub">Late</th>
              <th class="sub-header total-sub">OT</th>
              <th class="sub-header total-sub">Leaves</th>
              <th class="sub-header total-sub">Absent</th>
            </tr>
          </thead>
          <tbody>
            {#each employeeRows as row}
              <tr>
                <td class="sticky-col col-employee emp-name">{row.employee.user_name}</td>
                {#each row.days as day}
                  {#if day.isLeave}
                    <td colspan="5" class="leave-cell" title={day.leaveName}>
                      <span class="leave-badge">🏖 {day.leaveName || 'Leave'}</span>
                    </td>
                  {:else if day.isAbsent}
                    <td colspan="5" class="absent-cell">
                      <span class="absent-badge">✖ Absent</span>
                    </td>
                  {:else if !day.shift}
                    <td colspan="5" class="no-shift-cell">
                      <span class="no-shift-badge">No Shift</span>
                    </td>
                  {:else}
                    <td class="data-cell">{formatTime(day.checkIn)}</td>
                    <td class="data-cell">{formatTime(day.checkOut)}</td>
                    <td class="data-cell hours-cell">{formatHours(day.workedHours)}</td>
                    <td class="data-cell {day.lateIn > 0 ? 'late-cell' : ''}">{day.lateIn > 0 ? formatMins(day.lateIn) : '-'}</td>
                    <td class="data-cell {day.overtime > 0 ? 'ot-cell' : ''}">{day.overtime > 0 ? formatMins(day.overtime) : '-'}</td>
                  {/if}
                {/each}
                <td class="total-cell">{row.expectedDays}</td>
                <td class="total-cell">{row.workedDays}</td>
                <td class="total-cell">{formatHours(row.totalWorked)}</td>
                <td class="total-cell">{formatHours(row.totalExpected)}</td>
                <td class="total-cell {row.totalLate > 0 ? 'late-total' : ''}">{formatMins(row.totalLate)}</td>
                <td class="total-cell {row.totalOvertime > 0 ? 'ot-total' : ''}">{formatMins(row.totalOvertime)}</td>
                <td class="total-cell">{row.leaveDays}</td>
                <td class="total-cell {row.absentDays > 0 ? 'absent-total' : ''}">{row.absentDays}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>

<style>
  .container {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #fafafa;
  }

  .header {
    padding: 12px 20px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    flex-wrap: wrap;
  }

  .header h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 700;
    color: #111827;
  }

  .date-range {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .date-range label {
    font-size: 12px;
    font-weight: 600;
    color: #6b7280;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .date-range input[type="date"] {
    padding: 6px 10px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 13px;
    color: #374151;
  }

  .btn-load {
    padding: 7px 18px;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-load:hover {
    background: #2563eb;
  }

  .btn-load:disabled {
    background: #93c5fd;
    cursor: not-allowed;
  }

  .content {
    flex: 1;
    overflow: auto;
    padding: 16px;
  }

  .loading, .empty {
    text-align: center;
    padding: 40px;
    color: #9ca3af;
    font-size: 14px;
  }

  .table-wrapper {
    overflow: auto;
    max-height: calc(100vh - 160px);
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    background: white;
  }

  table {
    border-collapse: collapse;
    font-size: 11px;
    white-space: nowrap;
    width: max-content;
    min-width: 100%;
  }

  thead {
    position: sticky;
    top: 0;
    z-index: 3;
  }

  .header-row-1 th, .header-row-2 th {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    padding: 6px 4px;
    text-align: center;
    font-weight: 600;
    color: #475569;
  }

  .date-header {
    min-width: 200px;
    border-bottom: none !important;
  }

  .date-header.sunday {
    background: #fef2f2 !important;
  }

  .date-label {
    font-size: 13px;
    font-weight: 700;
    color: #1e293b;
  }

  .day-name {
    font-size: 10px;
    font-weight: 500;
    color: #94a3b8;
    margin-top: 1px;
  }

  .totals-header {
    background: #eef2ff !important;
    color: #3730a3;
  }

  .sub-header {
    font-size: 10px;
    font-weight: 600;
    color: #64748b;
    padding: 4px 6px !important;
    min-width: 50px;
    border-top: none !important;
  }

  .total-sub {
    background: #eef2ff !important;
    color: #4338ca;
  }

  .sticky-col {
    position: sticky;
    left: 0;
    z-index: 2;
    background: white;
  }

  thead .sticky-col {
    z-index: 4;
    background: #f8fafc;
  }

  .col-employee {
    min-width: 140px;
    max-width: 180px;
    text-align: left;
    padding: 8px 10px !important;
  }

  .emp-name {
    font-weight: 600;
    color: #1e293b;
    border-right: 2px solid #e2e8f0;
  }

  tbody tr {
    border-bottom: 1px solid #f1f5f9;
  }

  tbody tr:hover {
    background: #f8fafc;
  }

  tbody tr:hover .sticky-col {
    background: #f8fafc;
  }

  td {
    border: 1px solid #f1f5f9;
    padding: 5px 6px;
    text-align: center;
    color: #475569;
    vertical-align: middle;
  }

  .data-cell {
    font-size: 11px;
  }

  .hours-cell {
    font-weight: 600;
    color: #1e40af;
  }

  .late-cell {
    color: #dc2626;
    font-weight: 600;
    font-size: 10px;
  }

  .ot-cell {
    color: #16a34a;
    font-weight: 600;
    font-size: 10px;
  }

  .leave-cell {
    background: #fef3c7;
    text-align: center;
  }

  .leave-badge {
    font-size: 10px;
    font-weight: 600;
    color: #92400e;
    white-space: nowrap;
  }

  .no-shift-cell {
    background: #f9fafb;
    text-align: center;
  }

  .no-shift-badge {
    font-size: 10px;
    color: #d1d5db;
  }

  .absent-cell {
    background: #fef2f2;
    text-align: center;
  }

  .absent-badge {
    font-size: 10px;
    font-weight: 700;
    color: #dc2626;
  }

  .absent-total {
    color: #dc2626;
  }

  .total-cell {
    font-weight: 700;
    background: #f5f3ff;
    color: #4338ca;
    border-left: 1px solid #e2e8f0;
    font-size: 11px;
  }

  .late-total {
    color: #dc2626;
  }

  .ot-total {
    color: #16a34a;
  }
</style>
