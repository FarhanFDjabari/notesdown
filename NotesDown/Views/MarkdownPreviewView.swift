import SwiftUI
import Markdown
import Foundation
import AppKit

struct MarkdownPreviewView: View {
    let markdownText: String
    @ObservedObject var scrollSync: ScrollSyncController
    @Environment(\.colorScheme) var colorScheme
    @State private var scrollPosition = ScrollPosition(edge: .top)

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
                        .accessibilityIdentifier("markdown-preview-content")
                }
            }
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: PreviewScrollGeometry.self) { geometry in
                PreviewScrollGeometry(
                    offsetY: geometry.contentOffset.y,
                    contentHeight: geometry.contentSize.height,
                    containerHeight: geometry.containerSize.height
                )
            } action: { _, geometry in
                scrollSync.previewGeometryChanged(
                    offsetY: geometry.offsetY,
                    contentHeight: geometry.contentHeight,
                    containerHeight: geometry.containerHeight
                )
            }
            .onChange(of: scrollSync.previewTarget) { _, target in
                guard let target else { return }
                scrollPosition.scrollTo(y: target.y)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

private struct PreviewScrollGeometry: Equatable {
    let offsetY: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}

struct MarkdownContentView: View {
    let markdownText: String

    var body: some View {
        let previewDocument = MarkdownPreviewDocument(markdownText: markdownText)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(previewDocument.document.children.enumerated()), id: \.offset) { _, child in
                MarkdownBlockView(block: child, footnoteReferences: previewDocument.footnoteReferences)
            }

            if !previewDocument.footnotes.isEmpty {
                FootnotesView(footnotes: previewDocument.footnotes)
            }
        }
        .accessibilityValue(previewDocument.accessibilitySummary)
    }
}

struct MarkdownBlockView: View {
    let block: any Markup
    let footnoteReferences: [String: Int]

    @ViewBuilder
    var body: some View {
        if let heading = block as? Heading {
            HeadingView(heading: heading)
        } else if let paragraph = block as? Paragraph {
            MarkdownInlineContentView(container: paragraph, footnoteReferences: footnoteReferences)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let table = block as? Markdown.Table {
            MarkdownTableView(table: table)
        } else if let codeBlock = block as? CodeBlock {
            CodeBlockView(codeBlock: codeBlock)
        } else if let list = block as? UnorderedList {
            UnorderedListView(list: list, footnoteReferences: footnoteReferences)
        } else if let list = block as? OrderedList {
            OrderedListView(list: list, footnoteReferences: footnoteReferences)
        } else if let blockQuote = block as? BlockQuote {
            BlockQuoteView(blockQuote: blockQuote, footnoteReferences: footnoteReferences)
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

                CodeBlockTextView(code: codeBlock.code, language: codeBlock.language)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

struct CodeBlockTextView: View {
    let code: String
    let language: String?

    var body: some View {
        Text(SyntaxHighlightedCode.attributedString(for: code, language: language))
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("markdown-preview-code-block")
    }
}

struct MarkdownInlineContentView: View {
    let container: any InlineContainer
    let footnoteReferences: [String: Int]

    var body: some View {
        let segments = MarkdownInlineRenderer.segments(in: container, footnoteReferences: footnoteReferences)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let text):
                    Text(AttributedString(text))
                        .fixedSize(horizontal: false, vertical: true)
                case .image(let image):
                    MarkdownImageView(image: image)
                }
            }
        }
    }
}

struct MarkdownImageView: View {
    let image: MarkdownInlineRenderer.ImageSegment

    var body: some View {
        if let url = image.url, url.isRemote {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    imagePlaceholder("Image could not be loaded")
                case .empty:
                    imagePlaceholder("Loading image...")
                @unknown default:
                    imagePlaceholder("Loading image...")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
            .accessibilityLabel(image.altText)
            .accessibilityIdentifier("markdown-preview-image")
        } else if let nsImage = image.localImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
                .accessibilityLabel(image.altText)
                .accessibilityIdentifier("markdown-preview-image")
        } else {
            imagePlaceholder(image.source)
                .accessibilityIdentifier("markdown-preview-image-placeholder")
        }
    }

    private func imagePlaceholder(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
        }
        .font(.callout)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FootnotesView: View {
    let footnotes: [MarkdownPreviewDocument.Footnote]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.top, 6)

            ForEach(footnotes) { footnote in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(footnote.number).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 22, alignment: .trailing)
                    Text(footnote.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier("markdown-preview-footnote-\(footnote.id)")
            }
        }
        .accessibilityIdentifier("markdown-preview-footnotes")
    }
}

