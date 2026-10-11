import AppKit
import ApplicationServices
import ServiceManagement
import AppLocalization

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let switcher = WindowSwitcher()
    private let shortcuts = GlobalShortcuts()
    private var statusItem: NSStatusItem?
    private var setupWindow: SetupWindow?
    private var permissionTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var enabled: Bool { !UserDefaults.standard.bool(forKey: "switchingPaused") }
    private var previousTrust: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        shortcuts.onPress = { [weak self] backwards in self?.switcher.switchWindow(backwards: backwards) }
        shortcuts.onOptionReleased = { [weak self] in self?.switcher.reset() }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.switcher.reset() } }
        createStatusItem()
        refreshPermission()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermission() }
        }
        if !AXIsProcessTrusted() || !UserDefaults.standard.bool(forKey: "hasLaunched")
            || CommandLine.arguments.contains("--show-setup") { showSetup() }
        UserDefaults.standard.set(true, forKey: "hasLaunched")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        shortcuts.stop()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshPermission()
        updateMenu(menu)
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "InApp Alt Tab")
        item.button?.toolTip = L10n.text(.appTooltip)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateMenu(menu)
    }

    private func updateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        let keys = NSMenuItem(title: L10n.text(.shortcutSummary), action: nil, keyEquivalent: "")
        keys.isEnabled = false
        menu.addItem(keys)
        menu.addItem(.separator())
        addItem(L10n.text(.enableSwitching), action: #selector(toggleEnabled), to: menu).state = enabled ? .on : .off
        addItem(L10n.text(.setupMenu), action: #selector(showSetup), to: menu)
        let login = addItem(L10n.text(.launchAtLogin), action: #selector(toggleLaunchAtLogin), to: menu)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        addItem(L10n.text(.quit), action: #selector(quit), to: menu)
    }

    @discardableResult private func addItem(_ title: String, action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private var statusText: String {
        if !AXIsProcessTrusted() { return L10n.text(.permissionRequired) }
        if !enabled { return L10n.text(.switchingPaused) }
        if let failure = shortcuts.failure { return failure }
        return L10n.text(shortcuts.isRegistered ? .switchingEnabled : .preparingShortcuts)
    }

    private func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        if trusted && enabled && previousTrust != trusted {
            shortcuts.start()
        } else if !trusted || !enabled {
            if shortcuts.isRegistered { shortcuts.stop() }
        }
        previousTrust = trusted
        setupWindow?.update(status: statusText, trusted: trusted)
    }

    @objc private func showSetup() {
        if setupWindow == nil {
            let window = SetupWindow()
            window.onRequestPermission = { [weak self] in self?.requestPermission() }
            setupWindow = window
        }
        setupWindow?.update(status: statusText, trusted: AXIsProcessTrusted())
        setupWindow?.present()
    }

    private func requestPermission() {
        // The SDK exposes this constant as a mutable C global; use its documented dictionary key.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleEnabled() {
        UserDefaults.standard.set(enabled, forKey: "switchingPaused")
        previousTrust = nil
        refreshPermission()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.text(.loginFailureTitle)
            alert.informativeText = L10n.format(.loginFailureDetail, error.localizedDescription)
            alert.addButton(withTitle: L10n.text(.ok))
            alert.runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
