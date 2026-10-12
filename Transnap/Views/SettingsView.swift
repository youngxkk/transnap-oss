//
//  SettingsView.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import AppKit
import SwiftData
import SwiftUI
import Translation

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var activeTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general, offline, about
        var id: String { rawValue }
        
        func title(in language: DisplayLanguage) -> String {
            switch self {
            case .general: return language.text("通用", "General", french: "Général", spanish: "General")
            case .offline: return language.text("离线包", "Offline", french: "Packs", spanish: "Sin conexión")
            case .about: return language.text("关于", "About", french: "À propos", spanish: "Acerca de")
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .offline: return "shippingbox"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        TabView(selection: $activeTab) {
            GeneralSettingsView(settingsStore: settingsStore)
                .tag(SettingsTab.general)
                .tabItem { Label(SettingsTab.general.title(in: settingsStore.displayLanguage), systemImage: SettingsTab.general.icon) }

            offlineTab
                .tag(SettingsTab.offline)
                .tabItem { Label(SettingsTab.offline.title(in: settingsStore.displayLanguage), systemImage: SettingsTab.offline.icon) }

            AboutSettingsView(settingsStore: settingsStore)
                .tag(SettingsTab.about)
                .tabItem { Label(SettingsTab.about.title(in: settingsStore.displayLanguage), systemImage: SettingsTab.about.icon) }
        }
        .frame(width: 480, height: 560)
        .padding(.vertical, 10)
        .preferredColorScheme(settingsStore.appearance == .system ? nil : (settingsStore.appearance == .dark ? .dark : .light))
    }

    @ViewBuilder
    private var offlineTab: some View {
        if #available(macOS 15.0, *) {
            OfflineSettingsView(settingsStore: settingsStore)
        } else {
            ContentUnavailableView(settingsStore.text("需要 macOS 15 或更新版本", "Requires macOS 15 or later"), systemImage: "exclamationmark.triangle")
        }
    }
}

