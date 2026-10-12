//
//  TransnapViewModel.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import Combine
import Foundation
import SwiftData
import SwiftUI
import Translation

@available(macOS 15.0, *)
@MainActor
final class TransnapViewModel: ObservableObject {
    @Published var translationConfiguration: TranslationSession.Configuration?
    @Published var inputText = ""
    @Published var translatedText = ""
    @Published var sourceText = ""
    @Published var lastResolvedSourceLanguageIdentifier: String?
    @Published var lastResolvedTargetLanguageIdentifier: String?
    @Published var statusMessage: String
    @Published var isTranslating = false
    @Published var lastErrorMessage: String?
    @Published private(set) var copyFeedbackToken = 0
    @Published private(set) var systemTranslationRequestID: UUID?
    private var pendingRequest: PendingTranslationRequest?
    private var currentTranslationRequestID = UUID()
    private let modelContext: ModelContext
    private let settingsStore: SettingsStore

    init(
        modelContext: ModelContext,
        settingsStore: SettingsStore
    ) {
        self.modelContext = modelContext
        self.settingsStore = settingsStore
        self.statusMessage = settingsStore.text("点击状态栏图标即可翻译剪贴板", "Click the menu bar icon to translate the clipboard")
    }

    func handleMenuOpened() {
        syncInputFromClipboard()
        requestAutomaticTranslationIfPossible()
    }

    func syncInputFromClipboard() {
        guard let clipboardText = ClipboardService.currentText() else {
            statusMessage = settingsStore.text("把内容复制后，点翻译即可", "Copy something, then click Translate")
            lastErrorMessage = nil
            return
        }

        inputText = clipboardText
        sourceText = clipboardText
        statusMessage = settingsStore.text("已填入剪贴板内容", "Clipboard text added")
        lastErrorMessage = nil
    }

