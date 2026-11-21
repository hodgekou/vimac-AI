// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices

public enum AXPermission {
    /// Whether this process may use the accessibility API.
    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Checks the permission and, when missing, asks the system to show its prompt.
    @discardableResult
    public static func request() -> Bool {
        // The value of kAXTrustedCheckOptionPrompt. The constant is a mutable global,
        // which Swift 6 rejects as not concurrency-safe.
        let promptKey = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }
}
