import SwiftUI

struct ContentView: View {
    let fileURL: URL?

    @StateObject private var documentViewModel = DocumentViewModel()
    @StateObject private var scrollSync = ScrollSyncController()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var windowManager: WindowManager
    @Environment(\.openWindow) private var openWindow
    @State private var didOpenInitialFile = false

    init(fileURL: URL? = nil) {
        // Only real files are loaded; the sentinel URL used to open empty
        // windows/tabs is not a file URL and is treated as an empty document.
        self.fileURL = (fileURL?.isFileURL == true) ? fileURL : nil
    }

    var body: some View {
        HSplitView {
            MarkdownEditorView(text: $documentViewModel.markdownText, scrollSync: scrollSync)
                .frame(minWidth: 300)
                .accessibilityIdentifier("markdown-editor-pane")

            MarkdownPreviewView(markdownText: documentViewModel.markdownText, scrollSync: scrollSync)
                .frame(minWidth: 300)
                .accessibilityIdentifier("markdown-preview-pane")
        }
        .navigationTitle(documentViewModel.document.fileName)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    documentViewModel.openFile()
                }) {
                    Label("Open", systemImage: "folder")
                }

                Button(action: {
                    documentViewModel.saveFile()
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Spacer()

                Button(action: {
                    themeManager.toggleTheme()
                }) {
                    Label(
                        themeManager.isDarkMode ? "Light Mode" : "Dark Mode",
                        systemImage: themeManager.isDarkMode ? "sun.max" : "moon"
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            documentViewModel.openFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileInNewWindow)) { _ in
            chooseFilesForNewWindows()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            documentViewModel.saveFile()
        }
        .focusedSceneValue(\.documentCommandHandlers, DocumentCommandHandlers(
            openFile: {
                documentViewModel.openFile()
            },
            openFilesInNewWindows: {
                chooseFilesForNewWindows()
            },
            saveFile: {
                documentViewModel.saveFile()
            }
        ))
        .onAppear {
            if !didOpenInitialFile, let fileURL {
                didOpenInitialFile = true
                documentViewModel.openFile(at: fileURL)
            }
        }
        .alert("Error", isPresented: .constant(documentViewModel.errorMessage != nil)) {
            Button("OK") {
                documentViewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = documentViewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .background(
            WindowCloseGuard(
                documentViewModel: documentViewModel,
                windowManager: windowManager
            )
        )
    }

    private func chooseFilesForNewWindows() {
        Task {
            do {
                let urls = try await documentViewModel.chooseFilesForNewWindows()
                for url in urls {
                    openWindow(value: url as URL?)
                }
            } catch FileService.FileServiceError.userCancelled {
                // User cancelled, do nothing
            } catch {
                documentViewModel.errorMessage = "Failed to open files: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}

private struct WindowCloseGuard: NSViewRepresentable {
    @ObservedObject var documentViewModel: DocumentViewModel
    let windowManager: WindowManager

    func makeCoordinator() -> Coordinator {
        Coordinator(documentViewModel: documentViewModel, windowManager: windowManager)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.documentViewModel = documentViewModel
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        var documentViewModel: DocumentViewModel
        private let windowManager: WindowManager

        private weak var window: NSWindow?
        private weak var previousDelegate: NSWindowDelegate?
        private var isClosingAfterConfirmation = false

        init(documentViewModel: DocumentViewModel, windowManager: WindowManager) {
            self.documentViewModel = documentViewModel
            self.windowManager = windowManager
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }

            detach()

            self.window = window
            previousDelegate = window.delegate
            window.delegate = self

            let documentViewModel = documentViewModel
            windowManager.registerWindow(
                window,
                isPristine: { documentViewModel.document.isPristine },
                load: { url in documentViewModel.openFile(at: url) }
            )
        }

        func detach() {
            guard let window else { return }
            windowManager.unregisterWindow(window)
            if window.delegate === self {
                window.delegate = previousDelegate
            }
            self.window = nil
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if isClosingAfterConfirmation || !documentViewModel.document.isModified {
                return previousDelegate?.windowShouldClose?(sender) ?? true
            }

            Task { @MainActor in
                guard await documentViewModel.confirmDestructiveChangeAndSaveIfNeeded() else { return }

                isClosingAfterConfirmation = true
                sender.performClose(nil)
                isClosingAfterConfirmation = false
            }

            return false
        }

        func windowWillClose(_ notification: Notification) {
            if let window {
                windowManager.unregisterWindow(window)
            }
            previousDelegate?.windowWillClose?(notification)
        }
    }
}