// MARK: - General Tab
struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var history: [TranslationRecord]
    @State private var showingClearHistoryAlert = false
    @State private var clearHistoryErrorMessage: String?
    @State private var showingDoubleCopyPermissionExplanation = false
    @State private var hasInputMonitoringPermission = false
    @State private var isHoveringInputMonitoringButton = false

    var body: some View {
        Form {
            Section {
                Picker(settingsStore.text("我的语言", "My Language"), selection: $settingsStore.primaryAutoDetectionLanguage) {
                    ForEach(TranslationLanguageOptions.autoDetectionCandidates) { option in
                        Text(option.title(in: settingsStore.displayLanguage)).tag(option.identifier)
                    }
                }

                Picker(settingsStore.text("常用互译语言", "Frequent Pair"), selection: $settingsStore.secondaryAutoDetectionLanguage) {
                    ForEach(TranslationLanguageOptions.autoDetectionCandidates) { option in
                        Text(option.title(in: settingsStore.displayLanguage)).tag(option.identifier)
                    }
                }
            } header: {
                Text(settingsStore.text("翻译语言", "Translation"))
            } footer: {
                Text(settingsStore.text("自动检测只会在这两种语言之间判断；其它语言需要在翻译面板里手动指定。", "Auto detection only decides between these two languages. Specify other languages manually in the translation panel."))
            }

            Section {
                Picker(settingsStore.text("应用显示语言", "App Display Language"), selection: $settingsStore.displayLanguage) {
                    ForEach(DisplayLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }

                Picker(settingsStore.text("外观", "Appearance"), selection: $settingsStore.appearance) {
                    ForEach(SettingsStore.Appearance.allCases) { appearance in
                        Text(appearance.title(in: settingsStore.displayLanguage)).tag(appearance)
                    }
                }

                HStack {
                    Text(settingsStore.text("登录时自动打开", "Open at Login"))
                    Spacer()
                    SettingsSwitch(
                        isOn: $settingsStore.launchAtLogin,
                        accessibilityLabel: settingsStore.text("登录时自动打开", "Open at Login")
                    )
                }
            } header: {
                Text(settingsStore.text("应用", "Application"))
            } footer: {
                Text(settingsStore.launchAtLoginState.message(in: settingsStore.displayLanguage))
            }

            Section {
                HStack(alignment: .center, spacing: 16) {
                    Text(settingsStore.text("打开翻译窗口", "Open Translation Window"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ShortcutRecorderView(settingsStore: settingsStore)
                        .frame(width: 176, height: 28)
                }

                HStack(alignment: .center, spacing: 16) {
                    Text(settingsStore.text("复制即翻译 👍🏻👍🏽👍🏿", "Copy to Translate 👍🏻👍🏽👍🏿"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        HStack(spacing: 2) {
                            Button {
                                openInputMonitoringSettings()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                    Text(settingsStore.text("辅助权限", "Auxiliary Permission"))
                                    Text(hasInputMonitoringPermission
                                        ? settingsStore.text("已开启", "Enabled")
                                        : settingsStore.text("未开启", "Disabled"))
                                        .foregroundStyle(hasInputMonitoringPermission ? .green : .orange)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Color.accentColor.opacity(isHoveringInputMonitoringButton ? 0.3 : 0.08),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                            .animation(.easeOut(duration: 0.12), value: isHoveringInputMonitoringButton)
                            .onHover { hovering in
                                isHoveringInputMonitoringButton = hovering
                            }
                            .help(settingsStore.text("打开权限设置", "Open Permission Settings"))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                        SettingsSwitch(
                            isOn: Binding(
                                get: { settingsStore.doubleCopyShortcutEnabled },
                                set: { isEnabled in
                                    if isEnabled {
                                        showingDoubleCopyPermissionExplanation = true
                                    } else {
                                        settingsStore.doubleCopyShortcutEnabled = false
                                    }
                                }
                            ),
                            accessibilityLabel: settingsStore.text("复制即翻译", "Copy to Translate")
                        )
                    }
                }
            } header: {
                Text(settingsStore.text("快捷键", "Shortcuts"))
            } footer: {
                ShortcutFooterView(settingsStore: settingsStore)
            }

            Section {
                HStack {
                    Text(settingsStore.text("最多保存", "Keep up to"))
                    Spacer()
                    HStack(spacing: 10) {
                        Slider(value: Binding(
                            get: { Double(settingsStore.historyLimit) },
                            set: { settingsStore.historyLimit = Int($0) }
                        ), in: 10...200, step: 10)
                        .frame(width: 160)

                        Text("\(settingsStore.historyLimit)")
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)

                        Text(settingsStore.text("条", "items"))
                            .foregroundStyle(.secondary)
                    }
                }

                Button(role: .destructive) {
                    showingClearHistoryAlert = true
                } label: {
                    ClearHistoryButtonLabel(
                        title: settingsStore.text("清空历史记录", "Clear History"),
                        isEnabled: !history.isEmpty
                    )
                }
                .buttonStyle(.plain)
                .opacity(history.isEmpty ? 0.45 : 1)
                .disabled(history.isEmpty)
            } header: {
                Text(settingsStore.text("历史记录", "History"))
            } footer: {
                Text(settingsStore.text("历史记录只保存在这台 Mac 上，不会上传。", "History is stored only on this Mac and is never uploaded."))
            }
        }
        .formStyle(.grouped)
        .alert(settingsStore.text("启用 ⌘C 连按翻译？", "Enable Double ⌘C Translation?"), isPresented: $showingDoubleCopyPermissionExplanation) {
            Button(settingsStore.text("取消", "Cancel"), role: .cancel) {}
            Button(settingsStore.text("确认启用", "Enable")) {
                requestInputMonitoringPermissionAndEnable()
            }
        } message: {
            Text(settingsStore.text(
                "Transnap 只监听按下 ⌘+C+C 快捷键，不记录键盘输入内容。",
                "Transnap only listens for the ⌘+C+C shortcut and does not record keyboard input."
            ))
        }
        .alert(settingsStore.text("清空历史记录？", "Clear history?"), isPresented: $showingClearHistoryAlert) {
            Button(settingsStore.text("取消", "Cancel"), role: .cancel) {}
            Button(settingsStore.text("清空", "Clear"), role: .destructive) {
                clearAllHistory()
            }
        } message: {
            Text(settingsStore.text("这会删除这台 Mac 上的全部翻译记录，且无法恢复。", "This will delete all translation history on this Mac and cannot be undone."))
        }
        .alert(settingsStore.text("清空失败", "Could Not Clear History"), isPresented: Binding(
            get: { clearHistoryErrorMessage != nil },
            set: { if !$0 { clearHistoryErrorMessage = nil } }
        )) {
            Button(settingsStore.text("知道了", "OK"), role: .cancel) {}
        } message: {
            Text(clearHistoryErrorMessage ?? "")
        }
        .onAppear {
            refreshInputMonitoringPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshInputMonitoringPermission()
        }
    }

private struct ClearHistoryButtonLabel: View {
    let title: String
    let isEnabled: Bool
    @State private var isHovering = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.red.opacity(isEnabled && isHovering ? 0.92 : 0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .scaleEffect(isEnabled && isHovering ? 1.018 : 1)
            .shadow(color: Color.red.opacity(isEnabled && isHovering ? 0.14 : 0), radius: 7, y: 2)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { hovering in
                isHovering = hovering && isEnabled
            }
    }

    private var backgroundColor: Color {
        isEnabled && isHovering ? Color.red.opacity(0.1) : Color.primary.opacity(0.045)
    }
}


    private func refreshInputMonitoringPermission() {
        hasInputMonitoringPermission = CGPreflightListenEventAccess()
        if !hasInputMonitoringPermission, settingsStore.doubleCopyShortcutEnabled {
            settingsStore.doubleCopyShortcutEnabled = false
        }
    }

    private func requestInputMonitoringPermissionAndEnable() {
        let granted = CGRequestListenEventAccess()
        hasInputMonitoringPermission = granted || CGPreflightListenEventAccess()
        settingsStore.doubleCopyShortcutEnabled = hasInputMonitoringPermission

        if !hasInputMonitoringPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                openInputMonitoringSettings()
            }
        }
    }

    private func openInputMonitoringSettings() {
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ]

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func clearAllHistory() {
        do {
            let records = try modelContext.fetch(FetchDescriptor<TranslationRecord>())
            for record in records {
                modelContext.delete(record)
            }
            try modelContext.save()
            clearHistoryErrorMessage = nil
        } catch {
            clearHistoryErrorMessage = error.localizedDescription
        }
    }
}

private struct ShortcutFooterView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var isHoveringRestart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(settingsStore.text(
                "选择文本后，点击键盘的 ⌘ + C + C（按住 ⌘ 并双击C），即可快速显示翻译。",
                "After selecting the text, press ⌘ + C + C on the keyboard (hold ⌘ and press C twice) to quickly show the translation."
            ))

            HStack(spacing: 0) {
                Text(settingsStore.text(
                    "如果打开权限后仍未生效，请",
                    "If it still does not work after enabling permission, please "
                ))

                Button {
                    relaunchApp()
                } label: {
                    Text(settingsStore.text("重启 Transnap", "restart Transnap"))
                        .foregroundStyle(isHoveringRestart ? Color.blue : Color.primary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringRestart = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

                Text(settingsStore.displayLanguage == .english ? "." : "。")
            }
        }
    }

    private func relaunchApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
