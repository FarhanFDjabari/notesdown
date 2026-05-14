import Foundation
import AppKit
import UniformTypeIdentifiers

protocol FileServiceProtocol {
    func openFile() async throws -> (content: String, url: URL)
    func openFiles() async throws -> [URL]
    func saveFile(content: String, to url: URL?) async throws -> URL
}

class FileService: FileServiceProtocol {
    enum FileServiceError: Error {
        case userCancelled
        case invalidURL
        case readError(Error)
        case writeError(Error)
    }

    func openFile() async throws -> (content: String, url: URL) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = Self.markdownOpenPanel(allowsMultipleSelection: false)
                panel.message = "Select a markdown file to open"

                panel.begin { response in
                    guard response == .OK, let url = panel.url else {
                        continuation.resume(throwing: FileServiceError.userCancelled)
                        return
                    }

                    do {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        continuation.resume(returning: (content, url))
                    } catch {
                        continuation.resume(throwing: FileServiceError.readError(error))
                    }
                }
            }
        }
    }

    func openFiles() async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = Self.markdownOpenPanel(allowsMultipleSelection: true)
                panel.message = "Select markdown files to open in new windows"

                panel.begin { response in
                    guard response == .OK, !panel.urls.isEmpty else {
                        continuation.resume(throwing: FileServiceError.userCancelled)
                        return
                    }

                    continuation.resume(returning: panel.urls)
                }
            }
        }
    }

    func saveFile(content: String, to url: URL?) async throws -> URL {
        if let url = url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                throw FileServiceError.writeError(error)
            }
        } else {
            return try await saveFileAs(content: content)
        }
    }

    private func saveFileAs(content: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
                panel.canCreateDirectories = true
                panel.nameFieldStringValue = "Untitled.md"
                panel.message = "Save your markdown document"

                panel.begin { response in
                    guard response == .OK, let url = panel.url else {
                        continuation.resume(throwing: FileServiceError.userCancelled)
                        return
                    }

                    do {
                        try content.write(to: url, atomically: true, encoding: .utf8)
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: FileServiceError.writeError(error))
                    }
                }
            }
        }
    }

    private static func markdownOpenPanel(allowsMultipleSelection: Bool) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "mdown") ?? .plainText,
            UTType(filenameExtension: "mkd") ?? .plainText
        ]
        return panel
    }
}
