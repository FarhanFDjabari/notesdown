import SwiftUI
import AppKit

@main
struct NotesDownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup(for: URL?.self) { $url in
            ContentView(fileURL: url ?? nil)
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

/// Routes open-document requests to windows.
///
/// The app declares a single value-based `WindowGroup`. For an open-document
/// event macOS/SwiftUI opens a fresh *empty* window per file (the launch window
/// at cold start, new empty windows while already running) but never binds the
/// opened file to it — the file arrives only via `AppDelegate.application(_:open:)`.
///
/// So this type loads each pending file into a fresh empty window as it
/// registers, then closes any pre-existing pristine "welcome" window so a
/// single window shows the file instead of leaving an empty one beside it.
@MainActor
final class WindowManager: ObservableObject {
    private struct WindowInfo {
        weak var window: NSWindow?
        let isPristine: () -> Bool
        let load: (URL) -> Void
    }

    private var windows: [ObjectIdentifier: WindowInfo] = [:]
    private var pending: [URL] = []
    private var preExistingWelcomeIDs: Set<ObjectIdentifier> = []
    private var consumedIDs: Set<ObjectIdentifier> = []

    func registerWindow(_ window: NSWindow, isPristine: @escaping () -> Bool, load: @escaping (URL) -> Void) {
        let id = ObjectIdentifier(window)
        windows[id] = WindowInfo(window: window, isPristine: isPristine, load: load)
        consume(into: id)
    }

    func unregisterWindow(_ window: NSWindow) {
        windows.removeValue(forKey: ObjectIdentifier(window))
    }

    func open(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if pending.isEmpty {
            preExistingWelcomeIDs = Set(
                windows.compactMap { id, info in
                    (info.window != nil && info.isPristine()) ? id : nil
                }
            )
        }
        pending.append(contentsOf: urls)

        // A window that registered before this event but is not a stale welcome
        // we intend to close is a valid target too. Otherwise we wait for the
        // empty window SwiftUI opens for this open-document event.
        for id in windows.keys where !preExistingWelcomeIDs.contains(id) {
            consume(into: id)
        }
    }

    private func consume(into id: ObjectIdentifier) {
        guard !pending.isEmpty,
              !consumedIDs.contains(id),
              !preExistingWelcomeIDs.contains(id),
              let info = windows[id],
              let window = info.window,
              info.isPristine()
        else { return }

        consumedIDs.insert(id)
        info.load(pending.removeFirst())
        window.makeKeyAndOrderFront(nil)

        if pending.isEmpty {
            finishOpenBatch()
        }
    }

    private func finishOpenBatch() {
        for id in preExistingWelcomeIDs {
            guard let info = windows[id], let window = info.window, info.isPristine() else { continue }
            window.close()
        }
        preExistingWelcomeIDs.removeAll()
        consumedIDs.removeAll()
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = WindowManager()

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        windowManager.open(urls)
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
                openWindow(value: nil as URL?)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Tab") {
                openNewTab()
            }
            .keyboardShortcut("t", modifiers: .command)

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

    private func openNewTab() {
        NSApp.keyWindow?.newWindowForTab(nil)
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
