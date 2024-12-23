import { defineConfig } from 'rollup';

import { swc, defineRollupSwcOption } from 'rollup-plugin-swc3';
import commonjs from '@rollup/plugin-commonjs';
import metablock from 'rollup-plugin-userscript-metablock';
import { nodeResolve } from '@rollup/plugin-node-resolve';
import replace from '@rollup/plugin-replace';

import pkgJson from './package.json';
import process from 'node:process';

const userScriptMetaBlockConfig = {
  file: './userscript.meta.json',
  override: {
    version: pkgJson.version,
    description: pkgJson.description,
    author: pkgJson.author
  }
};

export default defineConfig([
  {
    input: 'src/index.ts',
    output: [{
      format: 'iife',
      file: 'dist/make-bilibili-great-than-ever-before.user.js',
      sourcemap: false,
      esModule: false,
      compact: true,
      generatedCode: 'es2015'
    }],
    plugins: [
      swc(defineRollupSwcOption({
        jsc: {
          target: 'es2022',
          externalHelpers: true
        }
      })),
      commonjs({
        sourceMap: false,
        esmExternals: true
      }),
      nodeResolve({
        exportConditions: ['import', 'require', 'default']
      }),
      replace({
        preventAssignment: true,
        values: {
          'process.env.NODE_ENV': JSON.stringify('production'),
          'typeof window': JSON.stringify('object'),
          globalThis: 'unsafeWindow'
        }
      }),
      metablock(userScriptMetaBlockConfig)
    ],
    watch: process.env.WATCH
      ? {}
      : false,
    external: ['typed-query-selector']
  },
  {
    input: 'src/dummy.js',
    output: [{
      file: 'dist/make-bilibili-great-than-ever-before.meta.js'
    }],
    plugins: [
      metablock(userScriptMetaBlockConfig)
    ]
  }
]);
