# Transnap

[简体中文](README.md) | English

Transnap is available on the App Store: [Download on the App Store](https://apps.apple.com/app/id6762361410).

Transnap is a completely free macOS menu bar app that makes translating copied text quick and easy. It uses Apple's `Translation` framework to translate on your Mac. Open the translation panel from the menu bar, with a global keyboard shortcut, or with an optional shortcut that lets you press Copy twice. It is designed for short passages from articles, chats, and documents.

This source release uses local translation only, with no paid memberships or online translation services. No API keys, Node.js, or TypeScript setup is required.

Current source version:

- Version: `1.3`
- Build: `55`
- Default Bundle ID for the open-source version: `com.example.transnap` (customizable through local configuration)
- Minimum macOS: `15.0`

## Screenshot

![Transnap app screenshot](docs/screenshots/screen-1.png)

## Features

### Menu bar translation

Transnap runs in the menu bar. Clicking its icon opens the translation panel and automatically fills the input field with plain text from your clipboard.

The panel lets you:

- Automatically load text from the clipboard
- Type or paste text manually
- Select source and target languages automatically or manually
- Copy the translation with one click
- Open History and Settings

### Keyboard shortcuts

The default global shortcut is:

- `Command + Shift + C`

You can record a different shortcut in Settings.

> [!WARNING]
> You can also enable `Command + C + C` in Settings: hold `Command` and press `C` twice. This opens the translation panel immediately after copying and requires macOS Input Monitoring permission. Without that permission, the default global shortcut and menu bar access still work.

### Language and appearance

Settings includes:

- App language: Simplified Chinese or English
- Appearance: System, Light, or Dark
- A preferred language pair for automatic detection
- Source and target language selection for the translation panel

Automatic detection chooses between the two preferred languages you configure. You can select other languages manually in the translation panel.

### Translation history

Each successful translation creates a `TranslationRecord`, stored locally using SwiftData.

In the History window, you can:

- View the original text and translation
- See the language direction and timestamp
- Copy a previous translation
- Delete individual records
- Clear all translation history

You can set the maximum number of records in Settings. When a new translation is saved, the app removes older records that exceed this limit.

The default limit is 50 records, adjustable from 10 to 200.

### Launch at login

The “Open at Login” setting uses `SMAppService.mainApp` to register the app as a macOS login item. Depending on the system state, you may need to confirm it in System Settings under Login Items.

### Offline language packs

The offline language packs page displays language resource availability reported by Apple's `Translation` framework. When downloading is supported, it calls `prepareTranslation()` to let the system prepare offline translation resources. Downloaded language packs are managed by macOS System Settings.

### About and feedback

The About page in Settings provides links for email feedback, X, and Xiaohongshu. Click the feedback button to send an email, or hover over it to view and copy the email address.

## Permissions and privacy

### Clipboard

Transnap reads plain text from your clipboard to fill the input field and translate quickly. Translation takes place entirely on your Mac; your text is not uploaded, and translation history is stored locally. Using a language for the first time may require an internet connection to download Apple's system language pack. Once downloaded, it can be used offline.

### Input Monitoring

The double-copy shortcut is disabled by default. Transnap requests Input Monitoring permission only when you confirm that you want to enable `Command + C + C` in Settings.

When enabled, the app recognizes this shortcut through global keyboard events to open the translation panel after copying. It does not record other keystrokes or upload keyboard events. Without permission, this feature does not run; the default global shortcut and menu bar access remain available.

## Built with

- SwiftUI
- AppKit
- SwiftData
- Translation framework
- NaturalLanguage framework
- Carbon Hot Key API
- ServiceManagement

## Running locally

### Requirements

- macOS 15.0 or later
- Xcode 26 or later: the source uses `glassEffect` from the macOS 26 SDK and provides a compatible interface for macOS 15
- The app and tests are written in Swift and use Apple system frameworks; no third-party packages are required

### Using Xcode

1. Clone or download the repository and open [Transnap.xcodeproj](Transnap.xcodeproj).
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, then enter your own `DEVELOPMENT_TEAM` and a unique `TRANSNAP_BUNDLE_ID`. This local configuration applies to the app, unit test, and UI test targets and is ignored by Git.
3. Select the `Transnap` scheme and your Mac, then run the app.

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Alternatively, choose your Team and Bundle Identifier for each target directly in Xcode's Signing & Capabilities tab. This open-source release does not include the author's signing team, certificates, or private keys. Its default Bundle ID differs from the App Store version, so local data is stored separately.

The app runs as a menu bar utility and does not appear as a regular app in the Dock.

### Building from the command line

These commands compile without code signing and place build outputs in a temporary directory.

```bash
xcodebuild -project Transnap.xcodeproj -scheme Transnap \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/Transnap-Debug CODE_SIGNING_ALLOWED=NO build
```

Release build:

```bash
xcodebuild -project Transnap.xcodeproj -scheme Transnap \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath /tmp/Transnap-Release CODE_SIGNING_ALLOWED=NO build
```

After configuring your own signing, run the unit tests:

```bash
xcodebuild -project Transnap.xcodeproj -scheme Transnap \
  -destination 'platform=macOS' -derivedDataPath /tmp/Transnap-Tests \
  -only-testing:TransnapTests test
```

Both current UI tests are marked as skipped and do not establish that UI behavior has been verified.

## Before submitting to the App Store

Use the full workflow in Xcode Organizer:

1. Product > Archive
2. Validate App
3. Distribute App / Upload

Before submitting, confirm that:

- The version and build number match your planned release, and the build number is higher than any previously uploaded build
- You use your own registered Bundle ID and developer Team when publishing your version
- The archive includes both `arm64` and `x86_64`
- App Sandbox is enabled
- The uploaded app uses App Store distribution signing rather than local development signing
- Input Monitoring and the double-copy shortcut are accurately described in your product information and review notes
- You exclude locally generated `.dmg`, `.xcarchive`, `.xcresult`, and DerivedData artifacts from the upload

## Project structure

```text
Transnap.xcodeproj/                  # Xcode project
Config/                             # Build configuration and Info.plist
Transnap/
├── TransnapApp.swift                # App entry point; initializes models, menu bar, settings, and shortcuts
├── ContentView.swift                # SwiftUI preview
├── Assets.xcassets/                 # App, menu bar, and social link icons
├── Models/
│   └── TranslationRecord.swift      # SwiftData translation record model
├── Services/                       # Clipboard, shortcuts, language packs, windows, and user settings
├── ViewModels/
│   └── TransnapViewModel.swift      # Translation flow, state, history persistence, and retention
└── Views/                          # Translation panel, history, settings, and onboarding
TransnapTests/                      # Unit tests
TransnapUITests/                    # UI test entry points; currently skipped
```

## About this repository

This repository was created from the current source and does not include the original private repository's commit history. The public feedback email address, social accounts, App Store link, app assets, and copyright notices are retained.

Review staged changes before committing. Do not upload `Config/Local.xcconfig`, keys, certificates, personal Xcode configuration, or build artifacts.

## License

This project is licensed under the [MIT License](LICENSE). Copyright © 2026 youngxkk.

You may use, modify, distribute, and use the software commercially, provided you retain the copyright notice and license text. Third-party brand marks remain the property of their respective owners.
