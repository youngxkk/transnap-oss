//
//  MenuBarWelcomeViews.swift
//  Transnap
//
//  Created by Codex on 2026/5/10.
//

import AppKit
import SwiftUI

struct TranslatorWindowView: View {
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator

    var body: some View {
        TranslatorPanelView(
            viewModel: viewModel,
            settingsStore: settingsStore,
            windowCoordinator: windowCoordinator
        )
        .frame(minWidth: 360, minHeight: 300)
        .preferredColorScheme(preferredColorScheme)
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
struct WelcomePanelView: View {
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var offlineLanguageManager: OfflineLanguageManager
    @State private var selectedSourceLanguage: String
    @State private var selectedTargetLanguage: String
    @State private var isHoveringStartButton = false
    @State private var isHoveringSkipButton = false

    init(
        viewModel: TransnapViewModel,
        settingsStore: SettingsStore,
        offlineLanguageManager: OfflineLanguageManager
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.offlineLanguageManager = offlineLanguageManager
        _selectedSourceLanguage = State(initialValue: Self.defaultSourceLanguage())
        _selectedTargetLanguage = State(initialValue: "en")
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                languageSetup

                onboardingActions
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PanelBackgroundView())
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 6)

                Text("🎉")
                    .font(.system(size: 20))
                    .frame(width: 30, height: 30)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                    .offset(x: 8, y: 6)
            }

            VStack(spacing: 5) {
                Text(settingsStore.text("欢迎使用 Transnap", "Welcome to Transnap"))
                    .font(.system(size: 25, weight: .semibold))

                Text(settingsStore.text("选择文字后，使用快捷键 ⌘ + C + C (按住 ⌘ 并双击 C)，翻译会自动显示在弹窗中，此功能需在设置中手动打开。", "After copying text, Hold ⌘ and double-click C to automatically show the translation in the panel. This feature must be enabled manually in Settings."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var languageSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text(settingsStore.text("选择常用翻译语言", "Choose Your Languages"))
                        .font(.system(size: 14, weight: .semibold))
                }

                HStack(spacing: 10) {
                    languagePicker(
                        title: settingsStore.text("我的语言", "My Language"),
                        selection: $selectedSourceLanguage
                    )

                    languagePicker(
                        title: settingsStore.text("主要互译语言", "Translate Mainly To"),
                        selection: $selectedTargetLanguage
                    )
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }

            Text(settingsStore.text(
                "本地翻译使用 Apple 官方系统语言包，首次下载约 200 MB。下载后可完全离线翻译，速度超快。",
                "Local translation uses Apple's official system language packs. The first download is about 200 MB. Once downloaded, translation works fully offline and is very fast."
            ))
            .font(.system(size: 10, weight: .regular))
            .foregroundStyle(Color.secondary.opacity(0.72))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func languagePicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Picker(title, selection: selection) {
                ForEach(TranslationLanguageOptions.autoDetectionCandidates) { option in
                    Text(option.title(in: settingsStore.displayLanguage))
                        .tag(option.identifier)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var onboardingActions: some View {
        VStack(spacing: 12) {
            startButton
            skipButton
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var startButton: some View {
        Button(settingsStore.text("下载语言包并进入", "Download and Continue")) {
            startOnboardingDownload()
        }
        .buttonStyle(.plain)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 240, height: 50)
        .background(
            Capsule(style: .continuous)
                .fill(startButtonFill)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(isHoveringStartButton ? 0.36 : 0.16), lineWidth: 1)
        }
        .scaleEffect(isHoveringStartButton ? 1.035 : 1)
        .shadow(color: .blue.opacity(isHoveringStartButton ? 0.3 : 0.22), radius: isHoveringStartButton ? 13 : 10, y: isHoveringStartButton ? 6 : 5)
        .contentShape(Capsule(style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHoveringStartButton = hovering
            }
        }
    }

    private var skipButton: some View {
        Button(settingsStore.text("跳过", "Skip")) {
            completeWelcomeFlow()
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(isHoveringSkipButton ? Color.primary : Color.secondary)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHoveringSkipButton = hovering
            }
        }
        .help(settingsStore.text("先进入 App，稍后首次使用本地翻译时再下载语言包", "Enter the app now and download language packs later when local translation is first used"))
    }

    private var startButtonFill: Color {
        if isHoveringStartButton {
            return Color(red: 0.03, green: 0.54, blue: 1.0)
        }

        return Color(red: 0.05, green: 0.48, blue: 0.98)
    }

    private func startOnboardingDownload() {
        let sourceLanguage = selectedSourceLanguage
        var targetLanguage = selectedTargetLanguage

        if sourceLanguage == targetLanguage {
            targetLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                excluding: sourceLanguage
            )
            selectedTargetLanguage = targetLanguage
        }

        settingsStore.primaryAutoDetectionLanguage = sourceLanguage
        settingsStore.secondaryAutoDetectionLanguage = targetLanguage
        settingsStore.sourceLanguage = TranslationLanguageOptions.automaticIdentifier
        settingsStore.targetLanguage = TranslationLanguageOptions.automaticIdentifier
        completeWelcomeFlow()

        offlineLanguageManager.requestInstall(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    private func completeWelcomeFlow() {
        settingsStore.hasCompletedWelcomeFlow = true
        viewModel.syncInputFromClipboard()
    }

    private static func defaultSourceLanguage() -> String {
        let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        let language = Locale.Language(identifier: preferredIdentifier)
        let minimalIdentifier = language.minimalIdentifier
        let maximalIdentifier = language.maximalIdentifier

        if minimalIdentifier.hasPrefix("zh") || maximalIdentifier.contains("Hans") {
            return maximalIdentifier.contains("Hant") ? "zh-Hant" : "zh-Hans"
        }

        if let exactMatch = TranslationLanguageOptions.autoDetectionCandidates.first(where: {
            $0.identifier == minimalIdentifier || $0.identifier == preferredIdentifier
        }) {
            return exactMatch.identifier
        }

        return TranslationLanguageOptions.defaultPrimaryAutoDetectionLanguage
    }
}
