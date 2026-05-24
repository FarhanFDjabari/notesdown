import Markdown
import AppKit
import XCTest
@testable import NotesDown

final class MarkdownPreviewViewTests: XCTestCase {
    func testPreviewDocumentExtractsFootnotesAndRemovesDefinitionsFromMarkdownBody() {
        let previewDocument = MarkdownPreviewDocument(markdownText: """
        Paragraph with a footnote.[^note]

        [^note]: Footnote text
            continued text
        """)

        XCTAssertEqual(previewDocument.footnotes, [
            MarkdownPreviewDocument.Footnote(id: "note", number: 1, text: "Footnote text continued text")
        ])
        XCTAssertEqual(previewDocument.footnoteReferences["note"], 1)
        XCTAssertFalse(previewDocument.document.format().contains("[^note]:"))
    }

    func testTaskListItemsExposeCheckboxState() throws {
        let document = Document(parsing: """
        - [ ] Open task
        - [x] Closed task
        """)

        let list = try XCTUnwrap(Array(document.children).first as? UnorderedList)
        let items = Array(list.listItems)

        XCTAssertEqual(items.first?.checkbox, .unchecked)
        XCTAssertEqual(items.last?.checkbox, .checked)
    }

    func testInlineRendererCreatesImageSegments() throws {
        let document = Document(parsing: "![Alt text](/tmp/example.png)")
        let paragraph = try XCTUnwrap(Array(document.children).first as? Paragraph)

        let segments = MarkdownInlineRenderer.segments(in: paragraph, footnoteReferences: [:])

        guard case let .image(image) = try XCTUnwrap(segments.first) else {
            return XCTFail("Expected an image segment")
        }
        XCTAssertEqual(image.source, "/tmp/example.png")
        XCTAssertEqual(image.altText, "Alt text")
    }

    func testInlineRendererAppliesStrikethroughAttribute() throws {
        let document = Document(parsing: "This is ~~removed~~ text")
        let paragraph = try XCTUnwrap(Array(document.children).first as? Paragraph)

        let rendered = MarkdownInlineRenderer.attributedString(in: paragraph, footnoteReferences: [:])
        let removedRange = (rendered.string as NSString).range(of: "removed")

        XCTAssertNotEqual(removedRange.location, NSNotFound)
        XCTAssertEqual(
            rendered.attribute(.strikethroughStyle, at: removedRange.location, effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )
    }

    func testInlineRendererSuperscriptsFootnoteReferences() throws {
        let document = Document(parsing: "Text with note.[^a]")
        let paragraph = try XCTUnwrap(Array(document.children).first as? Paragraph)

        let rendered = MarkdownInlineRenderer.attributedString(in: paragraph, footnoteReferences: ["a": 1])
        let referenceRange = (rendered.string as NSString).range(of: "1")

        XCTAssertNotEqual(referenceRange.location, NSNotFound)
        XCTAssertEqual(rendered.attribute(.baselineOffset, at: referenceRange.location, effectiveRange: nil) as? Int, 5)
    }

    func testSyntaxHighlightedCodeAppliesTokenColors() {
        let rendered = SyntaxHighlightedCode.nsAttributedString(for: "let name = \"NotesDown\"", language: "swift")
        let keywordRange = (rendered.string as NSString).range(of: "let")
        let stringRange = (rendered.string as NSString).range(of: "\"NotesDown\"")

        XCTAssertEqual(rendered.attribute(.foregroundColor, at: keywordRange.location, effectiveRange: nil) as? NSColor, NSColor.systemPurple)
        XCTAssertEqual(rendered.attribute(.foregroundColor, at: stringRange.location, effectiveRange: nil) as? NSColor, NSColor.systemRed)
    }

    func testTableCellTextDoesNotFormatTableCells() throws {
        let document = Document(parsing: """
        | Name | Notes |
        | --- | --- |
        | Alice | pasted table text |
        """)

        let table = try XCTUnwrap(Array(document.children).first as? Markdown.Table)
        let firstBodyRow = try XCTUnwrap(Array(table.body.rows).first)
        let firstBodyCell = try XCTUnwrap(Array(firstBodyRow.cells).first)

        XCTAssertEqual(MarkdownTableView.formattedText(for: firstBodyCell), "Alice")
    }

    func testPastedTableCellsRenderWithoutMarkupFormatter() throws {
        let document = Document(parsing: """
        | Name | Notes | Count |
        | :--- | :---: | ---: |
        | **Alice** | pasted table text | 1 |
        | Bob | [link](https://example.com) | 2 |
        """)

        let table = try XCTUnwrap(Array(document.children).first as? Markdown.Table)
        let headerText = Array(table.head.cells).map(MarkdownTableView.formattedText)
        let bodyText = Array(table.body.rows).flatMap { row in
            Array(row.cells).map(MarkdownTableView.formattedText)
        }

        XCTAssertEqual(headerText, ["Name", "Notes", "Count"])
        XCTAssertEqual(bodyText, ["Alice", "pasted table text", "1", "Bob", "link", "2"])
    }

    func testMarkdownTableViewDoesNotReintroduceCellFormatCall() throws {
        let source = try markdownPreviewViewSource()

        XCTAssertFalse(
            source.contains("cell.format()"),
            "Table.Cell.format() asserts inside swift-markdown and must not be used for table rendering."
        )
    }

    func testMarkdownTableViewRendersFullLongCellContent() throws {
        let source = try markdownPreviewViewSource()

        XCTAssertFalse(source.contains(".lineLimit("))
        XCTAssertFalse(source.contains(".truncationMode("))
        XCTAssertTrue(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertTrue(source.contains(".clipped()"))
        XCTAssertTrue(source.contains(".textSelection(.disabled)"))
    }

    func testTableRowHeightGrowsToFitLongestCell() throws {
        let document = Document(parsing: """
        | Short | Long |
        | --- | --- |
        | OK | This is a long table cell that needs multiple visible lines in the preview |
        | OK | Fine |
        """)
        let table = try XCTUnwrap(Array(document.children).first as? Markdown.Table)
        let rows = Array(table.body.rows)
        let longRowHeight = MarkdownTableView.rowHeight(for: Array(try XCTUnwrap(rows.first).cells))
        let shortRowHeight = MarkdownTableView.rowHeight(for: Array(try XCTUnwrap(rows.last).cells))

        XCTAssertGreaterThan(longRowHeight, shortRowHeight)
    }

    func testTableRowHeightContinuesGrowingForVeryLongCells() throws {
        let document = Document(parsing: """
        | Short | Long |
        | --- | --- |
        | OK | This is a much longer table cell that should render in full instead of being truncated after just a few visible lines in the markdown preview table layout |
        | OK | This is a long table cell |
        """)
        let table = try XCTUnwrap(Array(document.children).first as? Markdown.Table)
        let rows = Array(table.body.rows)
        let veryLongRowHeight = MarkdownTableView.rowHeight(for: Array(try XCTUnwrap(rows.first).cells))
        let longRowHeight = MarkdownTableView.rowHeight(for: Array(try XCTUnwrap(rows.last).cells))

        XCTAssertGreaterThan(veryLongRowHeight, longRowHeight)
    }

    private func markdownPreviewViewSource() throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NotesDown/Views/MarkdownPreviewView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
