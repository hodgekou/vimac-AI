import AppKit
import AXKit
import InputKit
import os
import OverlayKit
import VimacCore

/// Runs one activation of search click mode: query, filter by typed text, act on Return.
@MainActor
final class SearchModeController {
    /// How long a second Return may follow a click to turn it into a double click.
    static let doubleClickWindow: Duration = .milliseconds(300)

    private let log = Logger(subsystem: "dev.vimac-ai.Vimac", category: "search")
    private let query: any ElementQuerying
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let target: @MainActor () -> ModeTarget?
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void

    private var task: Task<Void, Never>?
    private var elements: [ElementSnapshot] = []
    private var session: SearchSession?
    /// Set while waiting for the second Return of a double click.
    private var armedPoint: CGPoint?
    private var isActive = false

    init(
        query: any ElementQuerying,
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        target: @escaping @MainActor () -> ModeTarget?,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.query = query
        self.overlay = overlay
        self.interceptor = interceptor
        self.settings = settings
        self.target = target
        self.onShortcut = onShortcut
        self.onExit = onExit
    }

    /// Returns false when the keyboard could not be intercepted, in which case nothing was started.
    func start() -> Bool {
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
        task?.cancel()
        task = nil
        session = nil
        elements = []
        armedPoint = nil
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func runQuery(after delay: Duration) {
        task?.cancel()
        task = Task { [weak self, query] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard let self, !Task.isCancelled, self.isActive else { return }
            guard let target = self.target() else {
                self.stop()
                return
            }
            let application = target.application
            let found = try? await query.hintableElements(
                pid: application.processIdentifier,
                bundleURL: application.bundleURL,
                otherPIDs: target.otherPIDs
            )
            guard !Task.isCancelled, self.isActive else { return }
            guard let found, !found.isEmpty else {
                NSSound.beep()
                self.stop()
                return
            }
            self.log.notice("Searching \(found.count) elements in \(application.localizedName ?? "?", privacy: .public)")
            self.elements = ReadingOrder.sorted(found)
            self.session = SearchSession(texts: self.elements.map(\.searchText), alphabet: self.settings.hintAlphabet)
            self.render()
        }
    }

    private func render() {
        guard let session else { return }
        let items = zip(session.labels, session.matches).map { label, index in
            HintItem(label: label, point: elements[index].clickPoint)
        }
        overlay.showSearch(
            query: session.query,
            labelPrefix: session.labelPrefix,
            items: items,
            focus: session.focus,
            focusFrame: session.focusedIndex.map { elements[$0].clippedFrame },
            // The bar belongs on the screen of the window, not of the menu bar.
            anchor: (elements.first { $0.source == .window } ?? elements.first)?.frame
        )
    }

    private func handle(_ stroke: KeyStroke) {
        if let point = armedPoint {
            // Only Return is intercepted while armed. Its auto-repeat must not count as a second press.
            guard !stroke.isRepeat else { return }
            MouseSynthesizer.secondClick(at: point)
            stop()
            return
        }
        if onShortcut(stroke) { return }

        guard var current = session else {
            if stroke.keyCode == KeyCode.escape { stop() }
            return
        }
        let event = current.handle(stroke)
        session = current

        switch event {
        case .updated:
            render()
        case .rejected:
            NSSound.beep()
        case let .act(index, action):
            perform(action, on: elements[index])
        case .exit:
            stop()
        case .ignored:
            break
        }
    }

    private func perform(_ action: ClickAction, on element: ElementSnapshot) {
        let point = element.clickPoint
        session = nil
        overlay.hide()
        MouseSynthesizer.perform(action, at: point)

        if settings.chainClicks, action != .moveOnly, !element.acceptsText {
            elements = []
            runQuery(after: HintModeController.chainDelay)
        } else if action == .left {
            // Keep only Return for a moment: a second press makes this a double click.
            // Every other key goes straight to the application.
            armedPoint = point
            interceptor.swallowOnly = [KeyCode.return]
            task?.cancel()
            task = Task { [weak self] in
                try? await Task.sleep(for: Self.doubleClickWindow)
                guard let self, !Task.isCancelled else { return }
                self.stop()
            }
        } else {
            stop()
        }
    }
}
