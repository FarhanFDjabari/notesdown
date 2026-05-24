import XCTest
@testable import NotesDown

final class MarkdownEditorViewTests: XCTestCase {
    func testMarkdownSyntaxHighlighterFindsCoreMarkdownTokens() {
        let markdown = """
        # Heading
        > Quote
        - Item with **strong**, *emphasis*, `code`, and [link](https://example.com)
        ```
        code block
        ```
        """

        let tokenKinds = Set(MarkdownSyntaxHighlighter.tokens(in: markdown).map(\.kind))

        XCTAssertTrue(tokenKinds.contains(.heading))
        XCTAssertTrue(tokenKinds.contains(.quote))
        XCTAssertTrue(tokenKinds.contains(.listMarker))
        XCTAssertTrue(tokenKinds.contains(.strong))
        XCTAssertTrue(tokenKinds.contains(.emphasis))
        XCTAssertTrue(tokenKinds.contains(.inlineCode))
        XCTAssertTrue(tokenKinds.contains(.link))
        XCTAssertTrue(tokenKinds.contains(.fencedCodeDelimiter))
    }

    func testMarkdownEditorViewNoLongerUsesSwiftUITextEditor() throws {
        let source = try markdownEditorViewSource()

        XCTAssertTrue(source.contains("NSViewRepresentable"))
        XCTAssertTrue(source.contains("NSTextView"))
        XCTAssertTrue(source.contains("LineNumberGutterView"))
        XCTAssertFalse(source.contains("TextEditor(text:"))
    }

    private func markdownEditorViewSource() throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NotesDown/Views/MarkdownEditorView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
