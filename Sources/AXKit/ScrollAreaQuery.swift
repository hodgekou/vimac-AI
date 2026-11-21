// SPDX-License-Identifier: GPL-3.0-only
// Derived from QueryScrollAreasService.swift in Vimac (https://github.com/nchudleigh/vimac),
// Copyright © 2020 Dexter Leng, licensed under GPL-3.0.

import ApplicationServices

public struct AXScrollAreaQuery: Sendable {
    public var nodeBudget = 3000
    public var messagingTimeout: Float = 0.25
    public var maximumAreas = 10

    public init() {}

    /// Frames of the scroll areas in the focused window, largest first, in accessibility coordinates.
    /// Falls back to the window itself when it has no scroll area, and is empty when there is no window.
    public func scrollAreas(pid: pid_t) async throws -> [CGRect] {
        let application = AXElement.application(pid: pid)
        application.setMessagingTimeout(seconds: messagingTimeout)
        guard let window = try application.focusedWindow() else { return [] }

        let attributes = [
            kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute,
            kAXChildrenAttribute, kAXVisibleRowsAttribute,
        ]
        var areas: [CGRect] = []
        var windowFrame: CGRect?
        var visited = Set<AXElement>()
        var stack = [window]
        var budget = nodeBudget

        while let element = stack.popLast(), budget > 0 {
            try Task.checkCancellation()
            guard visited.insert(element).inserted else { continue }
            budget -= 1

            let values = element.values(of: attributes)
            guard let role = values[0] as? String else { continue }
            let frame = AXDecode.frame(position: values[1], size: values[2])
            if element == window { windowFrame = frame }

            if role == "AXScrollArea" {
                // Nested scroll areas are reached by scrolling the outer one, so the walk stops here.
                if let frame, frame.width > 0, frame.height > 0 { areas.append(frame) }
                continue
            }
            // Web content is scrolled through its enclosing scroll area.
            if role == "AXWebArea" { continue }

            let usesVisibleRows = role == "AXTable" || role == "AXOutline"
            stack.append(contentsOf: AXDecode.elements(usesVisibleRows ? (values[4] ?? values[3]) : values[3]))
        }

        if areas.isEmpty, let windowFrame, windowFrame.width > 0, windowFrame.height > 0 {
            return [windowFrame]
        }
        return Array(
            areas.sorted { $0.width * $0.height > $1.width * $1.height }.prefix(maximumAreas)
        )
    }
}
