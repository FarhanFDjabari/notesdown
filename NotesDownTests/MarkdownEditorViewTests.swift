import AppKit
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
        XCTAssertTrue(source.contains("override var isFlipped: Bool"))
        XCTAssertFalse(source.contains("TextEditor(text:"))
    }

    func testEditorColorPaletteUsesReadableTextForEachTheme() {
        let lightColors = MarkdownEditorColors(appearance: NSAppearance(named: .aqua)!)
        let darkColors = MarkdownEditorColors(appearance: NSAppearance(named: .darkAqua)!)

        XCTAssertLessThan(lightColors.text.perceivedBrightness, 0.25)
        XCTAssertGreaterThan(darkColors.text.perceivedBrightness, 0.75)
        XCTAssertGreaterThan(lightColors.currentLineHighlight.alphaComponent, 0)
        XCTAssertGreaterThan(darkColors.currentLineHighlight.alphaComponent, 0)
    }

    func testEditorColorPaletteProvidesDistinctSyntaxColorsForThemes() {
        let lightColors = MarkdownEditorColors(appearance: NSAppearance(named: .aqua)!)
        let darkColors = MarkdownEditorColors(appearance: NSAppearance(named: .darkAqua)!)

        XCTAssertNotEqual(lightColors.syntax.heading, darkColors.syntax.heading)
        XCTAssertNotEqual(lightColors.syntax.inlineCode, darkColors.syntax.inlineCode)
        XCTAssertNotEqual(lightColors.gutterText, darkColors.gutterText)
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

private extension NSColor {
    var perceivedBrightness: CGFloat {
        guard let color = usingColorSpace(.sRGB) else { return 0 }
        return (color.redComponent + color.greenComponent + color.blueComponent) / 3
    }
}
