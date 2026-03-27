<!-- Salary Management Window -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { get } from 'svelte/store';
  import { supabase } from '../../../lib/supabaseClient';
  import { authStore } from '../../../stores/authStore';

  interface Employee {
    id: string;       // employee_id
    user_id: string;  // users.id (auth UUID, used for attendance FK)
    user_name: string;
    email: string;
    basic_salary: number;
  }

  interface AttendanceRecord {
    user_id: string;
    employee_id: string;
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
    user_id: string | null;  // user_id from attendance (for modal operations)
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
    perDaySalary: number;
    perHourSalary: number;
    monthlySalary: number;
    actualByDays: number;
    actualByHours: number;
    otPayAmount: number;      // OT bonus amount
    latePenaltyAmount: number; // Late penalty amount
    totalBooked: number;   // Total booked for selected period
    totalPaid: number;     // Total paid for selected period
    ledgerBalance: number;  // Net balance (positive = we owe, negative = they owe)
    toPay: number;          // Amount we owe to employee
    toReceive: number;       // Amount employee owes us
  }

  let dateFrom = '';
  let dateTo = '';
  let loading = false;
  let isSubmitting = false; // Prevent double-submission during RPC calls
  let employees: Employee[] = [];
  let employeeRows: EmployeeRow[] = [];
  let dates: string[] = [];
  let ledgers: any[] = [];
  let applyOTMap: Map<string, boolean> = new Map(); // Track per-employee OT toggle state
  let applyLateMap: Map<string, boolean> = new Map(); // Track per-employee Late toggle state
  let currentUserId = ''; // Store current user ID for ledger entries

  // Lookup maps
  let attendanceMap: Map<string, AttendanceRecord> = new Map();
  let specialShiftMap: Map<string, ShiftInfo> = new Map();
  let regularShiftMap: Map<string, ShiftInfo> = new Map();
  let leavesByEmployee: Map<string, LeaveInfo[]> = new Map();

  onMount(() => {
    // Capture current user ID from authStore
    currentUserId = get(authStore).user?.id || '';
    
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

    try {
      // Use RPC to batch all queries together
      const { data: rpcResults, error: rpcError } = await supabase.rpc('fn_get_salary_data', {
        p_date_from: dateFrom,
        p_date_to: dateTo
      });

      if (rpcError) {
        console.error('Salary data RPC error:', rpcError);
        loading = false;
        return;
      }

      // DEBUG: Log raw RPC response
      console.log('DEBUG: Raw RPC Results:', JSON.stringify(rpcResults, null, 2));

      // Parse RPC results by type
      const rpcMap = new Map<string, any[]>();
      for (const row of (rpcResults || [])) {
        const data = Array.isArray(row.data) ? row.data : (row.data ? JSON.parse(row.data) : []);
        rpcMap.set(row.result_type, data);
        console.log(`DEBUG: ${row.result_type} =`, data);
      }

      const empData = rpcMap.get('employees') || [];
      const attData = rpcMap.get('attendance') || [];
      const specialShiftData = rpcMap.get('special_shifts') || [];
      const regularShiftData = rpcMap.get('shifts') || [];
      const leaveData = rpcMap.get('leaves') || [];
      
      console.log('DEBUG: Raw Shifts data:', JSON.stringify(regularShiftData, null, 2));
      console.log('DEBUG: Shifts count:', regularShiftData.length);
      if (regularShiftData.length > 0) {
        regularShiftData.forEach((s, i) => {
          console.log(`  Shift ${i}:`, s);
        });
      }

      // Clear maps
      employees = [];
      attendanceMap = new Map();
      specialShiftMap = new Map();
      regularShiftMap = new Map();
      leavesByEmployee = new Map();

      // Build employees FIRST so we can create user_id → employee_id mapping
      employees = (empData || []).map((emp: any) => ({
        id: emp.id,
        user_id: emp.user_id || '',
        user_name: emp.user_name,
        email: emp.email,
        basic_salary: emp.basic_salary
      }));

      // Build user_id → employee_id mapping for attendance processing
      const userToEmployeeMap = new Map<string, string>();
      for (const emp of employees) {
        if (emp.user_id) userToEmployeeMap.set(emp.user_id, emp.id);
      }

      // Build maps from RPC data
      if (attData) {
        for (const a of attData) {
          // Use employee_id from RPC if available, otherwise compute from user_id mapping
          const empId = a.employee_id || userToEmployeeMap.get(a.user_id) || a.user_id;
          attendanceMap.set(`${empId}|${a.date}`, {
            user_id: a.user_id,
            employee_id: empId,
            date: a.date,
            check_in: a.check_in,
            check_out: a.check_out
          } as AttendanceRecord);
        }
      }

      if (specialShiftData) {
        for (const s of specialShiftData) {
          // Calculate working hours from start/end time if not provided
          let workingHours = 0;
          if (s.start_time && s.end_time) {
            const startParts = s.start_time.split(':');
            const endParts = s.end_time.split(':');
            const startMin = parseInt(startParts[0]) * 60 + parseInt(startParts[1]);
            const endMin = parseInt(endParts[0]) * 60 + parseInt(endParts[1]);
            workingHours = (endMin - startMin) / 60;
          }
          specialShiftMap.set(`${s.employee_id}|${s.shift_date}`, {
            start_time: s.start_time,
            end_time: s.end_time,
            start_buffer: s.start_buffer || 0,
            end_buffer: s.end_buffer || 0,
            working_hours: workingHours,
            overlaps_next_day: s.overlaps_next_day || false
          });
        }
      }

      if (regularShiftData) {
        for (const s of regularShiftData) {
          regularShiftMap.set(s.employee_id, {
            start_time: s.start_time,
            end_time: s.end_time,
            start_buffer: s.start_buffer || 0,
            end_buffer: s.end_buffer || 0,
            working_hours: s.working_hours || 8, // Default to 8 hours if not specified
            overlaps_next_day: s.overlaps_next_day || false
          });
        }
      }

      if (leaveData) {
        for (const leave of leaveData) {
          const leaves = leavesByEmployee.get(leave.employee_id) || [];
          leaves.push(leave);
          leavesByEmployee.set(leave.employee_id, leaves);
        }
      }

      // Build employee rows using existing logic
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
          const shift = specialShiftMap.get(`${emp.id}|${date}`) || regularShiftMap.get(emp.id) || null;
          const empLeaves = leavesByEmployee.get(emp.id) || [];
          const dateObj = new Date(date);
          const dayOfWeek = dateObj.getDay();
          const leave = empLeaves.find((l: any) => {
            if (l.leave_type === 'date' && l.leave_date === date) return true;
            if (l.leave_type === 'weekday' && l.weekday === dayOfWeek) return true;
            return false;
          });
          const isLeave = !!leave;
          const leaveName = leave?.title || '';

          if (isLeave) leaveDays++;

          const att = attendanceMap.get(`${emp.id}|${date}`);
          const checkIn = att?.check_in || null;
          const checkOut = att?.check_out || null;

          let workedHours = 0;
          if (checkIn && checkOut) {
            const inTime = new Date(checkIn).getTime();
            const outTime = new Date(checkOut).getTime();
            workedHours = Math.max(0, (outTime - inTime) / 3600000);
          }

          let lateIn = 0;
          if (shift && checkIn && !isLeave) {
            const shiftStartParts = shift.start_time.split(':');
            const shiftStartMin = parseInt(shiftStartParts[0]) * 60 + parseInt(shiftStartParts[1]) + shift.start_buffer;
            const inDate = new Date(checkIn);
            const actualMin = inDate.getHours() * 60 + inDate.getMinutes();
            lateIn = Math.max(0, actualMin - shiftStartMin);
          }

          let overtime = 0;
          if (shift && workedHours > 0 && !isLeave) {
            const overtimeHours = workedHours - shift.working_hours;
            overtime = Math.max(0, Math.round(overtimeHours * 60));
          }

          const isAbsent = !!shift && !isLeave && !checkIn && date <= today;
          if (isAbsent) absentDays++;

          totalWorked += workedHours;
          if (shift && !isLeave) {
            totalExpected += shift.working_hours;
            expectedDays++;
          }
          if (checkIn) workedDays++;
          totalLate += lateIn;
          totalOvertime += overtime;

          return { 
            date, 
            user_id: att?.user_id || null,  // Include user_id from attendance record
            checkIn, 
            checkOut, 
            workedHours, 
            shift, 
            isLeave, 
            leaveName, 
            lateIn, 
            overtime, 
            isAbsent 
          };
        });

        const monthlySalary = emp.basic_salary || 0;
        const perDaySalary = expectedDays > 0 ? monthlySalary / expectedDays : 0;
        const perHourSalary = totalExpected > 0 ? monthlySalary / totalExpected : 0;
        const actualByDays = perDaySalary * workedDays;
        const actualByHours = perHourSalary * totalWorked;
        const otPayAmount = (perHourSalary * totalOvertime) / 60;
        const latePenaltyAmount = (perHourSalary * totalLate) / 60;
        const ledgerBalance = 0; // Will be calculated after fetching summary

        return {
          employee: emp,
          days,
          totalWorked,
          totalExpected,
          totalLate,
          totalOvertime,
          leaveDays,
          absentDays,
          expectedDays,
          workedDays,
          perDaySalary,
          perHourSalary,
          monthlySalary,
          actualByDays,
          actualByHours,
          otPayAmount,
          latePenaltyAmount,
          totalBooked: 0,
          totalPaid: 0,
          ledgerBalance,
          toPay: 0,
          toReceive: 0
        };
      });

      // Fetch salary summary (booked and paid amounts) for all employees
      const { data: summaryData, error: summaryError } = await supabase.rpc('fn_get_salary_summary', {
        p_date_from: dateFrom,
        p_date_to: dateTo
      });

      if (!summaryError && summaryData && Array.isArray(summaryData)) {
        for (const row of employeeRows) {
          const summary = summaryData.find((s: any) => s.employee_id === row.employee.id);
          if (summary) {
            // Use actual employee ledger balance (all-time, not just date range)
            // Use ?? instead of || so that 0 balance is not treated as falsy
            row.totalBooked = summary.total_booked ?? 0;
            row.totalPaid = summary.total_paid ?? 0;
            row.ledgerBalance = summary.ledger_balance ?? 0;
            row.toPay = Math.max(0, row.ledgerBalance);
            row.toReceive = Math.max(0, -row.ledgerBalance);
          }
        }
      }

      loading = false;
    } catch (err: any) {
      console.error('Load data error:', err);
      loading = false;
    }
  }

  function formatTime12Hour(hours: string, minutes: string): string {
    let h = parseInt(hours);
    const m = String(minutes).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return `${h}:${m} ${ampm}`;
  }

  function formatShiftTime(timeStr: string): string {
    const [h, m] = timeStr.split(':');
    return formatTime12Hour(h, m);
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

  function getUnbookedAmount(row: EmployeeRow): number {
    const actual = (applyOTMap.get(row.employee.id) ? row.actualByDays + row.otPayAmount : row.actualByDays) - (applyLateMap.get(row.employee.id) ? row.latePenaltyAmount : 0);
    const diff = Math.round((actual - row.totalBooked) * 100) / 100;
    // Ignore sub-rupee rounding dust from per-day booking
    if (diff > 0 && diff < 1 && row.totalBooked > 0) return 0;
    return Math.max(0, diff);
  }

  function formatDateLabel(dateStr: string): string {
    const d = new Date(dateStr);
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`;
  }

  function formatFullDate(dateStr: string): string {
    const d = new Date(dateStr);
    return `${String(d.getDate()).padStart(2, '0')}-${String(d.getMonth() + 1).padStart(2, '0')}-${d.getFullYear()}`;
  }

  function getDayName(dateStr: string): string {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[new Date(dateStr).getDay()];
  }

  let expandedRows: Set<string> = new Set();
  let showSalaryCols = false;

  // Modal state for time picker
  let showTimeModal = false;
  let modalType: 'check-in' | 'check-out' | null = null;
  let modalEmployeeId = ''; // employee_id for display
  let modalUserId = ''; // users.id for database operations
  let modalDate = '';
  let modalEmployeeName = '';
  let pickedHours = '09';
  let pickedMinutes = '00';
  let modalShiftInfo: ShiftInfo | null = null;

  // Modal state for salary booking & payment
  let showBookModal = false;
  let bookModalEmployeeId = '';
  let bookModalEmployeeName = '';
  let bookModalPerDaySalary = 0;
  let bookModalPerHourSalary = 0;
  let bookModalApplyOT = false;
  let bookModalApplyLate = false;
  let bookModalOTMultiplier = 2; // 2x, 1.5x, or 1x per hour
  let bookModalDayDetails: Array<{date: string, dayAmount: number, hourAmount: number, otAmount: number, lateAmount: number, useDay: boolean, applyOT: boolean, applyLate: boolean, isLeave: boolean, leaveName: string, isAbsent: boolean, workedHours: number, otHours: number, lateHours: number, isBooked: boolean, bookedAmount: number, paidAmount: number, unpaidAmount: number}> = [];
  let bookModalTotalAmount = 0;
  
  // Editing state for amount cells
  let editingCell: { index: number; field: 'dayAmount' | 'hourAmount' | 'otAmount' | 'lateAmount' | 'bookedAmount' } | null = null;
  let editingValue = '';
  
  let showPayModal = false;
  let paymentMethods: any[] = [];
  let selectedPaymentMethod = '';
  let payModalEmployeeId = '';
  let payModalEmployeeName = '';
  let payModalAmount = 0;
  let payModalDayDetails: Array<{
    date: string;
    bookedAmount: number;
    payAmount: number;
    paidAmount: number;
    balance: number;
  }> = [];
  let payModalTotalBooked = 0;
  let payModalTotalPay = 0;
  let payModalTotalPaid = 0;
  let payModalTotalBalance = 0;

  function toggleExpand(empId: string) {
    if (expandedRows.has(empId)) {
      expandedRows.delete(empId);
    } else {
      expandedRows.add(empId);
    }
    expandedRows = expandedRows; // trigger reactivity
  }

  function startEditCell(index: number, field: 'dayAmount' | 'hourAmount' | 'otAmount' | 'lateAmount' | 'bookedAmount') {
    editingCell = { index, field };
    editingValue = bookModalDayDetails[index][field].toFixed(2);
  }

  async function saveEditCell() {
    if (!editingCell) return;
    const value = parseFloat(editingValue);
    if (!isNaN(value) && value >= 0) {
      const detail = bookModalDayDetails[editingCell.index];
      if (editingCell.field === 'dayAmount') detail.dayAmount = value;
      else if (editingCell.field === 'hourAmount') detail.hourAmount = value;
      else if (editingCell.field === 'otAmount') detail.otAmount = value;
      else if (editingCell.field === 'lateAmount') detail.lateAmount = value;
      else if (editingCell.field === 'bookedAmount') {
        detail.bookedAmount = value;
        // Save booked amount change using RPC
        if (detail.isBooked && bookModalEmployeeId) {
          try {
            const { data: result, error: rpcError } = await supabase
              .rpc('fn_save_booked_amount', {
                p_employee_id: bookModalEmployeeId,
                p_date: detail.date,
                p_new_amount: value,
                p_created_by: currentUserId
              });

            if (rpcError) {
              console.error('RPC error:', rpcError);
              alert('Failed to save booked amount: ' + rpcError.message);
              return;
            }

            if (result && result[0] && !result[0].success) {
              alert('Failed to save: ' + result[0].message);
              return;
            }
          } catch (err: any) {
            console.error('Error saving booked amount:', err);
            alert('Error saving booked amount: ' + err.message);
          }
        }
      }
      
      bookModalDayDetails = bookModalDayDetails; // Trigger Svelte reactivity
      updateBookModalTotal();
    }
    editingCell = null;
    editingValue = '';
  }

  function cancelEditCell() {
    editingCell = null;
    editingValue = '';
  }

  function formatHoursMinutes(hours: number): string {
    const wholeHours = Math.floor(hours);
    const minutes = Math.round((hours - wholeHours) * 60);
    if (wholeHours > 0 && minutes > 0) {
      return `${wholeHours} hrs ${minutes} mins`;
    } else if (wholeHours > 0) {
      return `${wholeHours} hrs`;
    } else if (minutes > 0) {
      return `${minutes} mins`;
    }
    return '0 mins';
  }

  function openTimeModal(type: 'check-in' | 'check-out', employeeId: string, userId: string, date: string, employeeName: string, dayData: DayData) {
    modalType = type;
    modalEmployeeId = employeeId;
    modalUserId = userId;
    modalDate = date;
    modalEmployeeName = employeeName;
    modalShiftInfo = dayData.shift;
    
    // Set default time based on shift
    if (dayData.shift) {
      if (type === 'check-in') {
        const [h, m] = dayData.shift.start_time.split(':');
        pickedHours = h;
        pickedMinutes = m;
      } else {
        const [h, m] = dayData.shift.end_time.split(':');
        pickedHours = h;
        pickedMinutes = m;
      }
    } else {
      const now = new Date();
      pickedHours = String(now.getHours()).padStart(2, '0');
      pickedMinutes = String(now.getMinutes()).padStart(2, '0');
    }
    
    showTimeModal = true;
  }

  async function submitTime() {
    if (!modalType || !modalEmployeeId || !modalDate) return;
    
    const date = new Date(modalDate);
    const hours = parseInt(pickedHours);
    const minutes = parseInt(pickedMinutes);
    const iso = new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours, minutes).toISOString();
    
    try {
      // First, check if a record exists for this user_id and date
      const { data: existing, error: fetchError } = await supabase
        .from('attendance')
        .select('id, check_in, check_out')
        .eq('user_id', modalUserId)
        .eq('date', modalDate)
        .maybeSingle();
      
      if (fetchError) {
        alert('Error fetching record: ' + fetchError.message);
        return;
      }
      
      if (existing) {
        // Record exists, update the appropriate field
        let updateData: any = {};
        if (modalType === 'check-in') {
          updateData.check_in = iso;
        } else {
          updateData.check_out = iso;
        }
        
        const { error: updateError } = await supabase
          .from('attendance')
          .update(updateData)
          .eq('id', existing.id);
        
        if (updateError) {
          alert('Error updating record: ' + updateError.message);
        }
      } else {
        // Record doesn't exist, insert new one
        const newRecord: any = {
          user_id: modalUserId,
          date: modalDate,
        };
        
        if (modalType === 'check-in') {
          newRecord.check_in = iso;
          newRecord.check_out = null;
        } else {
          newRecord.check_in = null;
          newRecord.check_out = iso;
        }
        
        const { error: insertError } = await supabase
          .from('attendance')
          .insert([newRecord]);
        
        if (insertError) {
          alert('Error inserting record: ' + insertError.message);
        }
      }
      
      closeTimeModal();
      loadData();
    } catch (err: any) {
      alert('Error: ' + err.message);
    }
  }

  function closeTimeModal() {
    showTimeModal = false;
    modalType = null;
    modalEmployeeId = '';
    modalDate = '';
    modalEmployeeName = '';
  }

  function toggleOT(employeeId: string) {
    const current = applyOTMap.get(employeeId) ?? false;
    applyOTMap.set(employeeId, !current);
    applyOTMap = applyOTMap; // Trigger reactivity
  }

  function toggleLate(employeeId: string) {
    const current = applyLateMap.get(employeeId) ?? false;
    applyLateMap.set(employeeId, !current);
    applyLateMap = applyLateMap; // Trigger reactivity
  }

  function applyOTToAll() {
    bookModalDayDetails = bookModalDayDetails.map(d => ({ ...d, applyOT: true }));
    updateBookModalTotal();
  }

  function clearOTFromAll() {
    bookModalDayDetails = bookModalDayDetails.map(d => ({ ...d, applyOT: false }));
    updateBookModalTotal();
  }

  function applyLateToAll() {
    bookModalDayDetails = bookModalDayDetails.map(d => ({ ...d, applyLate: true }));
    updateBookModalTotal();
  }

  function clearLateFromAll() {
    bookModalDayDetails = bookModalDayDetails.map(d => ({ ...d, applyLate: false }));
    updateBookModalTotal();
  }

  // Book Salary Modal Functions
  async function openBookModal(employeeId: string, employeeName: string, amount: number) {
    // Find employee row to get salary details
    const empRow = employeeRows.find(r => r.employee.id === employeeId);
    if (!empRow) return;

    let bookedDates: Set<string> = new Set(); // Track which dates have been booked

    try {
      // Use RPC to get booked and paid amounts
      const { data: salaryStatus, error: rpcError } = await supabase
        .rpc('fn_get_salary_status', {
          p_employee_id: employeeId,
          p_date_from: dateFrom,
          p_date_to: dateTo
        });

      if (rpcError) {
        console.error('RPC error:', rpcError);
        return;
      }

      const bookedMap = new Map<string, number>();
      const paidMap = new Map<string, number>();
      
      if (salaryStatus && Array.isArray(salaryStatus)) {
        for (const status of salaryStatus) {
          bookedMap.set(status.date, status.booked_amount || 0);
          paidMap.set(status.date, status.paid_amount || 0);
          bookedDates.add(status.date); // Mark this date as booked
        }
      }

      bookModalEmployeeId = employeeId;
      bookModalEmployeeName = employeeName;
      bookModalPerDaySalary = empRow.perDaySalary;
      bookModalPerHourSalary = empRow.perHourSalary;
      bookModalApplyOT = false;
      bookModalApplyLate = false;

      // Build daily details for each date in range with OT and Late amounts
      bookModalDayDetails = dates.map((date) => {
        const dayData = empRow.days.find(d => d.date === date);
        // Only pay for: worked days with assigned shift AND actual attendance (check-in)
        // Exclude: leave days, off days (no shift), and absent days - all get ₹0
        const hasExpectedShift = dayData && dayData.shift;
        const hasAttendance = dayData && dayData.checkIn;
        const dayAmount = (dayData && hasExpectedShift && hasAttendance ? 1 : 0) * bookModalPerDaySalary;
        const hourAmount = (dayData?.workedHours || 0) * bookModalPerHourSalary;
        
        // Calculate OT and Late amounts for this specific day
        const otAmount = dayData?.overtime ? (dayData.overtime / 60) * bookModalPerHourSalary : 0;
        const lateAmount = dayData?.lateIn ? (dayData.lateIn / 60) * bookModalPerHourSalary : 0;
        
        const bookedAmount = bookedMap.get(date) || 0;
        const paidAmount = paidMap.get(date) || 0;
        const unpaidAmount = bookedAmount - paidAmount;
        
        return { 
          date, 
          dayAmount, 
          hourAmount,
          otAmount,
          lateAmount,
          workedHours: dayData?.workedHours || 0,
          otHours: dayData?.overtime ? dayData.overtime / 60 : 0,
          lateHours: dayData?.lateIn ? dayData.lateIn / 60 : 0,
          useDay: true,
          applyOT: false,
          applyLate: false,
          isLeave: dayData?.isLeave || false,
          leaveName: dayData?.leaveName || '',
          isAbsent: dayData?.isAbsent || false,
          isBooked: bookedDates.has(date),
          bookedAmount,
          paidAmount,
          unpaidAmount
        };
      });

      // Calculate total based on default (useDay: true)
      updateBookModalTotal();
      showBookModal = true;
    } catch (err: any) {
      console.error('Error opening book modal:', err);
      alert('Error loading salary data: ' + err.message);
    }
  }

  function updateBookModalTotal() {
    bookModalTotalAmount = bookModalDayDetails.reduce((sum, detail) => {
      // Skip already-booked days — only preview NEW bookings
      if (detail.isBooked) return sum;

      // Base salary (day or hour depending on toggle)
      let baseAmount = detail.useDay ? detail.dayAmount : detail.hourAmount;
      
      // Add OT if toggled for this date (with multiplier applied)
      if (detail.applyOT) {
        baseAmount += detail.otAmount * bookModalOTMultiplier;
      }
      
      // Subtract Late deduction if toggled for this date
      if (detail.applyLate) {
        baseAmount -= detail.lateAmount;
      }
      
      return sum + baseAmount;
    }, 0);
  }

  function closeBookModal() {
    showBookModal = false;
    bookModalEmployeeId = '';
    bookModalEmployeeName = '';
    bookModalPerDaySalary = 0;
    bookModalPerHourSalary = 0;
    bookModalApplyOT = false;
    bookModalApplyLate = false;
    editingCell = null;
    editingValue = '';
    bookModalOTMultiplier = 2;
    bookModalDayDetails = [];
    bookModalTotalAmount = 0;
  }

  async function bookSalary() {
    if (!bookModalEmployeeId || bookModalDayDetails.length === 0) {
      alert('No days to book');
      return;
    }

    // Prevent double-submission
    if (isSubmitting) {
      alert('Booking in progress... please wait');
      return;
    }

    try {
      isSubmitting = true;

      // Prepare details with calculated amounts
      const details = bookModalDayDetails
        .map(detail => {
          let amount = detail.useDay ? detail.dayAmount : detail.hourAmount;
          if (detail.applyOT) amount += detail.otAmount * bookModalOTMultiplier;
          if (detail.applyLate) amount -= detail.lateAmount;
          return { date: detail.date, bookedAmount: Math.max(0, amount) };
        });

      // Use RPC to book salary - single call batches all operations  
      const { data: result, error: rpcError } = await supabase
        .rpc('fn_book_salary', {
          p_employee_id: bookModalEmployeeId,
          p_date_from: dateFrom,
          p_date_to: dateTo,
          p_details: details,
          p_created_by: currentUserId
        });

      if (rpcError) throw new Error(rpcError.message);
      if (!result?.[0]) throw new Error('No response from server');

      const { inserted_count, updated_count } = result[0];
      closeBookModal();
      await loadData();
      alert(`Salary booked successfully! ${inserted_count} new entries created, ${updated_count} updated.`);
    } catch (err: any) {
      alert('Error booking salary: ' + err.message);
    } finally {
      isSubmitting = false;
    }
  }

  // Pay Salary Modal Functions
  async function loadPaymentMethods() {
    try {
      // Use RPC to get payment methods with balances
      const { data: methods, error: rpcError } = await supabase
        .rpc('fn_get_payment_methods');

      if (rpcError) {
        console.error('RPC error loading payment methods:', rpcError);
        paymentMethods = [];
        return;
      }

      if (Array.isArray(methods)) {
        paymentMethods = methods.map((m: any) => ({
          id: m.id,
          ledger_name: m.ledger_name,
          availableBalance: m.available_balance || 0
        }));
      } else {
        paymentMethods = [];
      }
    } catch (err: any) {
      console.error('Error loading payment methods:', err.message);
      paymentMethods = [];
    }
  }

  async function openPayModal(employeeId: string, employeeName: string, bookedAmount: number) {
    await loadPaymentMethods();
    payModalEmployeeId = employeeId;
    payModalEmployeeName = employeeName;
    selectedPaymentMethod = '';
    payModalDayDetails = [];
    payModalTotalBooked = 0;
    payModalTotalPay = 0;
    payModalTotalPaid = 0;
    payModalTotalBalance = 0;

    try {
      // Use RPC to get booked and paid amounts
      const { data: salaryStatus, error: rpcError } = await supabase
        .rpc('fn_get_salary_status', {
          p_employee_id: employeeId,
          p_date_from: dateFrom,
          p_date_to: dateTo
        });

      if (rpcError) {
        console.error('RPC error:', rpcError);
        return;
      }

      // Build daily breakdown from RPC response
      const days = (salaryStatus || [])
        .map((status: any) => ({
          date: status.date,
          bookedAmount: status.booked_amount || 0,
          payAmount: (status.booked_amount || 0) - (status.paid_amount || 0),
          paidAmount: status.paid_amount || 0,
          balance: (status.booked_amount || 0) - (status.paid_amount || 0)
        }))
        .sort((a: any, b: any) => a.date.localeCompare(b.date));

      payModalDayDetails = days;
      updatePayModalTotal();
    } catch (err: any) {
      console.error('Error loading pay modal data:', err);
    }

    showPayModal = true;
  }

  function updatePayModalTotal() {
    payModalTotalBooked = payModalDayDetails.reduce((sum, d) => sum + (d.bookedAmount || 0), 0);
    payModalTotalPay = payModalDayDetails.reduce((sum, d) => sum + (d.payAmount || 0), 0);
    payModalTotalPaid = payModalDayDetails.reduce((sum, d) => sum + (d.paidAmount || 0), 0);
    payModalTotalBalance = payModalTotalBooked - payModalTotalPaid;
  }

  function closePayModal() {
    showPayModal = false;
    payModalEmployeeId = '';
    payModalEmployeeName = '';
    payModalAmount = 0;
    selectedPaymentMethod = '';
    payModalDayDetails = [];
    payModalTotalBooked = 0;
    payModalTotalPay = 0;
    payModalTotalPaid = 0;
    payModalTotalBalance = 0;
  }

  async function paySalary() {
    if (!payModalEmployeeId || !selectedPaymentMethod) {
      alert('Please select payment method');
      return;
    }

    const totalPayAmount = payModalDayDetails.reduce((sum, d) => sum + (d.payAmount || 0), 0);
    if (totalPayAmount <= 0) {
      alert('Please enter payment amounts for at least one day');
      return;
    }

    try {
      // Use RPC to pay salary - single call batches all operations
      const payments = payModalDayDetails
        .filter(d => (d.payAmount || 0) > 0)
        .map(d => ({ date: d.date, payAmount: d.payAmount }));

      const { data: result, error: rpcError } = await supabase
        .rpc('fn_pay_salary', {
          p_employee_id: payModalEmployeeId,
          p_payment_ledger_id: selectedPaymentMethod,
          p_payments: payments,
          p_created_by: currentUserId
        });

      if (rpcError) {
        alert('Error paying salary: ' + rpcError.message);
        console.error('RPC error:', rpcError);
        return;
      }

      if (result && result[0]) {
        const { payment_count } = result[0];
        closePayModal();
        await loadData();
        alert(`Salary paid successfully! ${payment_count} day payments created.`);
      }
    } catch (err: any) {
      alert('Error paying salary: ' + err.message);
      console.error('Error:', err);
    }
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
      <button class="btn-toggle-cols" on:click={() => showSalaryCols = !showSalaryCols} title="{showSalaryCols ? 'Hide' : 'Show'} Salary / Day / Hour columns">
        {showSalaryCols ? '◀ Hide Salary' : '▶ Salary Info'}
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
            <tr>
              <th class="col-expand"></th>
              <th class="col-employee">Employee</th>
              <th class="total-sub">Exp Days</th>
              <th class="total-sub">Wkd Days</th>
              <th class="total-sub">Worked Hrs</th>
              <th class="total-sub">Expected Hrs</th>
              <th class="total-sub">Late</th>
              <th class="total-sub">OT</th>
              <th class="total-sub">Leaves</th>
              <th class="total-sub">Absent</th>
              {#if showSalaryCols}
                <th class="total-sub">Salary</th>
                <th class="total-sub">/Day</th>
                <th class="total-sub">/Hour</th>
              {/if}
              <th class="total-sub">Actual (Days)</th>
              <th class="total-sub">Actual (Hrs)</th>
              <th class="total-sub">Booked</th>
              <th class="total-sub">Unbooked</th>
              <th class="total-sub">Paid</th>
              <th class="total-sub">Ledger Balance</th>
              <th class="total-sub">Book</th>
              <th class="total-sub">Pay</th>
            </tr>
          </thead>
          <tbody>
            {#each employeeRows as row}
              <tr class="summary-row" on:click={() => toggleExpand(row.employee.id)}>
                <td class="expand-btn">{expandedRows.has(row.employee.id) ? '▼' : '▶'}</td>
                <td class="emp-name">{row.employee.user_name}</td>
                <td class="total-cell">{row.expectedDays}</td>
                <td class="total-cell">{row.workedDays}</td>
                <td class="total-cell">{formatHours(row.totalWorked)}</td>
                <td class="total-cell">{formatHours(row.totalExpected)}</td>
                <td class="total-cell {row.totalLate > 0 ? 'late-total' : ''}">{formatMins(row.totalLate)}</td>
                <td class="total-cell {row.totalOvertime > 0 ? 'ot-total' : ''}">{formatMins(row.totalOvertime)}</td>
                <td class="total-cell">{row.leaveDays}</td>
                <td class="total-cell {row.absentDays > 0 ? 'absent-total' : ''}">{row.absentDays}</td>
                {#if showSalaryCols}
                  <td class="total-cell salary-cell">₹{row.monthlySalary.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                  <td class="total-cell salary-cell">₹{row.perDaySalary.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                  <td class="total-cell salary-cell">₹{row.perHourSalary.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                {/if}
                <td class="total-cell actual-cell">₹{((applyOTMap.get(row.employee.id) ? row.actualByDays + row.otPayAmount : row.actualByDays) - (applyLateMap.get(row.employee.id) ? row.latePenaltyAmount : 0)).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                <td class="total-cell actual-cell">₹{((applyOTMap.get(row.employee.id) ? row.actualByHours + row.otPayAmount : row.actualByHours) - (applyLateMap.get(row.employee.id) ? row.latePenaltyAmount : 0)).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                <td class="total-cell booked-cell">₹{row.totalBooked.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                <td class="total-cell" class:unbooked-cell={getUnbookedAmount(row) > 0} class:booked-cell={getUnbookedAmount(row) === 0}>
                  ₹{getUnbookedAmount(row).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
                </td>
                <td class="total-cell paid-cell">₹{row.totalPaid.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                <td class="total-cell ledger-balance-cell">
                  {#if row.toPay > 0}
                    <span class="balance-amount to-pay">→ ₹{row.toPay.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
                  {:else if row.toReceive > 0}
                    <span class="balance-amount to-receive">← ₹{row.toReceive.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
                  {:else}
                    <span class="balance-amount neutral">₹0.00</span>
                  {/if}
                </td>
                <td class="total-cell action-cell">
                  <button
                    class="btn-book"
                    on:click={(e) => {
                      e.stopPropagation();
                      openBookModal(row.employee.id, row.employee.user_name, row.toPay);
                    }}
                  >
                    Book
                  </button>
                </td>
                <td class="total-cell action-cell">
                  <button
                    class="btn-pay"
                    on:click={(e) => {
                      e.stopPropagation();
                      openPayModal(row.employee.id, row.employee.user_name, row.toPay);
                    }}
                    disabled={row.toPay <= 0}
                  >
                    Pay
                  </button>
                </td>
              </tr>
              {#if expandedRows.has(row.employee.id)}
                <tr class="detail-row">
                  <td colspan={showSalaryCols ? 21 : 18} class="detail-td">
                    <div class="detail-table-wrapper">
                      <table class="detail-table">
                        <thead>
                          <tr>
                            {#each dates as date}
                              <th class="date-header {new Date(date).getDay() === 0 ? 'sunday' : ''}">
                                <div class="date-label">{formatDateLabel(date)}</div>
                                <div class="day-name">{getDayName(date)}</div>
                              </th>
                            {/each}
                          </tr>
                          <tr>
                            {#each dates as _}
                              <th class="sub-header">Status</th>
                            {/each}
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            {#each row.days as day}
                              {#if day.isLeave}
                                <td class="leave-cell" title={day.leaveName}>
                                  <span class="leave-badge">🏖 {day.leaveName || 'Leave'}</span>
                                </td>
                              {:else if day.isAbsent}
                                <td class="absent-cell">
                                  <span class="absent-badge">✖ Absent</span>
                                  <button class="btn-action btn-record" on:click={() => openTimeModal('check-in', row.employee.id, row.employee.user_id, day.date, row.employee.user_name, day)}>+ Check-in</button>
                                </td>
                              {:else if !day.shift}
                                <td class="no-shift-cell">
                                  <span class="no-shift-badge">No Shift</span>
                                </td>
                              {:else}
                                <td class="detail-data-cell">
                                  {#if !day.checkIn}
                                    <div class="detail-missing">
                                      <span style="color: #dc2626; font-weight: 600;">Missing Check-in</span>
                                      <button class="btn-action btn-record" on:click={() => openTimeModal('check-in', row.employee.id, row.employee.user_id, day.date, row.employee.user_name, day)}>+ Check-in</button>
                                    </div>
                                  {:else if !day.checkOut}
                                    <div class="detail-in-out">
                                      <span>In: {formatTime(day.checkIn)}</span>
                                      <span style="color: #dc2626; font-weight: 600;">Missing Check-out</span>
                                    </div>
                                    <button class="btn-action btn-record" on:click={() => openTimeModal('check-out', row.employee.id, row.employee.user_id, day.date, row.employee.user_name, day)}>+ Check-out</button>
                                  {:else}
                                    <div class="detail-in-out">
                                      <div class="detail-time-row">
                                        <span>In: {formatTime(day.checkIn)}</span>
                                        <button class="btn-action btn-edit" on:click={() => openTimeModal('check-in', row.employee.id, row.employee.user_id, day.date, row.employee.user_name, day)}>Edit</button>
                                      </div>
                                      <div class="detail-time-row">
                                        <span>Out: {formatTime(day.checkOut)}</span>
                                        <button class="btn-action btn-edit" on:click={() => openTimeModal('check-out', row.employee.id, row.employee.user_id, day.date, row.employee.user_name, day)}>Edit</button>
                                      </div>
                                    </div>
                                  {/if}
                                  <div class="detail-hours">{formatHours(day.workedHours)}</div>
                                  {#if day.lateIn > 0}
                                    <div class="detail-late">Late: {formatMins(day.lateIn)}</div>
                                  {/if}
                                  {#if day.overtime > 0}
                                    <div class="detail-ot">OT: {formatMins(day.overtime)}</div>
                                  {/if}
                                </td>
                              {/if}
                            {/each}
                          </tr>
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
</div>

{#if showTimeModal}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="modal-overlay" on:click={closeTimeModal} on:keydown={(e) => e.key === 'Escape' && closeTimeModal()}>
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div class="modal-content" on:click|stopPropagation role="dialog" aria-modal="true" tabindex="0">
      <div class="modal-header">
        <h3>{modalType === 'check-in' ? '⏥ Record Check-in' : '⏤ Record Check-out'}</h3>
        <button class="btn-close" on:click={closeTimeModal}>✕</button>
      </div>
      
      <div class="modal-body">
        <div class="modal-section">
          <strong>Employee:</strong> {modalEmployeeName}
        </div>
        
        <div class="modal-section">
          <strong>Date:</strong> {formatFullDate(modalDate)}
        </div>

        {#if modalShiftInfo}
          <div class="modal-section">
            <strong>Shift Details:</strong>
            <div class="shift-info">
              <span>Start: {formatShiftTime(modalShiftInfo.start_time)}</span>
              <span>End: {formatShiftTime(modalShiftInfo.end_time)}</span>
              <span>Duration: {formatHours(modalShiftInfo.working_hours)}</span>
            </div>
          </div>
        {/if}

        <div class="modal-section">
          <strong>Select Time:</strong>
          <div class="time-picker">
            <div class="time-input">
              <!-- svelte-ignore a11y_label_has_associated_control -->
              <label for="hours-input">Hours</label>
              <input id="hours-input" type="number" min="0" max="23" bind:value={pickedHours} />
            </div>
            <div class="time-separator">:</div>
            <div class="time-input">
              <!-- svelte-ignore a11y_label_has_associated_control -->
              <label for="minutes-input">Minutes</label>
              <input id="minutes-input" type="number" min="0" max="59" bind:value={pickedMinutes} />
            </div>
            <div class="time-display">
              {formatTime12Hour(pickedHours, pickedMinutes)}
            </div>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" on:click={closeTimeModal}>Cancel</button>
        <button class="btn-submit" on:click={submitTime}>Record {modalType === 'check-in' ? 'Check-in' : 'Check-out'}</button>
      </div>
    </div>
  </div>
{/if}

<!-- Book Salary Modal -->
{#if showBookModal}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="modal-overlay" on:click={closeBookModal} on:keydown={(e) => e.key === 'Escape' && closeBookModal()}>
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div class="modal-content book-modal" on:click|stopPropagation role="dialog" aria-modal="true" tabindex="0">
      <div class="modal-header">
        <h3>📖 Book Salary</h3>
        <button class="btn-close" on:click={closeBookModal}>✕</button>
      </div>
      
      <div class="modal-body book-modal-body">
        <div class="book-modal-header-info">
          <div class="header-item">
            <strong>Employee:</strong> {bookModalEmployeeName}
          </div>
          <div class="header-item">
            <strong>Period:</strong> {formatFullDate(dateFrom)} to {formatFullDate(dateTo)}
          </div>
        </div>

        <div class="book-modal-toggles">
          <div class="toggles-left">
            <button 
              class="apply-all-btn"
              on:click={applyOTToAll}
            >
              ✓ Apply OT All
            </button>
            <button 
              class="clear-all-btn"
              on:click={clearOTFromAll}
            >
              ✗ Clear OT All
            </button>
            <button 
              class="apply-all-btn"
              on:click={applyLateToAll}
            >
              ✓ Apply Late All
            </button>
            <button 
              class="clear-all-btn"
              on:click={clearLateFromAll}
            >
              ✗ Clear Late All
            </button>
          </div>

          <div class="toggles-right">
            <label class="radio-label">
              <input 
                type="radio" 
                bind:group={bookModalOTMultiplier}
                value={2}
                on:change={() => updateBookModalTotal()}
              />
              <span>2x OT</span>
            </label>
            <label class="radio-label">
              <input 
                type="radio" 
                bind:group={bookModalOTMultiplier}
                value={1.5}
                on:change={() => updateBookModalTotal()}
              />
              <span>1.5x OT</span>
            </label>
            <label class="radio-label">
              <input 
                type="radio" 
                bind:group={bookModalOTMultiplier}
                value={1}
                on:change={() => updateBookModalTotal()}
              />
              <span>1x OT</span>
            </label>
          </div>
        </div>

        <div class="book-modal-table-container">
          <table class="book-modal-table">
            <thead>
              <tr>
                <th class="date-th">Date</th>
                <th class="status-th">Booked</th>
                <th class="status-th">Status</th>
                <th class="amt-th">Day</th>
                <th class="amt-th">Hour</th>
                <th class="amt-th">OT Amt</th>
                <th class="toggle-th">Apply OT</th>
                <th class="amt-th">Late Amt</th>
                <th class="toggle-th">Apply Late</th>
                <th class="amt-th">Paid</th>
                <th class="amt-th">Unpaid</th>
                <th class="toggle-th">Pay Method</th>
              </tr>
            </thead>
            <tbody>
              {#each bookModalDayDetails as detail, idx (detail.date)}
                <tr>
                  <td class="date-col">
                    {detail.date}
                  </td>
                  <td class="status-col">
                    {#if detail.isBooked}
                      <div class="booked-info editable-cell" on:dblclick={() => startEditCell(idx, 'bookedAmount')}>
                        {#if editingCell?.index === idx && editingCell?.field === 'bookedAmount'}
                          <div class="edit-input-container">
                            <input
                              type="number"
                              step="0.01"
                              bind:value={editingValue}
                              on:keydown={(e) => {
                                if (e.key === 'Enter') saveEditCell();
                                if (e.key === 'Escape') cancelEditCell();
                              }}
                              class="edit-input"
                            />
                            <button class="save-btn" on:click={saveEditCell} title="Save">✓</button>
                            <button class="cancel-btn" on:click={cancelEditCell} title="Cancel">✕</button>
                          </div>
                        {:else}
                          <div class="booked-status">✓ Booked</div>
                          <div class="booked-amount">₹{detail.bookedAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>
                        {/if}
                      </div>
                    {:else}
                      <div class="booked-info">
                        <div class="booked-status" style="color: #f59e0b;">⏳ Will Book</div>
                        <div class="booked-amount" style="color: #059669;">₹{(detail.useDay ? detail.dayAmount : detail.hourAmount).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>
                      </div>
                    {/if}
                  </td>
                  <td class="status-col">
                    {#if detail.isAbsent}
                      <span class="status-badge absent">Absent</span>
                    {:else if detail.isLeave}
                      <span class="status-badge leave">{detail.leaveName || 'Leave'}</span>
                    {:else}
                      <span class="status-badge worked">Worked</span>
                    {/if}
                  </td>
                  <td class="amt-col editable-cell" on:dblclick={() => startEditCell(idx, 'dayAmount')}>
                    {#if editingCell?.index === idx && editingCell?.field === 'dayAmount'}
                      <input
                        type="number"
                        step="0.01"
                        bind:value={editingValue}
                        on:blur={saveEditCell}
                        on:keydown={(e) => {
                          if (e.key === 'Enter') saveEditCell();
                          if (e.key === 'Escape') cancelEditCell();
                        }}
                        class="edit-input"
                      />
                    {:else}
                      ₹{detail.dayAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
                    {/if}
                  </td>
                  <td class="amt-col editable-cell" on:dblclick={() => startEditCell(idx, 'hourAmount')}>
                    {#if editingCell?.index === idx && editingCell?.field === 'hourAmount'}
                      <input
                        type="number"
                        step="0.01"
                        bind:value={editingValue}
                        on:blur={saveEditCell}
                        on:keydown={(e) => {
                          if (e.key === 'Enter') saveEditCell();
                          if (e.key === 'Escape') cancelEditCell();
                        }}
                        class="edit-input"
                      />
                    {:else}
                      <div class="hour-info">
                        <div class="hour-amount">₹{detail.hourAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>
                        <div class="hour-duration">{formatHoursMinutes(detail.workedHours)}</div>
                      </div>
                    {/if}
                  </td>
                  <td class="amt-col editable-cell {detail.applyOT ? 'active-amt' : ''}" on:dblclick={() => startEditCell(idx, 'otAmount')}>
                    {#if editingCell?.index === idx && editingCell?.field === 'otAmount'}
                      <input
                        type="number"
                        step="0.01"
                        bind:value={editingValue}
                        on:blur={saveEditCell}
                        on:keydown={(e) => {
                          if (e.key === 'Enter') saveEditCell();
                          if (e.key === 'Escape') cancelEditCell();
                        }}
                        class="edit-input"
                      />
                    {:else}
                      <div class="hour-info">
                        <div class="hour-amount">₹{detail.otAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>
                        <div class="hour-duration">{formatHoursMinutes(detail.otHours)}</div>
                      </div>
                    {/if}
                  </td>
                  <td class="toggle-col">
                    <button
                      class="row-toggle-btn"
                      class:active={detail.applyOT}
                      on:click={() => {
                        bookModalDayDetails[idx].applyOT = !bookModalDayDetails[idx].applyOT;
                        updateBookModalTotal();
                      }}
                      title="Toggle OT for this date"
                    >
                      {detail.applyOT ? '✓' : '○'}
                    </button>
                  </td>
                  <td class="amt-col editable-cell {detail.applyLate ? 'active-amt' : ''}" on:dblclick={() => startEditCell(idx, 'lateAmount')}>
                    {#if editingCell?.index === idx && editingCell?.field === 'lateAmount'}
                      <input
                        type="number"
                        step="0.01"
                        bind:value={editingValue}
                        on:blur={saveEditCell}
                        on:keydown={(e) => {
                          if (e.key === 'Enter') saveEditCell();
                          if (e.key === 'Escape') cancelEditCell();
                        }}
                        class="edit-input"
                      />
                    {:else}
                      <div class="hour-info">
                        <div class="hour-amount">₹{detail.lateAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>
                        <div class="hour-duration">{formatHoursMinutes(detail.lateHours)}</div>
                      </div>
                    {/if}
                  </td>
                  <td class="toggle-col">
                    <button
                      class="row-toggle-btn"
                      class:active={detail.applyLate}
                      on:click={() => {
                        bookModalDayDetails[idx].applyLate = !bookModalDayDetails[idx].applyLate;
                        updateBookModalTotal();
                      }}
                      title="Toggle Late deduction for this date"
                    >
                      {detail.applyLate ? '✓' : '○'}
                    </button>
                  </td>
                  <td class="amt-col">₹{detail.paidAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                  <td class="amt-col {detail.unpaidAmount > 0 ? 'unpaid-amt' : ''}">₹{detail.unpaidAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                  <td class="toggle-col">
                    <button
                      class="toggle-method-btn"
                      class:using-day={detail.useDay}
                      class:using-hour={!detail.useDay}
                      on:click={() => {
                        bookModalDayDetails[idx].useDay = !bookModalDayDetails[idx].useDay;
                        updateBookModalTotal();
                      }}
                    >
                      {detail.useDay ? 'Day' : 'Hour'}
                    </button>
                  </td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr class="total-row">
                <td colspan="2"><strong>Total</strong></td>
                <td></td>
                <td></td>
                <td></td>
                <td></td>
                <td></td>
                <td></td>
                <td></td>
                <td class="amt-col">
                  <strong>₹{bookModalDayDetails.reduce((sum, d) => sum + d.paidAmount, 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</strong>
                </td>
                <td class="amt-col">
                  <strong>₹{bookModalDayDetails.reduce((sum, d) => sum + d.unpaidAmount, 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</strong>
                </td>
                <td></td>
              </tr>
            </tfoot>
          </table>
        </div>

        <div class="book-modal-total">
          <div class="total-row-display">
            <div class="total-item">
              <strong>📋 Total to Book (Preview):</strong>
              <span style="color: #059669; font-weight: 700; font-size: 16px;">₹{bookModalTotalAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
            </div>
            <div class="total-item">
              <strong>✓ Total Already Booked:</strong>
              <span>₹{bookModalDayDetails.reduce((sum, d) => sum + d.bookedAmount, 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
            </div>
            <div class="total-item">
              <strong>💳 Total Paid:</strong>
              <span>₹{bookModalDayDetails.reduce((sum, d) => sum + d.paidAmount, 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
            </div>
            <div class="total-item">
              <strong>⏳ Total Unpaid:</strong>
              <span style="color: #dc2626;">₹{bookModalDayDetails.reduce((sum, d) => sum + d.unpaidAmount, 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" on:click={closeBookModal} disabled={isSubmitting}>Cancel</button>
        <button class="btn-submit" on:click={bookSalary} disabled={isSubmitting}>
          {isSubmitting ? 'Booking...' : 'Book Salary'}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Pay Salary Modal -->
{#if showPayModal}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="modal-overlay" on:click={closePayModal} on:keydown={(e) => e.key === 'Escape' && closePayModal()}>
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div class="modal-content pay-modal-content" on:click|stopPropagation role="dialog" aria-modal="true" tabindex="0">
      <div class="modal-header">
        <h3>💳 Pay Salary - {payModalEmployeeName}</h3>
        <button class="btn-close" on:click={closePayModal}>✕</button>
      </div>
      
      <div class="payment-method-section">
        <label for="payment-method">Payment Method:</label>
        <select id="payment-method" bind:value={selectedPaymentMethod} class="method-select">
          <option value="">Select payment method...</option>
          {#each paymentMethods as method}
            <option value={method.id}>
              {method.ledger_name} - Balance: ₹{(method.availableBalance || 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
            </option>
          {/each}
        </select>
        {#if selectedPaymentMethod}
          {@const selectedMethod = paymentMethods.find(m => m.id === selectedPaymentMethod)}
          {#if selectedMethod}
            {@const isPositive = (selectedMethod.availableBalance || 0) >= 0}
            {@const isEnough = (selectedMethod.availableBalance || 0) >= payModalTotalPay}
            <div class="balance-display" class:negative={!isPositive} class:positive={isPositive}>
              <span class="balance-status">
                {#if isEnough}
                  <span class="status-icon">✓</span>
                  <span class="status-text">Sufficient Funds</span>
                {:else if isPositive}
                  <span class="status-icon">⚠</span>
                  <span class="status-text">Partial Funds</span>
                {:else}
                  <span class="status-icon">✗</span>
                  <span class="status-text">Insufficient Funds</span>
                {/if}
              </span>
              <span class="balance-amount">₹{(selectedMethod.availableBalance || 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
            </div>
          {/if}
        {/if}
      </div>

      <!-- Daily Breakdown Table -->
      <div class="pay-table-wrapper">
        <div class="pay-table-container">
          <table class="pay-modal-table">
            <thead>
              <tr>
                <th class="date-th">Date</th>
                <th class="amt-th">Booked</th>
                <th class="amt-th">Pay Amount</th>
                <th class="amt-th">Paid</th>
                <th class="amt-th">Balance</th>
              </tr>
            </thead>
            <tbody>
              {#each payModalDayDetails as day, idx (day.date)}
                <tr>
                  <td class="date-col">{day.date}</td>
                  <td class="amt-col">₹{day.bookedAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                  <td class="amt-col pay-editable">
                    <input
                      type="number"
                      step="0.01"
                      bind:value={day.payAmount}
                      on:change={() => updatePayModalTotal()}
                      class="pay-input"
                      placeholder="0.00"
                    />
                  </td>
                  <td class="amt-col">₹{day.paidAmount.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                  <td class="amt-col balance-col">₹{day.balance.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr class="total-row">
                <td class="total-label">Total</td>
                <td class="total-amt">₹{payModalTotalBooked.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                <td class="total-amt pay-total">₹{payModalTotalPay.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                <td class="total-amt">₹{payModalTotalPaid.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                <td class="total-amt balance-total">₹{payModalTotalBalance.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" on:click={closePayModal}>Cancel</button>
        <button class="btn-submit" on:click={paySalary}>Pay Salary</button>
      </div>
    </div>
  </div>
{/if}

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

  .btn-toggle-cols {
    padding: 7px 14px;
    background: #f3f4f6;
    color: #374151;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    margin-left: 8px;
  }

  .btn-toggle-cols:hover {
    background: #e5e7eb;
    border-color: #9ca3af;
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
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    background: white;
  }

  table {
    border-collapse: collapse;
    font-size: 12px;
    width: 100%;
  }

  thead th {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    padding: 8px 12px;
    text-align: center;
    font-weight: 600;
    color: #475569;
    font-size: 12px;
  }

  .col-expand {
    width: 36px;
    min-width: 36px;
  }

  .col-employee {
    text-align: left;
    min-width: 160px;
  }

  .total-sub {
    background: #eef2ff !important;
    color: #4338ca;
  }

  .summary-row {
    cursor: pointer;
    transition: background 0.15s;
  }

  .summary-row:hover {
    background: #f0f4ff;
  }

  .expand-btn {
    text-align: center;
    font-size: 11px;
    color: #6b7280;
    padding: 8px;
    user-select: none;
  }

  .emp-name {
    font-weight: 600;
    color: #1e293b;
    text-align: left;
    padding: 8px 12px;
  }

  tbody td {
    border: 1px solid #f1f5f9;
    padding: 8px 10px;
    text-align: center;
    color: #475569;
    font-size: 12px;
  }

  .total-cell {
    font-weight: 700;
    color: #4338ca;
    background: #fafaff;
  }

  .salary-cell {
    color: #059669;
  }

  .actual-cell {
    color: #0369a1;
    font-weight: 800;
  }

  .late-total {
    color: #dc2626;
  }

  .ot-total {
    color: #16a34a;
  }

  .absent-total {
    color: #dc2626;
  }

  /* Detail row */
  .detail-row {
    background: #f8fafc;
  }

  .detail-td {
    padding: 0 !important;
    border: none !important;
  }

  .detail-table-wrapper {
    overflow-x: auto;
    padding: 8px 12px 12px 48px;
  }

  .detail-table {
    border-collapse: collapse;
    font-size: 11px;
    white-space: nowrap;
    width: max-content;
  }

  .detail-table thead th {
    background: #f1f5f9;
    border: 1px solid #e2e8f0;
    padding: 5px 8px;
    font-size: 11px;
  }

  .date-header {
    min-width: 110px;
    text-align: center;
  }

  .date-header.sunday {
    background: #fef2f2 !important;
  }

  .date-label {
    font-size: 12px;
    font-weight: 700;
    color: #1e293b;
  }

  .day-name {
    font-size: 9px;
    font-weight: 500;
    color: #94a3b8;
  }

  .sub-header {
    font-size: 9px;
    font-weight: 600;
    color: #94a3b8;
    padding: 3px 6px !important;
  }

  .detail-table tbody td {
    border: 1px solid #e2e8f0;
    padding: 6px 8px;
    vertical-align: top;
    font-size: 11px;
  }

  .detail-data-cell {
    background: white;
  }

  .detail-in-out {
    display: flex;
    flex-direction: column;
    gap: 1px;
    font-size: 10px;
    color: #475569;
  }

  .detail-missing {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 10px;
    margin-bottom: 4px;
  }

  .detail-hours {
    font-weight: 700;
    color: #1e40af;
    font-size: 11px;
    margin-top: 3px;
  }

  .detail-late {
    color: #dc2626;
    font-weight: 600;
    font-size: 10px;
  }

  .btn-action {
    padding: 3px 6px;
    border: none;
    border-radius: 3px;
    font-size: 9px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
  }

  .btn-record {
    background: #3b82f6;
    color: white;
  }

  .btn-record:hover {
    background: #2563eb;
  }

  .btn-edit {
    background: #10b981;
    color: white;
    padding: 2px 6px;
    font-size: 8px;
    margin-left: 4px;
  }

  .btn-edit:hover {
    background: #059669;
  }

  .detail-time-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 4px;
    margin-bottom: 2px;
  }

  .detail-ot {
    color: #16a34a;
    font-weight: 600;
    font-size: 10px;
  }

  .leave-cell {
    background: #fef3c7;
    text-align: center;
    vertical-align: middle;
  }

  .leave-badge {
    font-size: 10px;
    font-weight: 600;
    color: #92400e;
  }

  .no-shift-cell {
    background: #f9fafb;
    text-align: center;
    vertical-align: middle;
  }

  .no-shift-badge {
    font-size: 10px;
    color: #d1d5db;
  }

  .absent-cell {
    background: #fef2f2;
    text-align: center;
    vertical-align: middle;
  }

  .absent-badge {
    font-size: 10px;
    font-weight: 700;
    color: #dc2626;
  }

  .booked-cell {
    color: #059669;
    font-weight: 600;
  }

  .unbooked-cell {
    color: #d97706;
    font-weight: 600;
  }

  .paid-cell {
    color: #2563eb;
    font-weight: 600;
  }

  .ledger-balance-cell {
    color: #475569;
    background: #f9fafb;
    font-weight: 700;
  }

  .balance-amount {
    display: inline-block;
    padding: 4px 8px;
    border-radius: 3px;
  }

  .balance-amount.to-pay {
    color: #dc2626;
    background: #fee2e2;
  }

  .balance-amount.to-receive {
    color: #16a34a;
    background: #dcfce7;
  }

  .balance-amount.neutral {
    color: #9ca3af;
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

  .modal-content {
    background: white;
    border-radius: 8px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
    width: 90%;
    max-width: 400px;
    display: flex;
    flex-direction: column;
  }

  .modal-header {
    padding: 16px 20px;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 700;
    color: #1f2937;
  }

  .btn-close {
    background: none;
    border: none;
    font-size: 20px;
    cursor: pointer;
    color: #6b7280;
    padding: 0;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .btn-close:hover {
    color: #111827;
  }

  .modal-body {
    padding: 16px 20px;
    flex: 1;
    overflow-y: auto;
    max-height: 400px;
  }

  .modal-section {
    margin-bottom: 16px;
    font-size: 13px;
    color: #374151;
  }

  .modal-section strong {
    display: block;
    margin-bottom: 6px;
    color: #111827;
    font-weight: 600;
  }

  .shift-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 8px 12px;
    background: #f0f9ff;
    border-left: 3px solid #0284c7;
    border-radius: 3px;
    font-size: 12px;
  }

  .shift-info span {
    color: #0c4a6e;
  }

  .time-picker {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px;
    background: #f9fafb;
    border-radius: 4px;
  }

  .time-input {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .time-input label {
    font-size: 11px;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
  }

  .time-input input {
    width: 50px;
    padding: 6px;
    border: 1px solid #d1d5db;
    border-radius: 3px;
    font-size: 14px;
    font-weight: 600;
    text-align: center;
    color: #1f2937;
  }

  .time-input input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .time-separator {
    font-size: 18px;
    font-weight: 700;
    color: #9ca3af;
  }

  .time-display {
    margin-left: auto;
    font-size: 24px;
    font-weight: 700;
    color: #1f2937;
    min-width: 70px;
    text-align: right;
  }

  .modal-footer {
    padding: 12px 20px;
    border-top: 1px solid #e5e7eb;
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }

  .btn-cancel {
    padding: 8px 16px;
    background: #e5e7eb;
    color: #374151;
    border: none;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-cancel:hover {
    background: #d1d5db;
  }

  .btn-submit {
    padding: 8px 16px;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-submit:hover {
    background: #2563eb;
  }

  .btn-book {
    padding: 6px 12px;
    background: #2563eb;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-book:hover {
    background: #1d4ed8;
  }

  .btn-pay {
    padding: 6px 12px;
    background: #10b981;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-pay:hover:not(:disabled) {
    background: #059669;
  }

  .btn-pay:disabled {
    background: #d1d5db;
    color: #9ca3af;
    cursor: not-allowed;
  }

  .action-cell {
    text-align: center;
    padding: 8px 4px !important;
  }

  .method-select {
    width: 100%;
    padding: 8px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 13px;
    margin-top: 6px;
    background: white;
    cursor: pointer;
  }

  .method-select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  /* Book Modal Toggle Styles */
  .book-modal-toggles {
    display: flex;
    gap: 12px;
    margin: 12px 0;
    padding: 12px;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    flex-wrap: wrap;
    justify-content: space-between;
    align-items: flex-start;
  }

  .toggles-left {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }

  .toggles-right {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
  }

  .apply-all-btn {
    padding: 6px 10px;
    background: #10b981;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .apply-all-btn:hover {
    background: #059669;
  }

  .clear-all-btn {
    padding: 6px 10px;
    background: #ef4444;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .clear-all-btn:hover {
    background: #dc2626;
  }

  .radio-label {
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    user-select: none;
    font-size: 13px;
    font-weight: 500;
    color: #374151;
  }

  .radio-label input[type="radio"] {
    width: 14px;
    height: 14px;
    cursor: pointer;
    accent-color: #f59e0b;
  }

  .radio-label:hover {
    color: #1f2937;
  }

  /* Book Modal Table Styles */
  .book-modal {
    max-width: 900px;
    display: flex;
    flex-direction: column;
  }

  .book-modal-body {
    max-height: 750px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .book-modal-header-info {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px 16px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    font-size: 13px;
    color: #374151;
    flex-shrink: 0;
  }

  .book-modal-header-info .header-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .book-modal-header-info strong {
    color: #1f2937;
    font-weight: 600;
    margin-right: 8px;
  }

  .book-modal-table-container {
    margin: 0;
    border: 1px solid #e5e7eb;
    border-radius: 0;
    overflow-y: auto;
    flex: 1;
    border-top: 1px solid #e5e7eb;
    border-bottom: 1px solid #e5e7eb;
  }

  .book-modal-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }

  .book-modal-table thead {
    background: #f3f4f6;
    border-bottom: 2px solid #d1d5db;
    position: sticky;
    top: 0;
    z-index: 10;
  }

  .book-modal-table th {
    padding: 10px 8px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    white-space: nowrap;
    background: #f3f4f6;
  }

  .book-modal-table .date-th {
    text-align: left;
    min-width: 90px;
  }

  .book-modal-table .status-th {
    text-align: center;
    font-size: 12px;
    min-width: 90px;
  }

  .book-modal-table .amt-th {
    text-align: right;
    font-size: 12px;
    min-width: 80px;
  }

  .book-modal-table .toggle-th {
    text-align: center;
    font-size: 12px;
    min-width: 75px;
  }

  .book-modal-table tbody tr {
    border-bottom: 1px solid #f3f4f6;
  }

  .book-modal-table tbody tr:last-child {
    border-bottom: none;
  }

  .book-modal-table td {
    padding: 10px 8px;
    color: #374151;
  }

  .book-modal-table .date-col {
    font-weight: 600;
    color: #1f2937;
    min-width: 90px;
  }

  .book-modal-table .status-col {
    text-align: center;
    font-size: 12px;
    min-width: 90px;
  }

  .status-badge {
    display: inline-block;
    padding: 4px 8px;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 600;
    white-space: nowrap;
  }

  .status-badge.absent {
    background: #fee2e2;
    color: #dc2626;
  }

  .status-badge.leave {
    background: #fef3c7;
    color: #92400e;
  }

  .status-badge.worked {
    background: #dcfce7;
    color: #166534;
  }

  .booked-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .booked-status {
    font-size: 11px;
    font-weight: 600;
    color: #0284c7;
  }

  .booked-amount {
    font-size: 12px;
    font-weight: 600;
    color: #1f2937;
    font-family: 'Courier New', monospace;
  }

  .book-modal-table .amt-col {
    text-align: right;
    font-family: 'Courier New', monospace;
    font-weight: 600;
    color: #1f2937;
  }

  .book-modal-table .editable-cell {
    cursor: pointer;
    position: relative;
    padding: 4px 8px !important;
  }

  .book-modal-table .editable-cell:hover {
    background: #f0f0f0;
    border-radius: 2px;
  }

  .edit-input-container {
    display: flex;
    gap: 4px;
    align-items: center;
  }

  .edit-input {
    flex: 1;
    padding: 4px 4px;
    font-family: 'Courier New', monospace;
    font-weight: 600;
    border: 2px solid #3b82f6;
    border-radius: 2px;
    font-size: 13px;
    text-align: right;
  }

  .edit-input:focus {
    outline: none;
    border-color: #1d4ed8;
    box-shadow: 0 0 4px rgba(59, 130, 246, 0.5);
  }

  .save-btn, .cancel-btn {
    padding: 4px 8px;
    border: none;
    border-radius: 2px;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .save-btn {
    background-color: #10b981;
    color: white;
  }

  .save-btn:hover {
    background-color: #059669;
    box-shadow: 0 2px 4px rgba(16, 185, 129, 0.3);
  }

  .save-btn:active {
    transform: scale(0.95);
  }

  .cancel-btn {
    background-color: #ef4444;
    color: white;
  }

  .cancel-btn:hover {
    background-color: #dc2626;
    box-shadow: 0 2px 4px rgba(239, 68, 68, 0.3);
  }

  .cancel-btn:active {
    transform: scale(0.95);
  }

  .hour-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .hour-amount {
    font-family: 'Courier New', monospace;
    font-weight: 600;
    color: #1f2937;
  }

  .hour-duration {
    font-size: 11px;
    color: #6b7280;
    font-family: 'Courier New', monospace;
    font-weight: 500;
  }

  .book-modal-table .toggle-col {
    text-align: center;
    padding: 8px 4px !important;
  }

  .row-toggle-btn {
    padding: 4px 10px;
    border: 2px solid #cbd5e1;
    border-radius: 4px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    background: white;
    color: #64748b;
    transition: all 0.2s;
    min-width: 45px;
  }

  .row-toggle-btn:hover {
    border-color: #94a3b8;
    background: #f1f5f9;
  }

  .row-toggle-btn.active {
    background: #10b981;
    color: white;
    border-color: #059669;
  }

  .row-toggle-btn.active:hover {
    background: #059669;
  }

  .active-amt {
    background: #dcfce7 !important;
    color: #166534 !important;
    font-weight: 700;
  }

  .toggle-method-btn {
    padding: 6px 12px;
    border: 2px solid #d1d5db;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    background: white;
    color: #374151;
    transition: all 0.2s;
    min-width: 60px;
  }

  .toggle-method-btn:hover {
    border-color: #9ca3af;
    background: #f9fafb;
  }

  .toggle-method-btn.using-day {
    background: #dbeafe;
    color: #0c4a6e;
    border-color: #0284c7;
  }

  .toggle-method-btn.using-day:hover {
    background: #bfdbfe;
    border-color: #0284c7;
  }

  .toggle-method-btn.using-hour {
    background: #fcd34d;
    color: #92400e;
    border-color: #eab308;
  }

  .toggle-method-btn.using-hour:hover {
    background: #fbbf24;
    border-color: #eab308;
  }

  .book-modal-total {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    background: #f0fdf4;
    border-top: 1px solid #bbf7d0;
    border-radius: 0;
    margin: 0;
    font-size: 14px;
    flex-shrink: 0;
    border-bottom: 1px solid #e5e7eb;
  }

  .book-modal-total strong {
    color: #166534;
    font-weight: 700;
  }

  .total-row-display {
    display: flex;
    gap: 24px;
    width: 100%;
  }

  .total-item {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .total-item strong {
    color: #166534;
    font-size: 13px;
  }

  .total-item span {
    font-size: 16px;
    font-weight: 700;
    color: #16a34a;
    font-family: 'Courier New', monospace;
  }

  .unpaid-amt {
    background: #fef3c7 !important;
    font-weight: 600;
    color: #d97706;
  }

  .book-modal-table tfoot {
    background: #f0fdf4;
    border-top: 2px solid #86efac;
  }

  .book-modal-table tfoot td {
    padding: 8px 4px;
    font-weight: 600;
    border: 1px solid #e5e7eb;
  }

  /* Pay Modal Specific Styles */
  .pay-modal-content {
    width: 95%;
    max-width: 1100px;
    height: 85vh;
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .payment-method-section {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    background: #f9fafb;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .payment-method-section label {
    font-weight: 600;
    color: #374151;
    white-space: nowrap;
    min-width: 120px;
  }

  .payment-method-section .method-select {
    flex: 1;
    padding: 8px 12px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 13px;
  }

  .balance-display {
    display: flex;
    gap: 8px;
    align-items: center;
    padding: 0 12px;
    border: 1px solid #bfdbfe;
    border-radius: 4px;
    white-space: nowrap;
    flex-shrink: 0;
    transition: all 0.2s ease;
  }

  .balance-display.positive {
    background: #dcfce7;
    border-color: #86efac;
  }

  .balance-display.negative {
    background: #fee2e2;
    border-color: #fca5a5;
  }

  .balance-status {
    display: flex;
    gap: 6px;
    align-items: center;
    font-weight: 600;
    font-size: 12px;
  }

  .balance-display.positive .balance-status {
    color: #166534;
  }

  .balance-display.negative .balance-status {
    color: #b91c1c;
  }

  .status-icon {
    font-size: 14px;
    font-weight: 700;
  }

  .status-text {
    font-size: 12px;
  }

  .balance-amount {
    font-family: 'Courier New', monospace;
    font-weight: 700;
    font-size: 14px;
  }

  .balance-display.positive .balance-amount {
    color: #15803d;
  }

  .balance-display.negative .balance-amount {
    color: #991b1b;
  }

  .pay-table-wrapper {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .pay-table-container {
    flex: 1;
    overflow-y: auto;
    border-bottom: 1px solid #e5e7eb;
  }

  .pay-modal-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }

  .pay-modal-table thead {
    background: #f3f4f6;
    border-bottom: 2px solid #d1d5db;
    position: sticky;
    top: 0;
    z-index: 10;
  }

  .pay-modal-table th {
    padding: 10px 8px;
    text-align: right;
    font-weight: 600;
    color: #374151;
    white-space: nowrap;
    background: #f3f4f6;
  }

  .pay-modal-table .date-th {
    text-align: left;
    min-width: 100px;
  }

  .pay-modal-table tbody tr {
    border-bottom: 1px solid #f3f4f6;
  }

  .pay-modal-table tbody tr:hover {
    background: #f9fafb;
  }

  .pay-modal-table td {
    padding: 8px;
    color: #374151;
  }

  .pay-modal-table .date-col {
    font-weight: 600;
    color: #1f2937;
    min-width: 100px;
    text-align: left;
  }

  .pay-modal-table .amt-col {
    text-align: right;
    font-family: 'Courier New', monospace;
    font-weight: 600;
    color: #1f2937;
    min-width: 110px;
  }

  .pay-modal-table .pay-editable {
    background: #fef3c7;
    padding: 4px 4px;
  }

  .pay-input {
    width: 100%;
    padding: 4px 6px;
    border: 1px solid #fbbf24;
    border-radius: 2px;
    font-family: 'Courier New', monospace;
    font-weight: 600;
    font-size: 13px;
    text-align: right;
  }

  .pay-input:focus {
    outline: none;
    border-color: #f59e0b;
    box-shadow: 0 0 4px rgba(245, 158, 11, 0.3);
  }

  .pay-modal-table .balance-col {
    color: #dc2626;
    font-weight: 700;
  }

  .pay-modal-table tfoot {
    background: #f0fdf4;
    border-top: 2px solid #86efac;
    position: sticky;
    bottom: 0;
    z-index: 9;
  }

  .pay-modal-table .total-row td {
    padding: 12px 8px;
    font-weight: 700;
    color: #166534;
    background: #f0fdf4;
  }

  .pay-modal-table .total-label {
    text-align: left;
  }

  .pay-modal-table .total-amt {
    text-align: right;
    font-family: 'Courier New', monospace;
    color: #16a34a;
    min-width: 110px;
  }

  .pay-modal-table .pay-total {
    background: #fef3c7;
    color: #92400e;
  }

  .pay-modal-table .balance-total {
    color: #dc2626;
  }
</style>
