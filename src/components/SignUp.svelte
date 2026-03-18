<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '../stores/authStore';
  import {
    signUp,
    validateEmail,
    validatePassword,
    validatePhoneNumber,
  } from '../lib/services/authService';

  let email = '';
  let phone_number = '';
  let password = '';
  let confirmPassword = '';
  let agreedToTerms = false;
  let touched = { email: false, phone: false, password: false, confirm: false };
  let isSubmitting = false;

  onMount(async () => {
    // Check if user is already logged in
    if ($authStore.isAuthenticated) {
      // Redirect to dashboard or home
      window.location.href = '/';
    }
  });

  function handleBlur(field: keyof typeof touched) {
    touched[field] = true;
  }

  function getEmailError(): string {
    if (!touched.email) return '';
    if (!email) return 'Email is required';
    if (!validateEmail(email)) return 'Invalid email format';
    return '';
  }

  function getPhoneError(): string {
    if (!touched.phone) return '';
    if (!phone_number) return 'Phone number is required';
    if (!validatePhoneNumber(phone_number))
      return 'Invalid phone number format (e.g., +1-234-567-8900)';
    return '';
  }

  function getPasswordError(): string {
    if (!touched.password) return '';
    if (!password) return 'Password is required';
    if (!validatePassword(password)) return 'Password must be exactly 6 digits';
    return '';
  }

  function getConfirmPasswordError(): string {
    if (!touched.confirm) return '';
    if (!confirmPassword) return 'Confirm password is required';
    if (password !== confirmPassword) return 'Passwords do not match';
    return '';
  }

  function formatPhoneNumber(e: Event) {
    const input = e.target as HTMLInputElement;
    let value = input.value.replace(/\D/g, '');

    if (value.length > 0) {
      if (value.length <= 3) {
        value = value;
      } else if (value.length <= 6) {
        value = `${value.slice(0, 3)}-${value.slice(3)}`;
      } else {
        value = `${value.slice(0, 3)}-${value.slice(3, 6)}-${value.slice(6, 10)}`;
      }
    }

    phone_number = value;
  }

  async function handleSignUp() {
    touched.email = true;
    touched.phone = true;
    touched.password = true;
    touched.confirm = true;

    const emailError = getEmailError();
    const phoneError = getPhoneError();
    const passwordError = getPasswordError();
    const confirmError = getConfirmPasswordError();

    if (emailError || phoneError || passwordError || confirmError) {
      return;
    }

    if (!agreedToTerms) {
      authStore.setError('You must agree to the Terms of Service');
      return;
    }

    isSubmitting = true;
    const result = await signUp({ email, phone_number, password });

    if (result.success) {
      // Redirect on successful signup
      setTimeout(() => {
        window.location.href = '/login?message=signup_success';
      }, 500);
    }

    isSubmitting = false;
  }

  function handleKeyPress(e: KeyboardEvent) {
    if (e.key === 'Enter' && !isSubmitting) {
      handleSignUp();
    }
  }
</script>

