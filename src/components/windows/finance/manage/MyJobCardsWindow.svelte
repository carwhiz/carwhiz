<!-- ============================================================
     FINANCE > MANAGE > MY JOB CARDS (STAFF PANEL)
     Purpose: Staff view their assigned job cards
     Window ID: finance-my-jobs
     Actions: Start job, Add notes, Upload photos, Close job
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import { canUserViewResource } from '../../../../lib/services/permissionService';

  let myJobs: any[] = [];
  let loading = true;
  let permDenied = false;
  let statusFilter = '';

  // Detail view
  let viewingJob: any = null;
  let jcItems: any[] = [];
  let jcPhotos: any[] = [];
  let jcNotes: any[] = [];
  let jcLogs: any[] = [];

  // Add note
  let newNote = '';
  let noteSaving = false;

  // Photo upload
  let photoUploading = false;
  let photoError = '';

  // Actions
  let actionLoading = false;
  let actionError = '';

  $: filteredJobs = statusFilter ? myJobs.filter(j => j.status === statusFilter) : myJobs;

  onMount(async () => {
    const userId = $authStore.user?.id;
    if (userId) {
      const allowed = await canUserViewResource(userId, 'finance-my-jobs');
      if (!allowed) { permDenied = true; loading = false; return; }
    }
    await loadMyJobs();
  });

  function formatDate(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
  }

  function formatDateTime(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    let h = d.getHours(); const min = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM'; h = h % 12 || 12;
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()} ${h}:${min} ${ampm}`;
  }

  async function loadMyJobs() {
    loading = true;
    const userId = $authStore.user?.id;
    if (!userId) { loading = false; return; }

    const { data } = await supabase
      .from('job_cards')
      .select('id, job_card_no, status, priority, description, details, expected_date, created_at, customers(name), vehicles(model_name)')
      .eq('assigned_user_id', userId)
      .in('status', ['Open', 'In Progress', 'Closed'])
      .order('created_at', { ascending: false });
    myJobs = (data || []).map((j: any) => ({
      ...j,
      customer_name: j.customers?.name || '—',
      vehicle_name: j.vehicles?.model_name || '—',
    }));
    loading = false;
  }

  async function openJobDetail(job: any) {
    viewingJob = job;
    actionError = '';
    await loadJobDetails(job.id);
  }

  async function loadJobDetails(id: string) {
    const [itemsRes, photosRes, notesRes, logsRes] = await Promise.all([
      supabase.from('job_card_items').select('*').eq('job_card_id', id).order('created_at'),
      supabase.from('job_card_photos').select('*').eq('job_card_id', id).order('created_at'),
      supabase.from('job_card_notes').select('*, users:created_by(email)').eq('job_card_id', id).order('created_at', { ascending: false }),
      supabase.from('job_card_logs').select('*, users:action_by(email)').eq('job_card_id', id).order('created_at', { ascending: false }),
    ]);
    jcItems = itemsRes.data || [];
    jcPhotos = photosRes.data || [];
    jcNotes = (notesRes.data || []).map((n: any) => ({ ...n, by_name: n.users?.email || '—' }));
    jcLogs = (logsRes.data || []).map((l: any) => ({ ...l, by_name: l.users?.email || '—' }));
  }

  function goBack() {
    viewingJob = null;
    jcItems = []; jcPhotos = []; jcNotes = []; jcLogs = [];
    newNote = '';
  }

  // ---- Start Job ----
  async function startJob() {
    if (!viewingJob || viewingJob.status !== 'Open') return;
    actionLoading = true;
    actionError = '';

    const { error } = await supabase.from('job_cards').update({
      status: 'In Progress',
      updated_by: $authStore.user?.id || null,
      updated_at: new Date().toISOString(),
    }).eq('id', viewingJob.id);

    if (error) { actionError = 'Failed to start job: ' + error.message; actionLoading = false; return; }

    await supabase.from('job_card_logs').insert({
      job_card_id: viewingJob.id,
      action: 'Started',
      from_status: 'Open',
      to_status: 'In Progress',
      note: 'Job started',
      action_by: $authStore.user?.id || null,
      created_by: $authStore.user?.id || null,
    });

    viewingJob.status = 'In Progress';
    actionLoading = false;
    await loadMyJobs();
    await loadJobDetails(viewingJob.id);
  }

  // ---- Close Job ----
  async function closeJob() {
    if (!viewingJob || viewingJob.status !== 'In Progress') return;
    if (!confirm('Close this job card? This marks it as completed.')) return;
    actionLoading = true;
    actionError = '';

    const { error } = await supabase.from('job_cards').update({
      status: 'Closed',
      closed_by: $authStore.user?.id || null,
      closed_at: new Date().toISOString(),
      updated_by: $authStore.user?.id || null,
      updated_at: new Date().toISOString(),
    }).eq('id', viewingJob.id);

    if (error) { actionError = 'Failed to close job: ' + error.message; actionLoading = false; return; }

    await supabase.from('job_card_logs').insert({
      job_card_id: viewingJob.id,
      action: 'Closed',
      from_status: 'In Progress',
      to_status: 'Closed',
      note: 'Job completed and closed',
      action_by: $authStore.user?.id || null,
      created_by: $authStore.user?.id || null,
    });

    viewingJob.status = 'Closed';
    actionLoading = false;
    await loadMyJobs();
    await loadJobDetails(viewingJob.id);
  }

  // ---- Add Note ----
  async function addNote() {
    if (!newNote.trim() || !viewingJob) return;
    noteSaving = true;

    await supabase.from('job_card_notes').insert({
      job_card_id: viewingJob.id,
      note: newNote.trim(),
      created_by: $authStore.user?.id || null,
    });

    await supabase.from('job_card_logs').insert({
      job_card_id: viewingJob.id,
      action: 'Note Added',
      note: newNote.trim().substring(0, 100),
      action_by: $authStore.user?.id || null,
      created_by: $authStore.user?.id || null,
    });

    newNote = '';
    noteSaving = false;
    await loadJobDetails(viewingJob.id);
  }

  // ---- Upload Photos ----
  async function handlePhotoUpload(e: Event) {
    const input = e.target as HTMLInputElement;
    const files = input.files;
    if (!files || files.length === 0 || !viewingJob) return;

    photoUploading = true;
    photoError = '';

    for (const file of Array.from(files)) {
      const ext = file.name.split('.').pop() || 'jpg';
      const fileName = `${viewingJob.id}/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`;

      const { error: uploadErr } = await supabase.storage
        .from('job-card-photos')
        .upload(fileName, file);

      if (uploadErr) {
        photoError = 'Upload failed: ' + uploadErr.message;
        continue;
      }

      const { data: urlData } = supabase.storage
        .from('job-card-photos')
        .getPublicUrl(fileName);

      if (urlData?.publicUrl) {
        await supabase.from('job_card_photos').insert({
          job_card_id: viewingJob.id,
          file_url: urlData.publicUrl,
          file_name: file.name,
          uploaded_by: $authStore.user?.id || null,
          created_by: $authStore.user?.id || null,
        });
      }
    }

    photoUploading = false;
    input.value = '';
    await loadJobDetails(viewingJob.id);
  }

  function getStatusClass(s: string): string {
    const map: Record<string, string> = { 'Open': 'status-open', 'In Progress': 'status-progress', 'Closed': 'status-closed' };
    return map[s] || '';
  }

  function getPriorityClass(p: string): string {
    const map: Record<string, string> = { 'Low': 'pri-low', 'Normal': 'pri-normal', 'High': 'pri-high', 'Urgent': 'pri-urgent' };
    return map[p] || '';
  }
</script>

<div class="staff-window">
  {#if permDenied}
    <div class="perm-denied"><p>You do not have permission to view your job cards.</p></div>
  {:else if !viewingJob}
    <!-- ===== JOB LIST ===== -->
    <div class="panel-header">
      <div class="header-left">
        <button class="back-btn" on:click={() => windowStore.close('finance-my-jobs')} title="Close">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>My Job Cards</h2>
      </div>
      <div class="header-right">
        <select class="filter-select" bind:value={statusFilter}>
          <option value="">All</option>
          <option value="Open">Open</option>
          <option value="In Progress">In Progress</option>
          <option value="Closed">Closed</option>
        </select>
        <button class="btn-refresh" on:click={loadMyJobs}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
        </button>
      </div>
    </div>

    <div class="job-list">
      {#if loading}
        <div class="loading-msg">Loading...</div>
      {:else if filteredJobs.length === 0}
        <div class="empty-msg">No job cards assigned to you.</div>
      {:else}
        {#each filteredJobs as job (job.id)}
          <button class="job-card" on:click={() => openJobDetail(job)}>
            <div class="job-card-top">
              <span class="jc-no">{job.job_card_no}</span>
              <span class="status-badge {getStatusClass(job.status)}">{job.status}</span>
            </div>
            <div class="job-card-body">
              <div class="job-info"><strong>{job.customer_name}</strong> — {job.vehicle_name}</div>
              <div class="job-desc">{job.description}</div>
            </div>
            <div class="job-card-footer">
              <span class="pri-badge {getPriorityClass(job.priority)}">{job.priority}</span>
              <span class="job-date">{formatDate(job.created_at)}</span>
              {#if job.expected_date}<span class="job-expected">Due: {formatDate(job.expected_date)}</span>{/if}
            </div>
          </button>
        {/each}
      {/if}
    </div>

  {:else}
    <!-- ===== JOB DETAIL ===== -->
    <div class="panel-header">
      <div class="header-left">
        <button class="back-btn" on:click={goBack}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>{viewingJob.job_card_no}</h2>
        <span class="status-badge {getStatusClass(viewingJob.status)}">{viewingJob.status}</span>
      </div>
    </div>

    {#if actionError}<div class="msg msg-error">{actionError}</div>{/if}

    <div class="detail-body">
      <!-- Info -->
      <div class="detail-section">
        <div class="info-grid">
          <div class="info-item"><span class="info-label">Customer</span><span>{viewingJob.customer_name}</span></div>
          <div class="info-item"><span class="info-label">Vehicle</span><span>{viewingJob.vehicle_name}</span></div>
          <div class="info-item"><span class="info-label">Priority</span><span class="pri-badge {getPriorityClass(viewingJob.priority)}">{viewingJob.priority}</span></div>
          <div class="info-item"><span class="info-label">Created</span><span>{formatDateTime(viewingJob.created_at)}</span></div>
          {#if viewingJob.expected_date}<div class="info-item"><span class="info-label">Expected</span><span>{formatDate(viewingJob.expected_date)}</span></div>{/if}
        </div>
        <div class="desc-block"><strong>Description:</strong> {viewingJob.description}</div>
        {#if viewingJob.details}<div class="desc-block"><strong>Notes:</strong> {viewingJob.details}</div>{/if}
      </div>

      <!-- Action buttons -->
      <div class="action-strip">
        {#if viewingJob.status === 'Open'}
          <button class="btn-action start" on:click={startJob} disabled={actionLoading}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polygon points="5 3 19 12 5 21 5 3"/></svg>
            Start Job
          </button>
        {/if}
        {#if viewingJob.status === 'In Progress'}
          <button class="btn-action close-job" on:click={closeJob} disabled={actionLoading}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="20 6 9 17 4 12"/></svg>
            Close Job
          </button>
        {/if}
      </div>

      <!-- Items -->
      <div class="detail-section">
        <h4>Items ({jcItems.length})</h4>
        {#if jcItems.length > 0}
          <table class="detail-table">
            <thead><tr><th>#</th><th>Type</th><th>Name</th><th class="num">Qty</th><th class="num">Price</th><th class="num">Total</th></tr></thead>
            <tbody>
              {#each jcItems as it, idx}
                <tr>
                  <td>{idx+1}</td>
                  <td><span class="type-tag" class:service={it.item_type === 'service'} class:consumable={it.item_type === 'consumable'}>{it.item_type}</span></td>
                  <td>{it.name}</td>
                  <td class="num">{it.qty}</td>
                  <td class="num">₹{(it.price||0).toFixed(2)}</td>
                  <td class="num">₹{(it.total||0).toFixed(2)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>

      <!-- Photos -->
      <div class="detail-section">
        <h4>Photos ({jcPhotos.length})</h4>
        {#if jcPhotos.length > 0}
          <div class="photo-grid">
            {#each jcPhotos as photo}
              <div class="photo-thumb">
                <img src={photo.file_url} alt={photo.file_name || 'Photo'} />
              </div>
            {/each}
          </div>
        {/if}
        {#if viewingJob.status !== 'Closed'}
          <div class="upload-area">
            <label class="upload-btn">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
              {photoUploading ? 'Uploading...' : 'Upload Photos'}
              <input type="file" accept="image/*" multiple on:change={handlePhotoUpload} hidden disabled={photoUploading} />
            </label>
            {#if photoError}<span class="photo-err">{photoError}</span>{/if}
          </div>
        {/if}
      </div>

      <!-- Notes -->
      <div class="detail-section">
        <h4>Notes ({jcNotes.length})</h4>
        {#if viewingJob.status !== 'Closed'}
          <div class="add-note">
            <textarea bind:value={newNote} rows="2" placeholder="Add a note..."></textarea>
            <button class="btn-primary" on:click={addNote} disabled={noteSaving || !newNote.trim()}>
              {noteSaving ? 'Saving...' : 'Add Note'}
            </button>
          </div>
        {/if}
        {#each jcNotes as note}
          <div class="note-card">
            <p>{note.note}</p>
            <span class="note-meta">{note.by_name} — {formatDateTime(note.created_at)}</span>
          </div>
        {/each}
      </div>

      <!-- Activity Log -->
      {#if jcLogs.length > 0}
        <div class="detail-section">
          <h4>Activity Log</h4>
          {#each jcLogs as log}
            <div class="log-entry">
              <span class="log-action">{log.action}</span>
              {#if log.from_status && log.to_status}<span class="log-trans">{log.from_status} → {log.to_status}</span>{/if}
              {#if log.note}<span class="log-note">{log.note}</span>{/if}
              <span class="log-meta">{log.by_name} — {formatDateTime(log.created_at)}</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .staff-window { display: flex; flex-direction: column; height: 100%; background: #fafafa; }
  .perm-denied { display: flex; align-items: center; justify-content: center; height: 100%; color: #991b1b; font-size: 15px; font-weight: 500; }

  .panel-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 20px; background: white; border-bottom: 1px solid #e5e7eb; flex-shrink: 0; }
  .header-left { display: flex; align-items: center; gap: 10px; }
  .header-left h2 { font-size: 16px; font-weight: 700; color: #111827; }
  .header-right { display: flex; gap: 8px; align-items: center; }
  .back-btn { background: none; border: none; cursor: pointer; color: #6b7280; padding: 4px; border-radius: 6px; display: flex; }
  .back-btn:hover { background: #f3f4f6; color: #111827; }
  .filter-select { padding: 6px 10px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 12px; }
  .btn-refresh { background: none; border: 1px solid #d1d5db; border-radius: 6px; padding: 6px; cursor: pointer; display: flex; color: #6b7280; }
  .btn-refresh:hover { background: #f3f4f6; }

  /* Job list */
  .job-list { flex: 1; overflow-y: auto; padding: 12px 20px; display: flex; flex-direction: column; gap: 8px; }
  .loading-msg, .empty-msg { text-align: center; color: #9ca3af; padding: 40px; font-size: 14px; }

  .job-card { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 14px 16px; cursor: pointer; text-align: left; transition: box-shadow 0.15s; width: 100%; }
  .job-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
  .job-card-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
  .jc-no { font-family: 'SF Mono', monospace; font-size: 13px; font-weight: 700; color: #C41E3A; }
  .job-card-body { margin-bottom: 8px; }
  .job-info { font-size: 14px; color: #111827; margin-bottom: 4px; }
  .job-desc { font-size: 12px; color: #6b7280; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .job-card-footer { display: flex; gap: 10px; align-items: center; font-size: 11px; }
  .job-date { color: #9ca3af; }
  .job-expected { color: #d97706; }

  /* Status & Priority */
  .status-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
  .status-open { background: #dbeafe; color: #1d4ed8; }
  .status-progress { background: #fef3c7; color: #d97706; }
  .status-closed { background: #dcfce7; color: #16a34a; }
  .pri-badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }
  .pri-low { background: #f3f4f6; color: #6b7280; }
  .pri-normal { background: #dbeafe; color: #1d4ed8; }
  .pri-high { background: #fef3c7; color: #d97706; }
  .pri-urgent { background: #fee2e2; color: #dc2626; }

  /* Detail body */
  .detail-body { flex: 1; overflow-y: auto; padding: 16px 20px; }
  .detail-section { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 14px; margin-bottom: 12px; }
  .detail-section h4 { font-size: 14px; font-weight: 700; margin-bottom: 10px; }
  .info-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 10px; margin-bottom: 10px; }
  .info-item { display: flex; flex-direction: column; gap: 2px; }
  .info-label { font-size: 11px; font-weight: 600; color: #6b7280; }
  .desc-block { font-size: 13px; color: #374151; margin-bottom: 6px; }

  /* Actions */
  .action-strip { display: flex; gap: 8px; margin-bottom: 12px; }
  .btn-action { display: inline-flex; align-items: center; gap: 6px; padding: 10px 20px; border: none; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; }
  .btn-action:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-action.start { background: #2563eb; color: white; }
  .btn-action.start:hover:not(:disabled) { background: #1d4ed8; }
  .btn-action.close-job { background: #16a34a; color: white; }
  .btn-action.close-job:hover:not(:disabled) { background: #15803d; }

  /* Table */
  .detail-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .detail-table th { background: #f9fafb; padding: 6px 10px; text-align: left; font-weight: 600; border-bottom: 2px solid #e5e7eb; }
  .detail-table td { padding: 6px 10px; border-bottom: 1px solid #f3f4f6; }
  .num { text-align: right; }
  .type-tag { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; background: #dbeafe; color: #1d4ed8; text-transform: capitalize; }
  .type-tag.service { background: #f3e8ff; color: #7c3aed; }
  .type-tag.consumable { background: #dcfce7; color: #16a34a; }

  /* Photos */
  .photo-grid { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 10px; }
  .photo-thumb { width: 80px; height: 80px; border-radius: 8px; overflow: hidden; border: 1px solid #e5e7eb; }
  .photo-thumb img { width: 100%; height: 100%; object-fit: cover; }
  .upload-area { display: flex; align-items: center; gap: 10px; margin-top: 8px; }
  .upload-btn { display: inline-flex; align-items: center; gap: 6px; padding: 8px 16px; background: #f3f4f6; border: 1px dashed #d1d5db; border-radius: 8px; font-size: 13px; cursor: pointer; color: #374151; }
  .upload-btn:hover { background: #e5e7eb; }
  .photo-err { color: #dc2626; font-size: 12px; }

  /* Notes */
  .add-note { display: flex; gap: 8px; margin-bottom: 10px; align-items: flex-start; }
  .add-note textarea { flex: 1; padding: 8px 10px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 13px; resize: vertical; font-family: inherit; outline: none; }
  .add-note textarea:focus { border-color: #C41E3A; }
  .note-card { background: #f9fafb; border-radius: 8px; padding: 10px 14px; margin-bottom: 6px; }
  .note-card p { font-size: 13px; color: #111827; margin: 0 0 4px; }
  .note-meta { font-size: 11px; color: #9ca3af; }

  /* Log */
  .log-entry { display: flex; align-items: center; gap: 8px; font-size: 12px; padding: 6px 0; border-bottom: 1px solid #f3f4f6; flex-wrap: wrap; }
  .log-action { font-weight: 600; color: #111827; }
  .log-trans { color: #6b7280; }
  .log-note { color: #374151; }
  .log-meta { color: #9ca3af; font-size: 11px; margin-left: auto; }

  .btn-primary { padding: 8px 16px; background: #C41E3A; color: white; border: none; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; }
  .btn-primary:hover:not(:disabled) { background: #a71830; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .msg { padding: 10px 16px; border-radius: 8px; font-size: 13px; margin: 8px 20px 0; }
  .msg-error { background: #fef2f2; color: #dc2626; }
</style>
