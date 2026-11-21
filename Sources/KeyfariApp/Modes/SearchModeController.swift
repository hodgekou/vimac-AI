// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

/// Runs one activation of search click mode: query, filter by typed text, act on Return.
@MainActor
final class SearchModeController {
    /// How long a second Return may follow a click to turn it into a double click.
    static let doubleClickWindow: Duration = .milliseconds(300)

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "search")
    private let query: any ElementQuerying
    private let vision: VisionAugmenter?
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let target: @MainActor () -> ModeTarget?
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void

    private var task: Task<Void, Never>?
    private var visionTask: Task<Void, Never>?
    private var elements: [ElementSnapshot] = []
    private var session: SearchSession?
    /// The key strokes that changed the session, replayed when detection adds elements.
    private var appliedStrokes: [KeyStroke] = []
    /// Set while waiting for the second Return of a double click.
    private var armedPoint: CGPoint?
    private var isActive = false

    init(
        query: any ElementQuerying,
        vision: VisionAugmenter?,
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        target: @escaping @MainActor () -> ModeTarget?,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.query = query
        self.vision = vision
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
        cancelTasks()
        session = nil
        elements = []
        appliedStrokes = []
        armedPoint = nil
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func cancelTasks() {
        task?.cancel()
        task = nil
        visionTask?.cancel()
        visionTask = nil
    }

    private func runQuery(after delay: Duration) {
        cancelTasks()
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
            let pid = application.processIdentifier
            let found =
                (try? await query.hintableElements(
                    pid: pid,
                    bundleURL: application.bundleURL,
                    otherPIDs: target.otherPIDs
                )) ?? []
            guard !Task.isCancelled, self.isActive else { return }
            // With detection on, an empty tree is not the end: the text regions may still arrive.
            guard !found.isEmpty || self.vision != nil else {
                NSSound.beep()
                self.stop()
                return
            }
            self.log.notice("Searching \(found.count) elements in \(application.localizedName ?? "?", privacy: .public)")
            self.appliedStrokes = []
            self.use(found)
            self.detectText(pid: pid, existing: found)
        }
    }

    private func use(_ found: [ElementSnapshot]) {
        elements = ReadingOrder.sorted(found)
        var fresh = SearchSession(texts: elements.map(\.searchText), alphabet: settings.hintAlphabet)
        // Whatever was typed so far applies to the new set of elements too.
        for stroke in appliedStrokes {
            _ = fresh.handle(stroke)
        }
        session = fresh
        render()
    }

    /// Adds on-screen text to the searchable elements once recognition finishes.
    private func detectText(pid: pid_t, existing: [ElementSnapshot]) {
        guard let vision else { return }
        visionTask = Task { [weak self] in
            let extras = await vision.additionalElements(pid: pid, existing: existing)
            guard let self, !Task.isCancelled, self.isActive, self.session != nil else { return }
            guard !extras.isEmpty else {
                if self.elements.isEmpty {
                    NSSound.beep()
                    self.stop()
                }
                return
            }
            self.use(self.elements + extras)
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
            anchor: (elements.first { $0.source == .window || $0.source == .vision } ?? elements.first)?.frame
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
            appliedStrokes.append(stroke)
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
        cancelTasks()
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
