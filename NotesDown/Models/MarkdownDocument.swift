import Foundation

struct MarkdownDocument: Identifiable, Equatable {
    let id: UUID
    var content: String
    var fileURL: URL?
    var isModified: Bool

    init(id: UUID = UUID(), content: String = "", fileURL: URL? = nil, isModified: Bool = false) {
        self.id = id
        self.content = content
        self.fileURL = fileURL
        self.isModified = isModified
    }

    var fileName: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    var hasUnsavedChanges: Bool {
        isModified
    }
}
