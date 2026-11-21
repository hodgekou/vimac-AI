// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import KeyfariCore

/// One label to draw. `point` is in accessibility coordinates.
public struct HintItem: Sendable {
    public let label: String
    public let point: CGPoint

    public init(label: String, point: CGPoint) {
        self.label = label
        self.point = point
    }
}

public struct HintStyle: Sendable {
    public struct Colors {
        public let background: NSColor
        public let foreground: NSColor
        public let border: NSColor
    }

    public var fontSize: CGFloat = 11
    public var cornerRadius: CGFloat = 5
    public var theme = HintTheme.vivid

    public init() {}

    /// The bright colours of the vivid theme, chosen to stay readable under white text.
    public static let palette: [NSColor] = [
        NSColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 1),  // blue
        NSColor(srgbRed: 0.55, green: 0.36, blue: 0.96, alpha: 1),  // violet
        NSColor(srgbRed: 0.93, green: 0.28, blue: 0.60, alpha: 1),  // pink
        NSColor(srgbRed: 0.96, green: 0.45, blue: 0.09, alpha: 1),  // orange
        NSColor(srgbRed: 0.06, green: 0.65, blue: 0.47, alpha: 1),  // green
        NSColor(srgbRed: 0.03, green: 0.60, blue: 0.75, alpha: 1),  // teal
    ]

    /// The accent gradient used for the search bar and the scroll outline.
    public static let accent: [NSColor] = [palette[0], palette[1], palette[2]]

    /// Colours of one label. In the vivid theme the colour follows the label's first letter,
    /// so labels that start alike, and are narrowed down together, look alike.
    public func colors(for label: String) -> Colors {
        switch theme {
        case .vivid:
            let seed = Int(label.unicodeScalars.first?.value ?? 0)
            return Colors(
                background: Self.palette[seed % Self.palette.count],
                foreground: .white,
                border: NSColor(calibratedWhite: 1, alpha: 0.35)
            )
        case .yellow:
            return Colors(
                background: NSColor(srgbRed: 1.0, green: 0.84, blue: 0.30, alpha: 1),
                foreground: .black,
                border: NSColor(calibratedWhite: 0.2, alpha: 0.9)
            )
        case .dark:
            return Colors(
                background: NSColor(calibratedWhite: 0.13, alpha: 0.95),
                foreground: .white,
                border: NSColor(calibratedWhite: 1, alpha: 0.45)
            )
        case .light:
            return Colors(
                background: NSColor(calibratedWhite: 0.98, alpha: 0.97),
                foreground: .black,
                border: NSColor(calibratedWhite: 0.2, alpha: 0.9)
            )
        }
    }
}

/// Draws labels, the scroll area outline and the search bar on a transparent panel per screen.
///
/// Everything passed in uses accessibility coordinates: origin at the top-left of the primary
/// screen, y growing downward.
@MainActor
public final class OverlayController {
    private struct Entry {
        let label: String
        let background: CALayer
        let text: CATextLayer
    }

    private struct Placement {
        let host: CALayer
        let origin: CGPoint
        let size: CGSize
        let scale: CGFloat
    }

