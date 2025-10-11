import XCTest
import SwiftUI
@testable import NotesDown

final class ThemeManagerTests: XCTestCase {
    var sut: ThemeManager!

    override func setUp() {
        super.setUp()
        sut = ThemeManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertFalse(sut.isDarkMode, "Should start in light mode")
        XCTAssertEqual(sut.colorScheme, .light, "Color scheme should be light")
    }

    func testToggleTheme() {
        XCTAssertFalse(sut.isDarkMode)

        sut.toggleTheme()
        XCTAssertTrue(sut.isDarkMode, "Should switch to dark mode")
        XCTAssertEqual(sut.colorScheme, .dark, "Color scheme should be dark")

        sut.toggleTheme()
        XCTAssertFalse(sut.isDarkMode, "Should switch back to light mode")
        XCTAssertEqual(sut.colorScheme, .light, "Color scheme should be light")
    }

    func testColorSchemeMapping() {
        sut.isDarkMode = false
        XCTAssertEqual(sut.colorScheme, .light)

        sut.isDarkMode = true
        XCTAssertEqual(sut.colorScheme, .dark)
    }
}
