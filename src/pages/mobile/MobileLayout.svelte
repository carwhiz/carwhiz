<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '../../stores/authStore';
  import { interfaceStore } from '../../stores/interfaceStore';
  import { logout } from '../../lib/services/authService';
  import { setMobilePage, mobilePageStore } from '../../stores/mobilePageStore';
  import MobileHome from './MobileHome.svelte';
  import MobileMyJobs from './MobileMyJobs.svelte';
  import MobileAttendance from './MobileAttendance.svelte';
  import MobileJobDetail from './MobileJobDetail.svelte';
  import MobileJobCreation from './MobileJobCreation.svelte';

  import logoPath from '../../assets/CARWHIZ.jpeg';

  let menuOpen = false;

  async function handleLogout() {
    await logout();
    interfaceStore.setInterface('login');
  }

  function toggleMenu() {
    menuOpen = !menuOpen;
  }

  function closeMenu() {
    menuOpen = false;
  }

  function goToHome() {
    setMobilePage('home', 'Home');
  }

  function goToMyJobs() {
    setMobilePage('my-jobs', 'My Jobs');
  }

  function goToAttendance() {
    setMobilePage('attendance', 'Attendance');
  }

  function goBack() {
    // Go back to my jobs from job detail or job creation
    if ($mobilePageStore.currentPage === 'job-detail' || $mobilePageStore.currentPage === 'job-creation') {
      goToMyJobs();
    } else {
      goToHome();
    }
  }

  function shouldShowBackButton(): boolean {
    return $mobilePageStore.currentPage === 'job-detail' || $mobilePageStore.currentPage === 'job-creation';
  }

  onMount(() => {
    setMobilePage('home', 'Home');
  });
</script>

