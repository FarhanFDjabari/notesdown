import AppKit
import XCTest

final class MarkdownEditorUITests: XCTestCase {
    func testEditorPaneDrawsMarkdownText() {
        let app = XCUIApplication()
        app.launch()

        let editor = app.textViews["markdown-editor-text-view"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Editor text view should exist after launch.")

        let value = editor.value as? String
        XCTAssertTrue(value?.contains("# Welcome to NotesDown") == true)
        XCTAssertTrue(editorFrameContainsVisibleText(editor.frame), "Editor should draw visible text pixels, not only line numbers.")
    }

    private func editorFrameContainsVisibleText(_ editorFrame: CGRect) -> Bool {
        let screenshot = XCUIScreen.main.screenshot()
        guard
            let bitmap = NSBitmapImageRep(data: screenshot.pngRepresentation),
            editorFrame.width > 160,
            editorFrame.height > 120
        else {
            return false
        }

        guard let screenFrame = NSScreen.main?.frame else { return false }
        let scaleX = CGFloat(bitmap.pixelsWide) / screenFrame.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / screenFrame.height

        let sampleRect = CGRect(
            x: editorFrame.minX + 80,
            y: editorFrame.minY + 40,
            width: editorFrame.width - 120,
            height: min(editorFrame.height - 80, 260)
        )

        var brightPixelCount = 0
        var sampledPixelCount = 0
        let minX = max(Int(sampleRect.minX * scaleX), 0)
        let maxX = min(Int(sampleRect.maxX * scaleX), bitmap.pixelsWide - 1)
        let minY = max(Int(sampleRect.minY * scaleY), 0)
        let maxY = min(Int(sampleRect.maxY * scaleY), bitmap.pixelsHigh - 1)

        for y in stride(from: minY, through: maxY, by: 4) {
            for x in stride(from: minX, through: maxX, by: 4) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                sampledPixelCount += 1

                if color.redComponent > 0.45 || color.greenComponent > 0.45 || color.blueComponent > 0.45 {
                    brightPixelCount += 1
                }
            }
        }

        return sampledPixelCount > 0 && brightPixelCount > 20
    }
}
