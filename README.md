# InApp Alt Tab

A small macOS menu bar app that switches between windows of the **currently focused application** with Option (Alt) + Tab.

For example, if you have multiple Word documents open in separate windows, you can move between them without switching to another application. Switching is immediate, with no preview or window picker. With zero or one eligible window, the shortcut does nothing.

## Requirements

- macOS 13 or later.
- Accessibility permission to control application windows.
- Xcode or Command Line Tools with Swift 6.2 or later to build from source.

There are no third-party package dependencies. The build script produces an app for the architecture of the Mac running the build; the initial build was tested on Apple Silicon.

## Build and install

```sh
git clone https://github.com/TakeruF/inapp-alt-tab.git
cd inapp-alt-tab
swift test
bash scripts/build-app.sh
```

The app is created at `dist/InApp Alt Tab.app`.

1. Move **InApp Alt Tab.app** to your Applications folder and launch it.
2. Use the Accessibility settings button in the setup window.
3. In **System Settings → Privacy & Security → Accessibility**, enable **InApp Alt Tab**. If the app is missing, use the **+** button to add it.
4. Open multiple windows in the same application and press **Option + Tab**.

You can also launch a development build directly:

```sh
open "dist/InApp Alt Tab.app"
```

The setup window and menu currently use Japanese text. Closing the setup window leaves the app running in the menu bar.

Builds use a local ad hoc signature. Developer ID signing, notarization, and a public binary release are not provided. To choose a different output directory, pass its path to the build script:

```sh
bash scripts/build-app.sh /path/to/output
```

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

The eight Swift Testing tests cover empty/single-window cases, duplicate entries, forward and backward cycling, enumeration changes, delayed focus reports, Option release, application changes, and windows being opened or closed.

The app has been built and launched on macOS 27.0.1. Shortcut registration has been checked, and the diagnostic command has switched between two blank Word documents in both directions and performed no operation with one document window. Physical keyboard input and the full hold-Option workflow still need manual verification.

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

## Implementation

The app uses Swift, AppKit, ApplicationServices, Carbon, and ServiceManagement. Global shortcuts are registered with Carbon. Accessibility windows are enumerated for the frontmost process and raised with `AXRaise`, followed by writable focus attributes. The frontmost process is checked again before acting.

`WindowCycle` contains the window-order logic and its tests. The executable target contains shortcut handling, window operations, setup, and menu bar controls. `scripts/build-app.sh` creates and signs the app bundle and includes the license in its resources.

## Acknowledgments

[AltTab](https://github.com/lwouis/alt-tab-macos) was consulted as a reference for global shortcut registration and Accessibility window operations. InApp Alt Tab is an independent implementation and does not redistribute AltTab source code or dependencies.

## License

Copyright (c) 2026 TakeruF. Released under the [MIT License](LICENSE).
