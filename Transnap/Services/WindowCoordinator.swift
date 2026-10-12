//
//  WindowCoordinator.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import AppKit
import SwiftData
import SwiftUI

@available(macOS 15.0, *)
@MainActor
final class WindowCoordinator {
    private let viewModel: TransnapViewModel
    private let settingsStore: SettingsStore
    private let modelContainer: ModelContainer

    private var translatorWindowController: NSWindowController?
    private var historyWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?

    init(
        viewModel: TransnapViewModel,
        settingsStore: SettingsStore,
        modelContainer: ModelContainer
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.modelContainer = modelContainer
    }

    func showTranslatorWindow() {
        if translatorWindowController == nil {
            let content = TranslatorWindowView(viewModel: viewModel, settingsStore: settingsStore, windowCoordinator: self)
                .modelContainer(modelContainer)
            translatorWindowController = makeTranslatorPanelController(
                size: NSSize(width: 380, height: 360),
                content: content
            )
        }

        viewModel.handleMenuOpened()
        positionTranslatorWindowIfNeeded()
        show(windowController: translatorWindowController)
    }

    func toggleTranslatorWindow() {
        if let window = translatorWindowController?.window,
           window.isVisible,
           NSApp.keyWindow === window || NSApp.mainWindow === window {
            window.orderOut(nil)
            return
        }

        showTranslatorWindow()
    }

    func showHistoryWindow() {
        if historyWindowController == nil {
            let content = HistoryWindowView(settingsStore: settingsStore)
                .modelContainer(modelContainer)
            historyWindowController = makeWindowController(
                title: settingsStore.text("翻译历史", "Translation History"),
                size: NSSize(width: 440, height: 520),
                content: content
            )
        }

        show(windowController: historyWindowController)
    }

    func showSettingsWindow() {
        if settingsWindowController == nil {
            let content = SettingsView(
                settingsStore: settingsStore
            )
                .modelContainer(modelContainer)
            settingsWindowController = makeSettingsWindowController(
                title: settingsStore.text("设置", "Settings"),
                size: NSSize(width: 480, height: 560),
                content: content
            )
        }

        show(windowController: settingsWindowController)
    }

    private func show(windowController: NSWindowController?) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = windowController?.window, window.isMiniaturized {
            window.deminiaturize(nil)
        }
        windowController?.showWindow(nil)
        windowController?.window?.orderFrontRegardless()
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func positionTranslatorWindowIfNeeded() {
        guard let window = translatorWindowController?.window else { return }

        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? window.screen ?? NSScreen.main
        guard let screen = targetScreen else { return }

        let windowSize = window.frame.size
        let horizontalInset: CGFloat = 36
        let verticalGap: CGFloat = 6
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY

        let x = screen.visibleFrame.maxX - windowSize.width - horizontalInset
        let y = screen.frame.maxY - menuBarHeight - windowSize.height - verticalGap

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func makeTranslatorPanelController<Content: View>(
        size: NSSize,
        content: Content
    ) -> NSWindowController {
        let hostingController = NSHostingController(rootView: content)
        let panel = FloatingTranslatorPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.setContentSize(size)
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        return NSWindowController(window: panel)
    }

    private func makeWindowController<Content: View>(
        title: String,
        size: NSSize,
        hidesTitle: Bool = false,
        content: Content
    ) -> NSWindowController {
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.center()
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = hidesTitle ? .hidden : .visible
        window.titlebarSeparatorStyle = .none
        return NSWindowController(window: window)
    }

    private func makeSettingsWindowController<Content: View>(
        title: String,
        size: NSSize,
        content: Content
    ) -> NSWindowController {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.contentViewController = NSHostingController(rootView: content)
        window.minSize = size
        window.maxSize = size
        window.isReleasedWhenClosed = false
        window.center()
        return NSWindowController(window: window)
    }
}

private final class FloatingTranslatorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
