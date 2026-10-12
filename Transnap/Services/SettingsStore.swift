//
//  SettingsStore.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import Carbon
import Combine
import Foundation

enum PreferredTargetLanguage: String, CaseIterable, Identifiable {
    case automatic
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "跟随系统自动判断"
        case .simplifiedChinese:
            return "固定翻译成中文"
        case .english:
            return "固定翻译成英文"
        }
    }
}

enum DisplayLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .simplifiedChinese: return "zh-Hans"
        case .english: return "en"
        }
    }

    func text(
        _ simplifiedChinese: String,
        _ english: String,
        french: String? = nil,
        spanish: String? = nil
    ) -> String {
        localizedText([
            .simplifiedChinese: simplifiedChinese,
            .english: english
        ])
    }

    func localizedText(_ translations: [DisplayLanguage: String]) -> String {
        translations[self]
            ?? translations[.english]
            ?? translations[.simplifiedChinese]
            ?? translations.values.first
            ?? ""
    }
}

struct TranslationLanguageOption: Identifiable, Hashable {
    let identifier: String
    private let localizedTitles: [DisplayLanguage: String]

    var id: String { identifier }

    init(
        identifier: String,
        simplifiedChineseTitle: String,
        englishTitle: String,
        frenchTitle: String? = nil,
        spanishTitle: String? = nil
    ) {
        self.identifier = identifier
        self.localizedTitles = [
            .simplifiedChinese: simplifiedChineseTitle,
            .english: englishTitle
        ]
    }

    func title(in language: DisplayLanguage) -> String {
        language.localizedText(localizedTitles)
    }
}

enum TranslationLanguageOptions {
    static let automaticIdentifier = "auto"
    static let defaultPrimaryAutoDetectionLanguage = "zh-Hans"
    static let defaultSecondaryAutoDetectionLanguage = "en"

    static let all: [TranslationLanguageOption] = [
        TranslationLanguageOption(identifier: automaticIdentifier, simplifiedChineseTitle: "自动检测", englishTitle: "Auto Detect", frenchTitle: "Détection automatique", spanishTitle: "Detección automática"),
        TranslationLanguageOption(identifier: "zh-Hans", simplifiedChineseTitle: "简体中文", englishTitle: "Simplified Chinese", frenchTitle: "Chinois simplifié", spanishTitle: "Chino simplificado"),
        TranslationLanguageOption(identifier: "zh-Hant", simplifiedChineseTitle: "繁体中文", englishTitle: "Traditional Chinese", frenchTitle: "Chinois traditionnel", spanishTitle: "Chino tradicional"),
        TranslationLanguageOption(identifier: "en", simplifiedChineseTitle: "英语", englishTitle: "English", frenchTitle: "Anglais", spanishTitle: "Inglés"),
        TranslationLanguageOption(identifier: "ja", simplifiedChineseTitle: "日语", englishTitle: "Japanese", frenchTitle: "Japonais", spanishTitle: "Japonés"),
        TranslationLanguageOption(identifier: "ko", simplifiedChineseTitle: "韩语", englishTitle: "Korean", frenchTitle: "Coréen", spanishTitle: "Coreano"),
        TranslationLanguageOption(identifier: "es", simplifiedChineseTitle: "西班牙语", englishTitle: "Spanish", frenchTitle: "Espagnol", spanishTitle: "Español"),
        TranslationLanguageOption(identifier: "fr", simplifiedChineseTitle: "法语", englishTitle: "French", frenchTitle: "Français", spanishTitle: "Francés"),
        TranslationLanguageOption(identifier: "de", simplifiedChineseTitle: "德语", englishTitle: "German", frenchTitle: "Allemand", spanishTitle: "Alemán"),
        TranslationLanguageOption(identifier: "it", simplifiedChineseTitle: "意大利语", englishTitle: "Italian", frenchTitle: "Italien", spanishTitle: "Italiano"),
        TranslationLanguageOption(identifier: "pt", simplifiedChineseTitle: "葡萄牙语", englishTitle: "Portuguese", frenchTitle: "Portugais", spanishTitle: "Portugués"),
        TranslationLanguageOption(identifier: "ru", simplifiedChineseTitle: "俄语", englishTitle: "Russian", frenchTitle: "Russe", spanishTitle: "Ruso"),
        TranslationLanguageOption(identifier: "ar", simplifiedChineseTitle: "阿拉伯语", englishTitle: "Arabic", frenchTitle: "Arabe", spanishTitle: "Árabe"),
    ]

