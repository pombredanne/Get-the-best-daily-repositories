import { fileURLToPath } from 'node:url'
// import { svelte as Svelte } from '@sveltejs/vite-plugin-svelte'
import React from '@vitejs/plugin-react'
import Vue from '@vitejs/plugin-vue'
import UnoCSS from 'unocss/vite'
import { defineConfig } from 'vite'
// import Solid from 'vite-plugin-solid'

export default defineConfig({
  resolve: {
    alias: {
      'shiki-stream/vue': fileURLToPath(new URL('../src/vue/index.ts', import.meta.url)),
      'shiki-stream/react': fileURLToPath(new URL('../src/react/index.ts', import.meta.url)),
      'shiki-stream': fileURLToPath(new URL('../src/index.ts', import.meta.url)),
    },
  },
  plugins: [
    Vue(),
    UnoCSS(),
    // Svelte(),
    // Solid({ include: ['src/renderer/solid.tsx', '../src/solid/**'] }),
    React({ include: ['src/renderer/react.tsx', '../src/react/**'] }),
  ],
})
