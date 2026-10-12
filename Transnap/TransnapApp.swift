//
//  TransnapApp.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit
import SwiftData
import SwiftUI

@available(macOS 15.0, *)
@main
struct TransnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let sharedModelContainer: ModelContainer
    private let settingsStore: SettingsStore
    private let appSettingsController: AppSettingsController?
    private let hotkeyManager: GlobalHotkeyManager?
    private let menuBarController: MenuBarController?
    private let windowCoordinator: WindowCoordinator
    @StateObject private var viewModel: TransnapViewModel

    init() {
        let schema = Schema([
            TranslationRecord.self,
        ])
        let container = Self.makeModelContainer(for: schema)

        sharedModelContainer = container

        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore

        let rootViewModel = TransnapViewModel(
            modelContext: container.mainContext,
            settingsStore: settingsStore
        )
        _viewModel = StateObject(wrappedValue: rootViewModel)


        let coordinator = WindowCoordinator(
            viewModel: rootViewModel,
            settingsStore: settingsStore,
            modelContainer: container
        )
        self.windowCoordinator = coordinator

        if Self.isRunningTests {
            appSettingsController = nil
            hotkeyManager = nil
            menuBarController = nil
        } else {
            appSettingsController = AppSettingsController(settingsStore: settingsStore)

            let menuBarController = MenuBarController(
                viewModel: rootViewModel,
                settingsStore: settingsStore,
                windowCoordinator: coordinator,
                modelContainer: container
            )
            self.menuBarController = menuBarController

            let hotkeyManager = GlobalHotkeyManager(settingsStore: settingsStore)
            hotkeyManager.onTrigger = {
                menuBarController.togglePopover()
            }
            hotkeyManager.onDoubleCopyTrigger = {
                menuBarController.showPopoverForShortcut()
            }
            self.hotkeyManager = hotkeyManager
        }
    }

    @SceneBuilder
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(settingsStore.text("设置...", "Settings...")) {
                        windowCoordinator.showSettingsWindow()
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                }

                CommandGroup(replacing: .appTermination) {
                    Button("Quit Transnap") {
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: [.command])
                }
            }
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private static func makeModelContainer(for schema: Schema) -> ModelContainer {
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfiguration])
        } catch {
            NSLog("Transnap failed to open persistent SwiftData store: \(error.localizedDescription)")
        }

        let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
        } catch {
            fatalError("Could not create fallback ModelContainer: \(error)")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
