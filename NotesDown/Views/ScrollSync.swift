import AppKit
import SwiftUI

/// Keeps the AppKit editor and the SwiftUI preview aligned by scroll fraction.
///
/// The editor is an `NSScrollView`; the preview is a SwiftUI `ScrollView`. Each
/// side reports its 0...1 vertical fraction when it scrolls and the other side
/// is moved to match. Because the preview reacts asynchronously, echoes are
/// suppressed by remembering the fraction we just applied and ignoring the
/// change notification that mirrors it.
@MainActor
final class ScrollSyncController: ObservableObject {
    /// Target the preview should scroll to, published so the SwiftUI preview can
    /// apply it through its `ScrollPosition` binding.
    @Published private(set) var previewTarget: PreviewTarget?

    struct PreviewTarget: Equatable {
        let id = UUID()
        let y: CGFloat
    }

    private weak var editorScroll: NSScrollView?
    private var previewContentHeight: CGFloat = 0
    private var previewContainerHeight: CGFloat = 0

    private var expectedPreviewFraction: CGFloat?
    private var expectedEditorFraction: CGFloat?

    private static let epsilon: CGFloat = 0.002

    // MARK: Editor

    func registerEditor(_ scrollView: NSScrollView) {
        editorScroll = scrollView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func editorDidScroll() {
        guard let editorScroll else { return }
        let fraction = scrollFraction(of: editorScroll)

        if let expected = expectedEditorFraction, abs(expected - fraction) < Self.epsilon {
            expectedEditorFraction = nil
            return
        }

        expectedPreviewFraction = fraction
        let scrollable = max(previewContentHeight - previewContainerHeight, 0)
        previewTarget = PreviewTarget(y: fraction * scrollable)
    }

    // MARK: Preview

    func previewGeometryChanged(offsetY: CGFloat, contentHeight: CGFloat, containerHeight: CGFloat) {
        previewContentHeight = contentHeight
        previewContainerHeight = containerHeight

        let scrollable = max(contentHeight - containerHeight, 1)
        let fraction = max(0, min(1, offsetY / scrollable))

        if let expected = expectedPreviewFraction, abs(expected - fraction) < Self.epsilon {
            expectedPreviewFraction = nil
            return
        }

        guard let editorScroll else { return }
        expectedEditorFraction = fraction
        setScrollFraction(fraction, on: editorScroll)
    }

    // MARK: Fraction helpers

    private func scrollFraction(of scrollView: NSScrollView) -> CGFloat {
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let visibleHeight = scrollView.contentView.bounds.height
        let scrollable = max(documentHeight - visibleHeight, 1)
        return max(0, min(1, scrollView.contentView.bounds.origin.y / scrollable))
    }

    private func setScrollFraction(_ fraction: CGFloat, on scrollView: NSScrollView) {
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let visibleHeight = scrollView.contentView.bounds.height
        let scrollable = max(documentHeight - visibleHeight, 0)
        let point = NSPoint(x: scrollView.contentView.bounds.origin.x, y: scrollable * fraction)
        scrollView.contentView.scroll(to: point)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
