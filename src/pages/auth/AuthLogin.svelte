<script lang="ts">
  import { interfaceStore } from '../../stores/interfaceStore';
  import { authStore } from '../../stores/authStore';
  import { login } from '../../lib/services/authService';
  import type { LoginPayload } from '../../types/auth';

  let codeDigits: string[] = ['', '', '', '', '', ''];
  let loading = false;
  let error = '';
  let loginMode: 'desktop' | 'mobile' = 'desktop';
  let inputRefs: HTMLInputElement[] = [];

  function getAccessCode() {
    return codeDigits.join('');
  }

  async function handleLogin() {
    const fullCode = getAccessCode();
    if (fullCode.length !== 6) {
      error = 'Please enter a valid 6-digit access code';
      return;
    }

    loading = true;
    error = '';

    try {
      const result = await login({ password: fullCode } as LoginPayload);
      if (!result.success) {
        error = result.error || 'Login failed';
      } else {
        // Redirect to appropriate interface
        interfaceStore.setInterface(loginMode);
      }
    } catch (err: any) {
      error = err.message || 'Login failed';
    } finally {
      loading = false;
    }
  }

  function handleDigitInput(index: number, e: Event) {
    const input = e.target as HTMLInputElement;
    let value = input.value;

    // Only allow digits
    value = value.replace(/[^0-9]/g, '');

    // Only take the last digit if multiple are pasted
    if (value.length > 1) {
      value = value.charAt(value.length - 1);
    }

    codeDigits[index] = value;

    // Move to next input if digit entered
    if (value && index < 5) {
      inputRefs[index + 1]?.focus();
    }

    // If all filled and on last box, submit
    if (getAccessCode().length === 6 && index === 5) {
      handleLogin();
    }
  }

  function handleKeyDown(index: number, e: KeyboardEvent) {
    if (e.key === 'Backspace' && !codeDigits[index] && index > 0) {
      // Move to previous input on backspace if current is empty
      inputRefs[index - 1]?.focus();
    } else if (e.key === 'Enter' && getAccessCode().length === 6) {
      handleLogin();
    }
  }

  function handlePaste(e: ClipboardEvent) {
    e.preventDefault();
    const pastedData = e.clipboardData?.getData('text') || '';
    const digits = pastedData.replace(/[^0-9]/g, '').split('').slice(0, 6);

    digits.forEach((digit, index) => {
      codeDigits[index] = digit;
    });

    // Focus on the appropriate input
    const focusIndex = Math.min(digits.length, 5);
    inputRefs[focusIndex]?.focus();

    codeDigits = codeDigits; // Trigger reactivity
  }
</script>

<div class="auth-page login-page">
  <div class="auth-container">
    <div class="auth-box">
      <div class="auth-header">
        <img src="/src/assets/CARWHIZ.jpeg" alt="CarWhizz Logo" class="auth-logo" />
      </div>

      <div class="mode-toggle">
        <button
          type="button"
          class="mode-btn"
          class:active={loginMode === 'desktop'}
          on:click={() => (loginMode = 'desktop')}
        >
          Desktop
        </button>
        <button
          type="button"
          class="mode-btn"
          class:active={loginMode === 'mobile'}
          on:click={() => (loginMode = 'mobile')}
        >
          Mobile
        </button>
      </div>

      <form on:submit|preventDefault={handleLogin}>
        <div class="form-group">
          <label>Access Code</label>
          <div class="code-inputs">
            {#each codeDigits as digit, index}
              <input
                bind:this={inputRefs[index]}
                type="text"
                inputmode="numeric"
                maxlength="1"
                class="code-box"
                value={digit}
                on:input={(e) => handleDigitInput(index, e)}
                on:keydown={(e) => handleKeyDown(index, e)}
                on:paste={handlePaste}
                disabled={loading}
              />
            {/each}
          </div>
          <p class="code-hint">Enter your 6-digit access code</p>
        </div>

        {#if error}
          <div class="error-message">{error}</div>
        {/if}

        <button 
          type="submit" 
          class="btn btn-primary" 
          disabled={loading || getAccessCode().length !== 6}
        >
          {loading ? 'Logging in...' : 'Login'}
        </button>
      </form>

      <div class="auth-footer">
        <p>Contact your administrator for an access code</p>
        <button 
          type="button"
          class="privacy-link"
          on:click={() => interfaceStore.setInterface('privacy')}
        >
          Privacy Policy
        </button>
      </div>
    </div>
  </div>
</div>

<style>
  .auth-page {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    min-height: 100dvh;
    background: linear-gradient(135deg, #f97316 0%, #fb923c 100%);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  .auth-container {
    width: 100%;
    max-width: 400px;
    padding: 1rem;
  }

  .auth-box {
    background: white;
    border-radius: 8px;
    padding: 2rem;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  }

  .auth-header {
    text-align: center;
    margin-bottom: 1rem;
  }

  .auth-logo {
    width: 80px;
    height: 80px;
    border-radius: 12px;
    object-fit: contain;
    margin: 0 auto;
  }

  .auth-title {
    margin: 0 0 0.5rem 0;
    text-align: center;
    font-size: 2rem;
    color: #f97316;
  }

  .auth-subtitle {
    margin: 0 0 2rem 0;
    text-align: center;
    font-size: 0.9rem;
    color: #6b7280;
  }

  .mode-toggle {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1.5rem;
    background: #f3f4f6;
    padding: 0.25rem;
    border-radius: 6px;
  }

  .mode-btn {
    flex: 1;
    padding: 0.5rem 1rem;
    border: none;
    background: transparent;
    color: #6b7280;
    font-weight: 500;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
  }

  .mode-btn.active {
    background: white;
    color: #f97316;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .mode-btn:hover {
    color: #f97316;
  }

  .form-group {
    margin-bottom: 1.5rem;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
    color: #1f2937;
  }

  .code-inputs {
    display: flex;
    gap: 0.5rem;
    justify-content: center;
    margin-bottom: 0.5rem;
  }

  .code-box {
    width: 3rem;
    height: 3rem;
    padding: 0;
    font-size: 1.5rem;
    text-align: center;
    font-weight: 700;
    border: 2px solid #d1d5db;
    border-radius: 8px;
    box-sizing: border-box;
    transition: all 0.2s;
    background: white;
    color: #1f2937;
  }

  .code-box:focus {
    outline: none;
    border-color: #f97316;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
  }

  .code-box:disabled {
    background: #f3f4f6;
    cursor: not-allowed;
  }

  .code-hint {
    margin: 0.5rem 0 0 0;
    font-size: 0.8rem;
    color: #9ca3af;
    text-align: center;
  }

  .error-message {
    margin-bottom: 1rem;
    padding: 0.75rem;
    background: #fee2e2;
    color: #dc2626;
    border-radius: 4px;
    font-size: 0.9rem;
  }

  .btn {
    width: 100%;
    padding: 0.75rem;
    border: none;
    border-radius: 4px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-primary {
    background: #f97316;
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background: #ea580c;
  }

  .btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .auth-footer {
    margin: 1.5rem 0 0 0;
    text-align: center;
    font-size: 0.85rem;
    color: #9ca3af;
  }

  .privacy-link {
    display: block;
    margin: 1rem 0 0 0;
    background: none;
    border: none;
    color: #f97316;
    font-size: 0.85rem;
    cursor: pointer;
    text-decoration: underline;
    transition: color 0.2s;
  }

  .privacy-link:hover {
    color: #ea580c;
  }

  .auth-footer p {
    margin: 0;
  }
</style>
