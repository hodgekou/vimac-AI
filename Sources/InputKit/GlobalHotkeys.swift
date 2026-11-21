// SPDX-License-Identifier: GPL-3.0-only

import Carbon.HIToolbox
import KeyfariCore

/// System-wide keyboard shortcuts registered through the Carbon hot key API.
@MainActor
public final class GlobalHotkeys {
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var references: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    public init() {}

    /// Registers a shortcut. Returns false when the system rejects it, for example because another application owns it.
    @discardableResult
    public func register(keyCode: UInt16, modifiers: Modifiers, handler: @escaping @MainActor () -> Void) -> Bool {
        installEventHandlerIfNeeded()

        let id = nextID
        nextID += 1
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            Self.carbonFlags(modifiers),
            EventHotKeyID(signature: 0x4B46_5249 /* 'KFRI' */, id: id),
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return false }
        references.append(reference)
        handlers[id] = handler
        return true
    }

    public func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        handlers.removeAll()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(userData).takeUnretainedValue()
                let id = hotKeyID.id
                // Carbon delivers hot key events on the main thread.
                MainActor.assumeIsolated { hotkeys.handlers[id]?() }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private static func carbonFlags(_ modifiers: Modifiers) -> UInt32 {
        var flags = 0
        if modifiers.contains(.command) { flags |= cmdKey }
        if modifiers.contains(.shift) { flags |= shiftKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.control) { flags |= controlKey }
        return UInt32(flags)
    }
}
