import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  base: '/',
  build: {
    // Optimize chunk splitting for better module loading
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          if (id.includes('html5-qrcode') || id.includes('qrcode')) {
            return 'qrcode';
          }
        },
      },
    },
    // Ensure smaller chunks don't cause issues
    chunkSizeWarningLimit: 1000,
  },
  plugins: [
    svelte(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['logo.jpeg'],
      manifest: {
        name: 'CarWhizz',
        short_name: 'CarWhizz',
        description: 'Smart car management and authorization system',
        theme_color: '#F97316',
        background_color: '#ffffff',
        display: 'standalone',
        start_url: '/',
        scope: '/',
        icons: [
          {
            src: '/logo.jpeg',
            sizes: 'any',
            type: 'image/jpeg',
            purpose: 'any',
          },
          {
            src: '/logo.jpeg',
            sizes: 'any',
            type: 'image/jpeg',
            purpose: 'maskable',
          },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,ico,jpeg,jpg,woff,woff2}'],
        globIgnores: ['**/node_modules/**/*', '**/.*/**/*'],
        cleanupOutdatedCaches: true,
        navigateFallback: '/index.html',
        navigateFallbackAllowlist: [/^(?!\/__)/],
        // Runtime caching for dynamic imports
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-cache',
              expiration: { maxEntries: 20 },
            },
          },
          {
            urlPattern: /^https:\/\/fonts\.gstatic\.com\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'gstatic-fonts-cache',
              expiration: { maxEntries: 20 },
            },
          },
          {
            // Cache assets (including dynamic chunks)
            urlPattern: /\/assets\/.+\.(js|css)$/,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'assets-cache',
              expiration: { maxEntries: 60 },
              networkTimeoutSeconds: 3,
            },
          },
        ],
      },
      devOptions: {
        enabled: true,
      },
    }),
  ],
})