<div class="mobile-layout">
  <!-- Mobile Header - Common for all pages -->
  <header class="mobile-header">
    <div class="header-left">
      {#if shouldShowBackButton()}
        <button class="back-btn" on:click={goBack} title="Back">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" width="20" height="20">
            <polyline points="15 18 9 12 15 6"></polyline>
          </svg>
        </button>
      {/if}
      <img src={logoPath} alt="CarWhizz" class="mobile-logo" />
      <span class="page-title">{$mobilePageStore.pageTitle}</span>
    </div>
    <div class="header-right">
      <span class="user-name">{$authStore.user?.email || 'User'}</span>
      <div class="menu-container">
        <button class="menu-btn" on:click={toggleMenu} title="Menu">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="24" height="24">
            <line x1="3" y1="12" x2="21" y2="12"></line>
            <line x1="3" y1="6" x2="21" y2="6"></line>
            <line x1="3" y1="18" x2="21" y2="18"></line>
          </svg>
        </button>
        {#if menuOpen}
          <div class="menu-dropdown">
            <button class="menu-item logout-item" on:click={() => { handleLogout(); closeMenu(); }}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="18" height="18" style="margin-right:8px; vertical-align:middle;">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
                <polyline points="16 17 21 12 16 7"></polyline>
                <line x1="21" y1="12" x2="9" y2="12"></line>
              </svg>
              Logout
            </button>
          </div>
        {/if}
      </div>
    </div>
  </header>

  <!-- Mobile Content -->
  <div class="mobile-content">
    {#if $mobilePageStore.currentPage === 'home'}
      <MobileHome />
    {:else if $mobilePageStore.currentPage === 'my-jobs'}
      <MobileMyJobs />
    {:else if $mobilePageStore.currentPage === 'attendance'}
      <MobileAttendance />
    {:else if $mobilePageStore.currentPage === 'job-detail'}
      <MobileJobDetail />
    {:else if $mobilePageStore.currentPage === 'job-creation'}
      <MobileJobCreation />
    {:else}
      <MobileHome />
    {/if}
  </div>

  <!-- Mobile Bottom Navigation (hide on job-detail and job-creation pages) -->
  {#if $mobilePageStore.currentPage !== 'job-detail' && $mobilePageStore.currentPage !== 'job-creation'}
    <nav class="mobile-bottom-nav">
      <button 
        class="nav-btn"
        class:active={$mobilePageStore.currentPage === 'home'}
        on:click={goToHome}
        title="Home"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="24" height="24" class="nav-icon">
          <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path>
          <polyline points="9 22 9 12 15 12 15 22"></polyline>
        </svg>
        <span class="nav-label">Home</span>
      </button>
      <button 
        class="nav-btn"
        class:active={$mobilePageStore.currentPage === 'attendance'}
        on:click={goToAttendance}
        title="Scanner"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="24" height="24" class="nav-icon">
          <path d="M3 7V5a2 2 0 0 1 2-2h2M3 17v2a2 2 0 0 0 2 2h2M21 7V5a2 2 0 0 0-2-2h-2M21 17v2a2 2 0 0 1-2 2h-2"></path>
          <rect x="7" y="7" width="10" height="10" rx="1"></rect>
        </svg>
        <span class="nav-label">Scanner</span>
      </button>
      <button 
        class="nav-btn"
        class:active={$mobilePageStore.currentPage === 'my-jobs'}
        on:click={goToMyJobs}
        title="My Jobs"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="24" height="24" class="nav-icon">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
          <polyline points="14 2 14 8 20 8"></polyline>
          <line x1="16" y1="13" x2="8" y2="13"></line>
          <line x1="16" y1="17" x2="8" y2="17"></line>
          <polyline points="10 9 9 9 8 9"></polyline>
        </svg>
        <span class="nav-label">Jobs</span>
      </button>
    </nav>
  {/if}
</div>

<style>
  .mobile-layout {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    min-height: 100dvh;
    background: var(--neutral-50);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    
    /* OVERRIDE GLOBALS FOR MOBILE RED/WHITE THEME */
    --brand-primary: #C41E3A; /* Desktop Accent Red */
    --brand-secondary: #a01830; /* Darker variant */
    --brand-primary-light: rgba(196, 30, 58, 0.1);
  }

  .mobile-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: max(1rem, env(safe-area-inset-top)) 1rem 1rem 1rem;
    background: linear-gradient(135deg, var(--brand-primary) 0%, var(--brand-secondary) 100%);
    color: white;
    box-shadow: var(--shadow-md);
    z-index: 100;
    flex-shrink: 0;
  }

  .header-left {
    font-weight: 600;
    font-size: 1.125rem;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex: 1;
    min-width: 0;
    padding-left: max(0, env(safe-area-inset-left));
  }

  .back-btn {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    padding: 0.625rem 1rem;
    border-radius: 6px;
    color: white;
    cursor: pointer;
    font-size: 0.875rem;
    font-weight: 600;
    transition: all 0.2s ease;
    white-space: nowrap;
    flex-shrink: 0;
    min-height: 44px;
    display: flex;
    align-items: center;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    user-select: none;
  }

  .back-btn:active {
    background: rgba(255, 255, 255, 0.35);
    transform: scale(0.96);
  }

  .mobile-logo {
    width: 40px;
    height: 40px;
    border-radius: 6px;
    object-fit: contain;
    flex-shrink: 0;
  }

  .page-title {
    font-weight: 700;
    font-size: 1.125rem;
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
    letter-spacing: -0.5px;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding-right: max(0, env(safe-area-inset-right));
  }

  .user-name {
    font-size: 0.875rem;
    opacity: 0.95;
    max-width: 150px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .menu-container {
    position: relative;
  }

  .menu-btn {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    padding: 0.625rem 0.75rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1.25rem;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 44px;
    min-height: 44px;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    user-select: none;
  }

  .menu-btn:active {
    background: rgba(255, 255, 255, 0.35);
    transform: scale(0.96);
  }

  .menu-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    background: white;
    border: 1px solid var(--neutral-200);
    border-radius: 8px;
    box-shadow: var(--shadow-lg);
    min-width: 160px;
    margin-top: 0.5rem;
    z-index: 1000;
    overflow: hidden;
  }

  .menu-item {
    display: block;
    width: 100%;
    padding: 0.75rem 1rem;
    background: none;
    border: none;
    text-align: left;
    cursor: pointer;
    font-size: 0.95rem;
    color: var(--neutral-700);
    transition: all 0.15s ease;
  }

  .menu-item:hover {
    background: var(--neutral-100);
  }

  .menu-item:active {
    background: var(--neutral-200);
  }

  .logout-item {
    color: var(--status-error);
    border-top: 1px solid var(--neutral-200);
  }

  .logout-item:hover {
    background: #fee2e2;
  }

  .mobile-content {
    flex: 1;
    padding: 1rem;
    padding-bottom: calc(4.5rem + env(safe-area-inset-bottom));
  }

  .mobile-bottom-nav {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    justify-content: space-around;
    align-items: center;
    height: 4rem;
    background: white;
    border-top: 1px solid var(--neutral-200);
    box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.08);
    z-index: 99;
    padding-bottom: max(0, env(safe-area-inset-bottom));
  }

  .nav-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 4px;
    width: 100%;
    height: 100%;
    min-height: 48px;
    background: none;
    border: none;
    cursor: pointer;
    color: #6b7280;
    transition: all 0.25s ease;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    user-select: none;
    padding-top: 6px;
  }

  .nav-icon {
    transition: transform 0.2s ease, color 0.2s ease;
  }

  .nav-label {
    font-size: 0.65rem;
    font-weight: 600;
    letter-spacing: 0.02em;
    text-transform: uppercase;
  }

  .nav-btn.active {
    color: var(--brand-primary);
  }

  .nav-btn.active .nav-icon {
    transform: translateY(-2px);
  }

  .nav-btn:active .nav-icon {
    transform: scale(0.9);
  }

  @media (max-width: 768px) {
    .user-name {
      display: none;
    }

    .mobile-header {
      padding: max(0.75rem, env(safe-area-inset-top)) 0.75rem 0.75rem 0.75rem;
    }

    .header-left {
      gap: 0.5rem;
    }

    .page-title {
      font-size: 1rem;
    }

    .mobile-logo {
      width: 36px;
      height: 36px;
    }
  }

  @media (max-width: 480px) {
    .page-title {
      font-size: 0.95rem;
    }

    .mobile-header {
      gap: 0.5rem;
    }
  }
</style>
