import AppKit
import ApplicationServices
import os
import WindowCycle

struct AccessibleWindow: Equatable {
    let element: AXUIElement
    static func == (lhs: Self, rhs: Self) -> Bool { CFEqual(lhs.element, rhs.element) }
}

final class WindowSwitcher {
    private var cycle = WindowCycle<AccessibleWindow>()
    private var discoveredWindows: [pid_t: [AXUIElement]] = [:]
    private var discoveryCursor: [pid_t: UInt64] = [:]
    private var discoveryTargets: [pid_t: Set<CGWindowID>] = [:]
    private let logger = Logger(subsystem: "dev.takeruf.inapp-alt-tab", category: "WindowSwitcher")

    init() {
        // The global timeout also bounds reads on window elements returned by AXWindows.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
    }

    func reset() { cycle.reset() }

    @discardableResult
    func switchWindow(backwards: Bool) -> Bool {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            reset()
            return false
        }
        let pid = app.processIdentifier
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.25)
        guard let windows = value(application, kAXWindowsAttribute) as? [AXUIElement] else {
            reset()
            return false
        }
        let focused = elementValue(application, kAXFocusedWindowAttribute)
        if let focused, isModal(focused) {
            reset()
            return false
        }
        let ids = WindowSpaceActivation.windowIDs(pid: pid)
        let remembered = (discoveredWindows[pid] ?? []).filter {
            guard let id = WindowSpaceActivation.id(of: $0) else { return false }
            return ids.contains(id)
        }
        var observed: [AXUIElement] = []
        for window in windows + remembered where !observed.contains(where: { CFEqual($0, window) }) {
            observed.append(window)
        }
        // Some apps omit the focused window from AXWindows, notably across Spaces.
        if let focused, !observed.contains(where: { CFEqual($0, focused) }) {
            observed.insert(focused, at: 0)
        }
        let knownIDs = Set(observed.compactMap { WindowSpaceActivation.id(of: $0) })
        let missing = ids.subtracting(knownIDs)
        if discoveryTargets[pid] != missing {
            discoveryCursor[pid] = 0
            discoveryTargets[pid] = missing
        }
        if !missing.isEmpty {
            var cursor = discoveryCursor[pid] ?? 0
            observed += WindowSpaceActivation.discover(pid: pid, ids: missing, cursor: &cursor)
            discoveryCursor[pid] = cursor
        }
        discoveredWindows[pid] = observed
        let candidates = observed.filter(isSwitchable)
        // Retain only live processes; AX elements must not accumulate after apps quit.
        let running = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        discoveredWindows = discoveredWindows.filter { running.contains($0.key) }
        discoveryCursor = discoveryCursor.filter { running.contains($0.key) }
        discoveryTargets = discoveryTargets.filter { running.contains($0.key) }
        guard let target = cycle.next(owner: pid,
                                      windows: candidates.map { AccessibleWindow(element: $0) },
                                      focused: focused.map { AccessibleWindow(element: $0) },
                                      backwards: backwards) else { return false }
        // AX queries are IPC. The user may switch applications while a query is in flight.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            reset()
            return false
        }
        let window = target.element
        AXUIElementSetMessagingTimeout(window, 0.25)
        if value(window, kAXMinimizedAttribute) as? Bool == true {
            guard AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else {
                reset()
                return false
            }
        }
        let result = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        guard result == .success else {
            logger.error("Window raise failed: \(result.rawValue)")
            reset()
            return false
        }
        setIfWritable(window, kAXMainAttribute, kCFBooleanTrue)
        setIfWritable(window, kAXFocusedAttribute, kCFBooleanTrue)
        setIfWritable(application, kAXFocusedWindowAttribute, window)
        // AXRaise changes the app's stacking order, but cannot enter another window's
        // full-screen Space. Ask WindowServer to activate this particular window.
        // This also handles returning from a full-screen window to a desktop window.
        if let error = WindowSpaceActivation.activate(window, pid: pid), error != .success {
            logger.error("Window Space activation failed: \(error.rawValue)")
        }
        return true
    }

    private func isSwitchable(_ window: AXUIElement) -> Bool {
        guard value(window, kAXRoleAttribute) as? String == kAXWindowRole else { return false }
        let subrole = value(window, kAXSubroleAttribute) as? String
        guard subrole == nil || subrole == kAXStandardWindowSubrole else { return false }
        return value(window, kAXModalAttribute) as? Bool != true
    }

    private func isModal(_ window: AXUIElement) -> Bool {
        value(window, kAXModalAttribute) as? Bool == true
            || value(window, kAXSubroleAttribute) as? String == kAXDialogSubrole
            || !(value(window, "AXSheets") as? [AXUIElement] ?? []).isEmpty
    }

    private func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private func elementValue(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let result = value(element, attribute), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }

    private func setIfWritable(_ element: AXUIElement, _ attribute: String, _ value: CFTypeRef) {
        var writable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, attribute as CFString, &writable) == .success,
              writable.boolValue else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }
}

