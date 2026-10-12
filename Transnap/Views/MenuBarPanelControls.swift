//
//  MenuBarPanelControls.swift
//  Transnap
//
//  Created by Codex on 2026/5/10.
//

import AppKit
import SwiftUI

struct HeaderLanguageMenuButton: View {
    let title: String
    let selection: String
    let displayLanguage: DisplayLanguage
    let onSelect: (String) -> Void

    var body: some View {
        HeaderLanguagePopupButton(
            title: title,
            selection: selection,
            displayLanguage: displayLanguage,
            onSelect: onSelect
        )
        .frame(height: 18)
    }
}

private struct HeaderLanguagePopupButton: NSViewRepresentable {
    let title: String
    let selection: String
    let displayLanguage: DisplayLanguage
    let onSelect: (String) -> Void

    func makeNSView(context: Context) -> HeaderLanguagePopupNSButton {
        HeaderLanguagePopupNSButton()
    }

    func updateNSView(_ nsView: HeaderLanguagePopupNSButton, context: Context) {
        nsView.configure(
            title: title,
            selection: selection,
            displayLanguage: displayLanguage,
            onSelect: onSelect
        )
    }
}

private final class HeaderLanguagePopupNSButton: NSControl {
    private let titleLabel = NSTextField(labelWithString: "")
    private let chevronImageView = NSImageView()
    private var selection = TranslationLanguageOptions.automaticIdentifier
    private var displayLanguage: DisplayLanguage = .simplifiedChinese
    private var onSelect: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byClipping
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevronImageView.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        chevronImageView.symbolConfiguration = .init(pointSize: 8, weight: .semibold)
        chevronImageView.contentTintColor = .secondaryLabelColor
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stackView = NSStackView(views: [titleLabel, chevronImageView])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 8),
            chevronImageView.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let width = titleLabel.intrinsicContentSize.width + 4 + 8
        return NSSize(width: ceil(width), height: 18)
    }

    func configure(
        title: String,
        selection: String,
        displayLanguage: DisplayLanguage,
        onSelect: @escaping (String) -> Void
    ) {
        self.selection = selection
        self.displayLanguage = displayLanguage
        self.onSelect = onSelect
        titleLabel.stringValue = title
        invalidateIntrinsicContentSize()
    }

    override func mouseDown(with event: NSEvent) {
        showLanguageMenu()
    }

    private func showLanguageMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for option in TranslationLanguageOptions.all {
            let item = NSMenuItem(
                title: option.title(in: displayLanguage),
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = option.identifier
            item.state = selection == option.identifier ? .on : .off
            menu.addItem(item)
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 2), in: self)
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        onSelect?(identifier)
    }
}

struct CompactLanguageMenuButton: View {
    let title: String
    let selection: String
    let displayLanguage: DisplayLanguage
    let onSelect: (String) -> Void

    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(TranslationLanguageOptions.all) { option in
                Button {
                    onSelect(option.identifier)
                } label: {
                    if selection == option.identifier {
                        Label(option.title(in: displayLanguage), systemImage: "checkmark")
                    } else {
                        Text(option.title(in: displayLanguage))
                    }
                }
            }
        } label: {
            Text(title)
                .lineLimit(1)
                .font(.system(size: 10, weight: isHovering ? .semibold : .medium))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(isHovering ? Color.accentColor.opacity(0.13) : Color.clear)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(isHovering ? Color.accentColor.opacity(0.36) : Color.clear, lineWidth: 1)
                }
                .scaleEffect(isHovering ? 1.04 : 1)
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var labelColor: Color {
        if isHovering {
            return .accentColor
        }

        return selection == "auto" ? .secondary : .primary.opacity(0.72)
    }
}

@available(macOS 15.0, *)
struct PanelBackgroundView: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Group {
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
            } else {
                shape
                    .fill(Color.white.opacity(0.58))
                    .background(.regularMaterial, in: shape)
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    }
            }
        }
    }
}

struct ResizeCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                ResizeCursor.shared.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private enum ResizeCursor {
    static let shared: NSCursor = .resizeUpDown
}

enum HeaderPopoverHint: String {
    case history
    case settings
    case quit
}

struct HeaderIconButton: View {
    let hint: HeaderPopoverHint
    @ObservedObject var settingsStore: SettingsStore
    let systemName: String
    let hoverTint: Color
    let title: String
    let message: String
    let action: () -> Void

    @State private var isHovering = false
    @State private var isShowingPopover = false
    @State private var hidePopoverWorkItem: DispatchWorkItem?

    var body: some View {
        Button {
            hidePopover()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: isHovering ? .semibold : .medium))
                .foregroundStyle(isHovering ? hoverTint : .secondary)
                .frame(width: 28, height: 28)
                .background(backgroundShape)
                .overlay(borderShape)
                .scaleEffect(isHovering ? 1.08 : 1)
                .shadow(color: isHovering ? hoverTint.opacity(0.18) : .clear, radius: 7, y: 2)
        }
        .buttonStyle(HeaderIconPressButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(title)
        .accessibilityHint(message)
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
            HeaderIconPopover(message: message)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
            updatePopoverVisibility(for: hovering)
        }
    }

    private func updatePopoverVisibility(for hovering: Bool) {
        hidePopoverWorkItem?.cancel()

        guard hovering else {
            hidePopover()
            return
        }
        guard settingsStore.shouldShowInterfaceHint(hint.rawValue) else { return }

        isShowingPopover = true
        settingsStore.recordInterfaceHintShown(hint.rawValue)

        let hideWorkItem = DispatchWorkItem {
            isShowingPopover = false
        }
        hidePopoverWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: hideWorkItem)
    }

    private func hidePopover() {
        hidePopoverWorkItem?.cancel()
        isShowingPopover = false
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isHovering ? hoverTint.opacity(0.14) : Color.black.opacity(0.05))
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(isHovering ? hoverTint.opacity(0.42) : Color.clear, lineWidth: 1)
    }
}

private struct HeaderIconPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(
                .interactiveSpring(response: 0.22, dampingFraction: 0.72, blendDuration: 0.08),
                value: configuration.isPressed
            )
    }
}

private struct HeaderIconPopover: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
        .presentationBackground(Color.black.opacity(0.92))
    }
}
