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

        WindowGroup("Markdown Document", for: URL.self) { fileURL in
            ContentView(initialFileURL: fileURL.wrappedValue)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .environmentObject(appDelegate.windowManager)
        }
        .windowResizability(.contentSize)
        .commands {
            NotesDownCommands()
        }
    }
}

class WindowManager: ObservableObject {
    @Published var filesToOpenInNewWindows: [URL] = []

    func openInNewWindows(_ urls: [URL]) {
        filesToOpenInNewWindows.append(contentsOf: urls)
    }

    @MainActor
    func consumeFilesToOpenInNewWindows() -> [URL] {
        let urls = filesToOpenInNewWindows
        filesToOpenInNewWindows.removeAll()
        return urls
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = WindowManager()
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        windowManager.openInNewWindows(urls)

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
    static let openFileInNewWindow = Notification.Name("openFileInNewWindow")
    static let openFileURL = Notification.Name("openFileURL")
    static let saveFile = Notification.Name("saveFile")
}

struct NotesDownCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.documentCommandHandlers) private var documentCommandHandlers

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Open...") {
                documentCommandHandlers?.openFile()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(documentCommandHandlers == nil)

            Button("Open in New Window...") {
                documentCommandHandlers?.openFilesInNewWindows()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(documentCommandHandlers == nil)

            Divider()

            Button("Save") {
                documentCommandHandlers?.saveFile()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(documentCommandHandlers == nil)
        }
    }
}

struct DocumentCommandHandlers {
    let openFile: () -> Void
    let openFilesInNewWindows: () -> Void
    let saveFile: () -> Void
}

private struct DocumentCommandHandlersKey: FocusedValueKey {
    typealias Value = DocumentCommandHandlers
}

extension FocusedValues {
    var documentCommandHandlers: DocumentCommandHandlers? {
        get { self[DocumentCommandHandlersKey.self] }
        set { self[DocumentCommandHandlersKey.self] = newValue }
    }
}
