<script lang="ts">
  import { windowStore } from '../../stores/windowStore';
  import { authStore } from '../../stores/authStore';
</script>

<div class="taskbar">
  <div class="taskbar-windows">
    {#if $windowStore.length === 0}
      <span class="taskbar-empty">No windows open</span>
    {:else}
      {#each $windowStore as window (window.id)}
        <button 
          class="taskbar-item"
          on:click={() => {
            if (window.minimized) windowStore.minimize(window.id);
            windowStore.focus(window.id);
          }}
          title={window.title}
        >
          <span class="taskbar-title">{window.title}</span>
          <span 
            class="taskbar-close"
            on:click|stopPropagation={() => windowStore.close(window.id)}
            title="Close"
            role="button"
            tabindex="0"
          >
            ✕
          </span>
        </button>
      {/each}
    {/if}
  </div>
  <div class="taskbar-info">
    <span class="user-badge">{$authStore.user?.user_name || $authStore.user?.email}</span>
  </div>
</div>

<style>
  .taskbar {
    height: 48px;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-top: 1px solid #e2e8f0;
    box-shadow: 0 -2px 12px rgba(0, 0, 0, 0.05);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 24px;
    z-index: 50;
    gap: 12px;
    flex-shrink: 0;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
  }

  .taskbar-windows {
    display: flex;
    align-items: center;
    gap: 8px;
    flex: 1;
    overflow-x: auto;
    padding: 4px;
    min-height: 48px;
    min-width: 0;
  }

  .taskbar-empty {
    font-size: 13px;
    color: #9ca3af;
    font-style: italic;
  }

  .taskbar-windows::-webkit-scrollbar {
    height: 4px;
  }

  .taskbar-windows::-webkit-scrollbar-track {
    background: transparent;
  }

  .taskbar-windows::-webkit-scrollbar-thumb {
    background: rgba(196, 30, 58, 0.3);
    border-radius: 2px;
  }

  .taskbar-item {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    color: #334155;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
    flex-shrink: 0;
    white-space: nowrap;
  }

  .taskbar-item:hover {
    background: #f1f5f9;
    border-color: #C41E3A;
    color: #C41E3A;
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.2);
  }

  .taskbar-title {
    max-width: 150px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .taskbar-close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    padding: 0;
    background: transparent;
    border: none;
    color: #9ca3af;
    border-radius: 3px;
    cursor: pointer;
    font-size: 11px;
    transition: all 0.2s;
    flex-shrink: 0;
  }

  .taskbar-close:hover {
    background: rgba(196, 30, 58, 0.1);
    color: #C41E3A;
  }

  .taskbar-close:active {
    transform: scale(0.85);
  }

  .taskbar-info {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-shrink: 0;
  }

  .user-badge {
    font-size: 13px;
    font-weight: 600;
    color: #334155;
    padding: 6px 12px;
    background: #f1f5f9;
    border-radius: 6px;
    border: 1px solid #e2e8f0;
  }
</style>