    static let autoDetectionCandidates: [TranslationLanguageOption] = all.filter {
        $0.identifier != automaticIdentifier
    }

    static func title(for identifier: String, in language: DisplayLanguage = .simplifiedChinese) -> String {
        all.first(where: { $0.identifier == identifier })?.title(in: language)
            ?? Locale(identifier: language.localeIdentifier).localizedString(forIdentifier: identifier)
            ?? identifier
    }

    static func normalizedAutoDetectionLanguage(_ identifier: String?, fallback: String) -> String {
        guard let identifier,
              autoDetectionCandidates.contains(where: { $0.identifier == identifier }) else {
            return fallback
        }

        return identifier
    }

    static func fallbackAutoDetectionLanguage(excluding identifier: String) -> String {
        autoDetectionCandidates.first(where: { $0.identifier != identifier })?.identifier
            ?? defaultSecondaryAutoDetectionLanguage
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultMenuBarPanelHeight: Double = 430
    static let minMenuBarPanelHeight: Double = 410
    static let maxMenuBarPanelHeight: Double = 620
    static let maximumInterfaceHintShows = 2

    enum LaunchAtLoginState: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case unavailable(String)

        func message(in language: DisplayLanguage) -> String {
            switch self {
            case .enabled:
                return language.text(
                    "已开启，登录 Mac 后会自动打开。",
                    "Enabled. Transnap will open automatically after you log in.",
                    french: "Activé. Transnap s'ouvrira automatiquement après votre connexion.",
                    spanish: "Activado. Transnap se abrirá automáticamente después de iniciar sesión."
                )
            case .disabled:
                return language.text(
                    "已关闭，你可以随时手动打开。",
                    "Disabled. You can open it manually at any time.",
                    french: "Désactivé. Vous pouvez l'ouvrir manuellement à tout moment.",
                    spanish: "Desactivado. Puedes abrirlo manualmente en cualquier momento."
                )
            case .requiresApproval:
                return language.text(
                    "还需要你去系统“登录项”里确认一次。",
                    "Please confirm this once in macOS Login Items.",
                    french: "Veuillez confirmer une fois dans les éléments de connexion de macOS.",
                    spanish: "Confírmalo una vez en los ítems de inicio de macOS."
                )
            case let .unavailable(message):
                return message
            }
        }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        func title(in language: DisplayLanguage) -> String {
            switch self {
            case .system: return language.text("跟随系统", "System", french: "Système", spanish: "Sistema")
            case .light: return language.text("浅色模式", "Light", french: "Clair", spanish: "Claro")
            case .dark: return language.text("深色模式", "Dark", french: "Sombre", spanish: "Oscuro")
            }
        }
    }

    @Published var displayLanguage: DisplayLanguage {
        didSet { defaults.set(displayLanguage.rawValue, forKey: Keys.displayLanguage) }
    }

    @Published var downloadedLanguages: Set<String> {
        didSet { defaults.set(Array(downloadedLanguages), forKey: Keys.downloadedLanguages) }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    @Published var sourceLanguage: String {
        didSet { defaults.set(sourceLanguage, forKey: Keys.sourceLanguage) }
    }

    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }

    @Published var preferredTargetLanguage: PreferredTargetLanguage {
        didSet {
            defaults.set(preferredTargetLanguage.rawValue, forKey: Keys.preferredTargetLanguage)
        }
    }

    @Published var primaryAutoDetectionLanguage: String {
        didSet {
            let normalizedValue = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
                primaryAutoDetectionLanguage,
                fallback: TranslationLanguageOptions.defaultPrimaryAutoDetectionLanguage
            )
            if primaryAutoDetectionLanguage != normalizedValue {
                primaryAutoDetectionLanguage = normalizedValue
                return
            }

            if primaryAutoDetectionLanguage == secondaryAutoDetectionLanguage {
                secondaryAutoDetectionLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                    excluding: primaryAutoDetectionLanguage
                )
            }

