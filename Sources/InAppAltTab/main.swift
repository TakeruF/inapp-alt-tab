import AppKit
import ApplicationServices
import AppLocalization

if CommandLine.arguments.contains("--dump-localization") {
    let strings = Dictionary(uniqueKeysWithValues: AppText.allCases.map { ($0.rawValue, L10n.text($0)) })
    let report: [String: Any] = ["language": L10n.current.language,
                               "resourceBundlePath": Localizer.resourceBundleURL.path,
                               "strings": strings]
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
    exit(0)
}

if CommandLine.arguments.contains("--check-shortcuts") {
    let shortcuts = GlobalShortcuts()
    shortcuts.start()
    print(shortcuts.isRegistered ? L10n.text(.diagnosticShortcutsRegistered)
          : (shortcuts.failure ?? L10n.text(.diagnosticRegistrationFailed)))
    let succeeded = shortcuts.isRegistered
    shortcuts.stop()
    exit(succeeded ? 0 : 1)
}

if CommandLine.arguments.contains("--check-permission") {
    print(L10n.text(AXIsProcessTrusted() ? .diagnosticPermissionGranted : .diagnosticPermissionMissing))
    exit(0)
}

if CommandLine.arguments.contains("--switch-once") {
    print(L10n.format(.diagnosticFrontmost, NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"))
    let switcher = WindowSwitcher()
    let switched = switcher.switchWindow(backwards: CommandLine.arguments.contains("--backwards"))
    print(L10n.text(switched ? .diagnosticWindowSwitched : .diagnosticNoWindowSwitched))
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
