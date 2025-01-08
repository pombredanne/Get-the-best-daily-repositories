import { BrowserWindow, ipcMain } from "electron";
import { ipcMainHandle, ipcMainOn, isDev } from "../util.js";
import { getStaticData } from "../resourceManager.js";

export function setupIpcHandlers(mainWindow: BrowserWindow) {
  ipcMain.on("resetAppState", (event) => {
    event.reply("stateResetComplete");
  });

  ipcMainHandle("getStaticData", async () => await getStaticData());

  ipcMainOn("resizeWindow", ({ width, height }) => {
    if (mainWindow) {
      mainWindow.setSize(width, height);
    }
  });

  ipcMainOn("openDevTools", () => {
    if (isDev()) {
      mainWindow.webContents.openDevTools();
    }
  });

  ipcMainOn("frameWindowAction", (payload) => {
    switch (payload) {
      case "close":
        mainWindow.close();
        break;
      case "minimize":
        mainWindow.minimize();
        break;
      case "maximize":
        mainWindow.maximize();
        break;
      case "unmaximize":
        mainWindow.unmaximize();
        break;
    }
  });
}