            defaults.set(primaryAutoDetectionLanguage, forKey: Keys.primaryAutoDetectionLanguage)
        }
    }

    @Published var secondaryAutoDetectionLanguage: String {
        didSet {
            let normalizedValue = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
                secondaryAutoDetectionLanguage,
                fallback: TranslationLanguageOptions.defaultSecondaryAutoDetectionLanguage
            )
            if secondaryAutoDetectionLanguage != normalizedValue {
                secondaryAutoDetectionLanguage = normalizedValue
                return
            }

            if secondaryAutoDetectionLanguage == primaryAutoDetectionLanguage {
                primaryAutoDetectionLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                    excluding: secondaryAutoDetectionLanguage
                )
            }

            defaults.set(secondaryAutoDetectionLanguage, forKey: Keys.secondaryAutoDetectionLanguage)
        }
    }

    @Published var shortcutKeyCode: UInt32 {
        didSet {
            defaults.set(Int(shortcutKeyCode), forKey: Keys.shortcutKeyCode)
        }
    }

    @Published var shortcutModifiers: UInt32 {
        didSet {
            defaults.set(Int(shortcutModifiers), forKey: Keys.shortcutModifiers)
        }
    }

    @Published var doubleCopyShortcutEnabled: Bool {
        didSet {
            defaults.set(doubleCopyShortcutEnabled, forKey: Keys.doubleCopyShortcutEnabled)
        }
    }

    @Published var hasCompletedWelcomeFlow: Bool {
        didSet {
            defaults.set(hasCompletedWelcomeFlow, forKey: Keys.hasCompletedWelcomeFlow)
            if hasCompletedWelcomeFlow {
                defaults.set(currentBuildNumber, forKey: Keys.lastCompletedWelcomeBuild)
            } else {
                defaults.removeObject(forKey: Keys.lastCompletedWelcomeBuild)
            }
        }
    }

    @Published var menuBarPanelHeight: Double {
        didSet {
            let clampedValue = Self.clampMenuBarPanelHeight(menuBarPanelHeight)
            if menuBarPanelHeight != clampedValue {
                menuBarPanelHeight = clampedValue
                return
            }

            defaults.set(clampedValue, forKey: Keys.menuBarPanelHeight)
        }
    }

    @Published private var interfaceHintShownCounts: [String: Int]
    @Published private(set) var launchAtLoginState: LaunchAtLoginState = .disabled

    var shortcutDisplayString: String {
        ShortcutFormatter.string(forKeyCode: shortcutKeyCode, modifiers: shortcutModifiers)
    }

    var autoDetectionLanguageIdentifiers: [String] {
        [primaryAutoDetectionLanguage, secondaryAutoDetectionLanguage]
    }

    func text(
        _ simplifiedChinese: String,
        _ english: String,
        french: String? = nil,
        spanish: String? = nil
    ) -> String {
        displayLanguage.text(simplifiedChinese, english, french: french, spanish: spanish)
    }

    func shouldShowInterfaceHint(_ identifier: String) -> Bool {
        return interfaceHintShownCounts[identifier, default: 0] < Self.maximumInterfaceHintShows
    }

    func recordInterfaceHintShown(_ identifier: String) {
        guard interfaceHintShownCounts[identifier, default: 0] < Self.maximumInterfaceHintShows else { return }

        interfaceHintShownCounts[identifier, default: 0] += 1
        defaults.set(interfaceHintShownCounts, forKey: Keys.interfaceHintShownCounts)
    }

    private let defaults: UserDefaults
    private let currentBuildNumber: String

    init(
        defaults: UserDefaults = .standard,
        appBuild: String? = nil,
        showsWelcomeEveryLaunchInDebug: Bool? = nil,
        debugInstallStampOverride: Double? = nil
    ) {
        self.defaults = defaults
        self.currentBuildNumber = appBuild ?? Self.resolveCurrentBuildNumber()
        let resolvedShowsWelcomeEveryLaunchInDebug = showsWelcomeEveryLaunchInDebug ?? Self.defaultShowsWelcomeEveryLaunchInDebug
        let defaultShortcutKeyCode = Int(kVK_ANSI_C)
        let previousDefaultShortcutKeyCode = Int(kVK_ANSI_T)
        let oldDefaultShortcutModifiers = Int(UInt32(shiftKey) | UInt32(optionKey))
        let previousDefaultShortcutModifiers = Int(UInt32(shiftKey) | UInt32(controlKey))
        let defaultShortcutModifiers = Int(UInt32(shiftKey) | UInt32(cmdKey))

        self.downloadedLanguages = Set(defaults.stringArray(forKey: Keys.downloadedLanguages) ?? ["zh-Hans", "en"])

        self.displayLanguage = DisplayLanguage(rawValue: defaults.string(forKey: Keys.displayLanguage) ?? "") ?? .simplifiedChinese
        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.historyLimit = defaults.integer(forKey: Keys.historyLimit) == 0 ? 50 : defaults.integer(forKey: Keys.historyLimit)

        self.sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "auto"
        self.targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "auto"
        var storedInterfaceHintShownCounts = defaults.dictionary(forKey: Keys.interfaceHintShownCounts) as? [String: Int] ?? [:]
#if DEBUG
        storedInterfaceHintShownCounts = Self.resetInterfaceHintCountsForDebugInstallIfNeeded(
            defaults: defaults,
            storedCounts: storedInterfaceHintShownCounts,
            debugInstallStampOverride: debugInstallStampOverride
        )
#endif
        self.interfaceHintShownCounts = storedInterfaceHintShownCounts

        let preferredTargetRawValue = defaults.string(forKey: Keys.preferredTargetLanguage)
        self.preferredTargetLanguage = PreferredTargetLanguage(rawValue: preferredTargetRawValue ?? "") ?? .automatic

        let storedPrimaryAutoDetectionLanguage = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
            defaults.string(forKey: Keys.primaryAutoDetectionLanguage),
            fallback: TranslationLanguageOptions.defaultPrimaryAutoDetectionLanguage
        )
        var storedSecondaryAutoDetectionLanguage = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
            defaults.string(forKey: Keys.secondaryAutoDetectionLanguage),
            fallback: TranslationLanguageOptions.defaultSecondaryAutoDetectionLanguage
        )
        if storedPrimaryAutoDetectionLanguage == storedSecondaryAutoDetectionLanguage {
            storedSecondaryAutoDetectionLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                excluding: storedPrimaryAutoDetectionLanguage
            )
        }
        self.primaryAutoDetectionLanguage = storedPrimaryAutoDetectionLanguage
        self.secondaryAutoDetectionLanguage = storedSecondaryAutoDetectionLanguage

        let storedKeyCode = defaults.object(forKey: Keys.shortcutKeyCode) as? Int
        let storedModifiers = defaults.object(forKey: Keys.shortcutModifiers) as? Int
        let shouldMigrateOldDefaultShortcut =
            (storedKeyCode == previousDefaultShortcutKeyCode && storedModifiers == oldDefaultShortcutModifiers)
            || (storedKeyCode == previousDefaultShortcutKeyCode && storedModifiers == previousDefaultShortcutModifiers)
        let resolvedShortcutKeyCode = shouldMigrateOldDefaultShortcut
            ? defaultShortcutKeyCode
            : (storedKeyCode ?? defaultShortcutKeyCode)
        let resolvedShortcutModifiers = shouldMigrateOldDefaultShortcut
            ? defaultShortcutModifiers
            : (storedModifiers ?? defaultShortcutModifiers)
        self.shortcutKeyCode = UInt32(resolvedShortcutKeyCode)
        self.shortcutModifiers = UInt32(resolvedShortcutModifiers)
        self.doubleCopyShortcutEnabled = defaults.bool(forKey: Keys.doubleCopyShortcutEnabled)

        if shouldMigrateOldDefaultShortcut {
            defaults.set(resolvedShortcutKeyCode, forKey: Keys.shortcutKeyCode)
            defaults.set(resolvedShortcutModifiers, forKey: Keys.shortcutModifiers)
        }

