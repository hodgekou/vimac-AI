import AppKit
import VimacCore

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
    public var fontSize: CGFloat = 11
    public var cornerRadius: CGFloat = 3
    public var theme = HintTheme.yellow

    public init() {}

    var background: NSColor {
        switch theme {
        case .yellow: NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.30, alpha: 1)
        case .dark: NSColor(calibratedWhite: 0.13, alpha: 0.95)
        case .light: NSColor(calibratedWhite: 0.98, alpha: 0.97)
        }
    }

    var foreground: NSColor {
        theme == .dark ? .white : .black
    }

    var border: NSColor {
        theme == .dark ? NSColor(calibratedWhite: 1, alpha: 0.45) : NSColor(calibratedWhite: 0.2, alpha: 1)
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
            let blue = NSColor.systemBlue
            let rect = CGRect(origin: placement.origin, size: placement.size).insetBy(dx: 1, dy: 1)
            addBorder(rect, color: blue, to: placement.host)

            let badge = textLayer(String(index), size: 12, color: .white, scale: placement.scale)
            badge.backgroundColor = blue.cgColor
            badge.cornerRadius = 3
            badge.frame = CGRect(x: rect.minX + 6, y: rect.maxY - 24, width: 18, height: 18)
            placement.host.addSublayer(badge)
            decorations.append(badge)
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
                addBorder(rect, color: Self.green, to: placement.host)
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
        if panels.isEmpty {
            let screens = NSScreen.screens
            screenFrames = screens.map(\.frame)
            screenScales = screens.map(\.backingScaleFactor)
            // The primary screen defines the origin of both coordinate spaces.
            primaryHeight = screenFrames.first?.height ?? 0
            panels = screenFrames.map { OverlayPanel(screenFrame: $0) }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clearLayers()
        body()
        CATransaction.commit()
        panels.forEach { $0.orderFrontRegardless() }
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
              let host = panels[index].contentView?.layer else { return nil }
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
        let color = isFocused ? NSColor.black : style.foreground
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
        let size = CGSize(width: ceil(textSize.width) + 6, height: ceil(textSize.height) + 2)

        let background = CALayer()
        background.frame = CGRect(
            x: (placement.origin.x - size.width / 2).rounded(),
            y: (placement.origin.y - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
        background.backgroundColor = (isFocused ? Self.green : style.background).cgColor
        background.borderColor = style.border.cgColor
        background.borderWidth = 0.5
        background.cornerRadius = style.cornerRadius
        background.zPosition = CGFloat(entries.count)

        let text = CATextLayer()
        text.string = string
        text.contentsScale = placement.scale
        text.alignmentMode = .center
        text.frame = CGRect(x: 0, y: 1, width: size.width, height: ceil(textSize.height))
        background.addSublayer(text)

        placement.host.addSublayer(background)
        entries.append(Entry(label: label, background: background, text: text))
    }

    private func addBorder(_ rect: CGRect, color: NSColor, to host: CALayer) {
        let border = CALayer()
        border.frame = rect
        border.borderColor = color.cgColor
        border.borderWidth = 2
        border.cornerRadius = 4
        host.addSublayer(border)
        decorations.append(border)
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

        let width: CGFloat = 420, height: CGFloat = 40
        let bar = CALayer()
        bar.frame = CGRect(
            x: ((screenFrames[index].width - width) / 2).rounded(),
            y: 96,
            width: width,
            height: height
        )
        bar.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 0.92).cgColor
        bar.borderColor = NSColor(calibratedWhite: 1, alpha: 0.25).cgColor
        bar.borderWidth = 1
        bar.cornerRadius = 10
        bar.zPosition = 10_000

        let isEmpty = query.isEmpty
        let text = textLayer(
            isEmpty ? "Type to search" : query,
            size: 16,
            color: isEmpty ? NSColor(calibratedWhite: 1, alpha: 0.45) : .white,
            scale: screenScales[index]
        )
        text.alignmentMode = .left
        text.truncationMode = .end
        text.frame = CGRect(x: 14, y: 9, width: width - 120, height: 22)
        bar.addSublayer(text)

        if !isEmpty {
            let count = textLayer(
                matchCount == 1 ? "1 match" : "\(matchCount) matches",
                size: 12,
                color: NSColor(calibratedWhite: 1, alpha: 0.6),
                scale: screenScales[index]
            )
            count.alignmentMode = .right
            count.frame = CGRect(x: width - 104, y: 11, width: 90, height: 16)
            bar.addSublayer(count)
        }

        host.addSublayer(bar)
        decorations.append(bar)
    }
}
