import SwiftUI
import AppKit

@main
struct NotesDownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .environmentObject(appDelegate.windowManager)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "main"))
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}

class WindowManager: ObservableObject {
    @Published var fileToOpen: URL?
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = WindowManager()
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        windowManager.fileToOpen = url

        let visibleWindow = application.windows.first {
            $0.isVisible &&
            !$0.isMiniaturized &&
            $0.canBecomeKey
        }

        if let window = visibleWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let minimizedWindow = application.windows.first { $0.isMiniaturized }

            if let window = minimizedWindow {
                window.deminiaturize(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                let bundleURL = Bundle.main.bundleURL
                NSWorkspace.shared.openApplication(at: bundleURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }
    
    // Handle the case when app should reopen (e.g., clicking dock icon when no windows are visible)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows, check if we have any windows at all
            if !sender.windows.isEmpty {
                if let window = sender.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            return true
        }
        return false
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let openFileURL = Notification.Name("openFileURL")
    static let saveFile = Notification.Name("saveFile")
}
