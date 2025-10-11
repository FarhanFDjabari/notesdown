import XCTest
@testable import NotesDown

final class MarkdownDocumentTests: XCTestCase {

    func testInitialization() {
        let document = MarkdownDocument()

        XCTAssertNotNil(document.id)
        XCTAssertEqual(document.content, "")
        XCTAssertNil(document.fileURL)
        XCTAssertFalse(document.isModified)
    }

    func testInitializationWithParameters() {
        let content = "# Test Document"
        let url = URL(fileURLWithPath: "/tmp/test.md")

        let document = MarkdownDocument(content: content, fileURL: url, isModified: true)

        XCTAssertEqual(document.content, content)
        XCTAssertEqual(document.fileURL, url)
        XCTAssertTrue(document.isModified)
    }

    func testFileNameWithURL() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let document = MarkdownDocument(fileURL: url)

        XCTAssertEqual(document.fileName, "test.md")
    }

    func testFileNameWithoutURL() {
        let document = MarkdownDocument()

        XCTAssertEqual(document.fileName, "Untitled")
    }

    func testHasUnsavedChanges() {
        var document = MarkdownDocument()
        XCTAssertFalse(document.hasUnsavedChanges)

        document.isModified = true
        XCTAssertTrue(document.hasUnsavedChanges)
    }

    func testEquality() {
        let id = UUID()
        let doc1 = MarkdownDocument(id: id, content: "Test")
        let doc2 = MarkdownDocument(id: id, content: "Test")
        let doc3 = MarkdownDocument(content: "Test")

        XCTAssertEqual(doc1, doc2, "Documents with same ID should be equal")
        XCTAssertNotEqual(doc1, doc3, "Documents with different IDs should not be equal")
    }
}
