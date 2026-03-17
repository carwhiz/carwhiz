<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from './stores/authStore';
  import { getCurrentUser } from './lib/services/authService';
  import Login from './components/Login.svelte';
  import SignUp from './components/SignUp.svelte';
  import Dashboard from './components/Dashboard.svelte';

  let currentPage = 'login';
  let isInitializing = true;

  onMount(async () => {
    // Check authentication status
    try {
      const user = await getCurrentUser();
      if (user) {
        authStore.setUser(user);
        currentPage = 'dashboard';
      } else {
        // Check URL for page routing
        const path = window.location.pathname;
        if (path.includes('signup')) {
          currentPage = 'signup';
        } else {
          currentPage = 'login';
        }
      }
    } catch (error) {
      console.error('Auth check error:', error);
    } finally {
      isInitializing = false;
    }

    // Listen for hash/path changes
    window.addEventListener('hashchange', handleRouteChange);
    window.addEventListener('popstate', handleRouteChange);
  });

  function handleRouteChange() {
    const path = window.location.pathname;
    if (path.includes('signup')) {
      currentPage = 'signup';
    } else if (path.includes('login') || path === '/') {
      currentPage = 'login';
    }
  }
</script>

<main>
  {#if isInitializing}
    <div class="loading-container">
      <div class="spinner"></div>
      <p>Loading CarWhizz...</p>
    </div>
  {:else if currentPage === 'dashboard'}
    <Dashboard on:logout={() => { currentPage = 'login'; }} />
  {:else if currentPage === 'signup'}
    <SignUp />
  {:else}
    <Login on:login={() => { currentPage = 'dashboard'; }} />
  {/if}
</main>

<style>
  :global(*) {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  :global(body) {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen,
      Ubuntu, Cantarell, sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  main {
    width: 100%;
    min-height: 100vh;
  }

  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    background: linear-gradient(135deg, #FB923C 0%, #EA580C 100%);
    color: white;
  }

  .spinner {
    width: 50px;
    height: 50px;
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-bottom: 20px;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  p {
    font-size: 16px;
    font-weight: 500;
  }

  /* Mobile Responsive */
  @media (max-width: 480px) {
    main {
      min-height: 100vh;
    }
  }

  /* Tablet/Desktop */
  @media (min-width: 768px) {
    main {
      min-height: 100vh;
    }
  }
</style>
