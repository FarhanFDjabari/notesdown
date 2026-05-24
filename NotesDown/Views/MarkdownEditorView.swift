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

        guard let textView = scrollView.documentView as? NSTextView else {
            return hostView
        }

        let colors = MarkdownEditorColors(appearance: textView.effectiveAppearance)
        scrollView.backgroundColor = colors.background
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = colors.text
        textView.insertionPointColor = colors.text
        textView.backgroundColor = colors.background
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

        func applyEditorColors() -> MarkdownEditorColors {
            guard let textView else {
                return MarkdownEditorColors(appearance: NSApp.effectiveAppearance)
            }

            let colors = MarkdownEditorColors(appearance: textView.effectiveAppearance)
            textView.textColor = colors.text
            textView.insertionPointColor = colors.text
            textView.backgroundColor = colors.background
            textView.enclosingScrollView?.backgroundColor = colors.background
            gutterView?.colors = colors
            return colors
        }

        func applyEditorAttributes() {
            guard let textView, let textStorage = textView.textStorage else { return }
            let colors = applyEditorColors()
            let selectedRange = textView.selectedRange()
            let baseFont = textView.font ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let wholeRange = NSRange(location: 0, length: textStorage.length)

            textView.undoManager?.disableUndoRegistration()
            textStorage.beginEditing()
            textStorage.setAttributes([
                .font: baseFont,
                .foregroundColor: colors.text
            ], range: wholeRange)

            MarkdownSyntaxHighlighter.apply(to: textStorage, font: baseFont, colors: colors.syntax)
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
                value: MarkdownEditorColors(appearance: textView.effectiveAppearance).currentLineHighlight,
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
    var colors = MarkdownEditorColors(appearance: NSApp.effectiveAppearance) {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("markdown-editor-line-number-gutter")
        setAccessibilityLabel("Line numbers")
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("markdown-editor-line-number-gutter")
        setAccessibilityLabel("Line numbers")
        setAccessibilityRole(.group)
    }

    override func accessibilityValue() -> Any? {
        visibleLineNumbers().map(String.init).joined(separator: ",")
    }

    override func draw(_ dirtyRect: NSRect) {
        colors.gutterBackground.setFill()
        dirtyRect.fill()

        for (lineNumber, lineRange) in visibleLineRanges() {
            if lineRange.length == 0 {
                drawLineNumber(lineNumber, y: textView?.textContainerInset.height ?? 0)
                continue
            }

            guard
                let textView,
                let layoutManager = textView.layoutManager
            else { continue }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = lineRect.minY + textView.textContainerOrigin.y - textView.visibleRect.minY
            drawLineNumber(lineNumber, y: y)
        }
    }

    private func drawLineNumber(_ lineNumber: Int, y: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: colors.gutterText,
            .paragraphStyle: paragraphStyle
        ]
        let string = "\(lineNumber)" as NSString
        let drawRect = NSRect(x: 0, y: y + 1, width: Self.width - 10, height: 16)
        string.draw(in: drawRect, withAttributes: attributes)
    }

    private func visibleLineNumbers() -> [Int] {
        visibleLineRanges().map(\.0)
    }

    private func visibleLineRanges() -> [(Int, NSRange)] {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return [] }

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        return lineRanges(in: textView.string as NSString, intersecting: characterRange)
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

    static func apply(to textStorage: NSTextStorage, font: NSFont, colors: SyntaxColors) {
        for token in tokens(in: textStorage.string) {
            guard token.range.location != NSNotFound, NSMaxRange(token.range) <= textStorage.length else { continue }
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: colors.color(for: token.kind)
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

struct SyntaxColors {
    let heading: NSColor
    let emphasis: NSColor
    let strong: NSColor
    let inlineCode: NSColor
    let link: NSColor
    let quote: NSColor
    let listMarker: NSColor
    let fencedCodeDelimiter: NSColor

    func color(for kind: MarkdownSyntaxHighlighter.TokenKind) -> NSColor {
        switch kind {
        case .heading:
            return heading
        case .emphasis:
            return emphasis
        case .strong:
            return strong
        case .inlineCode:
            return inlineCode
        case .link:
            return link
        case .quote:
            return quote
        case .listMarker:
            return listMarker
        case .fencedCodeDelimiter:
            return fencedCodeDelimiter
        }
    }
}

struct MarkdownEditorColors {
    let background: NSColor
    let text: NSColor
    let gutterBackground: NSColor
    let gutterText: NSColor
    let currentLineHighlight: NSColor
    let syntax: SyntaxColors

    init(appearance: NSAppearance) {
        let isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if isDarkMode {
            background = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
            text = NSColor(calibratedWhite: 0.92, alpha: 1)
            gutterBackground = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 1)
            gutterText = NSColor(calibratedWhite: 0.62, alpha: 1)
            currentLineHighlight = NSColor(calibratedWhite: 1, alpha: 0.08)
            syntax = SyntaxColors(
                heading: NSColor(calibratedRed: 0.48, green: 0.70, blue: 1.00, alpha: 1),
                emphasis: NSColor(calibratedRed: 1.00, green: 0.56, blue: 0.78, alpha: 1),
                strong: NSColor(calibratedRed: 1.00, green: 0.70, blue: 0.36, alpha: 1),
                inlineCode: NSColor(calibratedRed: 0.78, green: 0.62, blue: 1.00, alpha: 1),
                link: NSColor(calibratedRed: 0.35, green: 0.82, blue: 0.88, alpha: 1),
                quote: NSColor(calibratedRed: 0.48, green: 0.84, blue: 0.52, alpha: 1),
                listMarker: NSColor(calibratedRed: 0.82, green: 0.66, blue: 0.48, alpha: 1),
                fencedCodeDelimiter: NSColor(calibratedWhite: 0.68, alpha: 1)
            )
        } else {
            background = NSColor(calibratedWhite: 1, alpha: 1)
            text = NSColor(calibratedWhite: 0.08, alpha: 1)
            gutterBackground = NSColor(calibratedWhite: 0.95, alpha: 1)
            gutterText = NSColor(calibratedWhite: 0.42, alpha: 1)
            currentLineHighlight = NSColor(calibratedRed: 0.18, green: 0.43, blue: 0.86, alpha: 0.10)
            syntax = SyntaxColors(
                heading: NSColor(calibratedRed: 0.03, green: 0.32, blue: 0.72, alpha: 1),
                emphasis: NSColor(calibratedRed: 0.68, green: 0.12, blue: 0.42, alpha: 1),
                strong: NSColor(calibratedRed: 0.70, green: 0.34, blue: 0.00, alpha: 1),
                inlineCode: NSColor(calibratedRed: 0.38, green: 0.18, blue: 0.70, alpha: 1),
                link: NSColor(calibratedRed: 0.00, green: 0.42, blue: 0.48, alpha: 1),
                quote: NSColor(calibratedRed: 0.14, green: 0.50, blue: 0.20, alpha: 1),
                listMarker: NSColor(calibratedRed: 0.48, green: 0.32, blue: 0.12, alpha: 1),
                fencedCodeDelimiter: NSColor(calibratedWhite: 0.46, alpha: 1)
            )
        }
    }
}

#Preview {
    MarkdownEditorView(text: .constant("# Hello World\n\nThis is a **markdown** editor."))
        .frame(width: 400, height: 600)
}
