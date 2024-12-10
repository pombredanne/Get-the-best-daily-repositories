import SwiftUI
import AppKit

@main
struct UnoApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var updater = UpdateChecker()
    @State private var showingUpdateSheet = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .background(WindowAccessor())
                .sheet(isPresented: $showingUpdateSheet) {
                    UpdateView(updater: updater)
                }
                .onAppear {
                    updater.checkForUpdates()
                    updater.onUpdateAvailable = {
                        showingUpdateSheet = true
                    }
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    showingUpdateSheet = true
                    updater.checkForUpdates()
                }
                .keyboardShortcut("U", modifiers: [.command])
                
                if updater.updateAvailable {
                    Button("Download Update") {
                        if let url = updater.downloadURL {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                
                Divider()
            }
        }
    }
}
