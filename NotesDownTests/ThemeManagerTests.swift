import XCTest
import SwiftUI
@testable import NotesDown

final class ThemeManagerTests: XCTestCase {
    var sut: ThemeManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "themePreference")
        sut = ThemeManager()
    }

    override func tearDown() {
        sut = nil
        UserDefaults.standard.removeObject(forKey: "themePreference")
        super.tearDown()
    }

    func testInitialStateFollowsSystem() {
        XCTAssertEqual(sut.preference, .system, "Should default to following the system appearance")
        XCTAssertNil(sut.colorScheme, "Following the system means no explicit color scheme")
    }

    func testToggleTheme() {
        sut.preference = .light
        XCTAssertFalse(sut.isDarkMode)

        sut.toggleTheme()
        XCTAssertTrue(sut.isDarkMode, "Should switch to dark mode")
        XCTAssertEqual(sut.colorScheme, .dark, "Color scheme should be dark")

        sut.toggleTheme()
        XCTAssertFalse(sut.isDarkMode, "Should switch back to light mode")
        XCTAssertEqual(sut.colorScheme, .light, "Color scheme should be light")
    }

    func testColorSchemeMapping() {
        sut.preference = .system
        XCTAssertNil(sut.colorScheme)

        sut.preference = .light
        XCTAssertEqual(sut.colorScheme, .light)

        sut.preference = .dark
        XCTAssertEqual(sut.colorScheme, .dark)
    }

    func testPreferencePersists() {
        sut.preference = .dark
        let reloaded = ThemeManager()
        XCTAssertEqual(reloaded.preference, .dark, "Preference should persist across launches")
    }
}
