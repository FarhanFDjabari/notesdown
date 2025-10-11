import SwiftUI
import Markdown

struct MarkdownPreviewView: View {
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
                VStack(alignment: .leading, spacing: 12) {
                    MarkdownContentView(markdownText: markdownText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

struct MarkdownContentView: View {
    let markdownText: String

    var body: some View {
        let document = Document(parsing: markdownText)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(document.children.enumerated()), id: \.offset) { _, child in
                MarkdownBlockView(block: child)
            }
        }
    }
}

struct MarkdownBlockView: View {
    let block: any Markup

    @ViewBuilder
    var body: some View {
        if let heading = block as? Heading {
            HeadingView(heading: heading)
        } else if let paragraph = block as? Paragraph {
            Text(paragraph.plainText)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let codeBlock = block as? CodeBlock {
            CodeBlockView(codeBlock: codeBlock)
        } else if let list = block as? UnorderedList {
            UnorderedListView(list: list)
        } else if let list = block as? OrderedList {
            OrderedListView(list: list)
        } else if let blockQuote = block as? BlockQuote {
            BlockQuoteView(blockQuote: blockQuote)
        } else if block is ThematicBreak {
            Divider()
                .padding(.vertical, 8)
        } else {
            // Fallback for unsupported blocks including tables
            Text(block.format())
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HeadingView: View {
    let heading: Heading

    var body: some View {
        let text = heading.plainText
        Group {
            switch heading.level {
            case 1:
                Text(text)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
            case 2:
                Text(text)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
            case 3:
                Text(text)
                    .font(.title2)
                    .fontWeight(.semibold)
            case 4:
                Text(text)
                    .font(.title3)
                    .fontWeight(.semibold)
            case 5:
                Text(text)
                    .font(.headline)
                    .fontWeight(.semibold)
            case 6:
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            default:
                Text(text)
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct CodeBlockView: View {
    let codeBlock: CodeBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language = codeBlock.language, !language.isEmpty {
                Text(language)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(codeBlock.code)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct UnorderedListView: View {
    let list: UnorderedList

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            MarkdownBlockView(block: child)
                        }
                    }
                }
            }
        }
        .padding(.leading, 16)
    }
}

struct OrderedListView: View {
    let list: OrderedList

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(Int(list.startIndex) + index).")
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            MarkdownBlockView(block: child)
                        }
                    }
                }
            }
        }
        .padding(.leading, 16)
    }
}

struct BlockQuoteView: View {
    let blockQuote: BlockQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blockQuote.children.enumerated()), id: \.offset) { _, child in
                MarkdownBlockView(block: child)
            }
        }
        .padding(.leading, 16)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: 4)
        }
        .padding(.leading, 4)
    }
}

#Preview {
    MarkdownPreviewView(markdownText: """
    # Heading 1
    ## Heading 2
    ### Heading 3

    This is a paragraph with **bold**, *italic*, and `inline code`.

    [This is a link](https://example.com)

    ## Lists

    - Unordered item 1
    - Unordered item 2
    - Unordered item 3

    1. Ordered item 1
    2. Ordered item 2
    3. Ordered item 3

    ## Code Block

    ```swift
    let greeting = "Hello, World!"
    print(greeting)
    ```

    ## Quote

    > This is a blockquote
    > with multiple lines

    ---

    This version uses swift-markdown for better parsing!
    """)
        .frame(width: 600, height: 800)
}
