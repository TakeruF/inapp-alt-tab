# Changelog

## 1.1.0 — 2026-10-12

- Add Japanese, English, Chinese (Simplified and Traditional), and Korean throughout the setup window, menu bar, permission guidance, errors, and diagnostics.
- Follow macOS preferred languages and per-app language settings, with English fallback.
- Bundle all translations in both Universal and native builds.
- Allow the setup window to wrap translated text and fit longer messages.
- Add localization coverage for missing strings, regional preferences, Chinese script selection, fallback, and formatted error details.

## 1.0.0 — 2026-10-12

First public release.

- Switch between normal windows of the frontmost app with Option + Tab.
- Use Option + Shift + Tab to switch in the opposite direction.
- Hold Option and press Tab repeatedly to cycle in a stable order.
- Perform no window operation when zero or one eligible window is available.
- Restore minimized windows when selected and suspend switching around modal dialogs and sheets.
- Provide menu bar controls for pause/resume, setup, launch at login, and quitting.
- Use Accessibility permission without window previews, screen capture, or network requests.
- Ship a universal macOS app for Apple Silicon and Intel, with the MIT license included.

The setup window and menu use Japanese text. The app requires macOS 13 or later and is ad hoc signed without notarization. Intel runtime behavior, full-screen/other-Space windows, and physical-key reverse/hold-Option cycling remain unverified. Option + Tab switching between Word windows was confirmed by the user on Apple Silicon.
