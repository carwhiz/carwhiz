<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import QRCode from 'qrcode';
  import { authStore } from '../../../stores/authStore';

  let qrDataUrl: string = '';
  let qrGeneratedAt: Date = new Date();
  let refreshInterval: any;

  onMount(async () => {
    generateQR();
    // Regenerate QR code every 10 seconds for security
    refreshInterval = setInterval(generateQR, 10000);
  });

  onDestroy(() => {
    if (refreshInterval) clearInterval(refreshInterval);
  });

  async function generateQR() {
    try {
      const token = `${$authStore.user?.id}|${new Date().getTime()}`;
      qrDataUrl = await QRCode.toDataURL(token, {
        width: 250,
        margin: 2,
        color: { dark: '#111827', light: '#ffffff' }
      });
      qrGeneratedAt = new Date();
    } catch (err) {
      console.error('Error generating QR code:', err);
    }
  }
</script>

<div class="attendance-qr">
  <div class="qr-container">
    <h2>Attendance QR Code</h2>
    <p class="instructions">Scan this QR code on your mobile device to mark your attendance</p>

    {#if qrDataUrl}
      <div class="qr-display">
        <img src={qrDataUrl} alt="Attendance QR Code" class="qr-code" />
        <p class="refresh-time">
          Last refreshed: {qrGeneratedAt.toLocaleTimeString()}
        </p>
      </div>
    {:else}
      <div class="loading">Generating QR code...</div>
    {/if}

    <button class="btn-refresh" on:click={generateQR}>
      Refresh QR Code
    </button>

    <div class="info">
      <p>
        <strong>Employee ID:</strong> {$authStore.user?.email}
      </p>
      <p class="note">QR codes refresh every 10 seconds for security</p>
    </div>
  </div>
</div>

<style>
  .attendance-qr {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 20px;
    background: #fff;
    overflow-y: auto;
  }

  .qr-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 20px;
    flex: 1;
  }

  h2 {
    margin: 0;
    font-size: 18px;
    color: #111827;
  }

  .instructions {
    font-size: 13px;
    color: #6b7280;
    margin: 0;
    text-align: center;
    max-width: 300px;
  }

  .qr-display {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    padding: 20px;
    background: #f9fafb;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
  }

  .qr-code {
    width: 250px;
    height: 250px;
    border-radius: 8px;
  }

  .refresh-time {
    font-size: 12px;
    color: #9ca3af;
    margin: 0;
  }

  .loading {
    color: #9ca3af;
    font-size: 13px;
  }

  .btn-refresh {
    padding: 10px 20px;
    background-color: #C41E3A;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .btn-refresh:hover {
    background-color: #a01830;
  }

  .info {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px;
    background: #f0f9ff;
    border: 1px solid #bfdbfe;
    border-radius: 6px;
    text-align: center;
  }

  .info p {
    margin: 0;
    font-size: 13px;
    color: #1e40af;
  }

  .note {
    color: #0c4a6e;
    font-size: 12px !important;
  }
</style>
