import AppKit
import SwiftUI

struct MarkdownEditorView: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Editor")
                .font(.headline)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))

            MarkdownTextView(text: $text)
                .background(Color(NSColor.textBackgroundColor))
        }
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> MarkdownEditorHostView {
        let hostView = MarkdownEditorHostView()
        let scrollView = hostView.scrollView
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        guard let textView = scrollView.documentView as? NSTextView else {
            return hostView
        }

        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .editorForegroundColor
        textView.insertionPointColor = .editorForegroundColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.enabledTextCheckingTypes = 0
        textView.setAccessibilityIdentifier("markdown-editor-text-view")
        textView.string = text
        textView.textContainer?.containerSize = NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        context.coordinator.textView = textView
        context.coordinator.applyEditorAttributes()

        hostView.gutterView.textView = textView
        context.coordinator.gutterView = hostView.gutterView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textViewBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.updateLineHighlight()
        return hostView
    }

    func updateNSView(_ hostView: MarkdownEditorHostView, context: Context) {
        context.coordinator.parentText = $text
        guard let textView = context.coordinator.textView else { return }

        if textView.string != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, (text as NSString).length), length: 0))
            context.coordinator.isUpdatingFromSwiftUI = false
        }

        context.coordinator.applyEditorAttributes()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parentText: Binding<String>
        weak var textView: NSTextView?
        weak var gutterView: LineNumberGutterView?
        var isUpdatingFromSwiftUI = false
        private var highlightedLineRange: NSRange?

        init(text: Binding<String>) {
            self.parentText = text
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, !isUpdatingFromSwiftUI else { return }
            parentText.wrappedValue = textView.string
            applyEditorAttributes()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateLineHighlight()
        }

        func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.insertText("    ", replacementRange: textView.selectedRange())
                return true
            }

            return false
        }

        @objc func textViewBoundsDidChange(_ notification: Notification) {
            gutterView?.needsDisplay = true
        }

        func applyEditorAttributes() {
            guard let textView, let textStorage = textView.textStorage else { return }
            let selectedRange = textView.selectedRange()
            let baseFont = textView.font ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let wholeRange = NSRange(location: 0, length: textStorage.length)

            textView.undoManager?.disableUndoRegistration()
            textStorage.beginEditing()
            textStorage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.editorForegroundColor
            ], range: wholeRange)

            MarkdownSyntaxHighlighter.apply(to: textStorage, font: baseFont)
            textStorage.endEditing()
            textView.undoManager?.enableUndoRegistration()

            textView.setSelectedRange(selectedRange.clamped(toLength: textStorage.length))
            updateLineHighlight()
            gutterView?.needsDisplay = true
        }

        func updateLineHighlight() {
            guard let textView, let layoutManager = textView.layoutManager, let textStorage = textView.textStorage else { return }

            if let highlightedLineRange {
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: highlightedLineRange)
            }

            let string = textStorage.string as NSString
            let location = min(textView.selectedRange().location, string.length)
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            highlightedLineRange = lineRange

            layoutManager.addTemporaryAttribute(
                .backgroundColor,
                value: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.18),
                forCharacterRange: lineRange
            )
        }
    }
}

private final class MarkdownEditorHostView: NSView {
    let gutterView = LineNumberGutterView()
    let scrollView: NSScrollView

    override init(frame frameRect: NSRect) {
        scrollView = NSTextView.scrollableTextView()
        super.init(frame: frameRect)
        addSubview(gutterView)
        addSubview(scrollView)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let gutterWidth = LineNumberGutterView.width
        gutterView.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
        scrollView.frame = NSRect(x: gutterWidth, y: 0, width: max(bounds.width - gutterWidth, 0), height: bounds.height)
    }
}

private final class LineNumberGutterView: NSView {
    static let width: CGFloat = 48
    weak var textView: NSTextView?

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return }

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let lineRanges = lineRanges(in: textView.string as NSString, intersecting: characterRange)

        for (lineNumber, lineRange) in lineRanges {
            if lineRange.length == 0 {
                drawLineNumber(lineNumber, y: textView.textContainerInset.height)
                continue
            }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = lineRect.minY + textView.textContainerOrigin.y - visibleRect.minY
            drawLineNumber(lineNumber, y: y)
        }
    }

    private func drawLineNumber(_ lineNumber: Int, y: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]
        let string = "\(lineNumber)" as NSString
        let drawRect = NSRect(x: 0, y: y + 1, width: Self.width - 10, height: 16)
        string.draw(in: drawRect, withAttributes: attributes)
    }

    private func lineRanges(in string: NSString, intersecting range: NSRange) -> [(Int, NSRange)] {
        var results: [(Int, NSRange)] = []
        var lineNumber = 1
        var location = 0

        while location < string.length {
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            if NSIntersectionRange(lineRange, range).length > 0 {
                results.append((lineNumber, lineRange))
            } else if !results.isEmpty {
                break
            }

            location = NSMaxRange(lineRange)
            lineNumber += 1
        }

        if string.length == 0 {
            results.append((1, NSRange(location: 0, length: 0)))
        }

        return results
    }
}

struct MarkdownSyntaxHighlighter {
    enum TokenKind: CaseIterable {
        case heading
        case emphasis
        case strong
        case inlineCode
        case link
        case quote
        case listMarker
        case fencedCodeDelimiter
    }

    struct Token: Equatable {
        let kind: TokenKind
        let range: NSRange
    }

    static func tokens(in markdown: String) -> [Token] {
        let patterns: [(TokenKind, String)] = [
            (.heading, #"^#{1,6}\s+.*$"#),
            (.quote, #"^>\s?.*$"#),
            (.listMarker, #"^\s*(?:[-*+]|\d+\.)\s+"#),
            (.fencedCodeDelimiter, #"^```.*$"#),
            (.strong, #"(?s)(?:\*\*|__)(.+?)(?:\*\*|__)"#),
            (.emphasis, #"(?s)(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#),
            (.inlineCode, #"`[^`\n]+`"#),
            (.link, #"\[[^\]\n]+\]\([^)]+\)"#)
        ]

        return patterns.flatMap { kind, pattern in
            matches(for: pattern, in: markdown).map { Token(kind: kind, range: $0) }
        }
    }

    static func apply(to textStorage: NSTextStorage, font: NSFont) {
        let colors: [TokenKind: NSColor] = [
            .heading: .systemBlue,
            .emphasis: .systemPink,
            .strong: .systemOrange,
            .inlineCode: .systemPurple,
            .link: .systemTeal,
            .quote: .systemGreen,
            .listMarker: .systemBrown,
            .fencedCodeDelimiter: .secondaryLabelColor
        ]

        for token in tokens(in: textStorage.string) {
            guard token.range.location != NSNotFound, NSMaxRange(token.range) <= textStorage.length else { continue }
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: colors[token.kind] ?? NSColor.textColor
            ]

            switch token.kind {
            case .heading, .strong:
                attributes[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            case .emphasis:
                attributes[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            default:
                break
            }

            textStorage.addAttributes(attributes, range: token.range)
        }
    }

    private static func matches(for pattern: String, in markdown: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }

        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        return regex.matches(in: markdown, range: range).map(\.range)
    }
}

private extension NSRange {
    func clamped(toLength length: Int) -> NSRange {
        guard location <= length else {
            return NSRange(location: length, length: 0)
        }

        return NSRange(location: location, length: min(self.length, length - location))
    }
}

private extension NSColor {
    static var editorForegroundColor: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
    }
}

#Preview {
    MarkdownEditorView(text: .constant("# Hello World\n\nThis is a **markdown** editor."))
        .frame(width: 400, height: 600)
}
