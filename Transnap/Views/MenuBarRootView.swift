//
//  MenuBarRootView.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit
import SwiftUI
import Translation

@available(macOS 15.0, *)
struct MenuBarRootView: View {
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator
    @StateObject private var onboardingLanguageManager = OfflineLanguageManager()

    var body: some View {
        Group {
            if settingsStore.hasCompletedWelcomeFlow {
                TranslatorPanelView(
                    viewModel: viewModel,
                    settingsStore: settingsStore,
                    windowCoordinator: windowCoordinator
                )
            } else {
                WelcomePanelView(
                    viewModel: viewModel,
                    settingsStore: settingsStore,
                    offlineLanguageManager: onboardingLanguageManager
                )
            }
        }
        .frame(width: 360, height: settingsStore.menuBarPanelHeight)
        .preferredColorScheme(preferredColorScheme)
        .translationTask(onboardingLanguageManager.pendingConfiguration) { session in
            await onboardingLanguageManager.performPendingInstall(using: session)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch settingsStore.appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@available(macOS 15.0, *)
struct TranslatorPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator
    @StateObject private var offlineLanguageManager = OfflineLanguageManager()
    @State private var inputEditorHeight: CGFloat = 126
    @State private var dragStartPanelHeight: Double?
    private let resizeHandleHeight: CGFloat = 20
    private let inputMinLines = 5
    private let inputMaxLines = 8
    private let resultMinimumHeight: CGFloat = 126
    @State private var isHoveringTranslate: Bool = false
    @State private var isHoveringSwapLanguages: Bool = false
    @State private var isHoveringCopy: Bool = false
    @State private var isInputEditorTextEmpty = true
    @State private var showCopiedFeedback = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                    .padding(.bottom, -4)
                inputSection
                actionSection
                resultSection
            }
            .padding(14)
            .padding(.bottom, resizeHandleHeight + 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(panelBackground)
        .scrollBounceBehavior(.basedOnSize)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.isTranslating)
        .animation(.easeInOut(duration: 0.22), value: viewModel.translatedText)
        .task {
            await offlineLanguageManager.refreshStatuses()
        }
        .translationTask(viewModel.translationConfiguration) { [requestID = viewModel.systemTranslationRequestID] session in
            await viewModel.performTranslation(using: session, requestID: requestID)
        }
        .translationTask(offlineLanguageManager.pendingConfiguration) { session in
            await offlineLanguageManager.performPendingInstall(using: session)
        }
        .overlay(alignment: .bottom) {
            resizeHandle
        }
        .onChange(of: viewModel.copyFeedbackToken) { _, _ in
            guard !viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                showCopiedFeedback = true
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedFeedback = false
                }
            }
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        PanelBackgroundView()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image("StatusBarIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)

                    Text("Transnap")
                }
                .font(.system(size: 20, weight: .semibold, design: .rounded))

                Spacer()

                headerIcon(
                    hint: .history,
                    systemName: "clock",
                    hoverTint: .accentColor,
                    title: settingsStore.text("历史记录", "History"),
                    message: settingsStore.text("查看翻译历史", "View translation history")
                ) {
                    windowCoordinator.showHistoryWindow()
                }

                headerIcon(
                    hint: .settings,
                    systemName: "gear",
                    hoverTint: .accentColor,
                    title: settingsStore.text("设置", "Settings"),
                    message: settingsStore.text("打开设置", "Open settings")
                ) {
                    windowCoordinator.showSettingsWindow()
                }

