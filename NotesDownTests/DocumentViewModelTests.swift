import XCTest
@testable import NotesDown

@MainActor
final class DocumentViewModelTests: XCTestCase {
    var sut: DocumentViewModel!
    var mockFileService: MockFileService!

    override func setUp() {
        super.setUp()
        mockFileService = MockFileService()
        sut = DocumentViewModel(fileService: mockFileService)
    }

    override func tearDown() {
        sut = nil
        mockFileService = nil
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

    func openFile() async throws -> (content: String, url: URL) {
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
        if let error = mockSaveError {
            throw error
        }
        guard let result = mockSaveResult else {
            throw FileService.FileServiceError.invalidURL
        }
        return result
    }
}
