# InApp Alt Tab

A small macOS menu bar app that switches between windows of the **currently focused application** with Option (Alt) + Tab.

For example, if you have multiple Word documents open in separate windows, you can move between them without switching to another application. Switching is immediate, with no preview or window picker. With zero or one eligible window, the shortcut does nothing.

## Requirements

- macOS 13 or later.
- Accessibility permission to control application windows.
- Xcode or Command Line Tools with Swift 6.2 or later to build from source.

There are no third-party package dependencies. GitHub releases provide a universal app for Apple Silicon and Intel Macs. Runtime behavior has been tested on Apple Silicon; Intel execution has not been verified. The default source build targets the architecture of the Mac running the build.

## Download and install

Download the universal ZIP from the [latest GitHub release](https://github.com/TakeruF/inapp-alt-tab/releases/latest), extract it, and move **InApp Alt Tab.app** to your Applications folder.

1. Launch **InApp Alt Tab.app**.
2. Use the Accessibility settings button in the setup window.
3. In **System Settings → Privacy & Security → Accessibility**, enable **InApp Alt Tab**. If the app is missing, use the **+** button to add it.
4. Open multiple windows in the same application and press **Option + Tab**.

Starting with 1.1.1, release builds use Developer ID Application signing and Apple notarization. macOS may ask you to confirm the first launch. Accessibility permission is still required to switch windows.

Older releases and default local source builds are ad hoc signed without notarization. macOS may require approval for those copies under **System Settings → Privacy & Security**. When upgrading from an ad hoc build, you may need to remove the old Accessibility entry and grant permission to the signed copy.

Each release includes `SHA256SUMS.txt` to verify the downloaded ZIP:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

Run the command in the folder containing both downloaded files.

## Build from source

```sh
git clone https://github.com/TakeruF/inapp-alt-tab.git
cd inapp-alt-tab
swift test
bash scripts/build-app.sh
```

The app is created at `dist/InApp Alt Tab.app`. Follow the installation and permission steps above.

You can also launch a development build directly:

```sh
open "dist/InApp Alt Tab.app"
```

Closing the setup window leaves the app running in the menu bar.

Source builds use a local ad hoc signature by default. To choose a different output directory, pass its path to the build script:

```sh
bash scripts/build-app.sh /path/to/output
```

To build the universal app used for releases:

```sh
bash scripts/build-app.sh --universal
```

## Signed and notarized releases

Release signing requires a **Developer ID Application** certificate and its private key in your local Keychain. List usable identities with `security find-identity -v -p codesigning`.

```sh
export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'
bash scripts/release.sh prepare
bash scripts/release.sh finish
```

`prepare` runs the tests, builds both architectures, enables Hardened Runtime, signs with a secure timestamp, and submits to Apple using the developer account already configured in Xcode. `finish` exports the notarized app, validates its attached ticket and Gatekeeper acceptance, and creates `dist/<version>/InApp-Alt-Tab-<version>-universal.zip` and `SHA256SUMS.txt`. If Apple is still processing, rerun `finish` later. Keep the submitted archive until completion; `prepare` refuses to overwrite it.

For `notarytool` instead of Xcode account authentication, securely save credentials with `xcrun notarytool store-credentials`, then set `NOTARY_KEYCHAIN_PROFILE` to that profile's name for both commands. Passwords and API keys must stay out of the repository and command history. The notarytool path retains Apple's submission status and log in the release directory.

To build a signed app without submitting it for notarization:

```sh
bash scripts/build-app.sh --universal --sign "$DEVELOPER_ID_APPLICATION" dist/signed
```

Signing alone does not notarize the app. Publish the ZIP produced by `finish`, which packages the app after its notarization ticket is attached. The release does not enable App Sandbox because window switching uses the Accessibility API.

## App language

The setup window, menu bar, permission guidance, errors, and diagnostic messages support:

- English
- Japanese
- Chinese (Simplified and Traditional)
- Korean

The app follows the preferred language order in macOS, including per-app language settings. If no supported language matches, it uses English. To choose a language just for this app, add **InApp Alt Tab** under **System Settings → General → Language & Region → Applications**, choose the language, and restart the app. This does not change the language of other applications.

Translation resources are included in the app bundle, so downloaded copies work without the source repository.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Option + Tab | Switch immediately to the next window of the focused app |
| Option + Shift + Tab | Switch in the opposite direction |
| Hold Option and press Tab repeatedly | Cycle through the app's windows |

The window order stays stable while Option is held, even if raising a window changes the order returned by macOS. Releasing Option ends that cycle. A new cycle starts from the focused window.

## Behavior

- Only the frontmost application's normal windows are eligible.
- Zero or one eligible window produces no window operation.
- Minimized windows are included and restored when selected.
- Switching is suspended while the focused window has a modal dialog or an attached sheet.
- Command + Tab continues to work as usual.
- The menu bar provides pause/resume, setup, launch at login, and quit controls.
- Launch at login is off by default. Install the app in your Applications folder before enabling it.

## Compatibility and limitations

Applications must expose their windows through the macOS Accessibility API. In-app tabs are not separate windows. Tool palettes and dialog windows are excluded.

Windows on other Spaces or in full-screen mode can only be switched if the application exposes them and macOS allows the Accessibility operation. Those configurations have not been verified.

## Privacy and permissions

Accessibility permission is used to enumerate and focus windows and observe Option-key release events. The app registers only its two shortcuts and observes modifier changes; it does not collect or save typed text or document contents.

There are no previews, screenshots, screen recording, or network requests. Screen Recording permission is not needed. Local preferences store pause state and whether setup has been shown. Operational errors may be recorded in the macOS system log without window titles or document contents.

## Troubleshooting

**Option + Tab is unavailable:** Quit or reconfigure any other app that uses the same shortcut, such as AltTab. Then restart InApp Alt Tab or toggle its enable menu item off and on. Registration errors appear in the menu and setup window.

**Windows do not switch:** Check Accessibility permission and confirm that the frontmost app has at least two normal windows. Close any modal dialog or sheet before trying again.

**Launch at login fails:** Move the app into your Applications folder. Check the relevant approval under **System Settings → General → Login Items** if macOS requests it.

## Development and verification

```sh
swift test
bash scripts/build-app.sh
```

The eight window-cycle tests cover empty/single-window cases, duplicate entries, forward and backward cycling, enumeration changes, delayed focus reports, Option release, application changes, and windows being opened or closed. Five localization tests cover complete translations, regional language matching, preference order, English fallback, Chinese script variants, and formatted error details.

The app has been built and launched on macOS 27.0.1. Shortcut registration has been checked, and the diagnostic command has switched between two blank Word documents in both directions and performed no operation with one document window. The user has also confirmed that pressing Option + Tab on a physical keyboard switches between Word document windows. Reverse switching with physical keys and the full hold-Option workflow still need manual verification.

For 1.1.0, packaged translations, localized permission descriptions, regional selection, and English fallback were checked. Setup windows were visually checked in all five locales on Apple Silicon.

For 1.1.1, all 13 tests pass. The extracted universal release ZIP was checked for Developer ID signing, Hardened Runtime, and secure timestamps in both architectures, a valid attached notarization ticket, and Gatekeeper acceptance as `Notarized Developer ID`. The signed app launches on Apple Silicon with switching enabled, and both shortcuts register successfully. Intel runtime behavior and physical-key reverse/hold-Option cycling remain unverified.

Quit the running app before checking shortcut registration:

```sh
"dist/InApp Alt Tab.app/Contents/MacOS/InAppAltTab" --check-shortcuts
"dist/InApp Alt Tab.app/Contents/MacOS/InAppAltTab" --check-permission
```

To test window operations separately from keyboard delivery, keep the target app in the foreground and invoke the following from a background process:

```sh
"dist/InApp Alt Tab.app/Contents/MacOS/InAppAltTab" --switch-once
"dist/InApp Alt Tab.app/Contents/MacOS/InAppAltTab" --switch-once --backwards
```

Running these commands from a foreground terminal makes the terminal itself the target. The diagnostic prints the frontmost application's bundle identifier and whether a window operation was performed.

To inspect packaged translations without changing saved language settings:

```sh
"dist/InApp Alt Tab.app/Contents/MacOS/InAppAltTab" --dump-localization -AppleLanguages '(ko)'
```

Replace `ko` with `en`, `ja`, `zh-Hans`, or `zh-Hant`. The report includes the selected language, resource bundle path, and translated strings. For a temporary setup preview, launch the app with `--show-setup` and the same language argument after quitting any running copy.

## Implementation

The app uses Swift, AppKit, ApplicationServices, Carbon, and ServiceManagement. Global shortcuts are registered with Carbon. Accessibility windows are enumerated for the frontmost process and raised with `AXRaise`, followed by writable focus attributes. The frontmost process is checked again before acting.

`WindowCycle` contains the window-order logic and its tests. `AppLocalization` contains native localized string resources and language-selection tests. The executable target contains shortcut handling, window operations, setup, and menu bar controls. `scripts/build-app.sh` creates and signs the app bundle and includes the license and all localization resources.

## Acknowledgments

[AltTab](https://github.com/lwouis/alt-tab-macos) was consulted as a reference for global shortcut registration and Accessibility window operations. InApp Alt Tab is an independent implementation and does not redistribute AltTab source code or dependencies.

## License

Copyright (c) 2026 TakeruF. Released under the [MIT License](LICENSE).
