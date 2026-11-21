import AppKit
import AXKit
import InputKit
import os
import OverlayKit
import VimacCore

/// The application a mode acts on.
struct ModeTarget {
    let application: NSRunningApplication
    /// Every other running application, searched for menu bar extras.
    let otherPIDs: [pid_t]
}

/// Runs one activation of label click mode: query, show labels, read keys, click.
@MainActor
final class HintModeController {
    /// How long a click chain waits for the interface to settle before it queries again.
    static let chainDelay: Duration = .milliseconds(250)

    private let log = Logger(subsystem: "dev.vimac-ai.Vimac", category: "hint")
    private let query: any ElementQuerying
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let memory: LabelMemory?
    private let target: @MainActor () -> ModeTarget?
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void

    private var queryTask: Task<Void, Never>?
    private var elements: [ElementSnapshot] = []
    private var labels: [String] = []
    private var bundleID = ""
    private var session: HintSession?
    private var isActive = false

    /// - Parameter target: returns the frontmost application, or nil when no mode may act on it.
    init(
        query: any ElementQuerying,
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        memory: LabelMemory?,
        target: @escaping @MainActor () -> ModeTarget?,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.query = query
        self.overlay = overlay
        self.interceptor = interceptor
        self.settings = settings
        self.memory = memory
        self.target = target
        self.onShortcut = onShortcut
        self.onExit = onExit
    }

    /// Returns false when the keyboard could not be intercepted, in which case nothing was started.
    func start() -> Bool {
        // Keys are swallowed from the first moment so that nothing typed during the query reaches the application.
        guard interceptor.start(onKeyDown: { [weak self] stroke in self?.handle(stroke) }) else {
            return false
        }
        isActive = true
        runQuery(after: .zero)
        return true
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        queryTask?.cancel()
        queryTask = nil
        session = nil
        elements = []
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func runQuery(after delay: Duration) {
        queryTask?.cancel()
        queryTask = Task { [weak self, query] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard let self, !Task.isCancelled, self.isActive else { return }
            guard let target = self.target() else {
                self.stop()
                return
            }
            let application = target.application
            let name = application.localizedName ?? "pid \(application.processIdentifier)"
            let started = ContinuousClock.now

            let found = try? await query.hintableElements(
                pid: application.processIdentifier,
                bundleURL: application.bundleURL,
                otherPIDs: target.otherPIDs
            )
            guard !Task.isCancelled, self.isActive else { return }
            let elapsed = ContinuousClock.now - started
            self.log.notice("Found \(found?.count ?? 0) elements in \(name, privacy: .public) after \(elapsed.description, privacy: .public)")
            self.bundleID = application.bundleIdentifier ?? ""
            self.show(found ?? [])
        }
    }

    private func show(_ found: [ElementSnapshot]) {
        guard !found.isEmpty else {
            NSSound.beep()
            stop()
            return
        }
        labels = memory?.assign(to: found, bundleID: bundleID, alphabet: settings.hintAlphabet)
            ?? HintLabelGenerator.labels(count: found.count, alphabet: settings.hintAlphabet)
        elements = found
        session = HintSession(labels: labels)
        overlay.showHints(zip(labels, found).map { HintItem(label: $0, point: $1.clickPoint) })
    }

    private func handle(_ stroke: KeyStroke) {
        if onShortcut(stroke) { return }

        guard var current = session else {
            // Still querying: only leaving the mode makes sense.
            if stroke.keyCode == KeyCode.escape { stop() }
            return
        }

        let event = current.handle(stroke)
        session = current

        switch event {
        case let .updated(prefix, _):
            overlay.update(prefix: prefix)
        case .rejected:
            NSSound.beep()
        case .rotate:
            overlay.rotate()
        case let .matched(index, action):
            memory?.remember(labels[index], for: elements[index], bundleID: bundleID)
            perform(action, on: elements[index])
        case .exit:
            stop()
        case .ignored:
            break
        }
    }

    private func perform(_ action: ClickAction, on element: ElementSnapshot) {
        // A chain stops on text fields, otherwise the text typed next would be read as labels.
        let continues = settings.chainClicks && action != .moveOnly && !element.acceptsText
        if continues {
            session = nil
            elements = []
            overlay.hide()
            MouseSynthesizer.perform(action, at: element.clickPoint)
            runQuery(after: Self.chainDelay)
        } else {
            stop()
            MouseSynthesizer.perform(action, at: element.clickPoint)
        }
    }
}
