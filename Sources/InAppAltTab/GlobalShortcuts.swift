import AppKit
import Carbon
import AppLocalization

final class GlobalShortcuts {
    private var handler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    var onPress: ((Bool) -> Void)?
    var onOptionReleased: (() -> Void)?
    private(set) var failure: String?
    var isRegistered: Bool { hotKeys.count == 2 }

    func start() {
        guard !isRegistered else { return }
        stop()
        failure = nil
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr, id.signature == 0x49415442 else { return OSStatus(eventNotHandledErr) }
            let shortcuts = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            // Carbon application event handlers run on the application's main event loop.
            MainActor.assumeIsolated { shortcuts.onPress?(id.id == 2) }
            return noErr
        }, 1, &event, context, &handler)
        guard status == noErr else {
            failure = L10n.format(.shortcutHandlerFailure, status)
            stop()
            return
        }
        for (id, modifiers) in [(UInt32(1), UInt32(optionKey)), (UInt32(2), UInt32(optionKey | shiftKey))] {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(kVK_Tab), modifiers,
                                             EventHotKeyID(signature: 0x49415442, id: id),
                                             GetApplicationEventTarget(), 0, &reference)
            guard result == noErr, let reference else {
                failure = L10n.format(.shortcutRegistrationFailure, result)
                stop()
                return
            }
            hotKeys.append(reference)
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.flagsChanged(event) }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.flagsChanged(event)
            return event
        }
    }

    func stop() {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        hotKeys = []
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        if let globalFlagsMonitor { NSEvent.removeMonitor(globalFlagsMonitor) }
        if let localFlagsMonitor { NSEvent.removeMonitor(localFlagsMonitor) }
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        onOptionReleased?()
    }

    private func flagsChanged(_ event: NSEvent) {
        if !event.modifierFlags.contains(.option) { onOptionReleased?() }
    }
}