struct MarkdownTableView: View {
    let table: Markdown.Table
    private static let cellWidth: CGFloat = 240
    private static let minimumCellHeight: CGFloat = 48
    private static let estimatedCharactersPerLine = 24
    private static let estimatedLineHeight: CGFloat = 22
    private static let verticalPadding: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                let headerHeight = Self.rowHeight(for: headerCells)
                GridRow {
                    ForEach(Array(headerCells.enumerated()), id: \.offset) { index, cell in
                        tableCell(cell, column: index, isHeader: true, rowHeight: headerHeight)
                    }
                }

                ForEach(Array(bodyRows.enumerated()), id: \.offset) { _, row in
                    let cells = Array(row.cells)
                    let rowHeight = Self.rowHeight(for: cells)
                    GridRow {
                        ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                            tableCell(cell, column: index, isHeader: false, rowHeight: rowHeight)
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

    private func tableCell(_ cell: Markdown.Table.Cell, column: Int, isHeader: Bool, rowHeight: CGFloat) -> some View {
        Text(AttributedString(MarkdownInlineRenderer.attributedString(in: cell, footnoteReferences: [:])))
            .font(isHeader ? .headline : .body)
            .fontWeight(isHeader ? .semibold : .regular)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(alignment(for: column))
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment(for: column)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: Self.cellWidth, alignment: frameAlignment(for: column))
            .frame(height: rowHeight, alignment: frameAlignment(for: column))
            .contentShape(Rectangle())
            .clipped()
            .textSelection(.disabled)
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

    static func formattedText(for cell: Markdown.Table.Cell) -> String {
        // Table.Cell.format() asserts inside swift-markdown 0.7.x. Use inline text only.
        cell.plainText
    }

    static func rowHeight(for cells: [Markdown.Table.Cell]) -> CGFloat {
        let maximumLineCount = cells
            .map(formattedText)
            .map(estimatedLineCount(for:))
            .max() ?? 1

        return max(
            minimumCellHeight,
            CGFloat(maximumLineCount) * estimatedLineHeight + verticalPadding
        )
    }

    private static func estimatedLineCount(for text: String) -> Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return max(
            1,
            lines.reduce(0) { total, line in
                total + max(1, Int(ceil(Double(line.count) / Double(estimatedCharactersPerLine))))
            }
        )
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
    let footnoteReferences: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    ListMarkerView(checkbox: item.checkbox, fallback: "•")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            MarkdownBlockView(block: child, footnoteReferences: footnoteReferences)
                        }
                    }
                }
                .accessibilityIdentifier(item.checkbox == nil ? "markdown-preview-list-item" : "markdown-preview-task-item")
            }
        }
        .padding(.leading, 16)
    }
}

struct OrderedListView: View {
    let list: OrderedList
    let footnoteReferences: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    ListMarkerView(checkbox: item.checkbox, fallback: "\(Int(list.startIndex) + index).")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            MarkdownBlockView(block: child, footnoteReferences: footnoteReferences)
                        }
                    }
                }
                .accessibilityIdentifier(item.checkbox == nil ? "markdown-preview-list-item" : "markdown-preview-task-item")
            }
        }
        .padding(.leading, 16)
    }
}

struct ListMarkerView: View {
    let checkbox: Checkbox?
    let fallback: String

    var body: some View {
        if let checkbox {
            Image(systemName: checkbox == .checked ? "checkmark.square" : "square")
                .foregroundColor(checkbox == .checked ? .accentColor : .secondary)
                .frame(width: 16)
                .accessibilityLabel(checkbox == .checked ? "Completed task" : "Incomplete task")
        } else {
            Text(fallback)
                .fontWeight(.bold)
                .frame(minWidth: 16, alignment: .trailing)
        }
    }
}

struct BlockQuoteView: View {
    let blockQuote: BlockQuote
    let footnoteReferences: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blockQuote.children.enumerated()), id: \.offset) { _, child in
                MarkdownBlockView(block: child, footnoteReferences: footnoteReferences)
            }
        }
        .padding(.vertical, 2)
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: 4)
        }
        .padding(.leading, 4)
    }
}

struct MarkdownPreviewDocument {
    struct Footnote: Identifiable, Equatable {
        let id: String
        let number: Int
        let text: String
    }

