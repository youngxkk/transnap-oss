//
//  TransnapTests.swift
//  TransnapTests
//
//  Created by deepsea on 2026/4/10.
//

import Foundation
import Carbon
import SwiftData
import XCTest
@testable import Transnap

@MainActor
final class TransnapTests: XCTestCase {
    func testWelcomeFlowStaysCompletedForSameBuild() {
        let suiteName = "TransnapTests.sameBuild.\(UUID().uuidString)"
        let defaults = makeDefaultsSuite(named: suiteName)

        let firstLaunchStore = SettingsStore(defaults: defaults, appBuild: "12")
        firstLaunchStore.hasCompletedWelcomeFlow = true

        let secondLaunchStore = SettingsStore(defaults: defaults, appBuild: "12")

        XCTAssertTrue(secondLaunchStore.hasCompletedWelcomeFlow)
    }

    func testWelcomeFlowResetsWhenBuildChanges() {
        let suiteName = "TransnapTests.newBuild.\(UUID().uuidString)"
        let defaults = makeDefaultsSuite(named: suiteName)

        let firstLaunchStore = SettingsStore(defaults: defaults, appBuild: "12")
        firstLaunchStore.hasCompletedWelcomeFlow = true

        let secondLaunchStore = SettingsStore(defaults: defaults, appBuild: "13")

        XCTAssertFalse(secondLaunchStore.hasCompletedWelcomeFlow)
    }

#if DEBUG
    func testWelcomeFlowResetsWhenDebugInstallChanges() {
        let suiteName = "TransnapTests.debugInstall.\(UUID().uuidString)"
        let defaults = makeDefaultsSuite(named: suiteName)

        let firstInstallStore = SettingsStore(
            defaults: defaults,
            appBuild: "12",
            debugInstallStampOverride: 100
        )
        firstInstallStore.hasCompletedWelcomeFlow = true

        let sameInstallStore = SettingsStore(
            defaults: defaults,
            appBuild: "12",
            debugInstallStampOverride: 100
        )
        XCTAssertTrue(sameInstallStore.hasCompletedWelcomeFlow)

        let nextInstallStore = SettingsStore(
            defaults: defaults,
            appBuild: "12",
            debugInstallStampOverride: 200
        )
        XCTAssertFalse(nextInstallStore.hasCompletedWelcomeFlow)
    }
#endif

    func testDefaultShortcutUsesCommandShiftC() {
        let settingsStore = makeSettingsStore()

        XCTAssertEqual(settingsStore.shortcutKeyCode, UInt32(kVK_ANSI_C))
        XCTAssertEqual(settingsStore.shortcutModifiers, UInt32(cmdKey) | UInt32(shiftKey))
    }

    func testDoubleCopyShortcutIsOptInByDefault() {
        let settingsStore = makeSettingsStore()

        XCTAssertFalse(settingsStore.doubleCopyShortcutEnabled)
    }

    func testInterfaceHintsStopAfterTwoShows() {
        let settingsStore = makeSettingsStore()
        let hintIdentifier = "history"

        for _ in 0..<SettingsStore.maximumInterfaceHintShows {
            XCTAssertTrue(settingsStore.shouldShowInterfaceHint(hintIdentifier))
            settingsStore.recordInterfaceHintShown(hintIdentifier)
        }

        XCTAssertFalse(settingsStore.shouldShowInterfaceHint(hintIdentifier))
    }

    func testMenuBarControllerCreatesStatusItemForMenuBarMode() throws {
        let settingsStore = makeSettingsStore()
        settingsStore.hasCompletedWelcomeFlow = true

        let container = try makeInMemoryContainer()
        let viewModel = TransnapViewModel(
            modelContext: container.mainContext,
            settingsStore: settingsStore
        )
        let windowCoordinator = WindowCoordinator(
            viewModel: viewModel,
            settingsStore: settingsStore,
            modelContainer: container
        )

        let controller = MenuBarController(
            viewModel: viewModel,
            settingsStore: settingsStore,
            windowCoordinator: windowCoordinator,
            modelContainer: container,
            showsWelcomeOnLaunch: false
        )

#if DEBUG
        XCTAssertTrue(controller.debugHasStatusItemButton)
        XCTAssertFalse(controller.debugIsPopoverShown)
#else
        _ = controller
#endif
    }

