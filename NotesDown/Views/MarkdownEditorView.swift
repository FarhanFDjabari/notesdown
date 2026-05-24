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

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let initialSize = NSSize(width: 600, height: 400)
        let textView = HighlightingMarkdownTextView(frame: NSRect(origin: .zero, size: initialSize))
        textView.string = text
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
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
        textView.textContainer?.containerSize = NSSize(width: initialSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        context.coordinator.textView = textView
        context.coordinator.applyEditorAttributes()

        scrollView.documentView = textView
        let rulerView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        context.coordinator.rulerView = rulerView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textViewBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        textView.updateLineHighlight()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parentText = $text
        guard let textView = context.coordinator.textView else { return }

        context.coordinator.updateTextViewLayout(in: scrollView)

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
        weak var textView: HighlightingMarkdownTextView?
        weak var rulerView: LineNumberRulerView?
        var isUpdatingFromSwiftUI = false

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
            textView?.updateLineHighlight()
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
            rulerView?.needsDisplay = true
        }

        func updateTextViewLayout(in scrollView: NSScrollView) {
            guard let textView, let textContainer = textView.textContainer else { return }

            let contentWidth = max(scrollView.contentSize.width, 1)
            textView.frame.size.width = contentWidth
            textContainer.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
            textView.layoutManager?.ensureLayout(for: textContainer)
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
                .foregroundColor: NSColor.textColor
            ], range: wholeRange)

            MarkdownSyntaxHighlighter.apply(to: textStorage, font: baseFont)
            textStorage.endEditing()
            textView.undoManager?.enableUndoRegistration()

            textView.setSelectedRange(selectedRange.clamped(toLength: textStorage.length))
            textView.updateLineHighlight()
            rulerView?.needsDisplay = true
        }
    }
}

private final class HighlightingMarkdownTextView: NSTextView {
    private var highlightedLineRange: NSRange?

    override func setSelectedRange(_ charRange: NSRange) {
        super.setSelectedRange(charRange)
        updateLineHighlight()
    }

    override func didChangeText() {
        super.didChangeText()
        updateLineHighlight()
    }

    func updateLineHighlight() {
        guard let layoutManager, let textStorage else { return }

        if let highlightedLineRange {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: highlightedLineRange)
        }

        let string = textStorage.string as NSString
        let location = min(selectedRange().location, string.length)
        let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
        highlightedLineRange = lineRange

        layoutManager.addTemporaryAttribute(
            .backgroundColor,
            value: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.18),
            forCharacterRange: lineRange
        )
    }
}

private final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let gutterWidth: CGFloat = 48

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = gutterWidth
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        rect.fill()

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
        let drawRect = NSRect(x: 0, y: y + 1, width: gutterWidth - 10, height: 16)
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

#Preview {
    MarkdownEditorView(text: .constant("# Hello World\n\nThis is a **markdown** editor."))
        .frame(width: 400, height: 600)
}
