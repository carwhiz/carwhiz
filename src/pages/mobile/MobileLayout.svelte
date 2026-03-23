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
    // Go back to my jobs from job detail
    if ($mobilePageStore.currentPage === 'job-detail') {
      goToMyJobs();
    } else {
      goToHome();
    }
  }

  function shouldShowBackButton(): boolean {
    return $mobilePageStore.currentPage === 'job-detail';
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
        <button class="back-btn" on:click={goBack} title="Back">← Back</button>
      {/if}
      <img src={logoPath} alt="CarWhizz" class="mobile-logo" />
      <span class="page-title">{$mobilePageStore.pageTitle}</span>
    </div>
    <div class="header-right">
      <span class="user-name">{$authStore.user?.email || 'User'}</span>
      <div class="menu-container">
        <button class="menu-btn" on:click={toggleMenu} title="Menu">☰</button>
        {#if menuOpen}
          <div class="menu-dropdown">
            <button class="menu-item logout-item" on:click={() => { handleLogout(); closeMenu(); }}>
              🚪 Logout
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
    {:else}
      <MobileHome />
    {/if}
  </div>

  <!-- Mobile Bottom Navigation (hide on job-detail page) -->
  {#if $mobilePageStore.currentPage !== 'job-detail'}
    <nav class="mobile-bottom-nav">
      <button 
        class="nav-btn"
        class:active={$mobilePageStore.currentPage === 'home'}
        on:click={goToHome}
        title="Home"
      >
        🏠
      </button>
      <button 
        class="nav-btn"
        class:active={$mobilePageStore.currentPage === 'my-jobs'}
        on:click={goToMyJobs}
        title="My Jobs"
      >
        📋
      </button>
      <button 
        class="nav-btn"
        class:active={$mobilePageStore.currentPage === 'attendance'}
        on:click={goToAttendance}
        title="Attendance"
      >
        👤
      </button>
    </nav>
  {/if}
</div>

<style>
  .mobile-layout {
    display: flex;
    flex-direction: column;
    height: 100vh;
    height: 100dvh;
    background: #f8fafc;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  .mobile-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    background: linear-gradient(135deg, #f97316 0%, #fb923c 100%);
    color: white;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    z-index: 100;
  }

  .header-left {
    font-weight: 600;
    font-size: 1.25rem;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex: 1;
    min-width: 0;
  }

  .back-btn {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    padding: 0.5rem 0.75rem;
    border-radius: 4px;
    color: white;
    cursor: pointer;
    font-size: 0.875rem;
    font-weight: 600;
    transition: background 0.2s;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .back-btn:active {
    background: rgba(255, 255, 255, 0.3);
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
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .user-name {
    font-size: 0.875rem;
    opacity: 0.9;
    max-width: 150px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .logout-btn {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    padding: 0.5rem 0.75rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    transition: background 0.2s;
  }

  .logout-btn:active {
    background: rgba(255, 255, 255, 0.3);
  }

  .menu-container {
    position: relative;
  }

  .menu-btn {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    padding: 0.5rem 0.75rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1.25rem;
    transition: background 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .menu-btn:active {
    background: rgba(255, 255, 255, 0.3);
  }

  .menu-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    min-width: 150px;
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
    color: #374151;
    transition: background 0.15s;
  }

  .menu-item:hover {
    background: #f3f4f6;
  }

  .menu-item:active {
    background: #e5e7eb;
  }

  .logout-item {
    color: #dc2626;
    border-top: 1px solid #e5e7eb;
  }

  .logout-item:hover {
    background: #fee2e2;
  }

  .mobile-content {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    -webkit-overflow-scrolling: touch;
    padding-bottom: 4rem;
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
    border-top: 1px solid #e5e7eb;
    box-shadow: 0 -2px 4px rgba(0, 0, 0, 0.05);
    z-index: 99;
  }

  .nav-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #6b7280;
    transition: all 0.2s;
  }

  .nav-btn.active {
    color: #f97316;
    background: #fff7ed;
  }

  .nav-btn:active {
    opacity: 0.8;
  }

  @media (max-width: 768px) {
    .user-name {
      display: none;
    }

    .mobile-header {
      padding: 0.75rem;
    }
  }
</style>
