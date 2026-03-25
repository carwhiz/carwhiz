<script lang="ts">
  import { interfaceStore } from '../../stores/interfaceStore';
  import { authStore } from '../../stores/authStore';
  import { login } from '../../lib/services/authService';
  import { supabase } from '../../lib/supabaseClient';
  import { canUserCreateResource } from '../../lib/services/permissionService';
  import type { LoginPayload } from '../../types/auth';
  import logoPath from '../../assets/CARWHIZ.jpeg';

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
        // Check if user has permission to access the chosen interface
        if (loginMode === 'desktop') {
          const userId = $authStore.user?.id;
          const userRole = $authStore.user?.role;
          
          // Admins always have desktop access
          if (userRole !== 'Admin') {
            if (userId) {
              try {
                // Only allow non-admins to access desktop if they have explicit permission
                const { data } = await supabase
                  .from('permissions')
                  .select('*')
                  .eq('user_id', userId)
                  .eq('resource', 'desktop-access')
                  .maybeSingle();
                
                // Only grant access if permission record exists AND can_create is true
                if (!data || !data.can_create) {
                  error = 'You do not have permission to access the Desktop interface';
                  authStore.logout();
                  loading = false;
                  return;
                }
              } catch (permError) {
                console.warn('Error checking desktop access permission:', permError);
                error = 'Unable to verify desktop access permission';
                authStore.logout();
                loading = false;
                return;
              }
            }
          }
        }
        
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
        <img src={logoPath} alt="CarWhizz Logo" class="auth-logo" />
      </div>

      <div class="mode-toggle">
        <span class="mode-label" class:active={loginMode === 'mobile'}>Mobile</span>
        <button 
          class="toggle-switch" 
          class:desktop={loginMode === 'desktop'}
          on:click={() => loginMode = loginMode === 'mobile' ? 'desktop' : 'mobile'}
          type="button"
        >
          <div class="toggle-knob"></div>
        </button>
        <span class="mode-label" class:active={loginMode === 'desktop'}>Desktop</span>
      </div>

      <form on:submit|preventDefault={handleLogin}>
        <div class="form-group">
          <label>Access Code</label>
          <div class="code-inputs">
            {#each codeDigits as digit, index}
              <input
                bind:this={inputRefs[index]}
                type="password"
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
        <p>&copy; 2026 CarWhizz. All rights reserved.</p>
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
    background: #f8f9fa;
    font-family: 'Segoe UI', Roboto, sans-serif;
  }

  .auth-container {
    width: 100%;
    max-width: 480px;
    padding: 1rem;
  }

  .auth-box {
    background: white;
    border-radius: 12px;
    padding: 3rem 4rem;
    box-shadow: 0 4px 40px rgba(0, 0, 0, 0.05);
  }

  .auth-header {
    text-align: center;
    margin-bottom: 2.5rem;
  }

  .auth-logo {
    width: 200px;
    height: auto;
    object-fit: contain;
    margin: 0 auto;
  }

  .mode-toggle {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    margin-bottom: 2rem;
  }

  .mode-label {
    font-size: 0.9rem;
    font-weight: 600;
    color: #9ca3af;
    transition: color 0.2s;
  }

  .mode-label.active {
    color: #c91e3a;
  }

  .toggle-switch {
    width: 48px;
    height: 24px;
    background: #e5e7eb;
    border-radius: 24px;
    position: relative;
    border: none;
    cursor: pointer;
    transition: background 0.2s;
    padding: 0;
  }

  .toggle-switch .toggle-knob {
    width: 20px;
    height: 20px;
    background: white;
    border-radius: 50%;
    position: absolute;
    top: 2px;
    left: 2px;
    transition: transform 0.2s;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .toggle-switch.desktop .toggle-knob {
    transform: translateX(24px);
  }

  .form-group {
    margin-bottom: 2rem;
  }

  label {
    display: block;
    margin-bottom: 0.6rem;
    font-size: 0.85rem;
    font-weight: 600;
    color: #4b5563;
    text-align: left;
  }

  .code-inputs {
    display: flex;
    gap: 0.75rem;
    justify-content: center;
    margin-bottom: 0.5rem;
  }

  .code-box {
    width: 3.2rem;
    height: 4rem;
    padding: 0;
    font-size: 2.5rem;
    text-align: center;
    font-weight: 600;
    border: 1.5px solid #e5e7eb;
    border-radius: 8px;
    box-sizing: border-box;
    transition: all 0.2s;
    background: transparent;
    color: #1f2937;
  }

  .code-box:focus {
    outline: none;
    border-color: #c91e3a;
    box-shadow: 0 0 0 2px rgba(201, 30, 58, 0.1);
    background: white;
  }

  .code-box:disabled {
    background: #f3f4f6;
    cursor: not-allowed;
  }

  .error-message {
    margin-bottom: 1.5rem;
    padding: 0.75rem;
    background: #fee2e2;
    color: #dc2626;
    border-radius: 8px;
    font-size: 0.9rem;
    text-align: center;
  }

  .btn {
    width: 100%;
    padding: 1rem;
    border: none;
    border-radius: 8px;
    font-size: 1.1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-primary {
    background: #d46b7a; /* Muted pinkish red to match image */
    color: white;
    box-shadow: 0 4px 14px rgba(212, 107, 122, 0.4);
  }

  .btn-primary:hover:not(:disabled) {
    background: #c55a69;
    box-shadow: 0 6px 20px rgba(212, 107, 122, 0.5);
  }

  .btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .auth-footer {
    margin: 2rem 0 0 0;
    padding-top: 1.5rem;
    border-top: 1px solid #f3f4f6;
    text-align: center;
    font-size: 0.8rem;
    color: #6b7280;
  }

  .privacy-link {
    display: block;
    margin: 0.5rem auto 0;
    background: none;
    border: none;
    color: #c91e3a;
    font-weight: 600;
    font-size: 0.85rem;
    cursor: pointer;
    text-decoration: none;
    transition: color 0.2s;
  }

  .privacy-link:hover {
    color: #a01830;
  }

  .auth-footer p {
    margin: 0;
  }

  /* ========== MOBILE OPTIMIZATIONS ========== */
  @media (max-width: 480px) {
    .auth-container {
      padding: 1rem;
    }
  
    .auth-box {
      padding: 2rem 1.25rem;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      border-radius: 10px;
    }
    
    .auth-logo {
      width: 140px;
      margin-bottom: 0.5rem;
    }

    .code-inputs {
      gap: 0.35rem;
    }

    .code-box {
      width: 2.5rem;
      height: 3.2rem;
      font-size: 1.8rem;
      border-radius: 6px;
    }

    .mode-toggle {
      gap: 0.5rem;
      margin-bottom: 1.5rem;
    }
    
    .form-group {
      margin-bottom: 1.5rem;
    }

    .auth-header {
      margin-bottom: 1.5rem;
    }
  }
</style>
