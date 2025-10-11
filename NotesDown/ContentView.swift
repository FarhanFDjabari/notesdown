import SwiftUI

struct ContentView: View {
    @StateObject private var documentViewModel = DocumentViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var windowManager: WindowManager

    var body: some View {
        HSplitView {
            MarkdownEditorView(text: $documentViewModel.markdownText)
                .frame(minWidth: 300)

            MarkdownPreviewView(markdownText: documentViewModel.markdownText)
                .frame(minWidth: 300)
        }
        .navigationTitle(documentViewModel.document.fileName)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    documentViewModel.openFile()
                }) {
                    Label("Open", systemImage: "folder")
                }

                Button(action: {
                    documentViewModel.saveFile()
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Spacer()

                Button(action: {
                    themeManager.toggleTheme()
                }) {
                    Label(
                        themeManager.isDarkMode ? "Light Mode" : "Dark Mode",
                        systemImage: themeManager.isDarkMode ? "sun.max" : "moon"
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            documentViewModel.openFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            documentViewModel.saveFile()
        }
        .onAppear {
            if let url = windowManager.fileToOpen {
                documentViewModel.openFile(at: url)
                windowManager.fileToOpen = nil
            }
        }
        .onChange(of: windowManager.fileToOpen) { oldURL, newURL in
            if let url = newURL {
                documentViewModel.openFile(at: url)
                windowManager.fileToOpen = nil
            }
        }
        .alert("Error", isPresented: .constant(documentViewModel.errorMessage != nil)) {
            Button("OK") {
                documentViewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = documentViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}