    func testMenuBarControllerRetiresTitleAfterCompletedPopoverFirstCloses() async throws {
        let settingsStore = makeSettingsStore()
        settingsStore.hasCompletedWelcomeFlow = false

        let container = try makeInMemoryContainer()
        let viewModel = TransnapViewModel(
            modelContext: container.mainContext,
            settingsStore: settingsStore
        )
        let windowCoordinator = WindowCoordinator(
            viewModel: viewModel,
            settingsStore: settingsStore,
            modelContainer: container
        )

        let controller = MenuBarController(
            viewModel: viewModel,
            settingsStore: settingsStore,
            windowCoordinator: windowCoordinator,
            modelContainer: container,
            showsWelcomeOnLaunch: false,
            statusItemTitleRetirementDelay: 0.01
        )

#if DEBUG
        XCTAssertEqual(controller.debugStatusItemTitle, " Transnap")
        settingsStore.hasCompletedWelcomeFlow = true
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(controller.debugStatusItemTitle, " Transnap")

        controller.debugSimulatePopoverDidClose()
        try await waitUntil {
            controller.debugStatusItemTitle == ""
        }
#else
        _ = controller
#endif
    }

    func testLanguageDirectionResolverDetectsSourceOnlyWhenBothLanguagesAreAutomatic() {
        let direction = LanguageDirectionResolver.resolve(
            for: "This is a simple English sentence for language detection.",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverDetectsSourceWhenUserChoosesTargetLanguage() {
        let direction = LanguageDirectionResolver.resolve(
            for: "This is a simple English sentence for language detection.",
            sourceLanguage: "auto",
            targetLanguage: "zh-Hans",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverTreatsShortASCIITextAsEnglishInAutomaticMode() {
        let direction = LanguageDirectionResolver.resolve(
            for: "hello",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverTreatsHanTextAsSimplifiedChineseInAutomaticMode() {
        let direction = LanguageDirectionResolver.resolve(
            for: "你好",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "zh-Hans")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "zh")
        XCTAssertEqual(direction?.targetIdentifier, "en")
    }

    func testLanguageDirectionResolverDefaultsLatinSmallLanguagesToEnglishInAutomaticMode() {
        let direction = LanguageDirectionResolver.resolve(
            for: "bonjour",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverKeepsManuallySelectedSmallLanguage() {
        let direction = LanguageDirectionResolver.resolve(
            for: "bonjour",
            sourceLanguage: "fr",
            targetLanguage: "zh-Hans",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "fr")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "fr")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverUsesConfiguredJapaneseEnglishPair() {
        let direction = LanguageDirectionResolver.resolve(
            for: "こんにちは",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["ja", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "ja")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "ja")
        XCTAssertEqual(direction?.targetIdentifier, "en")
    }

    func testLanguageDirectionResolverTranslatesEnglishToConfiguredPrimaryLanguage() {
        let direction = LanguageDirectionResolver.resolve(
            for: "hello",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["ja", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "ja")
    }

    func testSettingsStoreKeepsAutoDetectionLanguagesDistinct() {
        let settingsStore = makeSettingsStore()

        settingsStore.primaryAutoDetectionLanguage = "ja"
        settingsStore.secondaryAutoDetectionLanguage = "ja"

        XCTAssertEqual(settingsStore.secondaryAutoDetectionLanguage, "ja")
        XCTAssertNotEqual(settingsStore.primaryAutoDetectionLanguage, settingsStore.secondaryAutoDetectionLanguage)
    }

    func testDisplayLanguageOnlyOffersChineseAndEnglish() {
        XCTAssertEqual(DisplayLanguage.allCases, [.simplifiedChinese, .english])
    }

    func testTranslationLanguageTitlesUseSelectedDisplayLanguage() {
        XCTAssertEqual(
            TranslationLanguageOptions.title(for: "fr", in: .english),
            "French"
        )
        XCTAssertEqual(
            LanguageDirectionResolver.displayName(for: "es", in: .simplifiedChinese),
            "西班牙语"
        )
    }

    func testLanguageDirectionResolverMatchesSameLanguagesForNoOpTranslation() {
        XCTAssertTrue(LanguageDirectionResolver.languagesMatch("en", "en"))
        XCTAssertTrue(LanguageDirectionResolver.languagesMatch("en", "en-US"))
        XCTAssertTrue(LanguageDirectionResolver.languagesMatch("zh-Hans", "zh-Hans"))
        XCTAssertFalse(LanguageDirectionResolver.languagesMatch("zh-Hans", "zh-Hant"))
        XCTAssertFalse(LanguageDirectionResolver.languagesMatch("en", "zh-Hans"))
    }

    func testLegacyOnlinePreferenceStillUsesLocalTranslation() throws {
        let defaults = makeDefaultsSuite(named: "TransnapTests.legacySettings.\(UUID().uuidString)")
        defaults.set(true, forKey: "settings.onlineTranslationEnabled")
        defaults.set(true, forKey: "settings.debugProSubscriptionEnabled")
        let settingsStore = SettingsStore(defaults: defaults, appBuild: "1")
        settingsStore.sourceLanguage = "en"
        settingsStore.targetLanguage = "zh-Hans"
        let container = try makeInMemoryContainer()
        let viewModel = TransnapViewModel(modelContext: container.mainContext, settingsStore: settingsStore)

        viewModel.inputText = String(repeating: "Hello ", count: 1_000)
        viewModel.requestTranslationFromInput()

        XCTAssertNotNil(viewModel.translationConfiguration)
        XCTAssertNotNil(viewModel.systemTranslationRequestID)
        XCTAssertTrue(viewModel.isTranslating)
        XCTAssertNil(viewModel.lastErrorMessage)
        XCTAssertEqual(viewModel.sourceText, viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TranslationRecord>()), 0)
    }

    func testSameLanguageTranslationReturnsSourceTextWithoutStartingTranslation() throws {
        let settingsStore = makeSettingsStore()
        settingsStore.sourceLanguage = "en"
        settingsStore.targetLanguage = "en"
        let container = try makeInMemoryContainer()
        let viewModel = TransnapViewModel(
            modelContext: container.mainContext,
            settingsStore: settingsStore
        )

        viewModel.inputText = "Keep this text as-is"
        viewModel.requestTranslationFromInput()

        XCTAssertEqual(viewModel.sourceText, "Keep this text as-is")
        XCTAssertEqual(viewModel.translatedText, "Keep this text as-is")
        XCTAssertEqual(viewModel.lastResolvedSourceLanguageIdentifier, "en")
        XCTAssertEqual(viewModel.lastResolvedTargetLanguageIdentifier, "en")
        XCTAssertFalse(viewModel.isTranslating)
        XCTAssertNil(viewModel.translationConfiguration)
        XCTAssertNil(viewModel.lastErrorMessage)
    }

#if DEBUG
    func testLocalTranslationKeepsLatestRequestWhenQueuedRapidly() throws {
        let settingsStore = makeSettingsStore()
        settingsStore.sourceLanguage = "en"
        settingsStore.targetLanguage = "zh-Hans"
        let container = try makeInMemoryContainer()
        let viewModel = TransnapViewModel(
            modelContext: container.mainContext,
            settingsStore: settingsStore
        )

        viewModel.inputText = "First request"
        viewModel.requestTranslationFromInput()
        let firstRequest = try XCTUnwrap(viewModel.debugPendingSystemTranslationRequestForTesting)

        viewModel.inputText = "Second request"
        viewModel.requestTranslationFromInput()
        let secondRequest = try XCTUnwrap(viewModel.debugPendingSystemTranslationRequestForTesting)

        XCTAssertNotEqual(firstRequest.id, secondRequest.id)
        XCTAssertFalse(viewModel.debugIsCurrentTranslationRequestForTesting(firstRequest.id))
        XCTAssertTrue(viewModel.debugIsCurrentTranslationRequestForTesting(secondRequest.id))
        XCTAssertEqual(viewModel.systemTranslationRequestID, secondRequest.id)
        XCTAssertEqual(secondRequest.text, "Second request")
        XCTAssertEqual(secondRequest.targetIdentifier, "zh-Hans")
        XCTAssertEqual(viewModel.sourceText, "Second request")
    }
#endif

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TranslationRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for condition")
    }

    private func makeSettingsStore() -> SettingsStore {
        SettingsStore(
            defaults: makeDefaultsSuite(named: "TransnapTests.\(UUID().uuidString)"),
            appBuild: "1"
        )
    }

    private func makeDefaultsSuite(named suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
