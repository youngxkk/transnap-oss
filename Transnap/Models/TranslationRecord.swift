//
//  TranslationRecord.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import Foundation
import SwiftData

@Model
final class TranslationRecord {
    var sourceText: String
    var translatedText: String
    var sourceLanguageIdentifier: String
    var targetLanguageIdentifier: String
    var createdAt: Date
    var triggerRawValue: String

    init(
        sourceText: String,
        translatedText: String,
        sourceLanguageIdentifier: String,
        targetLanguageIdentifier: String,
        createdAt: Date = .now,
        trigger: TranslationTrigger
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguageIdentifier = sourceLanguageIdentifier
        self.targetLanguageIdentifier = targetLanguageIdentifier
        self.createdAt = createdAt
        self.triggerRawValue = trigger.rawValue
    }
}

enum TranslationTrigger: String, Codable {
    case menuBarClick
    case manualInput
}
