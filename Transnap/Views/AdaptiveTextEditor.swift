//
//  AdaptiveTextEditor.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import AppKit
import SwiftUI

struct AdaptiveTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    let minLines: Int
    let maxLines: Int
    var onTextChange: ((String) -> Void)? = nil
    var onContentPresenceChange: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            dynamicHeight: $dynamicHeight,
            minLines: minLines,
            maxLines: maxLines,
            onTextChange: onTextChange,
            onContentPresenceChange: onContentPresenceChange
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.makeScrollView()
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(scrollView: nsView, text: text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var dynamicHeight: CGFloat
        private let minLines: Int
        private let maxLines: Int
        private let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        private let onTextChange: ((String) -> Void)?
        private let onContentPresenceChange: ((Bool) -> Void)?

        init(
            text: Binding<String>,
            dynamicHeight: Binding<CGFloat>,
            minLines: Int,
            maxLines: Int,
            onTextChange: ((String) -> Void)?,
            onContentPresenceChange: ((Bool) -> Void)?
        ) {
            _text = text
            _dynamicHeight = dynamicHeight
            self.minLines = minLines
            self.maxLines = maxLines
            self.onTextChange = onTextChange
            self.onContentPresenceChange = onContentPresenceChange
        }

        func makeScrollView() -> NSScrollView {
            let scrollView = NSScrollView()
            scrollView.drawsBackground = false
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true

            let textView = PlaceholderAwareTextView()
            textView.delegate = self
            textView.onMarkedTextStateChange = { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.notifyContentPresence(for: textView)
            }
            textView.isRichText = false
            textView.importsGraphics = false
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticDataDetectionEnabled = false
            textView.font = font
            textView.backgroundColor = .clear
            textView.drawsBackground = false
            textView.textContainerInset = NSSize(width: 4, height: 8)
            textView.textContainer?.lineFragmentPadding = 0
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
            textView.string = text

            scrollView.documentView = textView
            DispatchQueue.main.async {
                self.recalculateHeight(for: scrollView)
            }
            return scrollView
        }

        func update(scrollView: NSScrollView, text: String) {
            guard let textView = scrollView.documentView as? NSTextView else { return }

            if !textView.hasMarkedText(), textView.string != text {
                textView.string = text
            }

            recalculateHeight(for: scrollView)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            onTextChange?(textView.string)
            notifyContentPresence(for: textView)

            if let scrollView = textView.enclosingScrollView {
                recalculateHeight(for: scrollView)
            }
        }

        private func notifyContentPresence(for textView: NSTextView) {
            onContentPresenceChange?(!textView.string.isEmpty || textView.hasMarkedText())
        }

        private func recalculateHeight(for scrollView: NSScrollView) {
            guard let textView = scrollView.documentView as? NSTextView,
                  let textContainer = textView.textContainer,
                  let layoutManager = textView.layoutManager else {
                return
            }

            layoutManager.ensureLayout(for: textContainer)

            let contentHeight = layoutManager.usedRect(for: textContainer).height
            let verticalInsets = textView.textContainerInset.height * 2
            let lineHeight = font.ascender - font.descender + font.leading
            let minHeight = CGFloat(minLines) * lineHeight + verticalInsets
            let maxHeight = CGFloat(maxLines) * lineHeight + verticalInsets
            let desiredHeight = min(max(contentHeight + verticalInsets, minHeight), maxHeight)

            scrollView.hasVerticalScroller = false

            if abs(dynamicHeight - desiredHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.dynamicHeight = desiredHeight
                }
            }
        }
    }
}

private final class PlaceholderAwareTextView: NSTextView {
    var onMarkedTextStateChange: (() -> Void)?

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        onMarkedTextStateChange?()
    }

    override func unmarkText() {
        super.unmarkText()
        onMarkedTextStateChange?()
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        super.insertText(insertString, replacementRange: replacementRange)
        onMarkedTextStateChange?()
    }
}
