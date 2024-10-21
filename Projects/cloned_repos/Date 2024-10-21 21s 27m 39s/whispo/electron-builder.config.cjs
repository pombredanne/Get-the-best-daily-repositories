// @ts-check

/** @type {import('electron-builder').Configuration} */
module.exports = {
  appId: "app.whispo",
  productName: "Whispo",
  directories: {
    buildResources: "build",
  },
  files: [
    "!**/.vscode/*",
    "!src/*",
    "!scripts/*",
    "!electron.vite.config.{js,ts,mjs,cjs}",
    "!{.eslintignore,.eslintrc.cjs,.prettierignore,.prettierrc.yaml,dev-app-update.yml,CHANGELOG.md,README.md}",
    "!{.env,.env.*,.npmrc,pnpm-lock.yaml}",
    "!{tsconfig.json,tsconfig.node.json,tsconfig.web.json}",
    "!*.{js,cjs,mjs,ts}",
    "!components.json",
    "!.prettierrc",
  ],
  asarUnpack: ["resources/**", "node_modules/**"],
  win: {
    executableName: "whispo",
  },
  nsis: {
    artifactName: "${name}-${version}-setup.${ext}",
    shortcutName: "${productName}",
    uninstallDisplayName: "${productName}",
    createDesktopShortcut: "always",
  },
  mac: {
    artifactName: "${productName}-${version}-${arch}.${ext}",
    entitlementsInherit: "build/entitlements.mac.plist",
    extendInfo: [
      {
        NSCameraUsageDescription:
          "Application requests access to the device's camera.",
      },
      {
        NSMicrophoneUsageDescription:
          "Application requests access to the device's microphone.",
      },
      {
        NSDocumentsFolderUsageDescription:
          "Application requests access to the user's Documents folder.",
      },
      {
        NSDownloadsFolderUsageDescription:
          "Application requests access to the user's Downloads folder.",
      },
    ],
    notarize: process.env.APPLE_TEAM_ID
      ? {
          teamId: process.env.APPLE_TEAM_ID,
        }
      : undefined,
  },
  dmg: {
    artifactName: "${productName}-${version}-${arch}.${ext}",
  },
  linux: {
    target: ["AppImage", "snap", "deb"],
    maintainer: "electronjs.org",
    category: "Utility",
  },
  appImage: {
    artifactName: "${name}-${version}.${ext}",
  },
  npmRebuild: false,
  publish: {
    provider: "github",
    owner: "egoist",
    repo: "whispo",
  },
  removePackageScripts: true,
}
