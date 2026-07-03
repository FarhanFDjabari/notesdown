import AppKit
import SwiftUI

enum ThemePreference: String {
    case system
    case light
    case dark
}

class ThemeManager: ObservableObject {
    @Published var preference: ThemePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: "themePreference")
        }
    }

    /// `nil` follows the system appearance; an explicit choice overrides it.
    var colorScheme: ColorScheme? {
        switch preference {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var isDarkMode: Bool {
        switch preference {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "themePreference")
        self.preference = stored.flatMap(ThemePreference.init) ?? .system
    }

    func toggleTheme() {
        preference = isDarkMode ? .light : .dark
    }
}
