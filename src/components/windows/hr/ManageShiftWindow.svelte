<!-- ============================================================
     HR > MANAGE > MANAGE SHIFT WINDOW
     Purpose: Manage employee shifts and schedules
     Window ID: hr-manage-shift
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../lib/supabaseClient';
  import { authStore } from '../../../stores/authStore';

  interface Employee {
    id: string;
    email: string;
    user_name: string;
    phone_number: string;
    role: string;
  }

  interface RegularShift {
    id: string;
    start_time: string;
    end_time: string;
    start_buffer: number;
    end_buffer: number;
    working_hours: number;
    overlaps_next_day: boolean;
    employee_id: string;
    employee_name?: string;
    created_at: string;
  }

  interface SpecialShift extends RegularShift {
    shift_date: string; // Date for this special shift
  }

  interface ShiftGroup {
    date_from: string;
    date_to: string;
    start_time: string;
    end_time: string;
    working_hours: number;
    start_buffer: number;
    end_buffer: number;
    overlaps_next_day: boolean;
    shifts: SpecialShift[];
  }

  interface OfficialLeave {
    id: string;
    leave_type: 'weekday' | 'date';
    weekday: number | null;
    leave_date: string | null;
    title: string;
    employee_id: string;
    employee_name?: string;
    created_at: string;
  }

  const WEEKDAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  const INDIAN_HOLIDAYS = [
    'Republic Day',
    'Maha Shivaratri',
    'Holi',
    'Good Friday',
    'Dr. Ambedkar Jayanti',
    'Ram Navami',
    'Mahavir Jayanti',
    'May Day',
    'Buddha Purnima',
    'Eid ul-Fitr',
    'Rath Yatra',
    'Eid ul-Adha',
    'Independence Day',
    'Muharram',
    'Janmashtami',
    'Milad un-Nabi',
    'Mahatma Gandhi Jayanti',
    'Dussehra',
    'Diwali',
    'Bhai Dooj',
    'Guru Nanak Jayanti',
    'Christmas',
    'New Year\'s Day',
    'Pongal / Makar Sankranti',
    'Ganesh Chaturthi',
    'Onam',
    'Navratri',
    'Karwa Chauth',
    'Chhath Puja',
  ];

  let activeTab: 'regular' | 'special' | 'leave' = 'regular';
  let employees: Employee[] = [];
  let regularShifts: RegularShift[] = [];
  let specialShifts: SpecialShift[] = [];
  let officialLeaves: OfficialLeave[] = [];
  let loading = true;
  let error = '';
  let successMessage = '';
  
  // Modal state
  let showModal = false;
  let showEditModal = false;
  let modalMode: 'create' | 'edit' = 'create';
  let selectedEmployee: Employee | null = null;
  let editingShift: SpecialShift | null = null;
  let editingGroup: ShiftGroup | null = null;

  // Leave modal state
  let showLeaveModal = false;
  let leaveMode: 'weekday' | 'date' = 'weekday';
  let leaveFormData = {
    title: '',
    weekday: 0,
    leave_date: '',
  };
  let editingLeave: OfficialLeave | null = null;
  let selectedLeaveEmployees: Set<string> = new Set();
  let leaveEmployeeSearch = '';
  let holidaySearch = '';
  let showHolidayDropdown = false;
  let useCustomTitle = false;
  let formData = {
    start_hour: '09',
    start_minute: '00',
    start_period: 'AM',
    start_buffer: 3,
    end_hour: '05',
    end_minute: '00',
    end_period: 'PM',
    end_buffer: 3,
    overlaps_next_day: false,
    // Special shift date range
    date_from: '',
    date_to: '',
  };

  let workingHours = { hours: 8, minutes: 0 };

  onMount(() => {
    loadEmployees();
    loadRegularShifts();
    loadSpecialShifts();
    loadOfficialLeaves();
  });

  function formatTime12(time: string): string {
    const [hStr, mStr] = time.split(':');
    let h = parseInt(hStr);
    const period = h >= 12 ? 'PM' : 'AM';
    if (h === 0) h = 12;
    else if (h > 12) h -= 12;
    return `${h}:${mStr} ${period}`;
  }

  async function loadEmployees() {
    loading = true;
    error = '';
    
    const { data, error: dbErr } = await supabase
      .from('users')
      .select('id, email, user_name, phone_number, role')
      .eq('is_employee', true)
      .order('user_name');

    if (dbErr) {
      error = dbErr.message;
    } else {
      employees = (data as Employee[]) || [];
    }
    loading = false;
  }

  async function loadRegularShifts() {
    const { data, error: dbErr } = await supabase
      .from('shifts')
      .select('*, users!shifts_employee_id_fkey(user_name)')
      .order('created_at');

    if (!dbErr && data) {
      regularShifts = data.map((s: any) => ({
        ...s,
        employee_name: s.users?.user_name || 'Unknown',
      })) as RegularShift[];
    }
  }

  async function loadSpecialShifts() {
    const { data, error: dbErr } = await supabase
      .from('special_shifts')
      .select('*, users!special_shifts_employee_id_fkey(user_name)')
      .order('shift_date');

    if (!dbErr && data) {
      specialShifts = data.map((s: any) => ({
        ...s,
        employee_name: s.users?.user_name || 'Unknown',
      })) as SpecialShift[];
    }
  }

  function openModal(emp?: Employee) {
    selectedEmployee = emp || null;
    showModal = true;
    formData = {
      start_hour: '09',
      start_minute: '00',
      start_period: 'AM',
      start_buffer: 3,
      end_hour: '05',
      end_minute: '00',
      end_period: 'PM',
      end_buffer: 3,
      overlaps_next_day: false,
      date_from: '',
      date_to: '',
    };
  }

  function closeModal() {
    showModal = false;
    selectedEmployee = null;
  }

  function populateFormFromShift(shift: SpecialShift) {
    const [h, m] = shift.start_time.split(':');
    let hour = parseInt(h);
    const min = parseInt(m);
    const period = hour >= 12 ? 'PM' : 'AM';
    if (hour === 0) hour = 12;
    else if (hour > 12) hour -= 12;
    formData.start_hour = String(hour).padStart(2, '0');
    formData.start_minute = String(min).padStart(2, '0');
    formData.start_period = period;

    const [eh, em] = shift.end_time.split(':');
    let ehour = parseInt(eh);
    const emin = parseInt(em);
    const eperiod = ehour >= 12 ? 'PM' : 'AM';
    if (ehour === 0) ehour = 12;
    else if (ehour > 12) ehour -= 12;
    formData.end_hour = String(ehour).padStart(2, '0');
    formData.end_minute = String(emin).padStart(2, '0');
    formData.end_period = eperiod;

    formData.start_buffer = shift.start_buffer;
    formData.end_buffer = shift.end_buffer;
    formData.overlaps_next_day = shift.overlaps_next_day;
  }

  function openEditModal(group: ShiftGroup) {
    editingGroup = group;
    editingShift = group.shifts[0];
    showEditModal = true;
    populateFormFromShift(editingShift);
  }

  function selectShiftForEdit(shift: SpecialShift) {
    editingShift = shift;
    populateFormFromShift(shift);
  }

  function closeEditModal() {
    showEditModal = false;
    editingGroup = null;
    editingShift = null;
  }

  async function saveEditShift() {
    if (!editingShift || !$authStore.user?.id) {
      error = 'Error: shift or user not found';
      return;
    }

    // Convert times to 24-hour
    let startH = parseInt(formData.start_hour);
    if (formData.start_period === 'PM' && startH !== 12) startH += 12;
    if (formData.start_period === 'AM' && startH === 12) startH = 0;

    let endH = parseInt(formData.end_hour);
    if (formData.end_period === 'PM' && endH !== 12) endH += 12;
    if (formData.end_period === 'AM' && endH === 12) endH = 0;

    const startTime = `${String(startH).padStart(2, '0')}:${formData.start_minute}`;
    const endTime = `${String(endH).padStart(2, '0')}:${formData.end_minute}`;

    const { error: dbErr } = await supabase
      .from('special_shifts')
      .update({
        start_time: startTime,
        end_time: endTime,
        start_buffer: formData.start_buffer,
        end_buffer: formData.end_buffer,
        overlaps_next_day: formData.overlaps_next_day,
        updated_by: $authStore.user.id,
      })
      .eq('id', editingShift.id);

    if (dbErr) {
      console.error('Edit error:', dbErr);
      error = dbErr.message;
      return;
    }

    successMessage = 'Special shift updated!';
    setTimeout(() => successMessage = '', 3000);
    closeEditModal();
    loadSpecialShifts();
  }

  function calculateWorkingHours() {
    // Convert start time to 24-hour format in minutes
    let startHour = parseInt(formData.start_hour);
    const startMinute = parseInt(formData.start_minute);
    if (formData.start_period === 'PM' && startHour !== 12) startHour += 12;
    if (formData.start_period === 'AM' && startHour === 12) startHour = 0;
    
    // Convert end time to 24-hour format in minutes
    let endHour = parseInt(formData.end_hour);
    const endMinute = parseInt(formData.end_minute);
    if (formData.end_period === 'PM' && endHour !== 12) endHour += 12;
    if (formData.end_period === 'AM' && endHour === 12) endHour = 0;

    let startTotalMinutes = startHour * 60 + startMinute;
    let endTotalMinutes = endHour * 60 + endMinute;

    // If end time is earlier than start time, assume it's next day
    if (endTotalMinutes <= startTotalMinutes) {
      endTotalMinutes += 24 * 60;
    }

    // Calculate direct working hours from start and end time only
    const totalMinutes = endTotalMinutes - startTotalMinutes;
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;

    return { hours, minutes };
  }

  function getDateRange(from: string, to: string): string[] {
    const dates: string[] = [];
    const start = new Date(from);
    const end = new Date(to);
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      dates.push(d.toISOString().split('T')[0]);
    }
    return dates;
  }

  function formatDate(dateStr: string): string {
    const d = new Date(dateStr + 'T00:00:00');
    return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  function formatDateRange(from: string, to: string): string {
    if (from === to) return formatDate(from);
    return `${formatDate(from)} – ${formatDate(to)}`;
  }

  function groupConsecutiveShifts(shifts: SpecialShift[]): ShiftGroup[] {
    if (shifts.length === 0) return [];
    const sorted = [...shifts].sort((a, b) => a.shift_date.localeCompare(b.shift_date));
    const groups: ShiftGroup[] = [];
    let cur: ShiftGroup = {
      date_from: sorted[0].shift_date,
      date_to: sorted[0].shift_date,
      start_time: sorted[0].start_time,
      end_time: sorted[0].end_time,
      working_hours: sorted[0].working_hours,
      start_buffer: sorted[0].start_buffer,
      end_buffer: sorted[0].end_buffer,
      overlaps_next_day: sorted[0].overlaps_next_day,
      shifts: [sorted[0]],
    };
    for (let i = 1; i < sorted.length; i++) {
      const s = sorted[i];
      const prevDate = new Date(cur.date_to + 'T00:00:00');
      const currDate = new Date(s.shift_date + 'T00:00:00');
      const diffDays = Math.round((currDate.getTime() - prevDate.getTime()) / 86400000);
      const same = s.start_time === cur.start_time && s.end_time === cur.end_time &&
        Number(s.start_buffer) === Number(cur.start_buffer) && Number(s.end_buffer) === Number(cur.end_buffer) &&
        s.overlaps_next_day === cur.overlaps_next_day;
      if (diffDays === 1 && same) {
        cur.date_to = s.shift_date;
        cur.shifts.push(s);
      } else {
        groups.push(cur);
        cur = {
          date_from: s.shift_date,
          date_to: s.shift_date,
          start_time: s.start_time,
          end_time: s.end_time,
          working_hours: s.working_hours,
          start_buffer: s.start_buffer,
          end_buffer: s.end_buffer,
          overlaps_next_day: s.overlaps_next_day,
          shifts: [s],
        };
      }
    }
    groups.push(cur);
    return groups;
  }

  $: {
    formData.start_hour;
    formData.start_minute;
    formData.start_period;
    formData.end_hour;
    formData.end_minute;
    formData.end_period;
    formData.start_buffer;
    formData.end_buffer;
    workingHours = calculateWorkingHours();
  }

  // --- Official Leave functions ---
  async function loadOfficialLeaves() {
    const { data, error: dbErr } = await supabase
      .from('official_leaves')
      .select('*, users!official_leaves_employee_id_fkey(user_name)')
      .order('created_at');

    if (!dbErr && data) {
      officialLeaves = data.map((l: any) => ({
        ...l,
        employee_name: l.users?.user_name || 'Unknown',
      })) as OfficialLeave[];
    }
  }

  function openLeaveModal(mode: 'weekday' | 'date', leave?: OfficialLeave) {
    leaveMode = mode;
    leaveEmployeeSearch = '';
    holidaySearch = '';
    showHolidayDropdown = false;
    useCustomTitle = false;
    if (leave) {
      editingLeave = leave;
      leaveFormData = {
        title: leave.title,
        weekday: leave.weekday ?? 0,
        leave_date: leave.leave_date ?? '',
      };
      selectedLeaveEmployees = new Set([leave.employee_id]);
      if (mode === 'date' && !INDIAN_HOLIDAYS.includes(leave.title)) {
        useCustomTitle = true;
      }
    } else {
      editingLeave = null;
      leaveFormData = { title: '', weekday: 0, leave_date: '' };
      selectedLeaveEmployees = new Set();
    }
    showLeaveModal = true;
  }

  function closeLeaveModal() {
    showLeaveModal = false;
    editingLeave = null;
    selectedLeaveEmployees = new Set();
    leaveEmployeeSearch = '';
    holidaySearch = '';
    showHolidayDropdown = false;
    useCustomTitle = false;
  }

  function toggleLeaveEmployee(empId: string) {
    if (editingLeave) return; // Can't change employee when editing
    const next = new Set(selectedLeaveEmployees);
    if (next.has(empId)) next.delete(empId);
    else next.add(empId);
    selectedLeaveEmployees = next;
  }

  function toggleAllLeaveEmployees() {
    if (editingLeave) return;
    const filtered = filteredLeaveEmployees;
    const allSelected = filtered.every(e => selectedLeaveEmployees.has(e.id));
    const next = new Set(selectedLeaveEmployees);
    if (allSelected) {
      filtered.forEach(e => next.delete(e.id));
    } else {
      filtered.forEach(e => next.add(e.id));
    }
    selectedLeaveEmployees = next;
  }

  $: filteredLeaveEmployees = employees.filter(e =>
    !leaveEmployeeSearch || e.user_name.toLowerCase().includes(leaveEmployeeSearch.toLowerCase())
  );

  $: filteredHolidays = INDIAN_HOLIDAYS.filter(h =>
    !holidaySearch || h.toLowerCase().includes(holidaySearch.toLowerCase())
  );

  function selectHoliday(name: string) {
    leaveFormData.title = name;
    holidaySearch = '';
    showHolidayDropdown = false;
    useCustomTitle = false;
  }

  function switchToCustomTitle() {
    useCustomTitle = true;
    leaveFormData.title = '';
    showHolidayDropdown = false;
  }

  async function saveLeave() {
    if (!$authStore.user?.id) {
      error = 'User not authenticated.';
      return;
    }
    if (leaveMode === 'date' && !leaveFormData.title.trim()) {
      error = 'Please select or enter a holiday name.';
      return;
    }
    if (leaveMode === 'date' && !leaveFormData.leave_date) {
      error = 'Please select a date.';
      return;
    }
    if (selectedLeaveEmployees.size === 0) {
      error = 'Please select at least one employee.';
      return;
    }

    const basePayload: Record<string, any> = {
      leave_type: leaveMode,
    };

    if (leaveMode === 'weekday') {
      basePayload.weekday = leaveFormData.weekday;
      basePayload.leave_date = null;
      basePayload.title = WEEKDAY_NAMES[leaveFormData.weekday] + ' Off';
    } else {
      basePayload.leave_date = leaveFormData.leave_date;
      basePayload.weekday = null;
      basePayload.title = leaveFormData.title.trim();
    }

    let dbErr;
    if (editingLeave) {
      const payload = { ...basePayload, updated_by: $authStore.user.id };
      ({ error: dbErr } = await supabase.from('official_leaves').update(payload).eq('id', editingLeave.id));
    } else {
      // Insert one row per selected employee
      const rows = [...selectedLeaveEmployees].map(empId => ({
        ...basePayload,
        employee_id: empId,
        created_by: $authStore.user!.id,
      }));
      ({ error: dbErr } = await supabase.from('official_leaves').insert(rows));
    }

    if (dbErr) {
      console.error('Leave error:', dbErr);
      error = dbErr.message;
      return;
    }

    successMessage = editingLeave ? 'Leave updated!' : `Leave added for ${selectedLeaveEmployees.size} employee(s)!`;
    setTimeout(() => successMessage = '', 3000);
    closeLeaveModal();
    loadOfficialLeaves();
  }

  async function deleteLeave(id: string) {
    const { error: dbErr } = await supabase.from('official_leaves').delete().eq('id', id);
    if (dbErr) {
      error = dbErr.message;
      return;
    }
    successMessage = 'Leave removed.';
    setTimeout(() => successMessage = '', 3000);
    loadOfficialLeaves();
  }

  async function saveShift() {
    if (!$authStore.user?.id) {
      error = 'User not authenticated. Please log in.';
      return;
    }

    if (!selectedEmployee) {
      error = 'Please select an employee';
      return;
    }

    // Convert 12-hour AM/PM to 24-hour format
    let startH = parseInt(formData.start_hour);
    if (formData.start_period === 'PM' && startH !== 12) startH += 12;
    if (formData.start_period === 'AM' && startH === 12) startH = 0;

    let endH = parseInt(formData.end_hour);
    if (formData.end_period === 'PM' && endH !== 12) endH += 12;
    if (formData.end_period === 'AM' && endH === 12) endH = 0;

    const startTime = `${String(startH).padStart(2, '0')}:${formData.start_minute}`;
    const endTime = `${String(endH).padStart(2, '0')}:${formData.end_minute}`;

    const baseData: Record<string, any> = {
      start_time: startTime,
      end_time: endTime,
      start_buffer: formData.start_buffer,
      end_buffer: formData.end_buffer,
      overlaps_next_day: formData.overlaps_next_day,
      employee_id: selectedEmployee.id,
    };

    let dbErr;

    if (activeTab === 'special') {
      // Special shifts: create one record per date in range
      if (!formData.date_from || !formData.date_to) {
        error = 'Please select date range for special shift';
        return;
      }

      const dates = getDateRange(formData.date_from, formData.date_to);
      const specialShiftsData = dates.map(d => ({
        ...baseData,
        shift_date: d,
        created_by: $authStore.user!.id,
      }));

      ({ error: dbErr } = await supabase.from('special_shifts').insert(specialShiftsData));
    } else {
      // Regular shifts: update or insert single row
      const shiftData: Record<string, any> = {
        ...baseData,
        created_by: $authStore.user?.id,
      };

      const existingShift = regularShifts.find(s => s.employee_id === selectedEmployee!.id);
      if (existingShift) {
        shiftData.updated_by = $authStore.user?.id;
        ({ error: dbErr } = await supabase.from('shifts').update(shiftData).eq('id', existingShift.id));
      } else {
        ({ error: dbErr } = await supabase.from('shifts').insert(shiftData));
      }
    }

    if (dbErr) {
      console.error('Shift error:', dbErr);
      error = dbErr.message;
      return;
    }

    successMessage = `${activeTab === 'special' ? 'Special' : 'Regular'} shift configured successfully!`;
    setTimeout(() => successMessage = '', 3000);
    closeModal();
    loadRegularShifts();
    loadSpecialShifts();
  }
</script>

<div class="window">
  <!-- Tab Navigation -->
  <div class="tab-nav">
    <button 
      class="tab" 
      class:active={activeTab === 'regular'}
      on:click={() => activeTab = 'regular'}
    >
      🟢 Regular Shift
    </button>
    <button 
      class="tab" 
      class:active={activeTab === 'special'}
      on:click={() => activeTab = 'special'}
    >
      📅 Special Shift
    </button>
    <button 
      class="tab" 
      class:active={activeTab === 'leave'}
      on:click={() => activeTab = 'leave'}
    >
      🏖️ Official Leave
    </button>
  </div>

  <!-- Content Area -->
  <div class="content">
    {#if error}
      <div class="alert alert-error">{error}</div>
    {/if}
    
    {#if successMessage}
      <div class="alert alert-success">{successMessage}</div>
    {/if}

    {#if activeTab === 'regular'}
      <!-- Regular Shift Tab -->
      <div class="tab-content">
        <div class="section-header">
          <h3>Configure Regular Shifts for Employees</h3>
          <!-- Add Regular Shift requires selecting an employee from the table below -->
        </div>

        <!-- Unassigned Employees Table -->
        <div class="section">
          <h4>Employees</h4>
          <div class="table-wrapper">
            {#if loading}
              <div class="message">Loading employees...</div>
            {:else}
              {@const unassigned = employees.filter(e => !regularShifts.some(s => s.employee_id === e.id))}
              {#if unassigned.length === 0}
                <div class="message">All employees have shifts assigned.</div>
              {:else}
                <table class="employees-table">
                  <thead>
                    <tr>
                      <th>Full Name</th>
                      <th>Phone</th>
                      <th>Role</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each unassigned as emp (emp.id)}
                      <tr>
                        <td>{emp.user_name}</td>
                        <td>{emp.phone_number || '—'}</td>
                        <td>{emp.role || '—'}</td>
                        <td>
                          <button class="btn-action" on:click={() => openModal(emp)}>+ Assign</button>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              {/if}
            {/if}
          </div>
        </div>

        <!-- Regular Shifts Table -->
        <div class="section">
          <h4>Regular Shifts</h4>
          <div class="table-wrapper">
            {#if regularShifts.length === 0}
              <div class="message">No regular shifts configured yet.</div>
            {:else}
              <table class="shifts-table">
                <thead>
                  <tr>
                    <th>Employee</th>
                    <th>Start Time</th>
                    <th>End Time</th>
                    <th>Working Hours</th>
                    <th>Start Buffer (Hrs)</th>
                    <th>End Buffer (Hrs)</th>
                    <th>Overlaps Next Day</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each regularShifts as shift (shift.id)}
                    {@const emp = employees.find(e => e.id === shift.employee_id)}
                    <tr>
                      <td>{shift.employee_name}</td>
                      <td>{formatTime12(shift.start_time)}</td>
                      <td>{formatTime12(shift.end_time)}</td>
                      <td class="center">{shift.working_hours}h</td>
                      <td class="center">{shift.start_buffer}</td>
                      <td class="center">{shift.end_buffer}</td>
                      <td class="center">{shift.overlaps_next_day ? '✓' : '—'}</td>
                      <td>
                        <button class="btn-action" on:click={() => emp && openModal(emp)}>Reassign</button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            {/if}
          </div>
        </div>
      </div>
    {/if}

    {#if activeTab === 'special'}
      <!-- Special Shift Tab -->
      <div class="tab-content">
        <div class="section-header">
          <h3>Configure Special Shifts for Employees</h3>
        </div>

        <!-- Unassigned for Special Employees Table -->
        <div class="section">
          <h4>Employees (Assign Special Shifts)</h4>
          <div class="table-wrapper">
            {#if loading}
              <div class="message">Loading employees...</div>
            {:else if employees.length === 0}
              <div class="message">No employees found.</div>
            {:else}
              <table class="employees-table">
                <thead>
                  <tr>
                    <th>Full Name</th>
                    <th>Phone</th>
                    <th>Role</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each employees as emp (emp.id)}
                    <tr>
                      <td>{emp.user_name}</td>
                      <td>{emp.phone_number || '—'}</td>
                      <td>{emp.role || '—'}</td>
                      <td>
                        <button class="btn-action" on:click={() => openModal(emp)}>+ Assign</button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            {/if}
          </div>
        </div>

        <!-- Special Shifts Table (Grouped by Employee) -->
        <div class="section">
          <h4>Special Shifts</h4>
          {#if specialShifts.length === 0}
            <div class="message">No special shifts configured yet.</div>
          {:else}
            {#each [...new Set(specialShifts.map(s => s.employee_id))].map(empId => ({
              id: empId,
              name: specialShifts.find(s => s.employee_id === empId)?.employee_name || 'Unknown',
              groups: groupConsecutiveShifts(specialShifts.filter(s => s.employee_id === empId))
            })) as empGroup (empGroup.id)}
              <div class="employee-group">
                <h5>{empGroup.name}</h5>
                <div class="table-wrapper">
                  <table class="shifts-table">
                    <thead>
                      <tr>
                        <th>Date</th>
                        <th>Days</th>
                        <th>Start Time</th>
                        <th>End Time</th>
                        <th>Working Hours</th>
                        <th>Start Buffer</th>
                        <th>End Buffer</th>
                        <th>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each empGroup.groups as group}
                        <tr>
                          <td>{formatDateRange(group.date_from, group.date_to)}</td>
                          <td class="center"><span class="days-badge">{group.shifts.length}</span></td>
                          <td>{formatTime12(group.start_time)}</td>
                          <td>{formatTime12(group.end_time)}</td>
                          <td class="center">{group.working_hours}h</td>
                          <td class="center">{group.start_buffer}</td>
                          <td class="center">{group.end_buffer}</td>
                          <td>
                            <button class="btn-action-small" on:click={() => openEditModal(group)}>Edit</button>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </div>
    {/if}

    {#if activeTab === 'leave'}
      <!-- Official Leave Tab -->
      <div class="tab-content">
        <div class="section-header">
          <h3>Official Leaves</h3>
        </div>

        <!-- Weekday Leaves -->
        <div class="section">
          <div class="section-row">
            <h4>Weekly Off Days</h4>
            <button class="btn-action" on:click={() => openLeaveModal('weekday')}>+ Add Weekday Leave</button>
          </div>
          {#each [officialLeaves.filter(l => l.leave_type === 'weekday')] as weekdayLeaves}
            {#if weekdayLeaves.length === 0}
              <div class="message">No weekly off days configured.</div>
            {:else}
              <div class="table-wrapper">
                <table class="shifts-table">
                  <thead>
                    <tr>
                      <th>Employee</th>
                      <th>Day</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each weekdayLeaves as leave (leave.id)}
                      <tr>
                        <td>{leave.employee_name}</td>
                        <td><span class="weekday-badge">{WEEKDAY_NAMES[leave.weekday ?? 0]}</span></td>
                        <td>
                          <button class="btn-action-small" on:click={() => openLeaveModal('weekday', leave)}>Edit</button>
                          <button class="btn-action-small btn-danger" on:click={() => deleteLeave(leave.id)}>Remove</button>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {/if}
          {/each}
        </div>

        <!-- Date-wise Leaves -->
        <div class="section">
          <div class="section-row">
            <h4>Date-wise Holidays</h4>
            <button class="btn-action" on:click={() => openLeaveModal('date')}>+ Add Holiday</button>
          </div>
          {#each [officialLeaves.filter(l => l.leave_type === 'date').sort((a, b) => (a.leave_date ?? '').localeCompare(b.leave_date ?? ''))] as dateLeaves}
            {#if dateLeaves.length === 0}
              <div class="message">No date-wise holidays configured.</div>
            {:else}
              <div class="table-wrapper">
                <table class="shifts-table">
                  <thead>
                    <tr>
                      <th>Employee</th>
                      <th>Date</th>
                      <th>Day</th>
                      <th>Title</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each dateLeaves as leave (leave.id)}
                      <tr>
                        <td>{leave.employee_name}</td>
                        <td>{leave.leave_date ? formatDate(leave.leave_date) : '—'}</td>
                        <td>{leave.leave_date ? WEEKDAY_NAMES[new Date(leave.leave_date + 'T00:00:00').getDay()] : '—'}</td>
                        <td>{leave.title}</td>
                        <td>
                          <button class="btn-action-small" on:click={() => openLeaveModal('date', leave)}>Edit</button>
                          <button class="btn-action-small btn-danger" on:click={() => deleteLeave(leave.id)}>Remove</button>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {/if}
          {/each}
        </div>
      </div>
    {/if}
  </div>
</div>

<!-- Modal: Configure Regular Shift -->
{#if showModal}
  <div class="modal-overlay" on:click={closeModal}>
    <div class="modal" on:click|stopPropagation>
      <div class="modal-header">
        <h3>{selectedEmployee ? `Assign Shift to ${selectedEmployee.user_name}` : 'Configure Regular Shift'}</h3>
      </div>

      <div class="modal-body">
        <div class="form-group">
          <label>Shift Start Time</label>
          <div class="time-input">
            <select bind:value={formData.start_hour} class="input-sm">
              {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                <option value={h}>{h}</option>
              {/each}
            </select>
            <span>:</span>
            <select bind:value={formData.start_minute} class="input-sm">
              {#each ['00', '15', '30', '45'] as m}
                <option value={m}>{m}</option>
              {/each}
            </select>
            <select bind:value={formData.start_period} class="input-sm">
              <option value="AM">AM</option>
              <option value="PM">PM</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label for="start-buffer">Start Time Buffer (Hours)</label>
          <input
            id="start-buffer"
            type="number"
            bind:value={formData.start_buffer}
            min="0"
            max="12"
            class="form-input"
          />
        </div>

        <div class="form-group">
          <label>Shift End Time</label>
          <div class="time-input">
            <select bind:value={formData.end_hour} class="input-sm">
              {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                <option value={h}>{h}</option>
              {/each}
            </select>
            <span>:</span>
            <select bind:value={formData.end_minute} class="input-sm">
              {#each ['00', '15', '30', '45'] as m}
                <option value={m}>{m}</option>
              {/each}
            </select>
            <select bind:value={formData.end_period} class="input-sm">
              <option value="AM">AM</option>
              <option value="PM">PM</option>
            </select>
          </div>
        </div>

        <div class="form-group working-hours-display">
          <label>Working Hours</label>
          <div class="working-hours-value">
            {workingHours.hours}h {workingHours.minutes}m
          </div>
        </div>

        <div class="form-group">
          <label for="end-buffer">End Time Buffer (Hours)</label>
          <input
            id="end-buffer"
            type="number"
            bind:value={formData.end_buffer}
            min="0"
            max="12"
            class="form-input"
          />
        </div>

        <div class="form-group checkbox">
          <label>
            <input type="checkbox" bind:checked={formData.overlaps_next_day} />
            <span>Shift Overlaps to Next Day</span>
          </label>
        </div>

        {#if activeTab === 'special'}
          <div class="form-group">
            <label for="date-from">Shift Date From</label>
            <input
              id="date-from"
              type="date"
              bind:value={formData.date_from}
              class="input"
            />
          </div>

          <div class="form-group">
            <label for="date-to">Shift Date To</label>
            <input
              id="date-to"
              type="date"
              bind:value={formData.date_to}
              class="input"
            />
          </div>
        {/if}
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" on:click={closeModal}>Cancel</button>
        <button class="btn-save" on:click={saveShift}>Save</button>
      </div>
    </div>
  </div>
{/if}

<!-- Modal: Edit Special Shift -->
{#if showEditModal && editingGroup}
  <div class="modal-overlay" on:click={closeEditModal}>
    <div class="modal modal-wide" on:click|stopPropagation>
      <div class="modal-header">
        <h3>Edit Special Shift – {editingGroup.shifts[0]?.employee_name || ''}</h3>
        <p class="modal-subtitle">{formatDateRange(editingGroup.date_from, editingGroup.date_to)}</p>
      </div>

      <div class="modal-body">
        <!-- Date selector: pick which date to edit -->
        {#if editingGroup.shifts.length > 1}
          <div class="date-selector">
            <label>Select Date to Edit</label>
            <div class="date-chips">
              {#each editingGroup.shifts as s}
                <button
                  class="date-chip" class:active={editingShift?.id === s.id}
                  on:click={() => selectShiftForEdit(s)}
                >
                  {formatDate(s.shift_date)}
                </button>
              {/each}
            </div>
          </div>
        {/if}

        {#if editingShift}
          <div class="editing-date-label">Editing: {formatDate(editingShift.shift_date)}</div>
        <div class="form-group">
          <label>Shift Start Time</label>
          <div class="time-input">
            <select bind:value={formData.start_hour} class="input-sm">
              {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                <option value={h}>{h}</option>
              {/each}
            </select>
            <span>:</span>
            <select bind:value={formData.start_minute} class="input-sm">
              {#each ['00', '15', '30', '45'] as m}
                <option value={m}>{m}</option>
              {/each}
            </select>
            <select bind:value={formData.start_period} class="input-sm">
              <option value="AM">AM</option>
              <option value="PM">PM</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label>Shift End Time</label>
          <div class="time-input">
            <select bind:value={formData.end_hour} class="input-sm">
              {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                <option value={h}>{h}</option>
              {/each}
            </select>
            <span>:</span>
            <select bind:value={formData.end_minute} class="input-sm">
              {#each ['00', '15', '30', '45'] as m}
                <option value={m}>{m}</option>
              {/each}
            </select>
            <select bind:value={formData.end_period} class="input-sm">
              <option value="AM">AM</option>
              <option value="PM">PM</option>
            </select>
          </div>
        </div>

        <div class="form-group working-hours-display">
          <label>Working Hours</label>
          <div class="working-hours-value">
            {workingHours.hours}h {workingHours.minutes}m
          </div>
        </div>

        <div class="form-group">
          <label for="edit-start-buffer">Start Time Buffer (Hours)</label>
          <input
            id="edit-start-buffer"
            type="number"
            bind:value={formData.start_buffer}
            min="0"
            max="12"
            class="form-input"
          />
        </div>

        <div class="form-group">
          <label for="edit-end-buffer">End Time Buffer (Hours)</label>
          <input
            id="edit-end-buffer"
            type="number"
            bind:value={formData.end_buffer}
            min="0"
            max="12"
            class="form-input"
          />
        </div>

        <div class="form-group checkbox">
          <label>
            <input type="checkbox" bind:checked={formData.overlaps_next_day} />
            <span>Shift Overlaps to Next Day</span>
          </label>
        </div>

        {/if}
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" on:click={closeEditModal}>Close</button>
        <button class="btn-save" on:click={saveEditShift}>Update This Date</button>
      </div>
    </div>
  </div>
{/if}

<!-- Modal: Add/Edit Official Leave -->
{#if showLeaveModal}
  <div class="modal-overlay" on:click={closeLeaveModal}>
    <div class="modal modal-wide" on:click|stopPropagation>
      <div class="modal-header">
        <h3>{editingLeave ? 'Edit' : 'Add'} {leaveMode === 'weekday' ? 'Weekly Off Day' : 'Holiday'}</h3>
      </div>

      <div class="modal-body">
        <!-- Employee Selection -->
        <div class="form-group">
          <label>Employees {#if !editingLeave}<span class="selected-count">({selectedLeaveEmployees.size} selected)</span>{/if}</label>
          {#if editingLeave}
            <div class="selected-emp-tag">{editingLeave.employee_name}</div>
          {:else}
            <input
              type="text"
              bind:value={leaveEmployeeSearch}
              placeholder="Search employees..."
              class="form-input search-input"
            />
            <div class="emp-checkbox-list">
              <label class="emp-checkbox select-all">
                <input
                  type="checkbox"
                  checked={filteredLeaveEmployees.length > 0 && filteredLeaveEmployees.every(e => selectedLeaveEmployees.has(e.id))}
                  on:change={toggleAllLeaveEmployees}
                />
                <span>Select All</span>
              </label>
              {#each filteredLeaveEmployees as emp (emp.id)}
                <label class="emp-checkbox">
                  <input
                    type="checkbox"
                    checked={selectedLeaveEmployees.has(emp.id)}
                    on:change={() => toggleLeaveEmployee(emp.id)}
                  />
                  <span>{emp.user_name}</span>
                </label>
              {/each}
              {#if filteredLeaveEmployees.length === 0}
                <div class="message">No employees found.</div>
              {/if}
            </div>
          {/if}
        </div>

        {#if leaveMode === 'weekday'}
          <div class="form-group">
            <label for="leave-weekday">Day of Week</label>
            <select id="leave-weekday" bind:value={leaveFormData.weekday} class="form-input">
              {#each WEEKDAY_NAMES as day, i}
                <option value={i}>{day}</option>
              {/each}
            </select>
          </div>
        {:else}
          <div class="form-group">
            <label>Holiday Name</label>
            {#if useCustomTitle}
              <div class="custom-title-row">
                <input
                  type="text"
                  bind:value={leaveFormData.title}
                  placeholder="Enter custom holiday name"
                  class="form-input"
                />
                <button class="btn-link" on:click={() => { useCustomTitle = false; leaveFormData.title = ''; }}>Pick from list</button>
              </div>
            {:else}
              <div class="holiday-picker">
                <input
                  type="text"
                  bind:value={holidaySearch}
                  placeholder={leaveFormData.title || 'Search holidays...'}
                  class="form-input"
                  on:focus={() => showHolidayDropdown = true}
                />
                {#if leaveFormData.title && !showHolidayDropdown}
                  <div class="selected-holiday">{leaveFormData.title}</div>
                {/if}
                {#if showHolidayDropdown}
                  <div class="holiday-dropdown">
                    {#each filteredHolidays as holiday}
                      <button class="holiday-option" on:click={() => selectHoliday(holiday)}>{holiday}</button>
                    {/each}
                    <button class="holiday-option custom-option" on:click={switchToCustomTitle}>+ Enter Custom Name</button>
                  </div>
                {/if}
              </div>
            {/if}
          </div>

          <div class="form-group">
            <label for="leave-date">Date</label>
            <input
              id="leave-date"
              type="date"
              bind:value={leaveFormData.leave_date}
              class="form-input"
            />
          </div>
        {/if}
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" on:click={closeLeaveModal}>Cancel</button>
        <button class="btn-save" on:click={saveLeave}>{editingLeave ? 'Update' : 'Save'}</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .window {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    background: #f5f5f5;
  }

  .tab-nav {
    display: flex;
    gap: 0;
    background: white;
    border-bottom: 1px solid #e0e0e0;
    flex-shrink: 0;
  }

  .tab {
    padding: 12px 20px;
    border: none;
    background: transparent;
    color: #666;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border-bottom: 3px solid transparent;
    transition: all 0.2s;
  }

  .tab:hover:not(:disabled) {
    color: #333;
    background: #f9f9f9;
  }

  .tab.active {
    color: #1abc9c;
    border-bottom-color: #1abc9c;
  }

  .tab:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
  }

  .tab-content {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .alert {
    padding: 12px 16px;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 500;
  }

  .alert-error {
    background: #fee;
    color: #c00;
    border-left: 4px solid #c00;
  }

  .alert-success {
    background: #efe;
    color: #060;
    border-left: 4px solid #060;
  }

  .section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }

  .section-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #333;
  }

  .section {
    background: white;
    border-radius: 6px;
    padding: 16px;
  }

  .section h4 {
    margin: 0 0 12px 0;
    font-size: 13px;
    font-weight: 600;
    color: #333;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .table-wrapper {
    overflow-x: auto;
  }

  .message {
    padding: 20px;
    text-align: center;
    color: #999;
    font-size: 13px;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }

  th {
    background: #f9fafb;
    padding: 10px;
    text-align: left;
    font-weight: 600;
    color: #666;
    border-bottom: 1px solid #e5e7eb;
    white-space: nowrap;
  }

  td {
    padding: 10px;
    border-bottom: 1px solid #f0f0f0;
    color: #333;
  }

  td.center {
    text-align: center;
  }

  .btn-action {
    padding: 5px 12px;
    background: #1abc9c;
    color: white;
    border: none;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-action:hover {
    background: #16a085;
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

  .modal {
    background: white;
    border-radius: 8px;
    max-width: 500px;
    width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  }

  .modal-header {
    background: linear-gradient(135deg, #1abc9c 0%, #16a085 100%);
    color: white;
    padding: 16px 20px;
    flex-shrink: 0;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
  }

  .modal-body {
    padding: 20px;
    overflow-y: auto;
    max-height: calc(90vh - 130px);
  }

  .modal-footer {
    padding: 12px 20px;
    border-top: 1px solid #eee;
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    flex-shrink: 0;
  }

  .btn-action-small {
    padding: 4px 12px;
    background: #3498db;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    font-weight: 500;
    transition: background 0.2s;
  }

  .btn-action-small:hover {
    background: #2980b9;
  }

  .employee-group {
    margin-bottom: 24px;
    padding: 12px;
    background: #f8f9fa;
    border-radius: 6px;
    border-left: 4px solid #1abc9c;
  }

  .employee-group h5 {
    margin: 0 0 12px 0;
    color: #1abc9c;
    font-size: 14px;
    font-weight: 600;
    text-transform: uppercase;
  }

  .form-group {
    margin-bottom: 16px;
  }

  .form-group label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #666;
    margin-bottom: 6px;
    text-transform: uppercase;
    letter-spacing: 0.02em;
  }

  .form-input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    font-size: 13px;
    box-sizing: border-box;
  }

  .form-input:focus {
    outline: none;
    border-color: #1abc9c;
    box-shadow: 0 0 0 2px rgba(26, 188, 156, 0.1);
  }

  .time-input {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .input-sm {
    padding: 8px 10px;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    font-size: 12px;
  }

  .input-sm:focus {
    outline: none;
    border-color: #1abc9c;
  }

  .form-group.checkbox label {
    display: flex;
    align-items: center;
    gap: 8px;
    text-transform: none;
    letter-spacing: normal;
    cursor: pointer;
  }

  .form-group.checkbox input {
    margin: 0;
  }

  .form-group.working-hours-display {
    background: #f0fdfb;
    border: 1px solid #d1f5ee;
    border-radius: 4px;
    padding: 12px;
    margin-bottom: 16px;
  }

  .form-group.working-hours-display label {
    margin-bottom: 8px;
  }

  .working-hours-value {
    font-size: 18px;
    font-weight: 700;
    color: #1abc9c;
    padding: 8px 0;
  }

  .modal-footer {
    display: flex;
    gap: 12px;
    padding: 16px 20px;
    border-top: 1px solid #e0e0e0;
    flex-shrink: 0;
  }

  .btn-cancel,
  .btn-save {
    flex: 1;
    padding: 10px 16px;
    border: none;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-cancel {
    background: #e5e7eb;
    color: #333;
  }

  .btn-cancel:hover {
    background: #d1d5db;
  }

  .btn-save {
    background: #1abc9c;
    color: white;
  }

  .btn-save:hover {
    background: #16a085;
  }

  .modal-wide {
    max-width: 560px;
  }

  .modal-subtitle {
    margin: 4px 0 0;
    font-size: 12px;
    opacity: 0.85;
  }

  .date-selector {
    margin-bottom: 16px;
    padding-bottom: 12px;
    border-bottom: 1px solid #eee;
  }

  .date-selector label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #666;
    margin-bottom: 8px;
    text-transform: uppercase;
    letter-spacing: 0.02em;
  }

  .date-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .date-chip {
    padding: 6px 12px;
    border: 1px solid #d0d0d0;
    border-radius: 16px;
    background: #f9f9f9;
    font-size: 12px;
    cursor: pointer;
    transition: all 0.2s;
  }

  .date-chip:hover {
    border-color: #1abc9c;
    background: #f0fdfb;
  }

  .date-chip.active {
    background: #1abc9c;
    color: white;
    border-color: #1abc9c;
    font-weight: 600;
  }

  .editing-date-label {
    font-size: 13px;
    font-weight: 600;
    color: #1abc9c;
    margin-bottom: 14px;
    padding: 8px 12px;
    background: #f0fdfb;
    border-radius: 4px;
    border-left: 3px solid #1abc9c;
  }

  .days-badge {
    display: inline-block;
    min-width: 22px;
    padding: 2px 6px;
    background: #e8f5e9;
    color: #2e7d32;
    border-radius: 10px;
    font-weight: 700;
    font-size: 11px;
    text-align: center;
  }

  .section-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }

  .section-row h4 {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: #333;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .weekday-badge {
    display: inline-block;
    padding: 3px 10px;
    background: #e3f2fd;
    color: #1565c0;
    border-radius: 12px;
    font-weight: 600;
    font-size: 11px;
  }

  .btn-danger {
    background: #e74c3c !important;
    margin-left: 6px;
  }

  .btn-danger:hover {
    background: #c0392b !important;
  }

  .emp-checkbox-list {
    max-height: 180px;
    overflow-y: auto;
    border: 1px solid #e0e0e0;
    border-radius: 4px;
    margin-top: 6px;
  }

  .emp-checkbox {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    cursor: pointer;
    transition: background 0.15s;
    font-size: 13px;
    text-transform: none;
    letter-spacing: normal;
    border-bottom: 1px solid #f5f5f5;
  }

  .emp-checkbox:hover {
    background: #f0fdfb;
  }

  .emp-checkbox.select-all {
    background: #f9fafb;
    font-weight: 600;
    border-bottom: 1px solid #e0e0e0;
    position: sticky;
    top: 0;
    z-index: 1;
  }

  .emp-checkbox input[type="checkbox"] {
    margin: 0;
    width: 16px;
    height: 16px;
    accent-color: #1abc9c;
  }

  .search-input {
    margin-bottom: 0;
  }

  .selected-count {
    font-weight: 400;
    color: #1abc9c;
    font-size: 11px;
    text-transform: none;
    letter-spacing: normal;
  }

  .selected-emp-tag {
    display: inline-block;
    padding: 6px 12px;
    background: #e8f5e9;
    color: #2e7d32;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 500;
  }

  .holiday-picker {
    position: relative;
  }

  .selected-holiday {
    margin-top: 4px;
    padding: 6px 10px;
    background: #e8f5e9;
    color: #2e7d32;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
  }

  .holiday-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    max-height: 200px;
    overflow-y: auto;
    background: white;
    border: 1px solid #d0d0d0;
    border-top: none;
    border-radius: 0 0 4px 4px;
    z-index: 10;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  }

  .holiday-option {
    display: block;
    width: 100%;
    text-align: left;
    padding: 9px 12px;
    border: none;
    background: white;
    font-size: 13px;
    cursor: pointer;
    border-bottom: 1px solid #f5f5f5;
    transition: background 0.15s;
  }

  .holiday-option:hover {
    background: #f0fdfb;
  }

  .holiday-option.custom-option {
    color: #1abc9c;
    font-weight: 600;
    background: #f9fafb;
    position: sticky;
    bottom: 0;
    border-top: 1px solid #e0e0e0;
  }

  .custom-title-row {
    display: flex;
    gap: 8px;
    align-items: center;
  }

  .custom-title-row .form-input {
    flex: 1;
  }

  .btn-link {
    background: none;
    border: none;
    color: #1abc9c;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    padding: 0;
  }

  .btn-link:hover {
    text-decoration: underline;
  }
</style>
