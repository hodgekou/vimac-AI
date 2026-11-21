import ScreenVision
import SwiftUI
import VimacCore

struct SettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            hints.tabItem { Label("Hints", systemImage: "character.cursor.ibeam") }
            scrolling.tabItem { Label("Scrolling", systemImage: "arrow.up.and.down") }
            activation.tabItem { Label("Activation", systemImage: "keyboard") }
            vision.tabItem { Label("AI", systemImage: "eye") }
        }
        .frame(width: 520, height: 440)
        .padding()
    }

    private var general: some View {
        Form {
            Section("Shortcuts") {
                ShortcutRecorder(title: "Show hints", shortcut: $store.settings.hintShortcut)
                ShortcutRecorder(title: "Search", shortcut: $store.settings.searchShortcut)
                ShortcutRecorder(title: "Scroll mode", shortcut: $store.settings.scrollShortcut)
                if store.effective.hintShortcut != store.settings.hintShortcut
                    || store.effective.searchShortcut != store.settings.searchShortcut
                    || store.effective.scrollShortcut != store.settings.scrollShortcut {
                    Text("Two modes share a shortcut, so the defaults are in use.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Toggle("Launch at login", isOn: $store.settings.launchAtLogin)
            }
            Section("Ignored applications") {
                TextEditor(text: ignoredApps)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 70)
                Text("One bundle identifier per line. The menu bar item can also ignore the frontmost application.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var hints: some View {
        Form {
            Section {
                TextField("Label characters", text: $store.settings.hintAlphabet)
                    .font(.system(.body, design: .monospaced))
                if store.effective.hintAlphabet != store.settings.hintAlphabet.lowercased() {
                    Text("Needs at least \(HintLabelGenerator.minimumAlphabetSize) different letters. Using \(store.effective.hintAlphabet) for now.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Stepper(
                    "Label size: \(Int(store.settings.hintFontSize)) pt",
                    value: $store.settings.hintFontSize,
                    in: 8...32
                )
                Picker("Theme", selection: $store.settings.hintTheme) {
                    Text("Yellow").tag(HintTheme.yellow)
                    Text("Dark").tag(HintTheme.dark)
                    Text("Light").tag(HintTheme.light)
                }
                Stepper(
                    "Corner radius: \(Int(store.settings.hintCornerRadius)) pt",
                    value: $store.settings.hintCornerRadius,
                    in: 0...10
                )
            }
            Section {
                Toggle("Keep labels stable", isOn: $store.settings.stableLabels)
                Toggle("Chain clicks", isOn: $store.settings.chainClicks)
                Text("Stay in the mode after a click. The chain ends on Esc or when a text field is clicked.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var scrolling: some View {
        Form {
            Section {
                Slider(value: scrollSpeed, in: 1...100, step: 1) {
                    Text("Speed: \(store.settings.scrollSpeed)")
                }
                Slider(value: $store.settings.dashMultiplier, in: 0.25...10) {
                    Text("Shift speed: ×\(store.settings.dashMultiplier, specifier: "%.2f")")
                }
            }
            Section("Reverse direction") {
                Toggle("Horizontal", isOn: $store.settings.reverseHorizontal)
                Toggle("Vertical", isOn: $store.settings.reverseVertical)
            }
        }
        .formStyle(.grouped)
    }

    private var activation: some View {
        Form {
            Section("Hold Space") {
                Toggle("Hold Space to show hints", isOn: $store.settings.holdSpaceEnabled)
                Slider(value: $store.settings.holdDelay, in: 0.1...1) {
                    Text("Delay: \(store.settings.holdDelay, specifier: "%.2f") s")
                }
                Text("Space is typed when you release it, so it appears slightly later than usual.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Key sequences") {
                TextField("Hints", text: $store.settings.hintKeySequence, prompt: Text("for example fd"))
                TextField("Scroll mode", text: $store.settings.scrollKeySequence, prompt: Text("for example jk"))
                Slider(value: $store.settings.keySequenceResetDelay, in: 0.1...1) {
                    Text("Timeout: \(store.settings.keySequenceResetDelay, specifier: "%.2f") s")
                }
                Text("At least two characters, and neither may start with the other. Leave empty to switch off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var vision: some View {
        Form {
            Section("On-screen text detection") {
                Picker("Detect text", selection: $store.settings.visionMode) {
                    Text("Off").tag(VisionMode.off)
                    Text("When a window exposes few elements").tag(VisionMode.fallback)
                    Text("Always").tag(VisionMode.always)
                }
                Text("Reads the window's pixels on this Mac to label text that the application does not expose. Nothing is saved or sent anywhere.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Screen Recording permission") {
                LabeledContent("Status", value: ScreenTextDetector.hasPermission ? "Granted" : "Not granted")
                Button("Request Permission…") {
                    ScreenTextDetector.requestPermission()
                }
                Text("Needed only for text detection. After granting it, quit and reopen Vimac-AI.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var ignoredApps: Binding<String> {
        Binding(
            get: { store.settings.ignoredBundleIDs.joined(separator: "\n") },
            set: { store.settings.ignoredBundleIDs = $0.components(separatedBy: .newlines) }
        )
    }

    private var scrollSpeed: Binding<Double> {
        Binding(
            get: { Double(store.settings.scrollSpeed) },
            set: { store.settings.scrollSpeed = Int($0) }
        )
    }
}
