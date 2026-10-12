//
//  AppSettingsController.swift
//  Transnap
//
//  Created by Codex on 2026/4/13.
//

import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppSettingsController {
    private let settingsStore: SettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var isSynchronizingLaunchAtLogin = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        bindSettings()

        DispatchQueue.main.async { [weak self] in
            self?.activate()
        }
    }

    private func bindSettings() {
        settingsStore.$appearance
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] appearance in
                self?.syncAppearance(appearance)
            }
            .store(in: &cancellables)

        settingsStore.$launchAtLogin
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.setLaunchAtLogin(isEnabled)
            }
            .store(in: &cancellables)
    }

    func activate() {
        syncAppearance(settingsStore.appearance)
        syncLaunchAtLoginFromSystem()
    }

    private func syncAppearance(_ appearance: SettingsStore.Appearance) {
        guard let app = NSApp else { return }

        switch appearance {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .vibrantLight)
        case .dark:
            app.appearance = NSAppearance(named: .vibrantDark)
        }
    }

    private func setLaunchAtLogin(_ isEnabled: Bool) {
        guard isSynchronizingLaunchAtLogin == false else { return }

        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            syncLaunchAtLoginFromSystem()
        } catch {
            settingsStore.updateLaunchAtLoginState(.unavailable(userFacingLaunchAtLoginError(from: error)))
            syncStoredLaunchAtLoginValue(from: SMAppService.mainApp.status)
        }
    }

    private func syncLaunchAtLoginFromSystem() {
        let status = SMAppService.mainApp.status
        syncStoredLaunchAtLoginValue(from: status)

        switch status {
        case .enabled:
            settingsStore.updateLaunchAtLoginState(.enabled)
        case .notRegistered:
            settingsStore.updateLaunchAtLoginState(.disabled)
        case .notFound:
            settingsStore.updateLaunchAtLoginState(.unavailable(settingsStore.text("当前环境暂不支持“登录时自动打开”。", "Open at Login is not supported in the current environment.")))
        case .requiresApproval:
            settingsStore.updateLaunchAtLoginState(.requiresApproval)
        @unknown default:
            settingsStore.updateLaunchAtLoginState(.unavailable(settingsStore.text("暂时无法读取“登录时自动打开”的状态。", "Unable to read the Open at Login status right now.")))
        }
    }

    private func syncStoredLaunchAtLoginValue(from status: SMAppService.Status) {
        let shouldBeEnabled: Bool
        switch status {
        case .enabled, .requiresApproval:
            shouldBeEnabled = true
        case .notRegistered, .notFound:
            shouldBeEnabled = false
        @unknown default:
            shouldBeEnabled = settingsStore.launchAtLogin
        }

        guard settingsStore.launchAtLogin != shouldBeEnabled else { return }

        isSynchronizingLaunchAtLogin = true
        settingsStore.launchAtLogin = shouldBeEnabled
        isSynchronizingLaunchAtLogin = false
    }

    private func userFacingLaunchAtLoginError(from error: Error) -> String {
        settingsStore.text("设置“登录时自动打开”失败：\(error.localizedDescription)", "Failed to update Open at Login: \(error.localizedDescription)")
    }
}
