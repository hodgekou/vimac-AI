// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices

/// An accessibility call failed with an error other than "no value".
public struct AXFailure: Error, Equatable, Sendable {
    public let code: Int32

    init(_ error: AXError) {
        code = error.rawValue
    }
}

/// A thin, hashable handle on an `AXUIElement`.
///
/// Every method is a blocking cross-process request, so call them off the main thread.
public struct AXElement: @unchecked Sendable, Hashable {
    public let raw: AXUIElement

    public init(_ raw: AXUIElement) {
        self.raw = raw
    }

    public static func application(pid: pid_t) -> AXElement {
        AXElement(AXUIElementCreateApplication(pid))
    }

    public static func == (lhs: AXElement, rhs: AXElement) -> Bool {
        CFEqual(lhs.raw, rhs.raw)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(raw))
    }

    /// Caps how long requests to this element's application may block.
    public func setMessagingTimeout(seconds: Float) {
        AXUIElementSetMessagingTimeout(raw, seconds)
    }

    /// Raw value of an attribute, or nil when the element has no such attribute or no value for it.
    public func value(of attribute: String) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(raw, attribute as CFString, &value)
        switch error {
        case .success:
            return value
        case .noValue, .attributeUnsupported:
            return nil
        default:
            throw AXFailure(error)
        }
    }

    public func string(of attribute: String) throws -> String? {
        try value(of: attribute) as? String
    }

    public func element(of attribute: String) throws -> AXElement? {
        guard let value = try value(of: attribute),
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return AXElement(unsafeDowncast(value, to: AXUIElement.self))
    }

    public func role() throws -> String? {
        try string(of: kAXRoleAttribute)
    }

    /// The focused window of an application element.
    /// Reading the role first wakes Chromium's accessibility tree, as Vimac did.
    public func focusedWindow() throws -> AXElement? {
        _ = try? role()
        return try element(of: kAXFocusedWindowAttribute)
    }
}
