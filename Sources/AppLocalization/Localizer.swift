import Foundation

public enum AppText: String, CaseIterable, Sendable {
    case appTooltip, shortcutSummary, enableSwitching, setupMenu, launchAtLogin, quit
    case permissionRequired, switchingPaused, switchingEnabled, preparingShortcuts
    case loginFailureTitle, loginFailureDetail, ok
    case setupTitle, setupInstructions, permissionOpen, permissionReview, setupFootnote, windowIcon
    case shortcutHandlerFailure, shortcutRegistrationFailure, accessibilityUsage
    case diagnosticShortcutsRegistered, diagnosticRegistrationFailed
    case diagnosticPermissionGranted, diagnosticPermissionMissing, diagnosticFrontmost
    case diagnosticWindowSwitched, diagnosticNoWindowSwitched
}

public struct Localizer: Sendable {
    public static let supportedLanguages = ["en", "ja", "zh-Hans", "zh-Hant", "ko"]
    public let language: String
    private let bundle: Bundle
    private let english: Bundle

    public init(preferredLanguages: [String]? = nil) {
        let resources = Self.resources
        let preferences = preferredLanguages
            ?? UserDefaults.standard.stringArray(forKey: "AppleLanguages")
            ?? Locale.preferredLanguages
        language = Bundle.preferredLocalizations(from: Self.supportedLanguages,
                                                forPreferences: preferences).first ?? "en"
        english = resources.url(forResource: "en", withExtension: "lproj").flatMap(Bundle.init(url:)) ?? resources
        bundle = resources.url(forResource: language, withExtension: "lproj").flatMap(Bundle.init(url:)) ?? english
    }

    public func text(_ key: AppText) -> String {
        let fallback = english.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
        return bundle.localizedString(forKey: key.rawValue, value: fallback, table: nil)
    }

    public func format(_ key: AppText, _ arguments: any CVarArg...) -> String {
        // OS error codes are identifiers; locale number grouping would change their displayed value.
        String(format: text(key), arguments: arguments)
    }

    public var translationBundleURL: URL { bundle.bundleURL }
    public static var resourceBundleURL: URL { resources.bundleURL }

    private static var resources: Bundle {
        // SwiftPM's generated accessor also contains a build-machine fallback. Prefer the shipped bundle.
        if let url = Bundle.main.url(forResource: "InAppAltTab_AppLocalization", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }
}

public enum L10n {
    public static let current = Localizer()
    public static func text(_ key: AppText) -> String { current.text(key) }
    public static func format(_ key: AppText, _ arguments: any CVarArg...) -> String {
        String(format: current.text(key), arguments: arguments)
    }
}
