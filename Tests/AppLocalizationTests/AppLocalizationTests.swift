import Foundation
import Testing
import AppLocalization

@Test(arguments: Localizer.supportedLanguages)
func everyLanguageProvidesEveryAppString(language: String) throws {
    let localizer = Localizer(preferredLanguages: [language])
    #expect(localizer.language == language)
    let bundle = try #require(Bundle(url: localizer.translationBundleURL))
    #expect(localizer.translationBundleURL.lastPathComponent == "\(language).lproj")
    for key in AppText.allCases {
        let text = bundle.localizedString(forKey: key.rawValue, value: "__MISSING__", table: nil)
        #expect(!text.isEmpty && text != "__MISSING__", "Missing \(key.rawValue) in \(language)")
    }
}

@Test(arguments: [("en-US", "en"), ("ja-JP", "ja"), ("zh-CN", "zh-Hans"), ("zh-SG", "zh-Hans"),
                  ("zh-TW", "zh-Hant"), ("zh-HK", "zh-Hant"), ("ko-KR", "ko"), ("fr-FR", "en")])
func regionPreferencesSelectTheExpectedTranslation(preference: String, expected: String) {
    #expect(Localizer(preferredLanguages: [preference]).language == expected)
}

@Test func respectsPreferenceOrderAndSkipsUnsupportedLanguages() {
    #expect(Localizer(preferredLanguages: ["fr-FR", "ko-KR", "ja-JP"]).language == "ko")
    #expect(Localizer(preferredLanguages: ["en-US", "ja-JP"]).language == "en")
}

@Test(arguments: Localizer.supportedLanguages)
func errorAndDiagnosticFormattingPreservesDetails(language: String) {
    let localizer = Localizer(preferredLanguages: [language])
    for key in [AppText.shortcutHandlerFailure, .shortcutRegistrationFailure] {
        let text = localizer.format(key, Int32(-9878))
        #expect(text.contains("-9878") && !text.contains("%d"))
    }
    let error = localizer.format(.loginFailureDetail, "test-error-detail")
    #expect(error.contains("test-error-detail") && !error.contains("%@"))
    let diagnostic = localizer.format(.diagnosticFrontmost, "com.microsoft.Word")
    #expect(diagnostic.contains("com.microsoft.Word") && !diagnostic.contains("%@"))
}

@Test func chineseScriptsHaveSeparateTranslations() {
    let simplified = Localizer(preferredLanguages: ["zh-CN"]).text(.setupTitle)
    let traditional = Localizer(preferredLanguages: ["zh-TW"]).text(.setupTitle)
    #expect(simplified != traditional)
}