<div class="signup-container">
  <div class="signup-card">
    {#if $authStore.error}
      <div class="alert alert-error" role="alert">
        {$authStore.error}
      </div>
    {/if}

    <div class="logo-section">
      <img src="/logo.jpeg" alt="CarWhizz Logo" class="logo" />
      <p class="subtitle">Create Your Account</p>
    </div>

    <form on:submit|preventDefault={handleSignUp} class="signup-form">
      <div class="form-group">
        <label for="email">Email Address</label>
        <input
          id="email"
          type="email"
          placeholder="Enter your email"
          bind:value={email}
          on:blur={() => handleBlur('email')}
          disabled={isSubmitting}
          class:error={touched.email && getEmailError()}
          class:valid={touched.email && !getEmailError() && email}
        />
        {#if getEmailError()}
          <span class="error-message">{getEmailError()}</span>
        {/if}
      </div>

      <div class="form-group">
        <label for="phone">Phone Number</label>
        <input
          id="phone"
          type="tel"
          placeholder="e.g., 123-456-7890"
          value={phone_number}
          on:input={formatPhoneNumber}
          on:blur={() => handleBlur('phone')}
          disabled={isSubmitting}
          class:error={touched.phone && getPhoneError()}
          class:valid={touched.phone && !getPhoneError() && phone_number}
        />
        {#if getPhoneError()}
          <span class="error-message">{getPhoneError()}</span>
        {/if}
      </div>

      <div class="form-group">
        <label for="password">Password (6-Digit Code)</label>
        <input
          id="password"
          type="password"
          placeholder="Enter 6-digit code"
          bind:value={password}
          maxlength="6"
          inputmode="numeric"
          on:blur={() => handleBlur('password')}
          disabled={isSubmitting}
          class:error={touched.password && getPasswordError()}
          class:valid={touched.password && !getPasswordError() && password}
        />
        {#if getPasswordError()}
          <span class="error-message">{getPasswordError()}</span>
        {/if}
      </div>

      <div class="form-group">
        <label for="confirm">Confirm Password</label>
        <input
          id="confirm"
          type="password"
          placeholder="Confirm 6-digit code"
          bind:value={confirmPassword}
          maxlength="6"
          inputmode="numeric"
          on:blur={() => handleBlur('confirm')}
          on:keypress={handleKeyPress}
          disabled={isSubmitting}
          class:error={touched.confirm && getConfirmPasswordError()}
          class:valid={touched.confirm && !getConfirmPasswordError() && confirmPassword}
        />
        {#if getConfirmPasswordError()}
          <span class="error-message">{getConfirmPasswordError()}</span>
        {/if}
      </div>

      <div class="checkbox-group">
        <input
          id="terms"
          type="checkbox"
          bind:checked={agreedToTerms}
          disabled={isSubmitting}
        />
        <label for="terms" class="checkbox-label">
          I agree to the <a href="/terms">Terms of Service</a> and
          <a href="/privacy">Privacy Policy</a>
        </label>
      </div>

      <button
        type="submit"
        class="btn-primary"
        disabled={isSubmitting ||
          !!getEmailError() ||
          !!getPhoneError() ||
          !!getPasswordError() ||
          !!getConfirmPasswordError() ||
          !agreedToTerms}
      >
        {#if $authStore.loading || isSubmitting}
          <span class="spinner"></span>
          Creating Account...
        {:else}
          Sign Up
        {/if}
      </button>
    </form>

    <div class="divider">OR</div>

    <div class="login-link">
      <p>Already have an account? <a href="/login">Login</a></p>
    </div>

    <div class="footer-text">
      <p>© 2026 CarWhizz. All rights reserved.</p>
    </div>
  </div>
</div>

<style>
  .signup-container {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #C41E3A 0%, #C41E3A 100%);
    padding: 20px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen,
      Ubuntu, Cantarell, sans-serif;
  }

  .signup-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    padding: 40px;
    width: 100%;
    max-width: 540px;
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
    border: 3px solid #C41E3A;
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

  .signup-form {
    display: flex;
    flex-direction: column;
    gap: 16px;
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

  input[type='text'],
  input[type='email'],
  input[type='password'],
  input[type='tel'] {
    padding: 12px 16px;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 16px;
    transition: all 0.3s ease;
    background: #f7fafc;
  }

  input[type='text']:focus,
  input[type='email']:focus,
  input[type='password']:focus,
  input[type='tel']:focus {
    outline: none;
    background: white;
    border-color: #C41E3A;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.15);
  }

  input[type='text'].error,
  input[type='email'].error,
  input[type='password'].error,
  input[type='tel'].error {
    border-color: #f56565;
    background: #fff5f5;
  }

  input[type='text'].valid,
  input[type='email'].valid,
  input[type='password'].valid,
  input[type='tel'].valid {
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
    margin-top: 2px;
  }

  .checkbox-group {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    margin: 8px 0;
  }

  input[type='checkbox'] {
    width: 20px;
    height: 20px;
    margin-top: 2px;
    cursor: pointer;
    accent-color: #C41E3A;
  }

  .checkbox-label {
    flex: 1;
    font-size: 13px;
    color: #4a5568;
    line-height: 1.5;
    cursor: pointer;
    margin: 0;
    font-weight: 400;
  }

  .checkbox-label a {
    color: #C41E3A;
    text-decoration: underline;
  }

  .btn-primary {
    padding: 12px 16px;
    background: linear-gradient(135deg, #C41E3A 0%, #C41E3A 100%);
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
    margin-top: 16px;
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

  .divider {
    text-align: center;
    color: #a0aec0;
    margin: 20px 0;
    font-size: 13px;
    font-weight: 600;
  }

  .login-link {
    text-align: center;
  }

  .login-link a {
    color: #C41E3A;
    text-decoration: none;
    font-weight: 600;
    transition: color 0.3s ease;
  }

  .login-link a:hover {
    color: #C41E3A;
    text-decoration: underline;
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
    margin-top: 20px;
  }

  .footer-text p {
    margin: 0;
  }

  /* Mobile Responsive */
  @media (max-width: 480px) {
    .signup-container {
      min-height: 100vh;
    }

    .signup-card {
      border-radius: 12px;
      padding: 20px 16px;
      margin: auto 0;
    }

    h1 {
      font-size: 24px;
    }

    input[type='text'],
    input[type='email'],
    input[type='password'],
    input[type='tel'],
    .btn-primary {
      font-size: 16px;
      padding: 14px 12px;
    }

    .signup-form {
      gap: 12px;
    }
  }

  /* Tablet/Desktop */
  @media (min-width: 768px) {
    .signup-card {
      padding: 48px;
    }

    h1 {
      font-size: 32px;
    }
  }
</style>
