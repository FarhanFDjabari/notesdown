import SwiftUI

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = false

    var colorScheme: ColorScheme? {
        return isDarkMode ? .dark : .light
    }

    func toggleTheme() {
        isDarkMode.toggle()
    }
}