    func requestTranslationFromInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = settingsStore.text("请输入要翻译的文本", "Enter text to translate")
            lastErrorMessage = settingsStore.text("输入框为空。", "The input field is empty.")
            return
        }

        queueTranslation(for: trimmed, trigger: .manualInput)
    }

    func requestAutomaticTranslationIfPossible() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        queueTranslation(for: trimmed, trigger: .menuBarClick)
    }

    func copyTranslatedText() {
        let trimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        ClipboardService.copy(text: trimmed)
        statusMessage = settingsStore.text("译文已复制", "Translation copied")
        lastErrorMessage = nil
        copyFeedbackToken += 1
    }

    func performTranslation(using session: TranslationSession, requestID: UUID?) async {
        guard let request = pendingRequest else { return }
        guard request.id == requestID, currentTranslationRequestID == request.id else { return }
        pendingRequest = nil

        defer {
            // A superseded task must not clear the newer request's loading state.
            if currentTranslationRequestID == request.id {
                isTranslating = false
                if Task.isCancelled {
                    lastErrorMessage = nil
                    statusMessage = settingsStore.text("翻译已取消", "Translation cancelled")
                }
            }
        }
        guard !Task.isCancelled else { return }

        do {
            let response = try await session.translate(request.text)
            guard isCurrentTranslationRequest(request.id) else { return }

            let record = TranslationRecord(
                sourceText: response.sourceText,
                translatedText: response.targetText,
                sourceLanguageIdentifier: request.detectedSourceIdentifier,
                targetLanguageIdentifier: request.targetIdentifier,
                trigger: request.trigger
            )

            modelContext.insert(record)
            try modelContext.save()
            try pruneHistoryIfNeeded()

            sourceText = response.sourceText
            translatedText = response.targetText
            lastResolvedSourceLanguageIdentifier = record.sourceLanguageIdentifier
            lastResolvedTargetLanguageIdentifier = record.targetLanguageIdentifier
            statusMessage = "\(settingsStore.text("本地翻译", "Local")) · \(LanguageDirectionResolver.displayName(for: record.sourceLanguageIdentifier, in: settingsStore.displayLanguage)) → \(LanguageDirectionResolver.displayName(for: record.targetLanguageIdentifier, in: settingsStore.displayLanguage))"
            lastErrorMessage = nil
        } catch is CancellationError {
            guard currentTranslationRequestID == request.id else { return }

            lastErrorMessage = nil
            statusMessage = settingsStore.text("翻译已取消", "Translation cancelled")
        } catch {
            guard isCurrentTranslationRequest(request.id) else { return }

            translatedText = ""
            sourceText = request.text
            statusMessage = settingsStore.text("翻译失败: \(error.localizedDescription)", "Translation failed: \(error.localizedDescription)")
            lastErrorMessage = error.localizedDescription
        }
    }

    func delete(_ record: TranslationRecord) {
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func queueTranslation(for text: String, trigger: TranslationTrigger) {
        guard let direction = LanguageDirectionResolver.resolve(
            for: text,
            sourceLanguage: settingsStore.sourceLanguage,
            targetLanguage: settingsStore.targetLanguage,
            automaticLanguageIdentifiers: settingsStore.autoDetectionLanguageIdentifiers
        ) else {
            statusMessage = settingsStore.text("无法识别语言", "Could not detect language")
            lastErrorMessage = settingsStore.text("系统未能识别文本语言。", "The system could not detect the text language.")
            return
        }

        let requestID = UUID()
        let request = PendingTranslationRequest(
            id: requestID,
            text: text,
            trigger: trigger,
            source: direction.source,
            target: direction.target,
            detectedSourceIdentifier: direction.detectedSourceIdentifier,
            targetIdentifier: direction.targetIdentifier
        )
        currentTranslationRequestID = requestID

        if LanguageDirectionResolver.languagesMatch(
            direction.detectedSourceIdentifier,
            direction.targetIdentifier
        ) {
            completeSameLanguageTranslation(
                text: text,
                request: request
            )
            return
        }

        sourceText = text
        translatedText = ""
        lastResolvedSourceLanguageIdentifier = nil
        lastResolvedTargetLanguageIdentifier = nil
        isTranslating = true
        lastErrorMessage = nil

        requestSystemTranslation(request)
    }

    private func completeSameLanguageTranslation(
        text: String,
        request: PendingTranslationRequest
    ) {
        sourceText = text
        translatedText = text
        lastResolvedSourceLanguageIdentifier = request.detectedSourceIdentifier
        lastResolvedTargetLanguageIdentifier = request.targetIdentifier
        isTranslating = false
        lastErrorMessage = nil
        pendingRequest = nil
        systemTranslationRequestID = nil
        translationConfiguration = nil
        statusMessage = "\(settingsStore.text("无需翻译", "No translation needed")) · \(LanguageDirectionResolver.displayName(for: request.detectedSourceIdentifier, in: settingsStore.displayLanguage)) → \(LanguageDirectionResolver.displayName(for: request.targetIdentifier, in: settingsStore.displayLanguage))"
    }

    private func isCurrentTranslationRequest(_ requestID: UUID) -> Bool {
        currentTranslationRequestID == requestID && !Task.isCancelled
    }

#if DEBUG
    var debugPendingSystemTranslationRequestForTesting: (id: UUID, text: String, targetIdentifier: String)? {
        guard let pendingRequest else { return nil }
        return (pendingRequest.id, pendingRequest.text, pendingRequest.targetIdentifier)
    }

    func debugIsCurrentTranslationRequestForTesting(_ requestID: UUID) -> Bool {
        isCurrentTranslationRequest(requestID)
    }
#endif

    private func requestSystemTranslation(
        _ request: PendingTranslationRequest
    ) {
        pendingRequest = request
        systemTranslationRequestID = request.id

        sourceText = request.text
        translatedText = ""
        lastResolvedSourceLanguageIdentifier = nil
        lastResolvedTargetLanguageIdentifier = nil
        isTranslating = true
        statusMessage = settingsStore.text(
            "本地翻译使用 Apple 官方系统语言包，首次使用可能需要下载约 200 MB。下载后可完全离线翻译，速度很快。",
            "Local translation uses Apple's official system language packs. First use may require about a 200 MB download. Once downloaded, translation works fully offline and is very fast."
        )
        lastErrorMessage = nil

        let nextConfiguration = TranslationSession.Configuration(
            source: request.source,
            target: request.target
        )

        if var existingConfiguration = translationConfiguration,
           existingConfiguration == nextConfiguration {
            existingConfiguration.invalidate()
            translationConfiguration = existingConfiguration
        } else {
            translationConfiguration = nextConfiguration
        }
    }

    private func pruneHistoryIfNeeded() throws {
        let limit = max(settingsStore.historyLimit, 1)
        let descriptor = FetchDescriptor<TranslationRecord>(
            sortBy: [SortDescriptor(\TranslationRecord.createdAt, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        guard records.count > limit else { return }

        for record in records.dropFirst(limit) {
            modelContext.delete(record)
        }

        try modelContext.save()
    }
}

private struct PendingTranslationRequest {
    let id: UUID
    let text: String
    let trigger: TranslationTrigger
    let source: Locale.Language?
    let target: Locale.Language
    let detectedSourceIdentifier: String
    let targetIdentifier: String
}