#if DEBUG
        Self.resetWelcomeFlowForDebugInstallIfNeeded(
            defaults: defaults,
            debugInstallStampOverride: debugInstallStampOverride
        )
#endif

        let hasCompletedWelcomeFlow = defaults.bool(forKey: Keys.hasCompletedWelcomeFlow)
        let lastCompletedWelcomeBuild = defaults.string(forKey: Keys.lastCompletedWelcomeBuild)
        let shouldMigrateWelcomeBuild = hasCompletedWelcomeFlow && lastCompletedWelcomeBuild == nil
        let shouldShowWelcomeForCurrentBuild: Bool

        if shouldMigrateWelcomeBuild {
            defaults.set(currentBuildNumber, forKey: Keys.lastCompletedWelcomeBuild)
            shouldShowWelcomeForCurrentBuild = false
        } else {
            shouldShowWelcomeForCurrentBuild =
                hasCompletedWelcomeFlow == false || lastCompletedWelcomeBuild != currentBuildNumber
        }

        self.hasCompletedWelcomeFlow = resolvedShowsWelcomeEveryLaunchInDebug ? false : !shouldShowWelcomeForCurrentBuild

        if shouldShowWelcomeForCurrentBuild || resolvedShowsWelcomeEveryLaunchInDebug {
            defaults.set(false, forKey: Keys.hasCompletedWelcomeFlow)
        }

        let storedMenuBarPanelHeight = defaults.object(forKey: Keys.menuBarPanelHeight) as? Double
        self.menuBarPanelHeight = Self.clampMenuBarPanelHeight(
            storedMenuBarPanelHeight ?? Self.defaultMenuBarPanelHeight
        )
    }

    func updateShortcut(keyCode: UInt32, modifiers: UInt32) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
    }

    func updateLaunchAtLoginState(_ state: LaunchAtLoginState) {
        launchAtLoginState = state
    }

    private static func clampMenuBarPanelHeight(_ value: Double) -> Double {
        min(max(value, minMenuBarPanelHeight), maxMenuBarPanelHeight)
    }

    private static func resolveCurrentBuildNumber(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

#if DEBUG
    private static func resetInterfaceHintCountsForDebugInstallIfNeeded(
        defaults: UserDefaults,
        storedCounts: [String: Int],
        debugInstallStampOverride: Double?
    ) -> [String: Int] {
        guard let installStamp = debugInstallStampOverride ?? debugInstallStamp() else {
            return storedCounts
        }

        let previousInstallStamp = defaults.object(forKey: Keys.debugInterfaceHintInstallStamp) as? Double
        defaults.set(installStamp, forKey: Keys.debugInterfaceHintInstallStamp)

        guard previousInstallStamp != installStamp else {
            return storedCounts
        }

        defaults.removeObject(forKey: Keys.interfaceHintShownCounts)
        return [:]
    }

    private static func resetWelcomeFlowForDebugInstallIfNeeded(
        defaults: UserDefaults,
        debugInstallStampOverride: Double?
    ) {
        guard let installStamp = debugInstallStampOverride ?? debugInstallStamp() else {
            return
        }

        let previousInstallStamp = defaults.object(forKey: Keys.debugWelcomeInstallStamp) as? Double
        defaults.set(installStamp, forKey: Keys.debugWelcomeInstallStamp)

        guard previousInstallStamp != installStamp else {
            return
        }

        defaults.set(false, forKey: Keys.hasCompletedWelcomeFlow)
        defaults.removeObject(forKey: Keys.lastCompletedWelcomeBuild)
    }

    private static func debugInstallStamp(bundle: Bundle = .main) -> Double? {
        let url = bundle.executableURL ?? bundle.bundleURL
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modificationDate = values.contentModificationDate else {
            return nil
        }

        return modificationDate.timeIntervalSince1970
    }
#endif

    private static var defaultShowsWelcomeEveryLaunchInDebug: Bool {
        false
    }
}

