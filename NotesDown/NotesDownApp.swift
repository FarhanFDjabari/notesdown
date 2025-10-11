import SwiftUI
import AppKit

@main
struct NotesDownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(initialURL: appDelegate.windowManager.pendingURL)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .environmentObject(appDelegate.windowManager)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    openNewWindow(with: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }

    private func openNewWindow(with url: URL?) {
        NotificationCenter.default.post(name: .openFile, object: nil)
    }
}

class WindowManager: ObservableObject {
    @Published var pendingURL: URL?
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = WindowManager()

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        windowManager.pendingURL = url

        if NSApplication.shared.windows.isEmpty {
            return
        }

        openNewWindowWithURL(url)
    }

    private func openNewWindowWithURL(_ url: URL) {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        let contentView = ContentView(initialURL: url)
            .environmentObject(ThemeManager())

        newWindow.contentView = NSHostingView(rootView: contentView)
        newWindow.makeKeyAndOrderFront(nil)
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let openFileURL = Notification.Name("openFileURL")
    static let saveFile = Notification.Name("saveFile")
}
