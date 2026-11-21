import AppKit
import ApplicationServices
import VimacCore

public protocol ElementQuerying: Sendable {
    /// Collects every element that should get a label.
    /// - Parameters:
    ///   - pid: the frontmost application.
    ///   - bundleURL: its bundle, used to detect applications that need accessibility switched on.
    ///   - otherPIDs: every other running application, searched for menu bar extras.
    func hintableElements(pid: pid_t, bundleURL: URL?, otherPIDs: [pid_t]) async throws -> [ElementSnapshot]
}

public struct AXElementQuery: ElementQuerying {
    /// The most nodes one activation may visit.
    public var nodeBudget = 5000
    /// How long requests to the frontmost application may block, in seconds.
    public var messagingTimeout: Float = 0.25
    /// How long the very first activation waits for the menu bar extras of other applications.
    public var extrasDeadline: Duration = .milliseconds(150)

    public init() {}

    public func hintableElements(pid: pid_t, bundleURL: URL?, otherPIDs: [pid_t]) async throws -> [ElementSnapshot] {
        let start = ContinuousClock.now

        // Asking every process for its extras takes longer than an activation may. The result of
        // the previous scan is used right away, and a new scan refreshes it for next time.
        var extras = Self.extrasCache.value
        let pids = [pid] + otherPIDs
        Self.extrasCache.refreshIfIdle { Self.menuBarExtras(pids: pids) }

        let application = AXElement.application(pid: pid)
        application.setMessagingTimeout(seconds: messagingTimeout)
        AppAccessibilityActivator.prepare(application: application, pid: pid, bundleURL: bundleURL)

        var elements = Self.menuBarItems(of: application)

        if let window = try? application.focusedWindow() {
            let traversal = TreeTraversal(budget: nodeBudget)
            if let root = try traversal.visit(window, clip: nil) {
                elements.append(contentsOf: traversal.hintableSnapshots(root: root, source: .window))
            }
        }
        elements.append(contentsOf: try Self.notificationElements())

        // Only the first activation has nothing cached and waits, up to the deadline.
        while extras == nil, ContinuousClock.now - start < extrasDeadline {
            try await Task.sleep(for: .milliseconds(10))
            extras = Self.extrasCache.value
        }
        elements.append(contentsOf: extras ?? [])
        return elements
    }

    /// Frame of the focused window of an application, in accessibility coordinates.
    public static func focusedWindowFrame(pid: pid_t) -> CGRect? {
        let application = AXElement.application(pid: pid)
        application.setMessagingTimeout(seconds: 0.25)
        guard let window = try? application.focusedWindow() else { return nil }
        let values = window.values(of: [kAXPositionAttribute, kAXSizeAttribute])
        return AXDecode.frame(position: values[0], size: values[1])
    }

    // MARK: Menu bar

    private static let extrasCache = RefreshingCache<[ElementSnapshot]>()

    private static func menuBarItems(of application: AXElement) -> [ElementSnapshot] {
        guard let menuBar = try? application.element(of: kAXMenuBarAttribute) else { return [] }
        return children(of: menuBar, source: .menuBar)
    }

    private static func menuBarExtras(pids: [pid_t]) -> [ElementSnapshot] {
        var result: [ElementSnapshot] = []
        for pid in pids {
            let application = AXElement.application(pid: pid)
            // Most applications have no extras; an unresponsive one must not hold up the rest.
            application.setMessagingTimeout(seconds: 0.05)
            guard let extras = try? application.element(of: "AXExtrasMenuBar") else { continue }
            result.append(contentsOf: children(of: extras, source: .menuBarExtra))
        }
        return result
    }

    private static func children(of element: AXElement, source: ElementSource) -> [ElementSnapshot] {
        let items = AXDecode.elements(try? element.value(of: kAXChildrenAttribute))
        return items.compactMap { item in
            let values = item.values(of: [
                kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute,
                kAXTitleAttribute, kAXDescriptionAttribute,
            ])
            guard let role = values[0] as? String,
                  let frame = AXDecode.frame(position: values[1], size: values[2]),
                  frame.width > 0, frame.height > 0 else { return nil }
            return ElementSnapshot(
                role: role,
                frame: frame,
                searchText: AXDecode.searchText([values[3], values[4]]),
                source: source
            )
        }
    }

    // MARK: Notification Center

    /// The buttons of notifications that are currently on screen.
    private static func notificationElements() throws -> [ElementSnapshot] {
        guard let center = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return [] }
        let application = AXElement.application(pid: center.processIdentifier)
        application.setMessagingTimeout(seconds: 0.1)

        let displays = displayBounds()
        var result: [ElementSnapshot] = []
        for window in AXDecode.elements(try? application.value(of: kAXWindowsAttribute)) {
            let traversal = TreeTraversal(budget: 300)
            guard let root = try traversal.visit(window, clip: nil) else { continue }
            // The process keeps windows parked off screen while nothing is shown.
            result.append(contentsOf: traversal.hintableSnapshots(root: root, source: .notification).filter { element in
                displays.contains { $0.intersects(element.clippedFrame) }
            })
        }
        return result
    }

    /// Bounds of the active displays, in the coordinates accessibility uses.
    private static func displayBounds() -> [CGRect] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }
}

/// Holds the latest result of a slow computation and recomputes it in the background.
private final class RefreshingCache<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value?
    private var isRefreshing = false

    var value: Value? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    /// Runs `compute` off the calling thread unless a refresh is already under way.
    func refreshIfIdle(_ compute: @escaping @Sendable () -> Value) {
        lock.lock()
        let shouldStart = !isRefreshing
        if shouldStart { isRefreshing = true }
        lock.unlock()
        guard shouldStart else { return }

        Task.detached(priority: .utility) {
            let result = compute()
            self.lock.withLock {
                self.stored = result
                self.isRefreshing = false
            }
        }
    }
}
