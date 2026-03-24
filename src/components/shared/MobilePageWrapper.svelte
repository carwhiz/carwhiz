<script lang="ts">
  // Simple content wrapper - header is managed by MobileLayout
</script>

<div class="mobile-page-content">
  <slot />
</div>

<style>
  .mobile-page-content {
    padding: 1rem;
    overflow-y: auto;
    background: var(--neutral-50);
  }
</style>

