import SwiftUI

struct MarkdownRenderer: View {
    let markdownText: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Preview")
                .font(.headline)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let attributedString = try? AttributedString(
                        markdown: markdownText,
                        options: AttributedString.MarkdownParsingOptions(
                            interpretedSyntax: .inlineOnlyPreservingWhitespace
                        )
                    ) {
                        Text(attributedString)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        Text(markdownText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

#Preview {
    MarkdownRenderer(markdownText: "# Hello World\\n\\nThis is a **markdown** preview.\\n\\n- Item 1\\n- Item 2\\n- Item 3")
        .frame(width: 400, height: 600)
}
