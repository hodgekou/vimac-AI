// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import KeyfariCore
import OverlayKit
import SwiftUI

@MainActor
enum Brand {
    /// The application icon, read straight from the bundle. `NSApplication.applicationIconImage`
    /// returned the generic document icon for this menu bar app.
    static let icon: NSImage =
        Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:)) ?? NSApplication.shared.applicationIconImage
}

/// A rounded square with a gradient fill and a white symbol, like the icons in System Settings.
struct IconBadge: View {
    let symbol: String
    let colors: [Color]
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: (colors.first ?? .clear).opacity(0.35), radius: 4, y: 2)
    }
}

struct SidebarItem: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                IconBadge(symbol: pane.symbol, colors: [pane.tint, pane.tint.opacity(0.75)], size: 24)
                Text(tr(pane.title))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? pane.tint.opacity(0.16) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A titled, rounded group of rows.
struct Card<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    let content: Content

    init(_ title: String, symbol: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(tr(title).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08))
                )
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, 12)
    }
}

/// A label on the left and a control on the right.
struct SettingRow<Control: View>: View {
    let title: String
    let detail: String?
    let control: Control

    init(_ title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr(title)).font(.system(size: 13))
                if let detail {
                    Text(tr(detail)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

struct ToggleRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool
    let tint: Color

    init(_ title: String, detail: String?, isOn: Binding<Bool>, tint: Color) {
        self.title = title
        self.detail = detail
        _isOn = isOn
        self.tint = tint
    }

    var body: some View {
        SettingRow(title, detail: detail) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(tint)
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    let format: (Double) -> String

    init(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        tint: Color,
        format: @escaping (Double) -> String
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.tint = tint
        self.format = format
    }

    var body: some View {
        SettingRow(title) {
            HStack(spacing: 10) {
                // Snapped in the binding rather than with `step:`, which draws a tick per step.
                Slider(
                    value: Binding(
                        get: { value },
                        set: { value = min(max(($0 / step).rounded() * step, range.lowerBound), range.upperBound) }
                    ),
                    in: range
                )
                .tint(tint)
                .frame(width: 190)
                Text(format(value))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(tint)
                    .frame(width: 58, alignment: .trailing)
            }
        }
    }
}

/// A tinted line of advice or warning.
struct Notice: View {
    let text: String
    let symbol: String
    let tint: Color

    init(_ text: String, symbol: String, tint: Color) {
        self.text = text
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint)
            // Text that was translated by the caller has no entry of its own and passes through.
            Text(tr(text))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

/// One key drawn as a keycap.
struct Keycap: View {
    let text: String
    var tint: Color?

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(tint ?? .primary)
            .padding(.horizontal, 7)
            .frame(minWidth: 24, minHeight: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 0.5, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke((tint ?? Color.primary).opacity(0.25))
            )
    }
}

struct KeyHint: View {
    let keys: [String]
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    Keycap(text: key)
                }
            }
            .frame(width: 124, alignment: .leading)
            Text(tr(text)).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

/// A selectable sample of a label theme.
struct ThemeSwatch: View {
    let theme: HintTheme
    let isSelected: Bool
    let action: () -> Void

    private var name: String {
        switch theme {
        case .vivid: "Vivid"
        case .yellow: "Yellow"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var body: some View {
        var style = HintStyle()
        style.theme = theme
        let samples = ["A", "S", "D"].map { ($0, style.colors(for: $0)) }
        return Button(action: action) {
            VStack(spacing: 5) {
                HStack(spacing: 2) {
                    ForEach(samples, id: \.0) { label, colors in
                        Text(label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(nsColor: colors.foreground))
                            .frame(width: 16, height: 16)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: colors.background)))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: colors.border), lineWidth: 0.5))
                    }
                }
                Text(tr(name))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            // Keeps its natural size: squeezed, the names wrapped letter by letter.
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
