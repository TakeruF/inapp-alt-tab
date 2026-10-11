import AppKit
import ApplicationServices

if CommandLine.arguments.contains("--check-shortcuts") {
    let shortcuts = GlobalShortcuts()
    shortcuts.start()
    print(shortcuts.isRegistered ? "Option+Tab and Option+Shift+Tab registered successfully" : (shortcuts.failure ?? "Registration failed"))
    let succeeded = shortcuts.isRegistered
    shortcuts.stop()
    exit(succeeded ? 0 : 1)
}

if CommandLine.arguments.contains("--check-permission") {
    print(AXIsProcessTrusted() ? "Accessibility: granted" : "Accessibility: not granted")
    exit(0)
}

if CommandLine.arguments.contains("--switch-once") {
    print("Frontmost app: \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown")")
    let switcher = WindowSwitcher()
    let switched = switcher.switchWindow(backwards: CommandLine.arguments.contains("--backwards"))
    print(switched ? "Window switched" : "No window switched")
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
