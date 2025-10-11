import SwiftUI
import UniformTypeIdentifiers

class MarkdownFileManager: ObservableObject {
    @Published var markdownText: String = "# Welcome to NotesDown\n\nStart editing your markdown document here...\n\n## Features\n\n- **Live Preview**: See your markdown rendered in real-time\n- **Simple Editing**: Easy-to-use text editor\n- **Light/Dark Mode**: Toggle between themes\n- **File Operations**: Open and save markdown files\n- **Offline**: Works completely offline\n\n## Example\n\nYou can create:\n\n1. Headers\n2. Lists\n3. **Bold** and *italic* text\n4. `Code blocks`\n5. And much more!\n\n```swift\nlet greeting = \"Hello, NotesDown!\"\nprint(greeting)\n```\n\nEnjoy writing in markdown!"

    private var currentFileURL: URL?

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText]
        panel.message = "Select a markdown file to open"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                DispatchQueue.main.async {
                    self?.markdownText = content
                    self?.currentFileURL = url
                }
            } catch {
                print("Error reading file: \\(error.localizedDescription)")
                self?.showAlert(message: "Failed to open file: \\(error.localizedDescription)")
            }
        }
    }

    func saveFile() {
        if let url = currentFileURL {
            // Save to existing file
            saveToURL(url)
        } else {
            // Show save panel for new file
            saveAs()
        }
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Untitled.md"
        panel.message = "Save your markdown document"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.saveToURL(url)
            self?.currentFileURL = url
        }
    }

    private func saveToURL(_ url: URL) {
        do {
            try markdownText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving file: \\(error.localizedDescription)")
            showAlert(message: "Failed to save file: \\(error.localizedDescription)")
        }
    }

    private func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
