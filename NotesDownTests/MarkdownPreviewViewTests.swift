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
}
