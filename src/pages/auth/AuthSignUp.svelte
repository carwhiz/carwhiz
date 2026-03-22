<script lang="ts">
  import { navigateTo } from '../../routes';

  function goToLogin() {
    navigateTo('login');
  }
</script>

<div class="auth-page signup-page">
  <div class="auth-container">
    <div class="auth-box">
      <div class="signup-info">
        <div class="info-box">
          <h2>Welcome to CarWhizz</h2>
          <p>CarWhizz is an invitation-only platform for automotive business management.</p>
          
          <div class="steps">
            <div class="step">
              <div class="step-number">1</div>
              <div class="step-content">
                <h3>Request Access</h3>
                <p>Contact your organization's administrator to request an account.</p>
              </div>
            </div>
            
            <div class="step">
              <div class="step-number">2</div>
              <div class="step-content">
                <h3>Get Access Code</h3>
                <p>The administrator will provide you with a unique 6-digit access code.</p>
              </div>
            </div>
            
            <div class="step">
              <div class="step-number">3</div>
              <div class="step-content">
                <h3>Login</h3>
                <p>Use your 6-digit code to login to CarWhizz.</p>
              </div>
            </div>
          </div>

          <div class="contact-section">
            <h3>Need Help?</h3>
            <p>Contact your organization's administrator for an access code.</p>
          </div>
        </div>
      </div>

      <button 
        type="button"
        class="btn btn-primary"
        on:click={goToLogin}
      >
        Have an Access Code? Login
      </button>

      <div class="auth-footer">
        <p>Already have an access code?</p>
        <button type="button" class="link-btn" on:click={goToLogin}>
          Go to Login →
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
    max-width: 500px;
    padding: 1rem;
  }

  .auth-box {
    background: white;
    border-radius: 8px;
    padding: 2rem;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
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

  .signup-info {
    margin-bottom: 2rem;
  }

  .info-box {
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 1.5rem;
  }

  .info-box h2 {
    margin: 0 0 0.5rem 0;
    font-size: 1.25rem;
    color: #1f2937;
  }

  .info-box p {
    margin: 0 0 1.5rem 0;
    font-size: 0.9rem;
    color: #6b7280;
    line-height: 1.5;
  }

  .steps {
    margin: 1.5rem 0;
  }

  .step {
    display: flex;
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .step-number {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: #f97316;
    color: white;
    border-radius: 50%;
    font-weight: 700;
    flex-shrink: 0;
  }

  .step-content h3 {
    margin: 0 0 0.25rem 0;
    font-size: 0.95rem;
    color: #1f2937;
  }

  .step-content p {
    margin: 0;
    font-size: 0.8rem;
    color: #6b7280;
  }

  .contact-section {
    margin-top: 1.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid #e5e7eb;
  }

  .contact-section h3 {
    margin: 0 0 0.5rem 0;
    font-size: 0.9rem;
    font-weight: 600;
    color: #1f2937;
  }

  .contact-section p {
    margin: 0;
    font-size: 0.8rem;
    color: #6b7280;
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
    font-size: 0.9rem;
    color: #6b7280;
  }

  .link-btn {
    background: none;
    border: none;
    color: #f97316;
    cursor: pointer;
    font-weight: 600;
    text-decoration: none;
    padding: 0;
    margin: 0 0.25rem;
  }

  .link-btn:hover {
    text-decoration: underline;
  }
</style>
