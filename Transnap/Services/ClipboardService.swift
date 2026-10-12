//
//  ClipboardService.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit

enum ClipboardService {
    static func currentText() -> String? {
        let pasteboard = NSPasteboard.general
        guard let value = pasteboard.string(forType: .string) else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
