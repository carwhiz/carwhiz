<script lang="ts">
  import { onMount, setContext } from 'svelte';
  import { authStore } from '../../stores/authStore';
  import { setMobilePage } from '../../stores/mobilePageStore';
  import SalaryManagement from '../../components/windows/hr/SalaryManagement.svelte';

  let isAdmin = false;

  onMount(() => {
    setMobilePage('salary', 'Salary Management');
    isAdmin = $authStore.user?.role === 'admin';
  });

  // Since SalaryManagement doesn't rely on being inside AppWindow, this should work.
  // It uses window content styled for desktop which might need overflow-x for the big tables
</script>

<div class="mobile-page-wrapper">
  {#if isAdmin}
    <div class="salary-desktop-container">
      <SalaryManagement />
    </div>
  {:else}
    <div class="unauthorized">
      <p>You do not have permission to view this page.</p>
    </div>
  {/if}
</div>

<style>
  .mobile-page-wrapper {
    width: 100%;
    height: 100%;
    overflow: auto;
    background: #f1f5f9;
  }

  .salary-desktop-container {
    width: 100%;
    min-width: 1024px; /* Ensure tables don't squash */
    background: white;
    height: max-content;
    min-height: 100%;
  }

  .unauthorized {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100%;
    padding: 2rem;
    text-align: center;
    color: #64748b;
  }
</style>
