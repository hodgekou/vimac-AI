// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Foundation

/// A session-level event tap on the main run loop that can swallow events.
@MainActor
public final class EventTap {
    /// Returns true to swallow the event.
    public typealias Handler = @MainActor (CGEventType, CGEvent) -> Bool

    private let mask: CGEventMask
    private let handler: Handler
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    public init(types: [CGEventType], handler: @escaping Handler) {
        mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        self.handler = handler
    }

    /// Installs the tap. Returns false when the system refuses, which happens without the Accessibility permission.
    @discardableResult
    public func start() -> Bool {
        guard port == nil else { return true }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
            // The run loop source is on the main run loop, so this runs on the main thread.
            let swallow = MainActor.assumeIsolated { tap.receive(type, event) }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }

        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    public func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(port)
        self.port = nil
        source = nil
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) -> Bool {
        // The system disables a tap whose callback was too slow; without this every key would leak through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return false
        }
        return handler(type, event)
    }
}
