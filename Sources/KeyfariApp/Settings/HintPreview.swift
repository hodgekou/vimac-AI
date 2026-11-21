// SPDX-License-Identifier: GPL-3.0-only

import KeyfariCore
import OverlayKit
import SwiftUI

/// A mock window that shows the labels as they will be drawn.
struct HintPreview: View {
    let settings: KeyfariCore.Settings

    private static let positions: [CGPoint] = [
        CGPoint(x: 52, y: 26), CGPoint(x: 122, y: 26), CGPoint(x: 192, y: 26),
        CGPoint(x: 86, y: 74), CGPoint(x: 250, y: 74), CGPoint(x: 400, y: 74),
        CGPoint(x: 330, y: 26), CGPoint(x: 452, y: 26),
    ]

    var body: some View {
        var style = HintStyle()
        style.theme = settings.hintTheme
        let labels = HintLabelGenerator.labels(count: Self.positions.count, alphabet: settings.hintAlphabet)
        let fontSize = min(settings.hintFontSize, 20)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.98, green: 0.93, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            // Stand-ins for a toolbar and a row of buttons.
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in Capsule().fill(.white.opacity(0.9)).frame(width: 60, height: 22) }
                Spacer()
                Capsule().fill(.white.opacity(0.9)).frame(width: 110, height: 22)
                Circle().fill(.white.opacity(0.9)).frame(width: 22, height: 22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 15)
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.75)).frame(width: 130, height: 30)
                RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.75)).frame(width: 170, height: 30)
                RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.75)).frame(width: 110, height: 30)
            }
            .padding(.horizontal, 22)
            .padding(.top, 59)

            ForEach(Array(zip(labels, Self.positions).enumerated()), id: \.offset) { _, pair in
                let colors = style.colors(for: pair.0)
                Text(pair.0)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Color(nsColor: colors.foreground))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: settings.hintCornerRadius, style: .continuous)
                            .fill(Color(nsColor: colors.background))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: settings.hintCornerRadius, style: .continuous)
                            .stroke(Color(nsColor: colors.border), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .position(pair.1)
            }
        }
        .frame(height: 108)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}
