//
//  SettingsTabs.swift
//  Transnap
//
//  Created by Codex on 2026/5/10.
//

import AppKit
import SwiftUI
import Translation

struct OfflineSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var offlineLanguageManager = OfflineLanguageManager()

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(settingsStore.text("系统语言包", "System Language Packs"))
                        Text(settingsStore.text("离线翻译语言包由 Apple 官方提供和管理。删除已下载语言包需要前往系统设置。", "Offline translation language packs are provided by Apple. To delete downloaded packs, open System Settings."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    Button {
                        openSystemTranslationLanguageSettings()
                    } label: {
                        Label(settingsStore.text("打开系统设置", "Open System Settings"), systemImage: "arrow.up.right.square")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .settingsHoverEffect(tint: .accentColor)
                    .fixedSize()
                }
                .frame(minHeight: 54, alignment: .center)
            } header: {
                Text(settingsStore.text("关于离线语言包", "About Offline Language Packs"))
            }

            Section {
                if offlineLanguageManager.packs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text(settingsStore.text("当前没有可下载的语言包。", "No downloadable language packs are available."))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                }

                ForEach(offlineLanguageManager.packs) { pack in
                    LabeledContent {
                        actionButton(for: pack.identifier)
                            .padding(.vertical, 4) // Added padding to the button container for better spacing
                    } label: {
                        Text(TranslationLanguageOptions.title(for: pack.identifier, in: settingsStore.displayLanguage))
                            .padding(.vertical, 8) // Ensure row height is sufficient
                    }
                }
            } header: {
                Text(settingsStore.text("离线语言包", "Offline Language Packs"))
            } footer: {
                Text(settingsStore.text(
                    "下载后可离线翻译。已下载语言包可在 macOS 系统设置中管理。位置：系统设置 > 通用 > 语言与地区 > 翻译语言。",
                    "After downloading, translation works offline. Downloaded packs can be managed in macOS System Settings (Path: System Settings > General > Language & Region > Translation Languages)."
                ))
            }

            if let lastErrorMessage = offlineLanguageManager.lastErrorMessage {
                Section {
                    Label(lastErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await offlineLanguageManager.refreshStatuses()
        }
        .translationTask(offlineLanguageManager.pendingConfiguration) { session in
            await offlineLanguageManager.performPendingInstall(using: session)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }

            Task {
                await offlineLanguageManager.refreshStatuses()
            }
        }
    }

    @ViewBuilder
    private func actionButton(for identifier: String) -> some View {
        let status = offlineLanguageManager.statuses[identifier] ?? .unsupported
        let isInstalling = offlineLanguageManager.isInstalling(identifier)

        switch status {
        case .installed:
            packStatusLabel(
                settingsStore.text("已下载", "Downloaded"),
                systemImage: "checkmark.circle.fill",
                tint: .green
            )

        case .supported:
            Button {
                offlineLanguageManager.requestInstall(for: identifier)
            } label: {
                packStatusLabel(
                    isInstalling ? settingsStore.text("下载中", "Downloading") : settingsStore.text("下载", "Download"),
                    systemImage: isInstalling ? nil : "icloud.and.arrow.down",
                    tint: .accentColor,
                    isLoading: isInstalling
                )
            }
            .buttonStyle(.plain)
            .settingsHoverEffect(tint: .accentColor, isEnabled: !isInstalling)
            .disabled(isInstalling)

        case .unsupported:
            packStatusLabel(
                settingsStore.text("不支持", "Unsupported"),
                systemImage: "xmark.circle",
                tint: .secondary
            )
        @unknown default:
            packStatusLabel(
                settingsStore.text("状态未知", "Unknown"),
                systemImage: "questionmark.circle",
                tint: .secondary
            )
        }
    }

    private func packStatusLabel(
        _ title: String,
        systemImage: String?,
        tint: Color,
        isLoading: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 4) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else if let systemImage {
                Image(systemName: systemImage)
            }

            Text(title)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(tint)
        .frame(minWidth: 76)
        .padding(.horizontal, 10)
        .padding(.vertical, 7) // Increased from 4
        .background(tint.opacity(0.1), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        }
        .fixedSize()
    }

    private func openSystemTranslationLanguageSettings() {
        let urlStrings = [
            "x-apple.systempreferences:com.apple.Localization-Settings.extension?translation",
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
            "x-apple.systempreferences:com.apple.Localization"
        ]

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        offlineLanguageManager.lastErrorMessage = settingsStore.text(
            "无法打开系统设置，请手动前往“系统设置 > 通用 > 语言与地区 > 翻译语言”。",
            "Could not open System Settings. Go to System Settings > General > Language & Region > Translation Languages."
        )
    }
}

