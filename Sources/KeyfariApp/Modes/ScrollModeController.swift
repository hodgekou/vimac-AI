// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

/// Runs one activation of scroll mode: find scroll areas, outline the active one, scroll on keys.
@MainActor
final class ScrollModeController {
    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "scroll")
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void
    private let scroller = ScrollSynthesizer()

    private var queryTask: Task<Void, Never>?
    private var areas: [CGRect] = []
    private var session: ScrollSession?
    private var isActive = false

    init(
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.overlay = overlay
        self.interceptor = interceptor
        self.settings = settings
        self.onShortcut = onShortcut
        self.onExit = onExit
    }

    /// Returns false when the keyboard could not be intercepted, in which case nothing was started.
    func start(application: NSRunningApplication) -> Bool {
        let started = interceptor.start(
            onKeyDown: { [weak self] stroke in self?.keyDown(stroke) },
            onKeyUp: { [weak self] keyCode in self?.keyUp(keyCode) }
        )
        guard started else { return false }
        isActive = true

        let pid = application.processIdentifier
        let name = application.localizedName ?? "pid \(pid)"
        queryTask = Task { [weak self] in
            let found = (try? await AXScrollAreaQuery().scrollAreas(pid: pid)) ?? []
            guard let self, !Task.isCancelled, self.isActive else { return }
            self.log.notice("Found \(found.count) scroll areas in \(name, privacy: .public)")
            guard !found.isEmpty else {
                NSSound.beep()
                self.stop()
                return
            }
            self.areas = found
            self.session = ScrollSession(areaCount: found.count)
            self.select(0)
        }
        return true
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        queryTask?.cancel()
        queryTask = nil
        scroller.stop()
        session = nil
        areas = []
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func select(_ index: Int) {
        let area = areas[index]
        overlay.showScrollArea(frame: area, index: index)
        // Scroll events go to whatever is under the cursor.
        MouseSynthesizer.move(to: CGPoint(x: area.midX, y: area.midY))
    }

    private func keyDown(_ stroke: KeyStroke) {
        if onShortcut(stroke) { return }
        guard var current = session else {
            if stroke.keyCode == KeyCode.escape { stop() }
            return
        }
        let event = current.keyDown(stroke, at: ProcessInfo.processInfo.systemUptime)
        session = current
        apply(event, areaIndex: current.areaIndex)
    }

    private func keyUp(_ keyCode: UInt16) {
        guard var current = session else { return }
        let event = current.keyUp(keyCode: keyCode)
        session = current
        apply(event, areaIndex: current.areaIndex)
    }

    private func apply(_ event: ScrollEvent, areaIndex: Int) {
        switch event {
        case let .start(direction, dash):
            let speed = Double(settings.scrollSpeed) * (dash ? settings.dashMultiplier : 1)
            scroller.start(
                direction,
                pixelsPerTick: max(Int(speed.rounded()), 1),
                reverseHorizontal: settings.reverseHorizontal,
                reverseVertical: settings.reverseVertical
            )
        case .stop:
            scroller.stop()
        case let .halfPage(direction):
            scroller.scroll(
                direction,
                pixels: Int(areas[areaIndex].height / 2),
                reverseHorizontal: settings.reverseHorizontal,
                reverseVertical: settings.reverseVertical
            )
        case .top:
            scroller.scrollToTop()
        case .bottom:
            scroller.scrollToBottom()
        case let .selectArea(index):
            scroller.stop()
            select(index)
        case .exit:
            stop()
        case .ignored:
            break
        }
    }
}
