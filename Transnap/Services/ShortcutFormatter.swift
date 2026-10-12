//
//  ShortcutFormatter.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import AppKit
import Carbon
import Foundation

enum ShortcutFormatter {
    static func string(forKeyCode keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }

        parts.append(keyString(for: keyCode))
        return parts.joined(separator: " ")
    }

    static func carbonModifiers(from eventModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if eventModifiers.contains(.command) { modifiers |= UInt32(cmdKey) }
        if eventModifiers.contains(.option) { modifiers |= UInt32(optionKey) }
        if eventModifiers.contains(.control) { modifiers |= UInt32(controlKey) }
        if eventModifiers.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    private static func keyString(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_Tab: return "⇥"
        default:
            if let scalar = keyboardLayoutCharacter(for: keyCode) {
                return scalar.uppercased()
            }
            return "\(keyCode)"
        }
    }

    private static func keyboardLayoutCharacter(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawLayoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        guard let keyboardLayout = CFDataGetBytePtr(layoutData)?.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1, { $0 }) else {
            return nil
        }

        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else {
            return nil
        }

        return String(utf16CodeUnits: chars, count: length)
    }
}
