import SwiftUI
import Shared

@main
struct MacNTFSApp: App {
    // Keep the daemon alive during the app lifecycle
    @State private var diskMonitor = DiskMonitorDaemon.shared
    
    init() {
        // Start the DiskArbitration listener
        diskMonitor.start()
    }
    
    var body: some Scene {
        // The Menubar Extra (Status bar item)
        MenuBarExtra("MacNTFS", systemImage: "externaldrive.badge.exclamationmark") {
            MenuBarView()
        }
        
        // The main Settings window
        WindowGroup("MacNTFS Settings") {
            SettingsView()
        }
    }
}

// A simple preview of the MenuBar content
struct MenuBarView: View {
    var body: some View {
        VStack {
            Text("MacNTFS")
                .font(.headline)
            Divider()
            
            Button("Preferences...") {
                // macOS 13+ standard way to bring forward the App Window
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "MacNTFS Settings" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
