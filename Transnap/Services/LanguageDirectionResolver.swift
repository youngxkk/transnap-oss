//
//  LanguageDirectionResolver.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import Foundation
import NaturalLanguage

struct TranslationDirection {
    let source: Locale.Language?
    let target: Locale.Language
    let detectedSourceIdentifier: String
    let targetIdentifier: String
}

enum LanguageDirectionResolver {
    private static let chineseCodes = ["zh", "zh-Hans", "zh-Hant"]
    private static let englishCode = "en"
    private static let defaultAutoDetectionLanguageIdentifiers = ["zh-Hans", "en"]
    private static let undeterminedLanguageIdentifier = "und"

    static func resolve(for text: String, sourceLanguage: String, targetLanguage: String, automaticLanguageIdentifiers: [String] = defaultAutoDetectionLanguageIdentifiers) -> TranslationDirection? {
        let automaticLanguages = normalizedAutomaticLanguageIdentifiers(automaticLanguageIdentifiers)
        let shouldDetectSourceLanguage = sourceLanguage == "auto"
        let detectedIdentifier = shouldDetectSourceLanguage
            ? detectLanguageIdentifier(for: text, automaticLanguageIdentifiers: automaticLanguages)
            : undeterminedLanguageIdentifier

        let finalSourceIdentifier: String
        if sourceLanguage == "auto" {
            finalSourceIdentifier = detectedIdentifier
        } else {
            finalSourceIdentifier = sourceLanguage
        }

        let finalTargetIdentifier: String
        if targetLanguage == "auto" {
            finalTargetIdentifier = automaticTargetIdentifier(
                for: finalSourceIdentifier,
                automaticLanguageIdentifiers: automaticLanguages
            )
        } else {
            finalTargetIdentifier = targetLanguage
        }

        return TranslationDirection(
            source: finalSourceIdentifier == undeterminedLanguageIdentifier ? nil : Locale.Language(identifier: finalSourceIdentifier),
            target: Locale.Language(identifier: finalTargetIdentifier),
            detectedSourceIdentifier: finalSourceIdentifier,
            targetIdentifier: finalTargetIdentifier
        )
    }

