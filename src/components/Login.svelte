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
        {#if isSubmitting}
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
    background: #ffffff;
    padding: 20px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen,
      Ubuntu, Cantarell, sans-serif;
    position: relative;
    overflow: hidden;
  }

  .login-card {
    background: white;
    border-radius: 12px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.08), 0 1px 3px rgba(0, 0, 0, 0.05);
    padding: 40px;
    width: 100%;
    max-width: 480px;
    animation: slideUp 0.6s ease-out;
    border: 1px solid #e2e8f0;
    position: relative;
    z-index: 1;
  }

  @keyframes slideUp {
    from {
      opacity: 0;
      transform: translateY(35px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .logo-section {
    text-align: center;
    margin: 0 auto 32px;
    border: none;
    padding: 0;
    overflow: hidden;
    width: 100%;
    background: transparent;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: auto;
    box-shadow: none;
    margin-bottom: 40px;
  }

  .logo {
    width: 100%;
    height: auto;
    display: block;
    object-fit: contain;
    max-width: 250px;
    max-height: 160px;
  }

  .interface-switch {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    margin-bottom: 24px;
    font-size: 13px;
    font-weight: 700;
    color: #999;
  }

  .interface-switch span.active {
    color: #C41E3A;
    text-shadow: 0 0 8px rgba(196, 30, 58, 0.2);
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
    background: #e5e7eb;
    border-radius: 12px;
    position: relative;
    transition: all 0.3s ease;
    border: 2px solid #d1d5db;
  }

  .switch-track.toggled {
    background: linear-gradient(135deg, #C41E3A 0%, #A01828 100%);
    border-color: #C41E3A;
  }

  .switch-thumb {
    position: absolute;
    top: 1px;
    left: 1px;
    width: 20px;
    height: 20px;
    background: white;
    border-radius: 50%;
    transition: all 0.3s ease;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
  }

  .switch-track.toggled .switch-thumb {
    transform: translateX(20px);
    margin: 0;
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
    letter-spacing: 0px;
  }

  input {
    padding: 12px 16px;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 16px;
    transition: all 0.4s ease;
    background: #f8fafc;
    color: #1a202c;
    font-weight: 500;
  }

  input::placeholder {
    color: #cbd5e1;
    font-weight: 400;
  }

  input:focus {
    outline: none;
    background: white;
    border-color: #C41E3A;
    box-shadow: 0 0 0 3px rgba(196, 30, 58, 0.15);
  }

  input.error {
    border-color: #ef4444;
    background: #fef2f2;
  }

  input.valid {
    border-color: #10b981;
    background: #f0fdf4;
  }

  input:disabled {
    background: #f1f5f9;
    cursor: not-allowed;
    opacity: 0.6;
  }

  .error-message {
    font-size: 13px;
    color: #C41E3A;
    margin-top: 4px;
    font-weight: 500;
  }

  .btn-primary {
    padding: 12px 16px;
    background: linear-gradient(135deg, #C41E3A 0%, #A01828 100%);
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
    letter-spacing: 0.3px;
    box-shadow: 0 8px 20px rgba(196, 30, 58, 0.3);
  }

  .btn-primary:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 12px 35px rgba(196, 30, 58, 0.4);
  }

  .btn-primary:active:not(:disabled) {
    transform: translateY(-1px);
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
    font-weight: 500;
  }

  .alert-error {
    background: #fef2f2;
    border: 1px solid #fca5a5;
    color: #C41E3A;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.15);
  }

  .footer-text {
    text-align: center;
    font-size: 12px;
    color: #64748b;
    margin-top: 24px;
    padding-top: 24px;
    border-top: 1px solid #e2e8f0;
  }

  .footer-text p {
    margin: 0;
    font-weight: 500;
  }

  .privacy-link {
    background: none;
    border: none;
    color: #C41E3A;
    font-size: 12px;
    cursor: pointer;
    text-decoration: none;
    margin-top: 8px;
    padding: 0;
    font-weight: 600;
    transition: all 0.3s ease;
  }

  .privacy-link:hover {
    color: #A01828;
    text-decoration: underline;
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
      border: 2px solid #C41E3A;
    }

    .logo-section {
      margin-bottom: 24px;
      min-height: 160px;
      padding: 10px;
      border-radius: 12px;
    }

    input,
    .btn-primary {
      font-size: 16px;
      padding: 12px 14px;
    }

    .logo {
      max-width: 220px;
      max-height: 140px;
    }
  }

  /* Tablet/Desktop */
  @media (min-width: 768px) {
    .login-card {
      padding: 48px;
    }

    .logo {
      width: 220px;
      height: auto;
    }
  }
</style>
