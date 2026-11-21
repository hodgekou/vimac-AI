// SPDX-License-Identifier: GPL-3.0-only

import AppKit

/// A transparent panel that covers one screen and never takes focus or mouse events.
public final class OverlayPanel: NSPanel {
    public init(screenFrame: NSRect) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        // Above pop-up menus, so the items of an open menu can carry labels too.
        level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        let content = NSView(frame: NSRect(origin: .zero, size: screenFrame.size))
        content.wantsLayer = true
        contentView = content
    }

    // Keys come from the event tap, so the panel must not steal focus from the target application.
    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }
}
