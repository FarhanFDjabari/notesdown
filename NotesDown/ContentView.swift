import SwiftUI

struct ContentView: View {
    let initialFileURL: URL?

    @StateObject private var documentViewModel = DocumentViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var windowManager: WindowManager
    @Environment(\.openWindow) private var openWindow
    @State private var didOpenInitialFile = false

    init(initialFileURL: URL? = nil) {
        self.initialFileURL = initialFileURL
    }

    var body: some View {
        HSplitView {
            MarkdownEditorView(text: $documentViewModel.markdownText)
                .frame(minWidth: 300)

            MarkdownPreviewView(markdownText: documentViewModel.markdownText)
                .frame(minWidth: 300)
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
            openInitialFileIfNeeded()
            openFilesInNewWindows(windowManager.consumeFilesToOpenInNewWindows())
        }
        .onChange(of: windowManager.filesToOpenInNewWindows) { _, _ in
            openFilesInNewWindows(windowManager.consumeFilesToOpenInNewWindows())
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
        .background(WindowCloseGuard(documentViewModel: documentViewModel))
    }

    private func openInitialFileIfNeeded() {
        guard !didOpenInitialFile, let initialFileURL else { return }
        didOpenInitialFile = true
        documentViewModel.openFile(at: initialFileURL)
    }

    private func openFilesInNewWindows(_ urls: [URL]) {
        for url in urls {
            openWindow(value: url)
        }
    }

    private func chooseFilesForNewWindows() {
        Task {
            do {
                let urls = try await documentViewModel.chooseFilesForNewWindows()
                openFilesInNewWindows(urls)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(documentViewModel: documentViewModel)
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

    final class Coordinator: NSObject, NSWindowDelegate {
        var documentViewModel: DocumentViewModel

        private weak var window: NSWindow?
        private weak var previousDelegate: NSWindowDelegate?
        private var isClosingAfterConfirmation = false

        init(documentViewModel: DocumentViewModel) {
            self.documentViewModel = documentViewModel
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }

            if self.window?.delegate === self {
                self.window?.delegate = previousDelegate
            }

            self.window = window
            previousDelegate = window.delegate
            window.delegate = self
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
            previousDelegate?.windowWillClose?(notification)
        }
    }
}