private enum Keys {
    static let downloadedLanguages = "settings.downloadedLanguages"
    static let displayLanguage = "settings.displayLanguage"
    static let appearance = "settings.appearance"
    static let launchAtLogin = "settings.launchAtLogin"
    static let historyLimit = "settings.historyLimit"
    static let sourceLanguage = "settings.sourceLanguage"
    static let targetLanguage = "settings.targetLanguage"
    static let interfaceHintShownCounts = "settings.interfaceHintShownCounts"
#if DEBUG
    static let debugInterfaceHintInstallStamp = "settings.debugInterfaceHintInstallStamp"
    static let debugWelcomeInstallStamp = "settings.debugWelcomeInstallStamp"
#endif
    static let preferredTargetLanguage = "settings.preferredTargetLanguage"
    static let primaryAutoDetectionLanguage = "settings.primaryAutoDetectionLanguage"
    static let secondaryAutoDetectionLanguage = "settings.secondaryAutoDetectionLanguage"
    static let shortcutKeyCode = "settings.shortcutKeyCode"
    static let shortcutModifiers = "settings.shortcutModifiers"
    static let doubleCopyShortcutEnabled = "settings.doubleCopyShortcutEnabled"
    static let hasCompletedWelcomeFlow = "settings.hasCompletedWelcomeFlow"
    static let lastCompletedWelcomeBuild = "settings.lastCompletedWelcomeBuild"
    static let menuBarPanelHeight = "settings.menuBarPanelHeight"
}