    static func displayName(for identifier: String, in displayLanguage: DisplayLanguage? = nil) -> String {
        if identifier == undeterminedLanguageIdentifier {
            return displayLanguage?.text(
                "自动检测",
                "Auto Detect",
                french: "Détection automatique",
                spanish: "Detección automática"
            ) ?? "自动检测"
        }

        if let displayLanguage {
            return TranslationLanguageOptions.title(for: identifier, in: displayLanguage)
        }

        return Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    static func languagesMatch(_ lhs: String, _ rhs: String) -> Bool {
        if isChinese(lhs) || isChinese(rhs) {
            return lhs == rhs
        }

        return languageMatches(lhs, rhs)
    }

    private static func detectLanguageIdentifier(for text: String, automaticLanguageIdentifiers: [String]) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fallbackLanguage = automaticLanguageIdentifiers.first else { return englishCode }
        guard !trimmedText.isEmpty else { return fallbackLanguage }

        if containsHanCharacter(in: trimmedText),
           let chineseLanguage = automaticLanguageIdentifiers.first(where: { isChinese($0) }) {
            return chineseLanguage
        }

        if containsKanaCharacter(in: trimmedText),
           let japaneseLanguage = automaticLanguageIdentifiers.first(where: { languageMatches($0, "ja") }) {
            return japaneseLanguage
        }

        if containsHangulCharacter(in: trimmedText),
           let koreanLanguage = automaticLanguageIdentifiers.first(where: { languageMatches($0, "ko") }) {
            return koreanLanguage
        }

        if isASCIIText(trimmedText),
           let englishLanguage = automaticLanguageIdentifiers.first(where: { isEnglish($0) }),
           automaticLanguageIdentifiers.contains(where: { usesNonLatinScript($0) }) {
            return englishLanguage
        }

        let recognizer = NLLanguageRecognizer()
        let hintWeight = 1.0 / Double(max(automaticLanguageIdentifiers.count, 1))
        recognizer.languageHints = automaticLanguageIdentifiers.reduce(into: [NLLanguage: Double]()) { hints, identifier in
            hints[naturalLanguage(for: identifier)] = hintWeight
        }
        recognizer.processString(trimmedText)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 12)
        return automaticLanguageIdentifiers.max { lhs, rhs in
            confidence(for: lhs, in: hypotheses) < confidence(for: rhs, in: hypotheses)
        } ?? fallbackLanguage
    }

    private static func automaticTargetIdentifier(for sourceIdentifier: String, automaticLanguageIdentifiers: [String]) -> String {
        guard let primaryLanguage = automaticLanguageIdentifiers.first else { return englishCode }
        let secondaryLanguage = automaticLanguageIdentifiers.dropFirst().first ?? englishCode

        if languageMatches(sourceIdentifier, primaryLanguage) {
            return secondaryLanguage
        }

        if languageMatches(sourceIdentifier, secondaryLanguage) {
            return primaryLanguage
        }

        return primaryLanguage
    }

    private static func normalizedAutomaticLanguageIdentifiers(_ identifiers: [String]) -> [String] {
        let candidates = identifiers.filter { $0 != "auto" }
        let uniqueCandidates = candidates.reduce(into: [String]()) { result, identifier in
            guard result.contains(where: { languageMatches($0, identifier) }) == false else { return }
            result.append(identifier)
        }

        if uniqueCandidates.count >= 2 {
            return Array(uniqueCandidates.prefix(2))
        }

        if let firstLanguage = uniqueCandidates.first {
            let fallbackLanguage = defaultAutoDetectionLanguageIdentifiers.first(where: {
                languageMatches($0, firstLanguage) == false
            }) ?? englishCode
            return [firstLanguage, fallbackLanguage]
        }

        return defaultAutoDetectionLanguageIdentifiers
    }

    private static func isChinese(_ identifier: String) -> Bool {
        chineseCodes.contains { identifier.hasPrefix($0) }
    }

    private static func isEnglish(_ identifier: String) -> Bool {
        identifier.hasPrefix(englishCode)
    }

    private static func languageMatches(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        if isChinese(lhs), isChinese(rhs) { return true }
        return lhs.hasPrefix("\(rhs)-") || rhs.hasPrefix("\(lhs)-")
    }

    private static func naturalLanguage(for identifier: String) -> NLLanguage {
        if isChinese(identifier) {
            return identifier.hasPrefix("zh-Hant") ? .traditionalChinese : .simplifiedChinese
        }

        return NLLanguage(rawValue: Locale.Language(identifier: identifier).languageCode?.identifier ?? identifier)
    }

    private static func confidence(for identifier: String, in hypotheses: [NLLanguage: Double]) -> Double {
        if isChinese(identifier) {
            return (hypotheses[.simplifiedChinese] ?? 0) + (hypotheses[.traditionalChinese] ?? 0)
        }

        return hypotheses[naturalLanguage(for: identifier)] ?? 0
    }

    private static func usesNonLatinScript(_ identifier: String) -> Bool {
        isChinese(identifier)
            || languageMatches(identifier, "ja")
            || languageMatches(identifier, "ko")
    }

    private static func containsHanCharacter(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2A6DF,
                 0x2A700...0x2B73F,
                 0x2B740...0x2B81F,
                 0x2B820...0x2CEAF:
                return true
            default:
                return false
            }
        }
    }

    private static func containsKanaCharacter(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x309F,
                 0x30A0...0x30FF,
                 0x31F0...0x31FF:
                return true
            default:
                return false
            }
        }
    }

    private static func containsHangulCharacter(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x1100...0x11FF,
                 0x3130...0x318F,
                 0xAC00...0xD7AF:
                return true
            default:
                return false
            }
        }
    }

    private static func isASCIIText(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy(\.isASCII)
    }
}
