import XCTest
@testable import NotesDown

@MainActor
final class DocumentViewModelTests: XCTestCase {
    var sut: DocumentViewModel!
    var mockFileService: MockFileService!
    var mockUnsavedChangesPrompter: MockUnsavedChangesPrompter!

    override func setUp() {
        super.setUp()
        mockFileService = MockFileService()
        mockUnsavedChangesPrompter = MockUnsavedChangesPrompter()
        sut = DocumentViewModel(
            fileService: mockFileService,
            unsavedChangesPrompter: mockUnsavedChangesPrompter
        )
    }

    override func tearDown() {
        sut = nil
        mockFileService = nil
        mockUnsavedChangesPrompter = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertFalse(sut.document.content.isEmpty, "Initial document should have default content")
        XCTAssertNil(sut.document.fileURL, "Initial document should not have a URL")
        XCTAssertFalse(sut.document.isModified, "Initial document should not be modified")
    }

    func testMarkdownTextGetter() {
        let expectedText = "# Test"
        sut.document.content = expectedText
        XCTAssertEqual(sut.markdownText, expectedText)
    }

    func testMarkdownTextSetter() {
        let newText = "# New Content"
        sut.markdownText = newText

        XCTAssertEqual(sut.document.content, newText)
        XCTAssertTrue(sut.document.isModified)
    }

    func testOpenFileSuccess() async {
        let expectedContent = "# Test File"
        let expectedURL = URL(fileURLWithPath: "/tmp/test.md")
        mockFileService.mockOpenResult = (expectedContent, expectedURL)

        sut.openFile()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.document.content, expectedContent)
        XCTAssertEqual(sut.document.fileURL, expectedURL)
        XCTAssertFalse(sut.document.isModified)
        XCTAssertNil(sut.errorMessage)
    }

    func testOpenFileUserCancelled() async {
        mockFileService.mockOpenError = FileService.FileServiceError.userCancelled

        sut.openFile()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(sut.errorMessage, "Should not set error message when user cancels")
    }

    func testOpenFileError() async {
        mockFileService.mockOpenError = FileService.FileServiceError.readError(NSError(domain: "test", code: 1))

        sut.openFile()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(sut.errorMessage, "Should set error message on failure")
        XCTAssertTrue(sut.errorMessage?.contains("Failed to open file") ?? false)
    }

    func testOpenFileSavesModifiedDocumentBeforeReplacingIt() async {
        let currentURL = URL(fileURLWithPath: "/tmp/current.md")
        let openedURL = URL(fileURLWithPath: "/tmp/opened.md")
        sut.document = MarkdownDocument(content: "# Unsaved", fileURL: currentURL, isModified: true)
        mockFileService.mockSaveResult = currentURL
        mockFileService.mockOpenResult = ("# Opened", openedURL)
        mockUnsavedChangesPrompter.decision = .save

        sut.openFile()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockUnsavedChangesPrompter.promptedFileName, "current.md")
        XCTAssertEqual(mockFileService.savedContent, "# Unsaved")
        XCTAssertEqual(mockFileService.savedURL, currentURL)
        XCTAssertEqual(mockFileService.openFileCallCount, 1)
        XCTAssertEqual(sut.document.content, "# Opened")
        XCTAssertEqual(sut.document.fileURL, openedURL)
        XCTAssertFalse(sut.document.isModified)
    }

    func testOpenFileDiscardsModifiedDocumentBeforeReplacingIt() async {
        let openedURL = URL(fileURLWithPath: "/tmp/opened.md")
        sut.document = MarkdownDocument(content: "# Unsaved", isModified: true)
        mockFileService.mockOpenResult = ("# Opened", openedURL)
        mockUnsavedChangesPrompter.decision = .discard

        sut.openFile()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockFileService.saveFileCallCount, 0)
        XCTAssertEqual(mockFileService.openFileCallCount, 1)
        XCTAssertEqual(sut.document.content, "# Opened")
        XCTAssertEqual(sut.document.fileURL, openedURL)
        XCTAssertFalse(sut.document.isModified)
    }

    func testOpenFileCancelKeepsModifiedDocument() async {
        let originalDocument = MarkdownDocument(content: "# Unsaved", isModified: true)
        sut.document = originalDocument
        mockFileService.mockOpenResult = ("# Opened", URL(fileURLWithPath: "/tmp/opened.md"))
        mockUnsavedChangesPrompter.decision = .cancel

        sut.openFile()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockFileService.saveFileCallCount, 0)
        XCTAssertEqual(mockFileService.openFileCallCount, 0)
        XCTAssertEqual(sut.document, originalDocument)
        XCTAssertTrue(sut.document.isModified)
    }

    func testChooseFilesForNewWindows() async throws {
        let expectedURLs = [
            URL(fileURLWithPath: "/tmp/first.md"),
            URL(fileURLWithPath: "/tmp/second.md")
        ]
        mockFileService.mockOpenFilesResult = expectedURLs

        let urls = try await sut.chooseFilesForNewWindows()

        XCTAssertEqual(urls, expectedURLs)
    }

    func testSaveFileWithExistingURL() async {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        sut.document.fileURL = url
        sut.document.content = "# Test"
        sut.document.isModified = true
        mockFileService.mockSaveResult = url

        sut.saveFile()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.document.fileURL, url)
        XCTAssertFalse(sut.document.isModified)
        XCTAssertNil(sut.errorMessage)
    }

    func testSaveFileUserCancelled() async {
        mockFileService.mockSaveError = FileService.FileServiceError.userCancelled

        sut.saveFile()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(sut.errorMessage, "Should not set error message when user cancels")
    }

    func testSaveFileError() async {
        mockFileService.mockSaveError = FileService.FileServiceError.writeError(NSError(domain: "test", code: 1))

        sut.saveFile()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(sut.errorMessage, "Should set error message on failure")
        XCTAssertTrue(sut.errorMessage?.contains("Failed to save file") ?? false)
    }
}

// Mock FileService for testing
class MockFileService: FileServiceProtocol {
    var mockOpenResult: (content: String, url: URL)?
    var mockOpenFilesResult: [URL]?
    var mockOpenError: Error?
    var mockOpenFilesError: Error?
    var mockSaveResult: URL?
    var mockSaveError: Error?
    var openFileCallCount = 0
    var saveFileCallCount = 0
    var savedContent: String?
    var savedURL: URL?

    func openFile() async throws -> (content: String, url: URL) {
        openFileCallCount += 1
        if let error = mockOpenError {
            throw error
        }
        guard let result = mockOpenResult else {
            throw FileService.FileServiceError.invalidURL
        }
        return result
    }

    func openFiles() async throws -> [URL] {
        if let error = mockOpenFilesError {
            throw error
        }
        guard let result = mockOpenFilesResult else {
            throw FileService.FileServiceError.invalidURL
        }
        return result
    }

    func saveFile(content: String, to url: URL?) async throws -> URL {
        saveFileCallCount += 1
        savedContent = content
        savedURL = url
        if let error = mockSaveError {
            throw error
        }
        guard let result = mockSaveResult else {
            throw FileService.FileServiceError.invalidURL
        }
        return result
    }
}

class MockUnsavedChangesPrompter: UnsavedChangesPrompting {
    var decision: UnsavedChangesDecision = .cancel
    var promptedFileName: String?

    func confirmDestructiveChange(fileName: String) async -> UnsavedChangesDecision {
        promptedFileName = fileName
        return decision
    }
}
