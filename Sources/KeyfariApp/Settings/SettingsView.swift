// SPDX-License-Identifier: GPL-3.0-only

import KeyfariCore
import ScreenVision
import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 760, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        // A new identity rebuilds every view, so a language change reaches all of the text at once.
        .id(store.settings.language)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                // The application icon, which already carries its own shadow and margin.
                Image(nsImage: Brand.icon)
                    .resizable()
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Keyfari").font(.system(size: 15, weight: .bold))
                    Text(tr("Keyboard navigation")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 14)

            ForEach(SettingsPane.allCases) { pane in
                SidebarItem(pane: pane, isSelected: navigation.pane == pane) {
                    navigation.pane = pane
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 44)
        .padding(.bottom, 12)
        .frame(width: 200)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
    }

    private var detail: some View {
        let pane = navigation.pane
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    IconBadge(symbol: pane.symbol, colors: [pane.tint, pane.tint.opacity(0.7)], size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr(pane.title)).font(.system(size: 22, weight: .bold))
                        Text(tr(pane.subtitle)).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 2)

                switch pane {
                case .general: general
                case .hints: hints
                case .scrolling: scrolling
                case .activation: activation
                case .vision: vision
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Panes

    @ViewBuilder
    private var general: some View {
        let tint = SettingsPane.general.tint
        Card("Shortcuts", symbol: "command", tint: tint) {
            ShortcutRecorder(title: "Show hints", detail: "Label everything clickable", shortcut: $store.settings.hintShortcut, tint: tint)
            RowDivider()
            ShortcutRecorder(title: "Search", detail: "Find an element by its text", shortcut: $store.settings.searchShortcut, tint: tint)
            RowDivider()
            ShortcutRecorder(title: "Scroll mode", detail: "Scroll with H J K L", shortcut: $store.settings.scrollShortcut, tint: tint)
            if store.effective.hintShortcut != store.settings.hintShortcut
                || store.effective.searchShortcut != store.settings.searchShortcut
                || store.effective.scrollShortcut != store.settings.scrollShortcut
            {
                RowDivider()
                Notice("Two modes share a shortcut, so the defaults are in use.", symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
        }
        Card("Startup", symbol: "power", tint: tint) {
            ToggleRow("Launch at login", detail: "Start Keyfari when you log in", isOn: $store.settings.launchAtLogin, tint: tint)
        }
        Card("Language", symbol: "globe", tint: tint) {
            SettingRow("Interface language", detail: "Takes effect immediately") {
                Picker("", selection: $store.settings.language) {
                    Text(tr("System default")).tag(AppLanguage.system)
                    // Each language is listed under its own name, so it can be found from any other.
                    Text(Language.english.nativeName).tag(AppLanguage.english)
                    Text(Language.chinese.nativeName).tag(AppLanguage.chinese)
                    Text(Language.japanese.nativeName).tag(AppLanguage.japanese)
                }
                .labelsHidden()
                .frame(width: 180)
            }
        }
        Card("Ignored applications", symbol: "nosign", tint: tint) {
            IgnoredApplicationsList(store: store, tint: tint)
        }
    }

    @ViewBuilder
    private var hints: some View {
        let tint = SettingsPane.hints.tint
        HintPreview(settings: store.effective)

        Card("Appearance", symbol: "paintpalette.fill", tint: tint) {
            SettingRow("Theme") {
                HStack(spacing: 8) {
                    ForEach(HintTheme.allCases, id: \.self) { theme in
                        ThemeSwatch(theme: theme, isSelected: store.settings.hintTheme == theme) {
                            store.settings.hintTheme = theme
                        }
                    }
                }
            }
            RowDivider()
            SliderRow("Label size", value: $store.settings.hintFontSize, range: 8...32, step: 1, tint: tint) { "\(Int($0)) pt" }
            RowDivider()
            SliderRow("Corner radius", value: $store.settings.hintCornerRadius, range: 0...10, step: 1, tint: tint) { "\(Int($0)) pt" }
        }
        Card("Label characters", symbol: "textformat.abc", tint: tint) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(tr("Label characters"), text: $store.settings.hintAlphabet)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                if store.effective.hintAlphabet != store.settings.hintAlphabet.lowercased() {
                    Notice(
                        tr(
                            "Needs at least %d different letters. Using %@ for now.", HintLabelGenerator.minimumAlphabetSize,
                            store.effective.hintAlphabet),
                        symbol: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                } else {
                    Text(tr("Letters used for labels. Home-row keys first keeps your fingers still."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        Card("Behaviour", symbol: "hand.tap.fill", tint: tint) {
            ToggleRow(
                "Keep labels stable", detail: "An element keeps the label it had when you last clicked it", isOn: $store.settings.stableLabels,
                tint: tint)
            RowDivider()
            ToggleRow(
                "Chain clicks", detail: "Stay in the mode after a click, until Esc or a text field", isOn: $store.settings.chainClicks, tint: tint)
        }
    }

    @ViewBuilder
    private var scrolling: some View {
        let tint = SettingsPane.scrolling.tint
        Card("Speed", symbol: "speedometer", tint: tint) {
            SliderRow("Scroll speed", value: scrollSpeed, range: 1...100, step: 1, tint: tint) { "\(Int($0))" }
            RowDivider()
            SliderRow("Speed with Shift", value: $store.settings.dashMultiplier, range: 0.25...10, step: 0.25, tint: tint) {
                String(format: "× %.2f", $0)
            }
        }
        Card("Direction", symbol: "arrow.left.arrow.right", tint: tint) {
            ToggleRow("Reverse horizontal", detail: nil, isOn: $store.settings.reverseHorizontal, tint: tint)
            RowDivider()
            ToggleRow("Reverse vertical", detail: nil, isOn: $store.settings.reverseVertical, tint: tint)
        }
        Card("Keys", symbol: "keyboard", tint: tint) {
            VStack(alignment: .leading, spacing: 10) {
                KeyHint(keys: ["H", "J", "K", "L"], text: "Scroll left, down, up, right")
                KeyHint(keys: ["D", "U"], text: "Half a page down, up")
                KeyHint(keys: ["G", "G"], text: "Top  ·  Shift-G for the bottom")
                KeyHint(keys: ["Tab"], text: "Next scroll area  ·  0–9 to jump")
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var activation: some View {
        let tint = SettingsPane.activation.tint
        Card("Hold Space", symbol: "space", tint: tint) {
            ToggleRow(
                "Hold Space to show hints", detail: "A short tap still types a space, when you release it", isOn: $store.settings.holdSpaceEnabled,
                tint: tint)
            RowDivider()
            SliderRow("Hold delay", value: $store.settings.holdDelay, range: 0.1...1, step: 0.05, tint: tint) {
                String(format: "%.2f s", $0)
            }
        }
        Card("Key sequences", symbol: "character.cursor.ibeam", tint: tint) {
            SettingRow("Show hints", detail: "For example fd") {
                TextField(tr("off"), text: $store.settings.hintKeySequence)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 90)
            }
            RowDivider()
            SettingRow("Scroll mode", detail: "For example jk") {
                TextField(tr("off"), text: $store.settings.scrollKeySequence)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 90)
            }
            RowDivider()
            SliderRow("Timeout", value: $store.settings.keySequenceResetDelay, range: 0.1...1, step: 0.05, tint: tint) {
                String(format: "%.2f s", $0)
            }
            RowDivider()
            Notice("At least two characters, and neither sequence may start with the other.", symbol: "info.circle.fill", tint: tint)
        }
    }

    @ViewBuilder
    private var vision: some View {
        let tint = SettingsPane.vision.tint
        let granted = ScreenTextDetector.hasPermission
        Card("On-screen text detection", symbol: "text.viewfinder", tint: tint) {
            SettingRow("Detect text") {
                Picker("", selection: $store.settings.visionMode) {
                    Text(tr("Off")).tag(VisionMode.off)
                    Text(tr("When needed")).tag(VisionMode.fallback)
                    Text(tr("Always")).tag(VisionMode.always)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            }
            RowDivider()
            Notice(
                "Reads the window's pixels on this Mac to label text the application does not expose. Nothing is saved or sent anywhere.",
                symbol: "lock.shield.fill",
                tint: tint
            )
        }
        Card("Screen Recording permission", symbol: "rectangle.dashed.badge.record", tint: tint) {
            SettingRow("Status", detail: "Turn it on in System Settings, then restart Keyfari") {
                HStack(spacing: 10) {
                    StatusPill(text: tr(granted ? "Granted" : "Not granted"), tint: granted ? .green : .orange)
                    if !granted {
                        Button(tr("Request…")) { ScreenRecordingAccess.request() }
                            .buttonStyle(.borderedProminent)
                            .tint(tint)
                        Button(tr("Restart")) { ScreenRecordingAccess.relaunch() }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: Bindings

    private var scrollSpeed: Binding<Double> {
        Binding(
            get: { Double(store.settings.scrollSpeed) },
            set: { store.settings.scrollSpeed = Int($0) }
        )
    }
}
