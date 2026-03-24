<script lang="ts">
  // Simple content wrapper - header is managed by MobileLayout
</script>

<div class="mobile-page-content">
  <slot />
</div>

<style>
  .mobile-page-content {
    background: var(--neutral-50);
    width: 100%;
    height: 100%;
  }
</style>

