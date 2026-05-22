import Markdown
import XCTest
@testable import NotesDown

final class MarkdownPreviewViewTests: XCTestCase {
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
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NotesDown/Views/MarkdownPreviewView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(
            source.contains("cell.format()"),
            "Table.Cell.format() asserts inside swift-markdown and must not be used for table rendering."
        )
    }
}
