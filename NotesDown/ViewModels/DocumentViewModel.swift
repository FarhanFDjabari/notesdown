import Foundation
import Combine

@MainActor
class DocumentViewModel: ObservableObject {
    @Published var document: MarkdownDocument
    @Published var errorMessage: String?

    private let fileService: FileServiceProtocol
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
    ), fileService: FileServiceProtocol = FileService()) {
        self.document = document
        self.fileService = fileService
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

    func openFile(at url: URL) {
        Task {
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
            do {
                let url = try await fileService.saveFile(content: document.content, to: document.fileURL)
                document.fileURL = url
                document.isModified = false
                errorMessage = nil
            } catch FileService.FileServiceError.userCancelled {
                // User cancelled, do nothing
            } catch {
                errorMessage = "Failed to save file: \(error.localizedDescription)"
            }
        }
    }
}
