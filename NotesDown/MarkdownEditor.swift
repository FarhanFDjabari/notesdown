import SwiftUI

struct MarkdownEditor: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Editor")
                .font(.headline)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
        }
    }
}

#Preview {
    MarkdownEditor(text: .constant("# Hello World\n\nThis is a **markdown** editor."))
        .frame(width: 400, height: 600)
}