struct AboutSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var hoveredLink: AboutLink?
    @State private var isFeedbackHovered = false
    @State private var isFeedbackPopoverHovered = false
    @State private var isFeedbackPopoverPresented = false
    @State private var isFeedbackEmailCopied = false
    private let feedbackEmail = "deepseals@icloud.com"

    private enum AboutLink: Hashable {
        case agreement, privacy, terms
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)

            VStack(spacing: 8) {
                Text("Transnap")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text(settingsStore.text("完全免费，纯本地翻译", "Completely free. Translation stays on your Mac."))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Text("\(settingsStore.text("版本", "Version")) \(version) (\(build))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 12) {
                    Button {
                        sendFeedback()
                    } label: {
                        Label(settingsStore.text("反馈问题", "Send Feedback"), systemImage: "envelope.fill")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                    .onHover { hovering in
                        isFeedbackHovered = hovering
                        if hovering {
                            isFeedbackPopoverPresented = true
                        } else {
                            dismissFeedbackPopoverAfterHover()
                        }
                    }
                    .popover(isPresented: $isFeedbackPopoverPresented, arrowEdge: .bottom) {
                        HStack(spacing: 10) {
                            Text(feedbackEmail)
                            Button {
                                NSPasteboard.general.clearContents()
                                isFeedbackEmailCopied = NSPasteboard.general.setString(feedbackEmail, forType: .string)
                            } label: {
                                Image(systemName: isFeedbackEmailCopied ? "checkmark" : "doc.on.doc")
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .help(settingsStore.text("复制邮箱", "Copy Email"))
                            .accessibilityLabel(settingsStore.text("复制邮箱", "Copy Email"))
                        }
                        .font(.system(size: 13))
                        .padding(12)
                        .onHover { hovering in
                            isFeedbackPopoverHovered = hovering
                            if !hovering { dismissFeedbackPopoverAfterHover() }
                        }
                        .onDisappear {
                            isFeedbackPopoverHovered = false
                            isFeedbackEmailCopied = false
                        }
                    }

                    Link(destination: URL(string: "https://x.com/invisilab_x")!) {
                        socialLinkLabel(logo: "XLogo", color: .primary, logoWidth: 14)
                            .accessibilityLabel("X")
                    }
                    Button {
                        openXiaohongshu()
                    } label: {
                        socialLinkLabel(
                            logo: "XiaohongshuLogo",
                            color: Color(red: 1, green: 36.0 / 255, blue: 66.0 / 255),
                            logoWidth: 36
                        )
                        .accessibilityLabel(settingsStore.text("小红书", "Xiaohongshu"))
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(spacing: 8) {
                Text("© 2026 Transnap Team")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)

                HStack(spacing: 4) {
                    Link(destination: URL(string: "https://maxc.cc/user-agreement/")!) {
                        linkLabel(settingsStore.text("用户协议", "User Agreement"), link: .agreement)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredLink = hovering ? .agreement : (hoveredLink == .agreement ? nil : hoveredLink)
                    }

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Link(destination: URL(string: "https://maxc.cc/privacy-policy/")!) {
                        linkLabel(settingsStore.text("隐私政策", "Privacy Policy"), link: .privacy)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredLink = hovering ? .privacy : (hoveredLink == .privacy ? nil : hoveredLink)
                    }

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Link(destination: URL(string: "https://maxc.cc/terms-of-use/")!) {
                        linkLabel(settingsStore.text("使用条款", "Terms"), link: .terms)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredLink = hovering ? .terms : (hoveredLink == .terms ? nil : hoveredLink)
                    }

                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .animation(.easeOut(duration: 0.14), value: hoveredLink)
            }
        }
        .padding(.bottom, 30)
    }

    private func linkLabel(_ title: String, link: AboutLink) -> some View {
        let isHovering = hoveredLink == link
        
        return HStack(spacing: 3) {
            Text(title)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(isHovering ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Color.accentColor.opacity(isHovering ? 0.11 : 0),
            in: Capsule()
        )
    }

    private func socialLinkLabel(logo: String, color: Color, logoWidth: CGFloat) -> some View {
        HStack(spacing: 7) {
            Image(logo)
                .resizable()
                .scaledToFit()
                .frame(width: logoWidth, height: 14)
                .foregroundStyle(color)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minWidth: 76)
        .frame(height: 32)
        .background(Color.primary.opacity(0.04), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        .contentShape(Capsule())
    }

    private func dismissFeedbackPopoverAfterHover() {
        // Allow the pointer to cross the gap between the button and popover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !isFeedbackHovered && !isFeedbackPopoverHovered {
                isFeedbackPopoverPresented = false
            }
        }
    }

    private func sendFeedback() {
        let subject = "Transnap Feedback (v\(version) build \(build))"
        let body = """
        Please describe the issue here:


        ----
        App Version: \(version) (\(build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Preferred Language: \(settingsStore.displayLanguage.rawValue)
        Appearance: \(settingsStore.appearance.rawValue)
        Shortcut: \(settingsStore.shortcutDisplayString)
        History Limit: \(settingsStore.historyLimit)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func openXiaohongshu() {
        let appUrl = URL(string: "xhsdiscover://user/5777e1583460946ad6894dc4")!
        let webUrl = URL(string: "https://xhslink.com/m/9T8pXxjXBQk")!

        if NSWorkspace.shared.urlForApplication(toOpen: appUrl) != nil {
            NSWorkspace.shared.open(appUrl)
        } else {
            NSWorkspace.shared.open(webUrl)
        }
    }
}

struct SettingsSwitch: View {
    @Binding var isOn: Bool
    let accessibilityLabel: String
    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(trackColor)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(isOn ? 0.04 : 0.08), lineWidth: 0.5)
                    }

                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .padding(2)
            }
            .frame(width: 42, height: 24)
            .contentShape(Capsule())
            .scaleEffect(isHovering ? 1.05 : 1)
            .shadow(color: (isOn ? Color.accentColor : Color.black).opacity(isHovering ? 0.18 : 0), radius: 5, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var trackColor: Color {
        if isOn {
            Color.accentColor.opacity(isHovering ? 0.94 : 1)
        } else {
            Color(nsColor: .quaternaryLabelColor).opacity(isHovering ? 0.88 : 0.65)
        }
    }
}

struct SettingsHoverEffect: ViewModifier {
    let tint: Color
    let isEnabled: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .brightness(isEnabled && isHovering ? 0.025 : 0)
            .scaleEffect(isEnabled && isHovering ? 1.018 : 1)
            .shadow(color: tint.opacity(isEnabled && isHovering ? 0.16 : 0), radius: 7, y: 2)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { hovering in
                isHovering = hovering && isEnabled
            }
    }
}

extension View {
    func settingsHoverEffect(tint: Color = .accentColor, isEnabled: Bool = true) -> some View {
        modifier(SettingsHoverEffect(tint: tint, isEnabled: isEnabled))
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @ObservedObject var settingsStore: SettingsStore

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.onShortcutRecorded = { keyCode, modifiers in
            settingsStore.updateShortcut(keyCode: keyCode, modifiers: modifiers)
            field.displayString = settingsStore.shortcutDisplayString
        }
        field.displayString = settingsStore.shortcutDisplayString
        return field
    }

    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        nsView.displayString = settingsStore.shortcutDisplayString
    }
}

final class ShortcutRecorderField: NSView {
    var onShortcutRecorded: ((UInt32, UInt32) -> Void)?
    var displayString: String = "" {
        didSet {
            label.stringValue = isRecording ? "按下快捷键" : displayString
        }
    }

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false
    private var isHovering = false
    private var trackingArea: NSTrackingArea?
    private var localEventMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        displayString = ""
        applyCurrentAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let nextTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(nextTrackingArea)
        trackingArea = nextTrackingArea
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyCurrentAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyCurrentAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        label.stringValue = "按下快捷键"
        applyCurrentAppearance()

        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return event }
                if self.isRecording {
                    let point = self.convert(event.locationInWindow, from: nil)
                    if !self.bounds.contains(point) {
                        self.window?.makeFirstResponder(nil)
                    }
                }
                return event
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        NSCursor.pointingHand.push()
        animateAppearanceChange()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        NSCursor.pop()
        animateAppearanceChange()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        label.stringValue = displayString
        applyCurrentAppearance()
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            window?.makeFirstResponder(nil)
            return
        }

        let modifiers = ShortcutFormatter.carbonModifiers(from: event.modifierFlags.intersection([.command, .option, .control, .shift]))
        guard modifiers != 0 else { return }

        onShortcutRecorded?(UInt32(event.keyCode), modifiers)
        isRecording = false
        window?.makeFirstResponder(nil)
        applyCurrentAppearance()
    }

    private func animateAppearanceChange() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            applyCurrentAppearance()
        }
    }

    private func applyCurrentAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accentColor = NSColor.controlAccentColor
            let backgroundColor: NSColor
            let borderColor: NSColor
            let textColor: NSColor

            if isRecording {
                backgroundColor = accentColor.withAlphaComponent(0.08)
                borderColor = accentColor.withAlphaComponent(0.28)
                textColor = accentColor
            } else if isHovering {
                backgroundColor = accentColor.withAlphaComponent(0.045)
                borderColor = accentColor.withAlphaComponent(0.18)
                textColor = .labelColor
            } else {
                backgroundColor = .textBackgroundColor
                borderColor = NSColor.separatorColor.withAlphaComponent(0.12)
                textColor = .labelColor
            }

            layer?.backgroundColor = backgroundColor.cgColor
            layer?.borderColor = borderColor.cgColor
            layer?.shadowColor = accentColor.cgColor
            layer?.shadowOpacity = isRecording ? 0.06 : 0
            layer?.shadowRadius = isRecording ? 3 : 0
            layer?.shadowOffset = NSSize(width: 0, height: -1)
            label.textColor = textColor
        }
    }
}
