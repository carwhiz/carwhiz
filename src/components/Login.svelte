<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '../stores/authStore';
  import { login, validatePassword } from '../lib/services/authService';
  import { interfaceStore } from '../stores/interfaceStore';
  import { createEventDispatcher } from 'svelte';
  import PrivacyPolicy from './PrivacyPolicy.svelte';

  const dispatch = createEventDispatcher();

  let showPrivacy = false;

  let password = '';
  let touched = { password: false };
  let isSubmitting = false;

  function toggleInterface() {
    interfaceStore.toggle();
  }

  onMount(async () => {
    // Check if user is already logged in
    if ($authStore.isAuthenticated) {
      // Redirect to dashboard or home
      window.location.href = '/';
    }
  });

  function getPasswordError(): string {
    if (!touched.password) return '';
    if (!password) return 'Access code is required';
    if (!validatePassword(password)) return 'Access code must be 6 digits';
    return '';
  }

  async function handleLogin() {
    touched.password = true;

    const passwordError = getPasswordError();

    if (passwordError) {
      return;
    }

    isSubmitting = true;
    const result = await login({ password });

    if (result.success) {
      dispatch('login');
    }

    isSubmitting = false;
  }

  function handleKeyPress(e: KeyboardEvent) {
    if (e.key === 'Enter' && !isSubmitting) {
      handleLogin();
    }
  }
</script>

<div class="login-container">
  <div class="login-card">
    {#if $authStore.error}
      <div class="alert alert-error" role="alert">
        {$authStore.error}
      </div>
    {/if}

    <div class="logo-section">
      <img src="/logo.jpeg" alt="CarWhizz Logo" class="logo" />
    </div>

    <div class="interface-switch">
      <span class:active={$interfaceStore === 'mobile'}>Mobile</span>
      <button class="switch-btn" on:click={toggleInterface} type="button" aria-label="Toggle interface mode">
        <span class="switch-track" class:toggled={$interfaceStore === 'desktop'}>
          <span class="switch-thumb"></span>
        </span>
      </button>
      <span class:active={$interfaceStore === 'desktop'}>Desktop</span>
    </div>

    <form on:submit|preventDefault={handleLogin} class="login-form">
      <div class="form-group">
        <label for="password">Access Code</label>
        <input
          id="password"
          type="password"
          placeholder="Enter 6-digit access code"
          bind:value={password}
          maxlength="6"
          inputmode="numeric"
          on:blur={() => { touched.password = true; }}
          on:keypress={handleKeyPress}
          disabled={isSubmitting}
          class:error={touched.password && getPasswordError()}
          class:valid={touched.password && !getPasswordError() && password}
        />
        {#if getPasswordError()}
          <span class="error-message">{getPasswordError()}</span>
        {/if}
      </div>

      <button
        type="submit"
        class="btn-primary"
        disabled={isSubmitting || !!getPasswordError()}
      >
        {#if $authStore.loading || isSubmitting}
          <span class="spinner"></span>
          Logging in...
        {:else}
          Login
        {/if}
      </button>
    </form>

    <div class="footer-text">
      <p>© 2026 CarWhizz. All rights reserved.</p>
      <button class="privacy-link" on:click={() => showPrivacy = true} type="button">Privacy Policy</button>
    </div>
  </div>
</div>

{#if showPrivacy}
  <PrivacyPolicy on:close={() => showPrivacy = false} />
{/if}

<style>
  .login-container {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #FB923C 0%, #EA580C 100%);
    padding: 20px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen,
      Ubuntu, Cantarell, sans-serif;
  }

  .login-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    padding: 40px;
    width: 100%;
    max-width: 500px;
    animation: slideUp 0.5s ease-out;
  }

  @keyframes slideUp {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .logo-section {
    text-align: center;
    margin-bottom: 24px;
    border: 3px solid #F97316;
    border-radius: 16px;
    padding: 0;
    overflow: hidden;
    width: 100%;
  }

  .logo {
    width: 100%;
    height: auto;
    display: block;
    object-fit: contain;
  }

  .interface-switch {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    margin-bottom: 24px;
    font-size: 14px;
    font-weight: 600;
    color: #999;
  }

  .interface-switch span.active {
    color: #EA580C;
  }

  .switch-btn {
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
    display: flex;
    align-items: center;
  }

  .switch-track {
    width: 44px;
    height: 24px;
    background: #e0e0e0;
    border-radius: 12px;
    position: relative;
    transition: background 0.3s;
  }

  .switch-track.toggled {
    background: #F97316;
  }

  .switch-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 20px;
    height: 20px;
    background: white;
    border-radius: 50%;
    transition: transform 0.3s;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
  }

  .switch-track.toggled .switch-thumb {
    transform: translateX(20px);
    margin: 0;
  }

  h1 {
    font-size: 28px;
    font-weight: 700;
    margin: 0;
    color: #1a202c;
    letter-spacing: -0.5px;
  }

  .subtitle {
    color: #718096;
    margin: 8px 0 0 0;
    font-size: 14px;
  }

  .login-form {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  label {
    font-weight: 600;
    color: #2d3748;
    font-size: 14px;
  }

  input {
    padding: 12px 16px;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 16px;
    transition: all 0.3s ease;
    background: #f7fafc;
  }

  input:focus {
    outline: none;
    background: white;
    border-color: #F97316;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.15);
  }

  input.error {
    border-color: #f56565;
    background: #fff5f5;
  }

  input.valid {
    border-color: #48bb78;
    background: #f0fff4;
  }

  input:disabled {
    background: #edf2f7;
    cursor: not-allowed;
    opacity: 0.6;
  }

  .error-message {
    font-size: 13px;
    color: #f56565;
    margin-top: 4px;
  }

  .btn-primary {
    padding: 12px 16px;
    background: linear-gradient(135deg, #FB923C 0%, #EA580C 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    margin-top: 10px;
  }

  .btn-primary:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 10px 30px rgba(249, 115, 22, 0.4);
  }

  .btn-primary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .spinner {
    display: inline-block;
    width: 16px;
    height: 16px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .alert {
    padding: 12px 16px;
    border-radius: 8px;
    margin-bottom: 20px;
    font-size: 14px;
  }

  .alert-error {
    background: #fff5f5;
    border: 1px solid #feb2b2;
    color: #c53030;
  }

  .footer-text {
    text-align: center;
    font-size: 12px;
    color: #a0aec0;
    margin-top: 24px;
  }

  .footer-text p {
    margin: 0;
  }

  .privacy-link {
    background: none;
    border: none;
    color: #EA580C;
    font-size: 12px;
    cursor: pointer;
    text-decoration: underline;
    margin-top: 8px;
    padding: 0;
  }

  .privacy-link:hover {
    color: #c2410c;
  }

  /* Mobile Responsive */
  @media (max-width: 480px) {
    .login-container {
      min-height: 100vh;
    }

    .login-card {
      border-radius: 12px;
      padding: 24px 20px;
      margin: auto 0;
    }

    h1 {
      font-size: 24px;
    }

    input,
    .btn-primary {
      font-size: 16px;
      padding: 14px 12px;
    }
  }

  /* Tablet/Desktop */
  @media (min-width: 768px) {
    .login-card {
      padding: 48px;
    }

    h1 {
      font-size: 32px;
    }

    .logo {
      width: 220px;
      height: 220px;
    }
  }
</style>
