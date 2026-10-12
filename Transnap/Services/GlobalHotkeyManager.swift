//
//  GlobalHotkeyManager.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import Carbon
import Combine
import Foundation
import AppKit

@MainActor
final class GlobalHotkeyManager {
    var onTrigger: (() -> Void)?
    var onDoubleCopyTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var copyEventTap: CFMachPort?
    private var copyEventTapRunLoopSource: CFRunLoopSource?
    private var cancellables: Set<AnyCancellable> = []
    private let settingsStore: SettingsStore
    private let hotKeyTarget: EventTargetRef?
    private var lastCommandCopyTime: TimeInterval?
    private var lastChangeCount: Int?
    private let doubleCopyInterval: TimeInterval = 0.65

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.hotKeyTarget = GetEventDispatcherTarget()
        installEventHandler()
        bindSettings()
    }

    deinit {
        MainActor.assumeIsolated {
            cancellables.removeAll()
            uninstallCopyEventTap()
            unregisterHotkey()
            uninstallEventHandler()
        }
    }

    private func bindSettings() {
        settingsStore.$shortcutKeyCode
            .combineLatest(settingsStore.$shortcutModifiers)
            .sink { [weak self] keyCode, modifiers in
                self?.registerShortcut(keyCode: keyCode, modifiers: modifiers)
            }
            .store(in: &cancellables)

        settingsStore.$doubleCopyShortcutEnabled
            .sink { [weak self] isEnabled in
                self?.updateCopyEventTap(isEnabled: isEnabled)
            }
            .store(in: &cancellables)
    }

    private func installEventHandler() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    manager.onTrigger?()
                }
            }

            return noErr
        }

        InstallEventHandler(
            hotKeyTarget,
            handler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func uninstallEventHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installCopyEventTap() {
        guard copyEventTap == nil else { return }
        guard CGPreflightListenEventAccess() else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard type == .keyDown, let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.handleCopyKeyDown(event)
            return Unmanaged.passUnretained(event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        copyEventTap = eventTap
        copyEventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        if let copyEventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), copyEventTapRunLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    private func uninstallCopyEventTap() {
        if let copyEventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), copyEventTapRunLoopSource, .commonModes)
            self.copyEventTapRunLoopSource = nil
        }

        if let copyEventTap {
            CGEvent.tapEnable(tap: copyEventTap, enable: false)
            self.copyEventTap = nil
        }

        lastCommandCopyTime = nil
        lastChangeCount = nil
    }

    private func updateCopyEventTap(isEnabled: Bool) {
        guard isEnabled else {
            uninstallCopyEventTap()
            return
        }

        installCopyEventTap()
    }

    private func handleCopyKeyDown(_ event: CGEvent) {
        guard UInt32(event.getIntegerValueField(.keyboardEventKeycode)) == UInt32(kVK_ANSI_C) else {
            lastCommandCopyTime = nil
            lastChangeCount = nil
            return
        }

        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
        guard isCommandCopy(event.flags) else {
            lastCommandCopyTime = nil
            lastChangeCount = nil
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard let lastCommandCopyTime else {
            self.lastCommandCopyTime = now
            self.lastChangeCount = NSPasteboard.general.changeCount
            return
        }

        guard now - lastCommandCopyTime <= doubleCopyInterval else {
            self.lastCommandCopyTime = now
            self.lastChangeCount = NSPasteboard.general.changeCount
            return
        }

        let capturedChangeCount = self.lastChangeCount ?? NSPasteboard.general.changeCount
        self.lastCommandCopyTime = nil
        self.lastChangeCount = nil

        waitForClipboardUpdate(initialChangeCount: capturedChangeCount, timeout: 0.5) { [weak self] in
            self?.onDoubleCopyTrigger?()
        }
    }

    private func waitForClipboardUpdate(initialChangeCount: Int, timeout: TimeInterval, completion: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func check() {
            if NSPasteboard.general.changeCount != initialChangeCount || Date() > deadline {
                completion()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    check()
                }
            }
        }
        check()
    }

    private func isCommandCopy(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskShift)
    }

    private func registerShortcut(keyCode: UInt32, modifiers: UInt32) {
        unregisterHotkey()

        let hotKeyID = EventHotKeyID(signature: OSType(0x54534E50), id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            hotKeyTarget,
            0,
            &hotKeyRef
        )

        if status != noErr {
            hotKeyRef = nil
        }
    }

    private func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

}
