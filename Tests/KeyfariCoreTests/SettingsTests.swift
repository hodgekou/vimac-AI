// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct SettingsTests {
    @Test func defaultsAreValid() {
        #expect(Settings().validated() == Settings())
    }

    @Test func outOfRangeValuesFallBack() {
        var settings = Settings()
        settings.hintAlphabet = "abc"
        settings.hintFontSize = 200
        settings.scrollSpeed = 0
        settings.dashMultiplier = 50
        #expect(settings.validated() == Settings())
    }

    @Test func alphabetIsLowercasedAndMustBeLetters() {
        var settings = Settings()
        settings.hintAlphabet = "ASDFGHJ"
        #expect(settings.validated().hintAlphabet == "asdfghj")
        settings.hintAlphabet = "asdf123"
        #expect(settings.validated().hintAlphabet == HintLabelGenerator.defaultAlphabet)
    }

    @Test func ignoredAppsAreTrimmedAndDeduplicated() {
        var settings = Settings()
        settings.ignoredBundleIDs = [" com.example.a ", "", "com.example.a", "com.example.b"]
        #expect(settings.validated().ignoredBundleIDs == ["com.example.a", "com.example.b"])
    }

    @Test func shortcutsMustBeDistinctAndModified() {
        var settings = Settings()
        settings.scrollShortcut = settings.hintShortcut
        #expect(settings.validated().scrollShortcut == Settings().scrollShortcut)

        settings = Settings()
        settings.hintShortcut = Shortcut(keyCode: KeyCode.space, modifiers: .shift)
        #expect(settings.validated().hintShortcut == Settings().hintShortcut)

        settings = Settings()
        settings.hintShortcut = Shortcut(keyCode: 3, modifiers: .control)
        #expect(settings.validated().hintShortcut == Shortcut(keyCode: 3, modifiers: .control))
    }

    @Test func shortcutDisplayAndMatching() {
        let shortcut = Shortcut(keyCode: KeyCode.space, modifiers: [.command, .shift])
        #expect(shortcut.displayString == "⇧⌘Space")
        #expect(Shortcut(keyCode: 3, modifiers: [.control, .option]).displayString == "⌃⌥F")
        #expect(shortcut.matches(KeyStroke(keyCode: KeyCode.space, modifiers: [.command, .shift])))
        #expect(!shortcut.matches(KeyStroke(keyCode: KeyCode.space, modifiers: .command)))
    }

    @Test func decodingAnOlderDocumentKeepsDefaultsForMissingFields() throws {
        let json = Data(#"{"scrollSpeed": 35}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: json)
        #expect(settings.scrollSpeed == 35)
        #expect(settings.hintAlphabet == HintLabelGenerator.defaultAlphabet)
    }
}
