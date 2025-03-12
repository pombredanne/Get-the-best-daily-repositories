# vite-plugin-mcp

[![npm version][npm-version-src]][npm-version-href]
[![npm downloads][npm-downloads-src]][npm-downloads-href]
[![bundle][bundle-src]][bundle-href]
[![JSDocs][jsdocs-src]][jsdocs-href]
[![License][license-src]][license-href]

Vite plugin that enables a MCP server for your Vite app to provide information about your setup and modules graphs.

> [!IMPORTANT]
> Experimental. Not ready for production.

```ts
import { defineConfig } from 'vite'
import { ViteMcp } from 'vite-plugin-mcp'

export default defineConfig({
  plugins: [
    ViteMcp()
  ],
})
```

Then the MCP server will be available at `http://localhost:5173/__mcp/sse`.

If you are using Cursor, create a `.cursor/mcp.json` file in your project root, this plugin will automatically update it for you.

## Sponsors

<p align="center">
  <a href="https://cdn.jsdelivr.net/gh/antfu/static/sponsors.svg">
    <img src='https://cdn.jsdelivr.net/gh/antfu/static/sponsors.svg'/>
  </a>
</p>

## License

[MIT](./LICENSE) License © [Anthony Fu](https://github.com/antfu)

<!-- Badges -->

[npm-version-src]: https://img.shields.io/npm/v/vite-plugin-mcp?style=flat&colorA=080f12&colorB=1fa669
[npm-version-href]: https://npmjs.com/package/vite-plugin-mcp
[npm-downloads-src]: https://img.shields.io/npm/dm/vite-plugin-mcp?style=flat&colorA=080f12&colorB=1fa669
[npm-downloads-href]: https://npmjs.com/package/vite-plugin-mcp
[bundle-src]: https://img.shields.io/bundlephobia/minzip/vite-plugin-mcp?style=flat&colorA=080f12&colorB=1fa669&label=minzip
[bundle-href]: https://bundlephobia.com/result?p=vite-plugin-mcp
[license-src]: https://img.shields.io/github/license/antfu/vite-plugin-mcp.svg?style=flat&colorA=080f12&colorB=1fa669
[license-href]: https://github.com/antfu/vite-plugin-mcp/blob/main/LICENSE
[jsdocs-src]: https://img.shields.io/badge/jsdocs-reference-080f12?style=flat&colorA=080f12&colorB=1fa669
[jsdocs-href]: https://www.jsdocs.io/package/vite-plugin-mcp
