// SPDX-License-Identifier: GPL-3.0-only

import Observation
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, hints, scrolling, activation, vision

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .hints: "Hints"
        case .scrolling: "Scrolling"
        case .activation: "Activation"
        case .vision: "AI Detection"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Shortcuts, startup and ignored apps"
        case .hints: "How labels look and behave"
        case .scrolling: "Speed and direction"
        case .activation: "Other ways to start a mode"
        case .vision: "Find text that apps do not expose"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .hints: "tag.fill"
        case .scrolling: "arrow.up.arrow.down"
        case .activation: "keyboard.fill"
        case .vision: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .general: Color(red: 0.23, green: 0.51, blue: 0.96)
        case .hints: Color(red: 0.96, green: 0.45, blue: 0.09)
        case .scrolling: Color(red: 0.06, green: 0.65, blue: 0.47)
        case .activation: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .vision: Color(red: 0.93, green: 0.28, blue: 0.60)
        }
    }
}

/// The selected pane. An observable object rather than view state, because the
/// Command Line Tools ship without the SwiftUI macro plugin that `@State` needs.
@MainActor
@Observable
final class SettingsNavigation {
    var pane = SettingsPane.general
}
