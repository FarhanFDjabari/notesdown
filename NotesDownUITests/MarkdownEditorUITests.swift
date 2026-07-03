import AppKit
import XCTest

final class MarkdownEditorUITests: XCTestCase {
    func testEditorPaneDrawsMarkdownText() {
        let app = launchFreshApp()

        let editor = app.textViews["markdown-editor-text-view"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Editor text view should exist after launch.")

        let value = editor.value as? String
        XCTAssertTrue(value?.contains("# Welcome to NotesDown") == true)

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "App window should exist after launch.")
        XCTAssertTrue(editorPaneContainsVisibleText(window.frame), "Editor pane should draw visible text pixels, not only line numbers.")
    }

    func testLineNumberGutterDrawsOrderedVisibleNumbers() {
        let app = launchFreshApp()

        let gutter = app.descendants(matching: .any)["markdown-editor-line-number-gutter"]
        XCTAssertTrue(gutter.waitForExistence(timeout: 5), "Line-number gutter should exist after launch.")
        let visibleLineNumbers = lineNumbers(from: gutter.value as? String)
        XCTAssertGreaterThanOrEqual(visibleLineNumbers.count, 10)
        XCTAssertEqual(visibleLineNumbers, Array(1...visibleLineNumbers.count))

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "App window should exist after launch.")
        XCTAssertTrue(gutterContainsVisibleNumbers(window.frame), "Line-number gutter should draw visible numbers.")
    }

    func testPreviewRendersExtendedMarkdownFeaturesFromEditorInput() {
        let app = launchFreshApp()

        let editor = app.textViews["markdown-editor-text-view"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Editor text view should exist after launch.")

        replaceEditorText("""
        # Preview fidelity

        - [ ] Incomplete task
        - [x] Complete task

        This has ~~struck text~~ and a footnote.[^first]

        ![Missing image](missing-preview-image.png)

        ```swift
        let name = "NotesDown"
        ```

        [^first]: Footnote content
        """, in: editor)

        let preview = app.descendants(matching: .any)["markdown-preview-content"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Preview content should exist after editing.")
        let value = preview.value as? String
        XCTAssertTrue(value?.contains("task-list") == true)
        XCTAssertTrue(value?.contains("image") == true)
        XCTAssertTrue(value?.contains("code-block") == true)
        XCTAssertTrue(value?.contains("footnotes") == true)
    }

    private func editorPaneContainsVisibleText(_ windowFrame: CGRect) -> Bool {
        let screenshot = XCUIScreen.main.screenshot()
        guard
            let bitmap = NSBitmapImageRep(data: screenshot.pngRepresentation),
            windowFrame.width > 420,
            windowFrame.height > 220
        else {
            return false
        }

        guard let screenFrame = NSScreen.main?.frame else { return false }
        let scaleX = CGFloat(bitmap.pixelsWide) / screenFrame.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / screenFrame.height

        let sampleRect = CGRect(
            x: windowFrame.minX + 90,
            y: windowFrame.minY + 80,
            width: max((windowFrame.width / 2) - 140, 80),
            height: min(windowFrame.height - 140, 320)
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

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState",
            "YES",
            "-themePreference",
            "dark"
        ]
        app.launch()
        return app
    }

    private func replaceEditorText(_ text: String, in editor: XCUIElement) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey("v", modifierFlags: .command)
    }

    private func lineNumbers(from value: String?) -> [Int] {
        value?
            .split(separator: ",")
            .compactMap { Int($0) } ?? []
    }

    private func gutterContainsVisibleNumbers(_ windowFrame: CGRect) -> Bool {
        let screenshot = XCUIScreen.main.screenshot()
        guard
            let bitmap = NSBitmapImageRep(data: screenshot.pngRepresentation),
            windowFrame.width > 420,
            windowFrame.height > 220
        else {
            return false
        }

        guard let screenFrame = NSScreen.main?.frame else { return false }
        let scaleX = CGFloat(bitmap.pixelsWide) / screenFrame.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / screenFrame.height

        let sampleRect = CGRect(
            x: windowFrame.minX + 18,
            y: windowFrame.minY + 90,
            width: 40,
            height: min(windowFrame.height - 150, 420)
        )

        var visibleNumberPixelCount = 0
        var sampledPixelCount = 0
        let minX = max(Int(sampleRect.minX * scaleX), 0)
        let maxX = min(Int(sampleRect.maxX * scaleX), bitmap.pixelsWide - 1)
        let minY = max(Int(sampleRect.minY * scaleY), 0)
        let maxY = min(Int(sampleRect.maxY * scaleY), bitmap.pixelsHigh - 1)

        for y in stride(from: minY, through: maxY, by: 3) {
            for x in stride(from: minX, through: maxX, by: 3) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                sampledPixelCount += 1

                if color.redComponent > 0.35 || color.greenComponent > 0.35 || color.blueComponent > 0.35 {
                    visibleNumberPixelCount += 1
                }
            }
        }

        return sampledPixelCount > 0 && visibleNumberPixelCount > 12
    }
}
