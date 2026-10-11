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
        var candidates = windows.filter(isSwitchable)
        // Some apps omit the focused window from AXWindows, notably across Spaces.
        if let focused, isSwitchable(focused), !candidates.contains(where: { CFEqual($0, focused) }) {
            candidates.insert(focused, at: 0)
        }
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
