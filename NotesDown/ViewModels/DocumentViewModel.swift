import Foundation
import Combine
import AppKit

enum UnsavedChangesDecision {
    case save
    case discard
    case cancel
}

@MainActor
protocol UnsavedChangesPrompting {
    func confirmDestructiveChange(fileName: String) async -> UnsavedChangesDecision
}

struct AppKitUnsavedChangesPrompter: UnsavedChangesPrompting {
    func confirmDestructiveChange(fileName: String) async -> UnsavedChangesDecision {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to save changes to \(fileName)?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .save
        case .alertSecondButtonReturn:
            return .discard
        default:
            return .cancel
        }
    }
}

@MainActor
class DocumentViewModel: ObservableObject {
    @Published var document: MarkdownDocument
    @Published var errorMessage: String?

    private let fileService: FileServiceProtocol
    private let unsavedChangesPrompter: UnsavedChangesPrompting
    private var cancellables = Set<AnyCancellable>()

    init(document: MarkdownDocument = MarkdownDocument(
        content: """
        # Welcome to NotesDown

        Start editing your markdown document here...

        ## Features

        - **Live Preview**: See your markdown rendered in real-time
        - **Simple Editing**: Easy-to-use text editor
        - **Light/Dark Mode**: Toggle between themes
        - **File Operations**: Open and save markdown files
        - **Offline**: Works completely offline

        ## Example

        You can create:

        1. Headers
        2. Lists
        3. **Bold** and *italic* text
        4. `Code blocks`
        5. And much more!

        ```swift
        let greeting = "Hello, NotesDown!"
        print(greeting)
        ```

        Enjoy writing in markdown!
        """
    ),
    fileService: FileServiceProtocol = FileService(),
    unsavedChangesPrompter: UnsavedChangesPrompting? = nil
    ) {
        self.document = document
        self.fileService = fileService
        self.unsavedChangesPrompter = unsavedChangesPrompter ?? AppKitUnsavedChangesPrompter()
    }

    var markdownText: String {
        get { document.content }
        set {
            document.content = newValue
            document.isModified = true
        }
    }

    func openFile() {
        Task {
            guard await confirmDestructiveChangeAndSaveIfNeeded() else { return }

            do {
                let (content, url) = try await fileService.openFile()
                document = MarkdownDocument(content: content, fileURL: url, isModified: false)
                errorMessage = nil
            } catch FileService.FileServiceError.userCancelled {
                // User cancelled, do nothing
            } catch {
                errorMessage = "Failed to open file: \(error.localizedDescription)"
            }
        }
    }

    func chooseFilesForNewWindows() async throws -> [URL] {
        try await fileService.openFiles()
    }

    func openFile(at url: URL) {
        Task {
            guard await confirmDestructiveChangeAndSaveIfNeeded() else { return }

            do {
                // Start accessing security-scoped resource
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let content = try String(contentsOf: url, encoding: .utf8)
                document = MarkdownDocument(content: content, fileURL: url, isModified: false)
                errorMessage = nil
            } catch {
                errorMessage = "Failed to open file: \(error.localizedDescription)"
            }
        }
    }

    func saveFile() {
        Task {
            await saveCurrentDocument()
        }
    }

    @discardableResult
    func confirmDestructiveChangeAndSaveIfNeeded() async -> Bool {
        guard document.isModified else { return true }

        switch await unsavedChangesPrompter.confirmDestructiveChange(fileName: document.fileName) {
        case .save:
            return await saveCurrentDocument()
        case .discard:
            return true
        case .cancel:
            return false
        }
    }

    @discardableResult
    private func saveCurrentDocument() async -> Bool {
        do {
            let url = try await fileService.saveFile(content: document.content, to: document.fileURL)
            document.fileURL = url
            document.isModified = false
            errorMessage = nil
            return true
        } catch FileService.FileServiceError.userCancelled {
            // User cancelled, do nothing
            return false
        } catch {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            return false
        }
    }
}
