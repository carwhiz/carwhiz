<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from './stores/authStore';
  import { interfaceStore } from './stores/interfaceStore';
  import { getCurrentUser } from './lib/services/authService';
  import { initRouter, getCurrentMode } from './routes';
  
  // Page imports
  import AuthLogin from './pages/auth/AuthLogin.svelte';
  import AuthSignUp from './pages/auth/AuthSignUp.svelte';
  import MobileLayout from './pages/mobile/MobileLayout.svelte';
  import DesktopLayout from './pages/desktop/DesktopLayout.svelte';
  import PrivacyPolicy from './pages/info/PrivacyPolicy.svelte';

  let isInitializing = true;

  // Subscribe to interface changes for reactive updates
  const unsubscribe = interfaceStore.subscribe(() => {
    // This subscription ensures reactivity when interface changes
  });

  onMount(() => {
    // Check authentication status
    (async () => {
      try {
        const user = await getCurrentUser();
        if (user) {
          authStore.setUser(user);
        }
      } catch (error) {
        console.error('Auth check error:', error);
      }

      // Get current URL on app load
      const currentUrl = typeof window !== 'undefined' ? window.location.pathname : '/';
      const currentMode = getCurrentMode();
      
      // Set interface based on current URL
      if (currentMode) {
        interfaceStore.setInterface(currentMode);
      } else {
        interfaceStore.setInterface('login');
      }

      // Initialize router after setting initial interface
      initRouter();

      isInitializing = false;
    })();

    // Setup Service Worker update handler to auto-reload when new version available
    if ('serviceWorker' in navigator) {
      const refreshing = { current: false };
      
      navigator.serviceWorker.addEventListener('controllerchange', () => {
        if (!refreshing.current) {
          refreshing.current = true;
          window.location.reload();
        }
      });

      // Poll for updates every 60 seconds
      setInterval(() => {
        navigator.serviceWorker.getRegistration().then((registration) => {
          if (registration) {
            registration.update();
          }
        });
      }, 60000);
    }

    return unsubscribe;
  });
</script>

<main>
  {#if isInitializing}
    <div class="loading-container">
      <div class="spinner"></div>
      <p>Loading CarWhizz...</p>
    </div>
  {:else if $interfaceStore.currentInterface === 'login'}
    <AuthLogin />
  {:else if $interfaceStore.currentInterface === 'signup'}
    <AuthSignUp />
  {:else if $interfaceStore.currentInterface === 'mobile'}
    <MobileLayout />
  {:else if $interfaceStore.currentInterface === 'desktop'}
    <DesktopLayout />
  {:else if $interfaceStore.currentInterface === 'privacy'}
    <PrivacyPolicy />
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
    background: linear-gradient(135deg, #C41E3A 0%, #C41E3A 100%);
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
