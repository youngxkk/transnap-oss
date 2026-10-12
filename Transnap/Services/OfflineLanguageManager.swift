//
//  OfflineLanguageManager.swift
//  Transnap
//
//  Created by Codex on 2026/4/13.
//

import Combine
import Foundation
import Translation

@available(macOS 15.0, *)
@MainActor
final class OfflineLanguageManager: ObservableObject {
    struct LanguagePack: Identifiable, Equatable {
        let identifier: String
        let name: String

        var id: String { identifier }
    }

    enum InstallState: Equatable {
        case idle
        case installing(String)
    }

    @Published private(set) var packs: [LanguagePack] = []
    @Published private(set) var statuses: [String: LanguageAvailability.Status] = [:]
    @Published private(set) var installState: InstallState = .idle
    @Published var lastErrorMessage: String?
    @Published var pendingConfiguration: TranslationSession.Configuration?

    private let availability: LanguageAvailability
    private let knownLanguageIdentifiers = TranslationLanguageOptions.autoDetectionCandidates.map(\.identifier)

    init(availability: LanguageAvailability = LanguageAvailability()) {
        self.availability = availability
        self.packs = knownLanguageIdentifiers.map { identifier in
            LanguagePack(
                identifier: identifier,
                name: Locale.current.localizedString(forIdentifier: identifier) ?? identifier
            )
        }
    }

    func refreshStatuses() async {
        lastErrorMessage = nil

        packs = knownLanguageIdentifiers
            .map { identifier in
                LanguagePack(
                    identifier: identifier,
                    name: Locale.current.localizedString(forIdentifier: identifier) ?? identifier
                )
            }

        guard !packs.isEmpty else { return }

        for pack in packs {
            let language = Locale.Language(identifier: pack.identifier)
            let status = await availability.status(from: language, to: nil)
            statuses[pack.identifier] = status
        }
    }

    func requestInstall(for identifier: String) {
        guard installState == .idle else { return }

        lastErrorMessage = nil
        installState = .installing(identifier)
        pendingConfiguration = TranslationSession.Configuration(
            source: Locale.Language(identifier: identifier),
            target: installCompanionLanguage(for: identifier)
        )
    }

    func requestInstall(source sourceIdentifier: String, target targetIdentifier: String) {
        guard installState == .idle else { return }
        guard sourceIdentifier != "auto", targetIdentifier != "auto", sourceIdentifier != targetIdentifier else { return }

        lastErrorMessage = nil
        installState = .installing(targetIdentifier)
        pendingConfiguration = TranslationSession.Configuration(
            source: Locale.Language(identifier: sourceIdentifier),
            target: Locale.Language(identifier: targetIdentifier)
        )
    }

    func performPendingInstall(using session: TranslationSession) async {
        guard case let .installing(identifier) = installState else { return }

        do {
            try await session.prepareTranslation()
            pendingConfiguration = nil
            installState = .idle
            await refreshStatuses()
        } catch {
            pendingConfiguration = nil
            installState = .idle
            lastErrorMessage = error.localizedDescription
            statuses[identifier] = await availability.status(from: Locale.Language(identifier: identifier), to: nil)
        }
    }

    func requestInstallIfNeeded(for identifier: String) async {
        guard identifier != "auto" else { return }
        guard installState == .idle || isInstalling(identifier) else { return }

        let language = Locale.Language(identifier: identifier)
        let status: LanguageAvailability.Status
        if let existingStatus = statuses[identifier] {
            status = existingStatus
        } else {
            status = await availability.status(from: language, to: nil)
        }
        statuses[identifier] = status

        guard status == .supported, !isInstalling(identifier) else { return }
        requestInstall(for: identifier)
    }

    func isInstalling(_ identifier: String) -> Bool {
        installState == .installing(identifier)
    }

    private func installCompanionLanguage(for identifier: String) -> Locale.Language {
        let fallback = identifier == "en" ? "zh-Hans" : "en"
        return Locale.Language(identifier: fallback)
    }

}