    let document: Document
    let footnotes: [Footnote]
    let footnoteReferences: [String: Int]
    let accessibilitySummary: String

    init(markdownText: String) {
        let parsed = Self.extractFootnotes(from: markdownText)
        let parsedDocument = Document(parsing: parsed.markdown)
        document = parsedDocument
        footnotes = parsed.footnotes
        footnoteReferences = Dictionary(uniqueKeysWithValues: parsed.footnotes.map { ($0.id, $0.number) })
        accessibilitySummary = Self.accessibilitySummary(for: parsedDocument, footnotes: parsed.footnotes)
    }

    static func extractFootnotes(from markdown: String) -> (markdown: String, footnotes: [Footnote]) {
        let lines = markdown.components(separatedBy: .newlines)
        let definitionPattern = #"^\[\^([^\]]+)\]:\s*(.*)$"#
        let regex = try? NSRegularExpression(pattern: definitionPattern)
        var outputLines: [String] = []
        var footnotes: [Footnote] = []
        var activeFootnoteIndex: Int?

        for line in lines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex?.firstMatch(in: line, range: range),
               let idRange = Range(match.range(at: 1), in: line),
               let textRange = Range(match.range(at: 2), in: line) {
                let id = String(line[idRange])
                let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                footnotes.append(Footnote(id: id, number: footnotes.count + 1, text: text))
                activeFootnoteIndex = footnotes.count - 1
                continue
            }

            if let activeFootnoteIndex,
               line.hasPrefix("    ") || line.hasPrefix("\t") {
                let continuation = line.trimmingCharacters(in: .whitespaces)
                let existing = footnotes[activeFootnoteIndex]
                footnotes[activeFootnoteIndex] = Footnote(
                    id: existing.id,
                    number: existing.number,
                    text: [existing.text, continuation].filter { !$0.isEmpty }.joined(separator: " ")
                )
                continue
            }

            activeFootnoteIndex = nil
            outputLines.append(line)
        }

        return (outputLines.joined(separator: "\n"), footnotes)
    }

    static func accessibilitySummary(for document: Document, footnotes: [Footnote]) -> String {
        var features: [String] = []

        for child in document.children {
            collectAccessibilityFeatures(from: child, into: &features)
        }

        if !footnotes.isEmpty {
            features.append("footnotes")
        }

        return features.joined(separator: ",")
    }

    private static func collectAccessibilityFeatures(from markup: any Markup, into features: inout [String]) {
        if let item = markup as? ListItem, item.checkbox != nil {
            features.append("task-list")
        }

        if markup is CodeBlock {
            features.append("code-block")
        }

        if markup is Markdown.Image {
            features.append("image")
        }

        for child in markup.children {
            collectAccessibilityFeatures(from: child, into: &features)
        }
    }
}

enum MarkdownInlineRenderer {
    enum Segment {
        case text(NSAttributedString)
        case image(ImageSegment)
    }

    struct ImageSegment: Equatable {
        let source: String
        let altText: String

        var url: URL? {
            if let remoteURL = URL(string: source), remoteURL.scheme == "http" || remoteURL.scheme == "https" {
                return remoteURL
            }

            if source.hasPrefix("file://") {
                return URL(string: source)
            }

            if source.hasPrefix("/") {
                return URL(fileURLWithPath: source)
            }

            return nil
        }

        var localImage: NSImage? {
            guard let url, !url.isRemote else { return nil }
            return NSImage(contentsOf: url)
        }
    }

    static func segments(in container: any InlineContainer, footnoteReferences: [String: Int]) -> [Segment] {
        var segments: [Segment] = []
        var currentText = NSMutableAttributedString()

        func flushText() {
            guard currentText.length > 0 else { return }
            segments.append(.text(currentText))
            currentText = NSMutableAttributedString()
        }

        for child in container.inlineChildren {
            if let image = child as? Markdown.Image {
                flushText()
                segments.append(.image(ImageSegment(
                    source: image.source ?? "",
                    altText: image.plainText.isEmpty ? "Markdown image" : image.plainText
                )))
            } else {
                currentText.append(attributedString(for: child, footnoteReferences: footnoteReferences))
            }
        }

        flushText()
        return segments
    }

    static func attributedString(in container: any InlineContainer, footnoteReferences: [String: Int]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in container.inlineChildren {
            result.append(attributedString(for: child, footnoteReferences: footnoteReferences))
        }
        return result
    }

