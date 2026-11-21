// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices
import Foundation

/// Switches on the accessibility tree of applications that build it only on request.
enum AppAccessibilityActivator {
    private static let prepared = PreparedSet()

    /// Electron applications expose their web content only after AXManualAccessibility is set.
    /// Chromium wakes up when its role is read, which `AXElement.focusedWindow()` already does.
    static func prepare(application: AXElement, pid: pid_t, bundleURL: URL?) {
        guard let bundleURL, prepared.insert(pid) else { return }
        let electron = bundleURL.appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
        if FileManager.default.fileExists(atPath: electron.path) {
            application.setBool(true, for: "AXManualAccessibility")
        }
    }

    private final class PreparedSet: @unchecked Sendable {
        private let lock = NSLock()
        private var pids = Set<pid_t>()

        /// Returns true the first time a pid is seen.
        func insert(_ pid: pid_t) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return pids.insert(pid).inserted
        }
    }
}