/// macOS has no public API for activating a specific window across Spaces.
/// Resolve the optional system entry points at runtime so future OS changes leave
/// ordinary Accessibility switching available instead of preventing app launch.
private enum WindowSpaceActivation {
    private typealias WindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias Activate = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias RemoteElement = @convention(c) (CFData) -> Unmanaged<AXUIElement>?

    // Keep the handles open for the lifetime of the resolved function pointers.
    private static let accessibility = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
    private static let skyLight = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static let windowID: WindowID? = {
        guard let accessibility, let symbol = dlsym(accessibility, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: WindowID.self)
    }()
    private static let activateWindow: Activate? = {
        guard let skyLight, let symbol = dlsym(skyLight, "_SLPSSetFrontProcessWithOptions") else { return nil }
        return unsafeBitCast(symbol, to: Activate.self)
    }()
    private static let processForPID: ProcessForPID? = {
        guard let accessibility, let symbol = dlsym(accessibility, "GetProcessForPID") else { return nil }
        return unsafeBitCast(symbol, to: ProcessForPID.self)
    }()
    private static let remoteElement: RemoteElement? = {
        guard let accessibility, let symbol = dlsym(accessibility, "_AXUIElementCreateWithRemoteToken") else { return nil }
        return unsafeBitCast(symbol, to: RemoteElement.self)
    }()

    static func id(of window: AXUIElement) -> CGWindowID? {
        guard let windowID else { return nil }
        var id = CGWindowID(0)
        return windowID(window, &id) == .success && id != 0 ? id : nil
    }

    static func windowIDs(pid: pid_t) -> Set<CGWindowID> {
        let rows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return Set(rows.compactMap { row in
            // Full-screen windows can use a nonzero layer (for example, layer 3).
            // Keep their IDs for discovery and cache validation; eligibility is
            // determined from the AX role/subrole, not WindowServer stacking level.
            guard row[kCGWindowOwnerPID as String] as? Int32 == pid else { return nil }
            return row[kCGWindowNumber as String] as? CGWindowID
        })
    }

    /// AppKit omits other-Space windows from AXWindows. Resolve their AX roots
    /// against WindowServer IDs, with a time budget and a cursor for sparse IDs.
    static func discover(pid: pid_t, ids: Set<CGWindowID>, cursor: inout UInt64) -> [AXUIElement] {
        guard let remoteElement, windowID != nil else { return [] }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.12
        var token = Data(count: 20)
        withUnsafeBytes(of: pid) { token.replaceSubrange(0..<4, with: $0) }
        var magic: UInt32 = 0x636f636f
        withUnsafeBytes(of: &magic) { token.replaceSubrange(8..<12, with: $0) }
        var remaining = ids
        var found: [AXUIElement] = []
        var attempts = 0
        while ProcessInfo.processInfo.systemUptime < deadline, !remaining.isEmpty, attempts < 4096 {
            attempts += 1
            let next = cursor
            cursor &+= 1
            withUnsafeBytes(of: next) { token.replaceSubrange(12..<20, with: $0) }
            guard let element = remoteElement(token as CFData)?.takeRetainedValue() else { continue }
            AXUIElementSetMessagingTimeout(element, 0.01)
            guard let id = id(of: element), remaining.contains(id),
                  ProcessInfo.processInfo.systemUptime < deadline else { continue }
            var role: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
                  role as? String == kAXWindowRole else { continue }
            found.append(element)
            remaining.remove(id)
        }
        // Once resolved, future newly created windows may reuse low AX IDs.
        if remaining.isEmpty { cursor = 0 }
        return found
    }

    static func activate(_ window: AXUIElement, pid: pid_t) -> CGError? {
        guard let activateWindow, let processForPID else { return nil }
        guard let id = id(of: window) else { return nil }
        var process = ProcessSerialNumber()
        guard processForPID(pid, &process) == noErr else { return nil }
        // 0x200 marks the request as a user initiated switch and raises only id.
        return activateWindow(&process, id, 0x200)
    }
}