    private static func attributedString(for inline: any InlineMarkup, footnoteReferences: [String: Int]) -> NSAttributedString {
        switch inline {
        case let text as Markdown.Text:
            return attributedTextWithFootnotes(text.string, footnoteReferences: footnoteReferences)
        case is SoftBreak:
            return NSAttributedString(string: " ")
        case is LineBreak:
            return NSAttributedString(string: "\n")
        case let code as InlineCode:
            return NSAttributedString(string: code.code, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .backgroundColor: NSColor.controlBackgroundColor
            ])
        case let strong as Strong:
            let result = NSMutableAttributedString(attributedString: attributedString(in: strong, footnoteReferences: footnoteReferences))
            result.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize), range: NSRange(location: 0, length: result.length))
            return result
        case let emphasis as Emphasis:
            let result = NSMutableAttributedString(attributedString: attributedString(in: emphasis, footnoteReferences: footnoteReferences))
            result.addAttribute(.font, value: NSFontManager.shared.convert(NSFont.systemFont(ofSize: NSFont.systemFontSize), toHaveTrait: .italicFontMask), range: NSRange(location: 0, length: result.length))
            return result
        case let strikethrough as Strikethrough:
            let result = NSMutableAttributedString(attributedString: attributedString(in: strikethrough, footnoteReferences: footnoteReferences))
            result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: result.length))
            return result
        case let link as Markdown.Link:
            let result = NSMutableAttributedString(attributedString: attributedString(in: link, footnoteReferences: footnoteReferences))
            if let destination = link.destination, let url = URL(string: destination) {
                result.addAttributes([
                    NSAttributedString.Key.link: url,
                    NSAttributedString.Key.foregroundColor: NSColor.linkColor,
                    NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: NSRange(location: 0, length: result.length))
            }
            return result
        case let image as Markdown.Image:
            return NSAttributedString(string: image.plainText)
        default:
            return attributedTextWithFootnotes(inline.plainText, footnoteReferences: footnoteReferences)
        }
    }

    private static func attributedTextWithFootnotes(_ text: String, footnoteReferences: [String: Int]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let pattern = #"\[\^([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return NSAttributedString(string: text)
        }

        var currentIndex = text.startIndex
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: fullRange) {
            guard
                let matchRange = Range(match.range, in: text),
                let idRange = Range(match.range(at: 1), in: text)
            else { continue }

            if currentIndex < matchRange.lowerBound {
                result.append(NSAttributedString(string: String(text[currentIndex..<matchRange.lowerBound])))
            }

            let id = String(text[idRange])
            if let number = footnoteReferences[id] {
                result.append(NSAttributedString(string: "\(number)", attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .baselineOffset: 5,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]))
            } else {
                result.append(NSAttributedString(string: String(text[matchRange])))
            }

            currentIndex = matchRange.upperBound
        }

        if currentIndex < text.endIndex {
            result.append(NSAttributedString(string: String(text[currentIndex..<text.endIndex])))
        }

        return result
    }
}

enum SyntaxHighlightedCode {
    static func attributedString(for code: String, language: String?) -> AttributedString {
        AttributedString(nsAttributedString(for: code, language: language))
    }

    static func nsAttributedString(for code: String, language: String?) -> NSAttributedString {
        let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor
        ])
        let language = language?.lowercased()
        let patterns: [(String, NSColor)] = [
            (#""(?:\\.|[^"\\])*""#, NSColor.systemRed),
            (#"\b(?:let|var|func|struct|class|enum|if|else|for|while|return|import|case|switch|guard|in|try|await)\b"#, NSColor.systemPurple),
            (#"\b(?:true|false|nil|self)\b"#, NSColor.systemOrange),
            (#"//.*$"#, NSColor.secondaryLabelColor)
        ]

        guard language == nil || ["swift", "js", "javascript", "ts", "typescript", "json", "kotlin"].contains(language ?? "") else {
            return result
        }

        for (pattern, color) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
            let range = NSRange(location: 0, length: result.length)
            for match in regex.matches(in: code, range: range) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        return result
    }
}

private extension URL {
    var isRemote: Bool {
        scheme == "http" || scheme == "https"
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
    - [ ] Task item
    - [x] Done task

    1. Ordered item 1
    2. Ordered item 2
    3. Ordered item 3

    This supports ~~strikethrough~~ and footnotes.[^note]

    ![NotesDown image](missing-image.png)

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

    [^note]: Footnotes render at the bottom of the preview.
    """, scrollSync: ScrollSyncController())
        .frame(width: 600, height: 800)
}
