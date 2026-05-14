import SwiftUI
import Markdown
import Foundation

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
            MarkdownInlineText(markdown: paragraph.format())
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let table = block as? Markdown.Table {
            MarkdownTableView(table: table)
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
        if codeBlock.language?.lowercased() == "mermaid" {
            MermaidBlockView(source: codeBlock.code)
        } else {
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
}

struct MarkdownInlineText: View {
    let markdown: String

    var body: some View {
        Text(attributedMarkdown)
    }

    private var attributedMarkdown: AttributedString {
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )

        return (try? AttributedString(markdown: trimmedMarkdown, options: options)) ?? AttributedString(trimmedMarkdown)
    }
}

struct MarkdownTableView: View {
    let table: Markdown.Table

    var body: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(headerCells.enumerated()), id: \.offset) { index, cell in
                        tableCell(cell, column: index, isHeader: true)
                    }
                }

                ForEach(Array(bodyRows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { index, cell in
                            tableCell(cell, column: index, isHeader: false)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerCells: [Markdown.Table.Cell] {
        Array(table.head.cells)
    }

    private var bodyRows: [Markdown.Table.Row] {
        Array(table.body.rows)
    }

    private func tableCell(_ cell: Markdown.Table.Cell, column: Int, isHeader: Bool) -> some View {
        MarkdownInlineText(markdown: cell.format())
            .font(isHeader ? .headline : .body)
            .fontWeight(isHeader ? .semibold : .regular)
            .multilineTextAlignment(alignment(for: column))
            .frame(minWidth: 120, maxWidth: 240, alignment: frameAlignment(for: column))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHeader ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 1)
            }
    }

    private func alignment(for column: Int) -> TextAlignment {
        switch table.columnAlignments[safe: column] ?? nil {
        case .center:
            return .center
        case .right:
            return .trailing
        case .left, .none:
            return .leading
        }
    }

    private func frameAlignment(for column: Int) -> Alignment {
        switch table.columnAlignments[safe: column] ?? nil {
        case .center:
            return .center
        case .right:
            return .trailing
        case .left, .none:
            return .leading
        }
    }
}

struct MermaidBlockView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("mermaid")
                .font(.caption)
                .foregroundColor(.secondary)

            MermaidDiagramView(diagram: MermaidDiagram(source: source))
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(source)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct MermaidDiagramView: View {
    let diagram: MermaidDiagram

    var body: some View {
        if diagram.edges.isEmpty {
            Text("Mermaid diagram preview is available for flowchart edges.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(diagram.edges.enumerated()), id: \.offset) { _, edge in
                    HStack(spacing: 8) {
                        MermaidNodeView(text: diagram.label(for: edge.from))

                        VStack(spacing: 2) {
                            if let label = edge.label {
                                Text(label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "arrow.right")
                                .foregroundColor(.accentColor)
                        }
                        .frame(minWidth: 32)

                        MermaidNodeView(text: diagram.label(for: edge.to))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MermaidNodeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
            }
    }
}

struct MermaidDiagram {
    struct Edge {
        let from: String
        let to: String
        let label: String?
    }

    private(set) var edges: [Edge] = []
    private var labels: [String: String] = [:]

    init(source: String) {
        parse(source)
    }

    func label(for nodeID: String) -> String {
        labels[nodeID] ?? nodeID
    }

    private mutating func parse(_ source: String) {
        let edgeOperators = ["-->", "==>", "-.->", "---"]

        for rawLine in source.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            line = line.trimmingCharacters(in: CharacterSet(charactersIn: ";"))

            guard !line.isEmpty,
                  !line.hasPrefix("flowchart"),
                  !line.hasPrefix("graph"),
                  let edgeOperator = edgeOperators.first(where: { line.contains($0) }) else {
                continue
            }

            let parts = line.components(separatedBy: edgeOperator)
            guard parts.count >= 2 else { continue }

            let fromNode = parseNode(parts[0])
            let toNode = parseNode(parts[1])

            labels[fromNode.id] = fromNode.label
            labels[toNode.id] = toNode.label
            edges.append(Edge(from: fromNode.id, to: toNode.id, label: toNode.edgeLabel))
        }
    }

    private mutating func parseNode(_ rawValue: String) -> (id: String, label: String, edgeLabel: String?) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var edgeLabel: String?

        if let firstPipe = value.firstIndex(of: "|"),
           let secondPipe = value[value.index(after: firstPipe)...].firstIndex(of: "|") {
            edgeLabel = String(value[value.index(after: firstPipe)..<secondPipe])
            value.removeSubrange(firstPipe...secondPipe)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let pairs: [(Character, Character)] = [("[", "]"), ("(", ")"), ("{", "}")]
        for pair in pairs {
            if let open = value.firstIndex(of: pair.0),
               let close = value.lastIndex(of: pair.1),
               open < close {
                let id = String(value[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
                let label = String(value[value.index(after: open)..<close])
                return (id.isEmpty ? label : id, label, edgeLabel)
            }
        }

        return (value, value, edgeLabel)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
