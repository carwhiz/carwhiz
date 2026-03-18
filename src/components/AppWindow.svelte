<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { windowStore, type AppWindow } from '../stores/windowStore';

  export let win: AppWindow;

  const dispatch = createEventDispatcher();
  let refreshKey = 0;
  let dragging = false;
  let dragOffsetX = 0;
  let dragOffsetY = 0;

  function onMouseDownTitlebar(e: MouseEvent) {
    if (win.maximized) return;
    dragging = true;
    dragOffsetX = e.clientX - win.x;
    dragOffsetY = e.clientY - win.y;
    windowStore.focus(win.id);
    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);
  }

  function onMouseMove(e: MouseEvent) {
    if (!dragging) return;
    const newX = Math.max(0, e.clientX - dragOffsetX);
    const newY = Math.max(0, e.clientY - dragOffsetY);
    windowStore.move(win.id, newX, newY);
  }

  function onMouseUp() {
    dragging = false;
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  }

  function handleFocus() {
    windowStore.focus(win.id);
  }

  function handleMinimize() {
    windowStore.minimize(win.id);
  }

  function handleMaximize() {
    windowStore.maximize(win.id);
  }

  function handleClose() {
    windowStore.close(win.id);
  }

  function handleRefresh() {
    refreshKey++;
  }
</script>

{#if !win.minimized}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="app-window"
    class:maximized={win.maximized}
    style={win.maximized
      ? `z-index: ${win.zIndex};`
      : `left: ${win.x}px; top: ${win.y}px; width: ${win.width}px; height: ${win.height}px; z-index: ${win.zIndex};`}
    on:mousedown={handleFocus}
  >
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="window-titlebar" on:mousedown={onMouseDownTitlebar}>
      <span class="window-title">{win.title}</span>
      <div class="window-controls">
        <button class="win-btn refresh-btn" on:click|stopPropagation={handleRefresh} title="Refresh">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 4v6h-6"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
        </button>
        <button class="win-btn minimize-btn" on:click|stopPropagation={handleMinimize} title="Minimize">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"/></svg>
        </button>
        <button class="win-btn maximize-btn" on:click|stopPropagation={handleMaximize} title={win.maximized ? 'Restore' : 'Maximize'}>
          {#if win.maximized}
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="7" width="12" height="12" rx="1"/><path d="M7 7V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2"/></svg>
          {:else}
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/></svg>
          {/if}
        </button>
        <button class="win-btn close-btn" on:click|stopPropagation={handleClose} title="Close">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
      </div>
    </div>

    <div class="window-body">
      {#key refreshKey}
        <slot />
      {/key}
    </div>
  </div>
{/if}

<style>
  .app-window {
    position: absolute;
    background: white;
    border-radius: 10px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.18), 0 2px 8px rgba(0, 0, 0, 0.08);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 320px;
    min-height: 200px;
  }

  .app-window.maximized {
    position: fixed;
    top: 0;
    left: 170px;
    right: 0;
    bottom: 48px;
    width: auto;
    height: auto;
    border-radius: 0;
  }

  .window-titlebar {
    height: 38px;
    background: linear-gradient(135deg, #FB923C 0%, #EA580C 100%);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 8px 0 14px;
    cursor: grab;
    user-select: none;
    flex-shrink: 0;
  }

  .window-titlebar:active {
    cursor: grabbing;
  }

  .window-title {
    color: white;
    font-size: 13px;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .window-controls {
    display: flex;
    gap: 4px;
    align-items: center;
  }

  .win-btn {
    width: 28px;
    height: 28px;
    border: none;
    border-radius: 6px;
    background: rgba(255, 255, 255, 0.15);
    color: white;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 5px;
    transition: background 0.15s;
  }

  .win-btn:hover {
    background: rgba(255, 255, 255, 0.3);
  }

  .close-btn:hover {
    background: #dc2626;
  }

  .win-btn svg {
    width: 14px;
    height: 14px;
  }

  .window-body {
    flex: 1;
    overflow: auto;
    background: #fafafa;
  }
</style>
