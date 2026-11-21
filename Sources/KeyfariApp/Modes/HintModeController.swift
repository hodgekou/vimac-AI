// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

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

    /// How many text regions detection found last time, per application. It sizes the block of
    /// labels set aside for detection, which has to be decided before detection finishes.
    private static var detectedCounts: [String: Int] = [:]
    private static let defaultReserve = 40

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "hint")
    private let query: any ElementQuerying
    private let vision: VisionAugmenter?
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let memory: LabelMemory?
    private let target: @MainActor () -> ModeTarget?
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void

    private var queryTask: Task<Void, Never>?
    private var visionTask: Task<Void, Never>?
    private var elements: [ElementSnapshot] = []
    private var labels: [String] = []
    /// Labels generated together with the shown ones and kept for elements that detection adds.
    private var reservedLabels: [String] = []
    private var bundleID = ""
    private var session: HintSession?
    private var isActive = false

    /// - Parameters:
    ///   - vision: adds on-screen text after the first labels are shown; nil when detection is off.
    ///   - target: returns the frontmost application, or nil when no mode may act on it.
    init(
        query: any ElementQuerying,
        vision: VisionAugmenter?,
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        memory: LabelMemory?,
        target: @escaping @MainActor () -> ModeTarget?,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.query = query
        self.vision = vision
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
        cancelTasks()
        clearState()
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func cancelTasks() {
        queryTask?.cancel()
        queryTask = nil
        visionTask?.cancel()
        visionTask = nil
    }

    private func clearState() {
        session = nil
        elements = []
        labels = []
        reservedLabels = []
    }

    private func runQuery(after delay: Duration) {
        cancelTasks()
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
            let pid = application.processIdentifier
            let name = application.localizedName ?? "pid \(pid)"
            let started = ContinuousClock.now

            let found =
                (try? await query.hintableElements(
                    pid: pid,
                    bundleURL: application.bundleURL,
                    otherPIDs: target.otherPIDs
                )) ?? []
            guard !Task.isCancelled, self.isActive else { return }
            let elapsed = ContinuousClock.now - started
            self.log.notice("Found \(found.count) elements in \(name, privacy: .public) after \(elapsed.description, privacy: .public)")

            self.bundleID = application.bundleIdentifier ?? ""
            self.show(found)
            self.detectText(pid: pid, existing: found)
        }
    }

    private func show(_ found: [ElementSnapshot]) {
        // With detection on, an empty tree is not the end: the text regions may still arrive.
        guard !found.isEmpty || vision != nil else {
            NSSound.beep()
            stop()
            return
        }

        // All labels are generated at once, including a block for detection, so the ones added
        // later can never be a prefix of the ones already on screen, or the other way round.
        let reserve = vision == nil ? 0 : (Self.detectedCounts[bundleID] ?? Self.defaultReserve) + 10
        let all =
            memory?.assign(to: found, bundleID: bundleID, alphabet: settings.hintAlphabet, reserve: reserve)
            ?? HintLabelGenerator.labels(count: found.count + reserve, alphabet: settings.hintAlphabet)

        elements = found
        labels = Array(all.prefix(found.count))
        reservedLabels = Array(all.dropFirst(found.count))
        session = HintSession(labels: labels)
        overlay.showHints(zip(labels, found).map { HintItem(label: $0, point: $1.clickPoint) })
    }

    /// Adds labels for on-screen text once recognition finishes. The labels already shown do not change.
    private func detectText(pid: pid_t, existing: [ElementSnapshot]) {
        guard let vision else { return }
        visionTask = Task { [weak self] in
            let extras = await vision.additionalElements(pid: pid, existing: existing)
            guard let self, !Task.isCancelled, self.isActive, var current = self.session else { return }

            Self.detectedCounts[self.bundleID] = extras.count
            // More regions than reserved labels: the rest go without, and the reserve grows next time.
            let added = Array(extras.prefix(self.reservedLabels.count))
            guard !added.isEmpty else {
                if self.elements.isEmpty {
                    NSSound.beep()
                    self.stop()
                }
                return
            }

            let newLabels = Array(self.reservedLabels.prefix(added.count))
            self.reservedLabels.removeFirst(added.count)
            self.elements.append(contentsOf: added)
            self.labels.append(contentsOf: newLabels)
            current.append(labels: newLabels)
            self.session = current
            self.overlay.appendHints(
                zip(newLabels, added).map { HintItem(label: $0, point: $1.clickPoint) },
                typedPrefix: current.prefix
            )
        }
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
            cancelTasks()
            clearState()
            overlay.hide()
            MouseSynthesizer.perform(action, at: element.clickPoint)
            runQuery(after: Self.chainDelay)
        } else {
            stop()
            MouseSynthesizer.perform(action, at: element.clickPoint)
        }
    }
}