                headerIcon(
                    hint: .quit,
                    systemName: "xmark.circle",
                    hoverTint: .red,
                    title: settingsStore.text("退出 Transnap", "Quit Transnap"),
                    message: settingsStore.text("退出 Transnap", "Quit Transnap")
                ) {
                    NSApp.terminate(nil)
                }
            }

            headerStatusRow

            if let lastErrorMessage = viewModel.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }

    private func headerIcon(
        hint: HeaderPopoverHint,
        systemName: String,
        hoverTint: Color,
        title: String,
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        HeaderIconButton(
            hint: hint,
            settingsStore: settingsStore,
            systemName: systemName,
            hoverTint: hoverTint,
            title: title,
            message: message,
            action: action
        )
    }

    @ViewBuilder
    private var headerStatusRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            headerLanguageSelector
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(inputSurfaceFill)

            AdaptiveTextEditor(
                text: $viewModel.inputText,
                dynamicHeight: $inputEditorHeight,
                minLines: inputMinLines,
                maxLines: inputMaxLines,
                onContentPresenceChange: { hasContent in
                    isInputEditorTextEmpty = !hasContent
                }
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: inputEditorHeight)
            .opacity(viewModel.isTranslating ? 0.68 : 1)

            if isInputEditorTextEmpty {
                Text(settingsStore.text("输入或粘贴要翻译的文本", "Type or paste text to translate"))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            isInputEditorTextEmpty = viewModel.inputText.isEmpty
        }
        .onChange(of: viewModel.inputText) { _, newValue in
            isInputEditorTextEmpty = newValue.isEmpty
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(settingsStore.text("翻译", "Translate")) {
                    viewModel.requestTranslationFromInput()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(isHoveringTranslate ? 1 : 0.88))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(isHoveringTranslate ? 0.35 : 0.16), lineWidth: 1)
                }
                .scaleEffect(isHoveringTranslate ? 1.04 : 1)
                .shadow(color: Color.accentColor.opacity(isHoveringTranslate ? 0.26 : 0.12), radius: isHoveringTranslate ? 9 : 4, y: isHoveringTranslate ? 3 : 1)
                .contentShape(Capsule(style: .continuous))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHoveringTranslate = hovering
                    }
                }

                Spacer()

                if !viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    copyFloatingButton
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }

            if let languageDownloadStatusRow {
                languageDownloadStatusRow
            }
        }
    }

    private var resizeHandle: some View {
        ZStack {
            Color.clear

            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.14))
                .frame(width: 52, height: 5)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: resizeHandleHeight)
        .background(.regularMaterial.opacity(0.001))
        .contentShape(Rectangle())
        .modifier(ResizeCursorModifier())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if dragStartPanelHeight == nil {
                        dragStartPanelHeight = settingsStore.menuBarPanelHeight
                    }

                    let startHeight = dragStartPanelHeight ?? settingsStore.menuBarPanelHeight
                    settingsStore.menuBarPanelHeight = startHeight + value.translation.height
                }
                .onEnded { _ in
                    dragStartPanelHeight = nil
                }
        )
    }

    private var resultSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isTranslating {
                    translatingResultState
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if viewModel.translatedText.isEmpty {
                    Text(settingsStore.text("翻译结果会显示在这里", "Translation results will appear here"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                } else {
                    Text(viewModel.translatedText)
                        .textSelection(.enabled)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .frame(minHeight: resultMinimumHeight)
        .padding(12)
        .background(resultSurfaceFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var inputSurfaceFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.white.opacity(0.08))
        } else {
            return AnyShapeStyle(.thinMaterial)
        }
    }

    private var resultSurfaceFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.white.opacity(0.12))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    private var translatingResultState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                spinnerView
                Text(settingsStore.text("正在生成译文", "Generating translation"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize()

            VStack(alignment: .leading, spacing: 8) {
                placeholderLine(width: 0.92)
                placeholderLine(width: 0.84)
                placeholderLine(width: 0.68)
            }
        }
    }

    private func placeholderLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.primary.opacity(0.08))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 12)
            .padding(.trailing, 140 * (1 - width))
    }

    private var copyFloatingButton: some View {
        Button {
            viewModel.copyTranslatedText()
        } label: {
            ZStack {
                copyButtonLabel(
                    text: settingsStore.text("复制译文", "Copy"),
                    systemImage: "doc.on.doc",
                    foregroundColor: isHoveringCopy ? .accentColor : .secondary
                )
                .opacity(showCopiedFeedback ? 0 : 1)

                copyButtonLabel(
                    text: settingsStore.text("已复制", "Copied"),
                    systemImage: "checkmark",
                    foregroundColor: .green
                )
                .opacity(showCopiedFeedback ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (showCopiedFeedback ? Color.green.opacity(0.12) : Color.accentColor.opacity(isHoveringCopy ? 0.14 : 0.04)),
                in: Capsule()
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isHoveringCopy ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .scaleEffect(isHoveringCopy ? 1.04 : 1)
            .shadow(color: isHoveringCopy ? Color.accentColor.opacity(0.16) : .clear, radius: 7, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHoveringCopy = hovering
            }
        }
    }

    private var languagePickerRow: some View {
        HStack(spacing: 3) {
            compactLanguageMenu(
                title: sourceLanguageLabel,
                selection: settingsStore.sourceLanguage
            ) { identifier in
                selectSourceLanguage(identifier)
            }

            Button {
                swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9, weight: isHoveringSwapLanguages ? .semibold : .medium))
                    .foregroundStyle(isHoveringSwapLanguages ? Color.accentColor : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isHoveringSwapLanguages ? Color.accentColor.opacity(0.13) : Color.clear)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(isHoveringSwapLanguages ? Color.accentColor.opacity(0.36) : Color.clear, lineWidth: 1)
                    }
                    .scaleEffect(isHoveringSwapLanguages ? 1.08 : 1)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHoveringSwapLanguages = hovering
                }
            }
            .help(settingsStore.text("交换原文和翻译语言", "Swap source and target languages"))

            compactLanguageMenu(
                title: targetLanguageLabel,
                selection: settingsStore.targetLanguage
            ) { identifier in
                selectTargetLanguage(identifier)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.035), in: Capsule())
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .fixedSize()
        .help(settingsStore.text("仅在自动识别不准确时手动指定语言", "Specify languages manually when auto detection is inaccurate"))
    }

    private var headerLanguageSelector: some View {
        HStack(spacing: 3) {
            headerLanguageMenu(
                title: sourceLanguageLabel,
                selection: settingsStore.sourceLanguage
            ) { identifier in
                selectSourceLanguage(identifier)
            }

            Text("→")

            headerLanguageMenu(
                title: targetLanguageLabel,
                selection: settingsStore.targetLanguage
            ) { identifier in
                selectTargetLanguage(identifier)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize()
        .help(settingsStore.text("仅在自动识别不准确时手动指定语言", "Specify languages manually when auto detection is inaccurate"))
    }

    private var sourceLanguageLabel: String {
        settingsStore.sourceLanguage == "auto"
            ? settingsStore.text("自动检测", "Auto")
            : TranslationLanguageOptions.title(for: settingsStore.sourceLanguage, in: settingsStore.displayLanguage)
    }

    private var targetLanguageLabel: String {
        settingsStore.targetLanguage == "auto"
            ? settingsStore.text("自动检测", "Auto")
            : TranslationLanguageOptions.title(for: settingsStore.targetLanguage, in: settingsStore.displayLanguage)
    }

    private func compactLanguageMenu(
        title: String,
        selection: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        CompactLanguageMenuButton(
            title: title,
            selection: selection,
            displayLanguage: settingsStore.displayLanguage,
            onSelect: onSelect
        )
    }

    private func headerLanguageMenu(
        title: String,
        selection: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HeaderLanguageMenuButton(
            title: title,
            selection: selection,
            displayLanguage: settingsStore.displayLanguage,
            onSelect: onSelect
        )
    }

    private func swapLanguages() {
        let source = settingsStore.sourceLanguage
        let target = settingsStore.targetLanguage
        settingsStore.sourceLanguage = target
        settingsStore.targetLanguage = source
    }

    private func selectSourceLanguage(_ identifier: String) {
        settingsStore.sourceLanguage = identifier
    }

    private func selectTargetLanguage(_ identifier: String) {
        settingsStore.targetLanguage = identifier
    }

    private var languageDownloadStatusRow: AnyView? {
        if case let .installing(identifier) = offlineLanguageManager.installState {
            return AnyView(
                HStack(alignment: .center, spacing: 8) {
                    spinnerView

                    VStack(alignment: .leading, spacing: 2) {
                        Text(settingsStore.text("正在下载 \(TranslationLanguageOptions.title(for: identifier, in: settingsStore.displayLanguage)) 语言包", "Downloading \(TranslationLanguageOptions.title(for: identifier, in: settingsStore.displayLanguage)) language pack"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(settingsStore.text("关闭系统下载窗口后，Transnap 会继续等待下载完成。", "After closing the system download window, Transnap will keep waiting for the download to finish."))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
        }

        if let lastErrorMessage = offlineLanguageManager.lastErrorMessage {
            return AnyView(
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(settingsStore.text("语言包下载失败", "Language Pack Download Failed"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(lastErrorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
        }

        return nil
    }

    private func copyButtonLabel(
        text: String,
        systemImage: String,
        foregroundColor: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 12)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(foregroundColor)
    }

    private func selectionAction(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var spinnerView: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(.small)
            .frame(width: 16, height: 16)
    }
}