    private static let green = NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.45, alpha: 1)

    public var style = HintStyle()
    /// Text of the search bar, replaceable so the app can localise it.
    public var searchPlaceholder = "Type to search"
    public var matchCountText: @MainActor (Int) -> String = { $0 == 1 ? "1 match" : "\($0) matches" }
    private var panels: [OverlayPanel] = []
    private var screenFrames: [CGRect] = []
    private var screenScales: [CGFloat] = []
    private var primaryHeight: CGFloat = 0
    private var entries: [Entry] = []
    private var decorations: [CALayer] = []
    private var isReversed = false

    public init() {}

    // MARK: Hint mode

    public func showHints(_ items: [HintItem]) {
        draw {
            for item in items {
                addEntry(label: item.label, at: item.point, isFocused: false, typedCount: 0)
            }
        }
    }

    /// Adds labels to the ones already shown, for elements that were found later.
    /// `typedPrefix` is what the user has typed so far; labels that do not start with it stay hidden.
    public func appendHints(_ items: [HintItem], typedPrefix: String) {
        preparePanels()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for item in items {
            let countBefore = entries.count
            addEntry(label: item.label, at: item.point, isFocused: false, typedCount: 0)
            if entries.count > countBefore, !item.label.hasPrefix(typedPrefix) {
                entries[countBefore].background.isHidden = true
            }
        }
        CATransaction.commit()
        panels.forEach { $0.orderFrontRegardless() }
    }

    /// Dims the typed prefix and hides labels that no longer match.
    public func update(prefix: String) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for entry in entries {
            let matches = entry.label.hasPrefix(prefix)
            entry.background.isHidden = !matches
            if matches {
                entry.text.string = attributedLabel(entry.label, typedCount: prefix.count)
            }
        }
        CATransaction.commit()
    }

    /// Flips the stacking order so labels hidden under others come to the front.
    public func rotate() {
        isReversed.toggle()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, entry) in entries.enumerated() {
            entry.background.zPosition = CGFloat(isReversed ? entries.count - index : index)
        }
        CATransaction.commit()
    }

    // MARK: Scroll mode

    /// Outlines one scroll area and shows its number.
    public func showScrollArea(frame: CGRect, index: Int) {
        draw {
            guard let placement = place(frame) else { return }
            let rect = CGRect(origin: placement.origin, size: placement.size).insetBy(dx: 2, dy: 2)
            addGradientBorder(rect, colors: HintStyle.accent, width: 3, cornerRadius: 8, to: placement.host)

            // A pill in the corner that names the scroll area.
            let pill = CAGradientLayer()
            pill.colors = HintStyle.accent.map(\.cgColor)
            pill.startPoint = CGPoint(x: 0, y: 0.5)
            pill.endPoint = CGPoint(x: 1, y: 0.5)
            pill.cornerRadius = 11
            pill.frame = CGRect(x: rect.minX + 10, y: rect.maxY - 32, width: 30, height: 22)
            let number = textLayer(String(index), size: 13, color: .white, scale: placement.scale)
            number.frame = CGRect(x: 0, y: 3, width: 30, height: 16)
            pill.addSublayer(number)
            addShadow(to: pill)
            placement.host.addSublayer(pill)
            decorations.append(pill)
        }
    }

    // MARK: Search mode

    /// Redraws search mode: a label per match, a green outline on the focused one, and the search bar.
    /// - Parameters:
    ///   - focus: position of the focused item in `items`.
    ///   - focusFrame: frame of the focused element.
    ///   - anchor: any rectangle on the screen that should carry the search bar.
    public func showSearch(
        query: String,
        labelPrefix: String,
        items: [HintItem],
        focus: Int?,
        focusFrame: CGRect?,
        anchor: CGRect?
    ) {
        draw {
            if let focusFrame, let placement = place(focusFrame) {
                let rect = CGRect(origin: placement.origin, size: placement.size).insetBy(dx: -2, dy: -2)
                addGradientBorder(
                    rect,
                    colors: [Self.green, HintStyle.palette[5]],
                    width: 2.5,
                    cornerRadius: 6,
                    to: placement.host
                )
            }
            for (index, item) in items.enumerated() {
                guard item.label.hasPrefix(labelPrefix) else { continue }
                addEntry(
                    label: item.label,
                    at: item.point,
                    isFocused: index == focus,
                    typedCount: labelPrefix.count
                )
            }
            addSearchBar(query: query, matchCount: items.count, anchor: anchor)
        }
    }

    public func hide() {
        clearLayers()
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    // MARK: Panels

    /// Clears the previous drawing, runs `body` without implicit animations, and shows the panels.
    private func draw(_ body: () -> Void) {
        preparePanels()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clearLayers()
        body()
        CATransaction.commit()
        panels.forEach { $0.orderFrontRegardless() }
    }

    /// Creates one panel per screen unless they exist already.
    private func preparePanels() {
        guard panels.isEmpty else { return }
        let screens = NSScreen.screens
        screenFrames = screens.map(\.frame)
        screenScales = screens.map(\.backingScaleFactor)
        // The primary screen defines the origin of both coordinate spaces.
        primaryHeight = screenFrames.first?.height ?? 0
        panels = screenFrames.map { OverlayPanel(screenFrame: $0) }
    }

    private func clearLayers() {
        entries.forEach { $0.background.removeFromSuperlayer() }
        entries.removeAll()
        decorations.forEach { $0.removeFromSuperlayer() }
        decorations.removeAll()
        isReversed = false
    }

    /// Finds the panel that shows `rect` and converts the rectangle into that panel's layer coordinates.
    private func place(_ rect: CGRect) -> Placement? {
        let global = ScreenGeometry.flipped(rect, primaryScreenHeight: primaryHeight)
        // A point has no area, so it is probed with a small square.
        let probe = global.isEmpty ? global.insetBy(dx: -0.5, dy: -0.5) : global
        guard let index = ScreenGeometry.indexOfScreen(containing: probe, screenFrames: screenFrames),
            let host = panels[index].contentView?.layer
        else { return nil }
        return Placement(
            host: host,
            origin: CGPoint(x: global.minX - screenFrames[index].minX, y: global.minY - screenFrames[index].minY),
            size: global.size,
            scale: screenScales[index]
        )
    }

    // MARK: Layers

    private func attributedLabel(_ label: String, typedCount: Int, isFocused: Bool = false) -> NSAttributedString {
        // The focus colour is light, so its text stays dark in every theme.
        let color = isFocused ? NSColor.black : style.colors(for: label).foreground
        let string = NSMutableAttributedString(
            string: label,
            attributes: [
                .font: NSFont.systemFont(ofSize: style.fontSize, weight: .bold),
                .foregroundColor: color,
            ]
        )
        if typedCount > 0 {
            string.addAttribute(
                .foregroundColor,
                value: color.withAlphaComponent(0.4),
                range: NSRange(location: 0, length: min(typedCount, label.count))
            )
        }
        return string
    }

    private func addEntry(label: String, at point: CGPoint, isFocused: Bool, typedCount: Int) {
        guard let placement = place(CGRect(origin: point, size: .zero)) else { return }
        let string = attributedLabel(label, typedCount: typedCount, isFocused: isFocused)
        let textSize = string.size()
        let size = CGSize(width: ceil(textSize.width) + 8, height: ceil(textSize.height) + 3)
        let colors = style.colors(for: label)

        let background = CALayer()
        background.frame = CGRect(
            x: (placement.origin.x - size.width / 2).rounded(),
            y: (placement.origin.y - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
        background.backgroundColor = (isFocused ? Self.green : colors.background).cgColor
        background.borderColor = colors.border.cgColor
        background.borderWidth = 0.5
        // Never rounder than a pill.
        background.cornerRadius = min(style.cornerRadius, size.height / 2)
        background.zPosition = CGFloat(entries.count)
        addShadow(to: background)

        let text = CATextLayer()
        text.string = string
        text.contentsScale = placement.scale
        text.alignmentMode = .center
        text.frame = CGRect(x: 0, y: 1.5, width: size.width, height: ceil(textSize.height))
        background.addSublayer(text)

        placement.host.addSublayer(background)
        entries.append(Entry(label: label, background: background, text: text))
    }

    /// A rounded outline drawn with a gradient.
    private func addGradientBorder(_ rect: CGRect, colors: [NSColor], width: CGFloat, cornerRadius: CGFloat, to host: CALayer) {
        let gradient = CAGradientLayer()
        gradient.frame = rect
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)

        let outline = CAShapeLayer()
        outline.path = CGPath(
            roundedRect: CGRect(origin: .zero, size: rect.size).insetBy(dx: width / 2, dy: width / 2),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        outline.fillColor = nil
        outline.strokeColor = NSColor.black.cgColor
        outline.lineWidth = width
        gradient.mask = outline

        host.addSublayer(gradient)
        decorations.append(gradient)
    }

    /// A soft drop shadow that lifts a layer off whatever is behind it.
    private func addShadow(to layer: CALayer) {
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 2.5
        layer.shadowOffset = CGSize(width: 0, height: -1)
    }

    private func textLayer(_ string: String, size: CGFloat, color: NSColor, scale: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = NSAttributedString(
            string: string,
            attributes: [.font: NSFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: color]
        )
        layer.alignmentMode = .center
        layer.contentsScale = scale
        return layer
    }

    private func addSearchBar(query: String, matchCount: Int, anchor: CGRect?) {
        // Without an anchor the bar goes on the primary screen.
        let index: Int
        if let anchor, let placement = place(anchor), let found = panels.firstIndex(where: { $0.contentView?.layer === placement.host }) {
            index = found
        } else {
            index = 0
        }
        guard panels.indices.contains(index), let host = panels[index].contentView?.layer else { return }

        let width: CGFloat = 460, height: CGFloat = 48
        let frame = CGRect(
            x: ((screenFrames[index].width - width) / 2).rounded(),
            y: 96,
            width: width,
            height: height
        )
        let bar = CALayer()
        bar.frame = frame
        bar.backgroundColor = NSColor(srgbRed: 0.09, green: 0.10, blue: 0.14, alpha: 0.94).cgColor
        bar.cornerRadius = height / 2
        bar.zPosition = 10_000
        bar.shadowColor = NSColor.black.cgColor
        bar.shadowOpacity = 0.35
        bar.shadowRadius = 14
        bar.shadowOffset = CGSize(width: 0, height: -4)

        // A round gradient badge with a magnifying glass.
        let badge = CAGradientLayer()
        badge.colors = HintStyle.accent.map(\.cgColor)
        badge.startPoint = CGPoint(x: 0, y: 1)
        badge.endPoint = CGPoint(x: 1, y: 0)
        badge.frame = CGRect(x: 8, y: 8, width: 32, height: 32)
        badge.cornerRadius = 16
        if let symbol = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .bold).applying(.init(paletteColors: [.white])))
        {
            let glyph = CALayer()
            glyph.contents = symbol
            glyph.contentsGravity = .center
            glyph.contentsScale = screenScales[index]
            glyph.frame = badge.bounds
            badge.addSublayer(glyph)
        }
        bar.addSublayer(badge)

        let isEmpty = query.isEmpty
        let text = textLayer(
            isEmpty ? searchPlaceholder : query,
            size: 17,
            color: isEmpty ? NSColor(calibratedWhite: 1, alpha: 0.4) : .white,
            scale: screenScales[index]
        )
        text.alignmentMode = .left
        text.truncationMode = .end
        text.frame = CGRect(x: 52, y: 12, width: width - 180, height: 24)
        bar.addSublayer(text)

        if !isEmpty {
            // The match count sits in its own tinted capsule.
            let hasMatches = matchCount > 0
            let tint = hasMatches ? Self.green : HintStyle.palette[2]
            let capsule = CALayer()
            capsule.backgroundColor = tint.withAlphaComponent(0.22).cgColor
            capsule.cornerRadius = 12
            capsule.frame = CGRect(x: width - 116, y: 12, width: 100, height: 24)
            let count = textLayer(
                matchCountText(matchCount),
                size: 12,
                color: tint,
                scale: screenScales[index]
            )
            count.frame = CGRect(x: 0, y: 4, width: 100, height: 16)
            capsule.addSublayer(count)
            bar.addSublayer(capsule)
        }

        addGradientBorder(frame.insetBy(dx: -1, dy: -1), colors: HintStyle.accent, width: 1.5, cornerRadius: height / 2 + 1, to: host)
        decorations.last?.zPosition = 10_001
        host.addSublayer(bar)
        decorations.append(bar)
    }
}
