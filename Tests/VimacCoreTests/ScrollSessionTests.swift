import Foundation
import Testing
@testable import VimacCore

@Suite struct ScrollSessionTests {
    // Key codes on an ANSI keyboard.
    let h: UInt16 = 4, j: UInt16 = 38, k: UInt16 = 40, l: UInt16 = 37
    let d: UInt16 = 2, u: UInt16 = 32, g: UInt16 = 5, n: UInt16 = 45, p: UInt16 = 35
    let two: UInt16 = 19, nine: UInt16 = 25

    @Test func directionKeysStartAndKeyUpStops() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: h), at: 0) == .start(.left, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: l), at: 0) == .start(.right, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: k), at: 0) == .start(.up, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: j), at: 0) == .start(.down, dash: false))
        // Only the key that scrolls now stops the scroll.
        #expect(session.keyUp(keyCode: k) == .ignored)
        #expect(session.keyUp(keyCode: j) == .stop)
        #expect(session.keyUp(keyCode: j) == .ignored)
    }

    @Test func shiftDashes() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: j, modifiers: .shift), at: 0) == .start(.down, dash: true))
    }

    @Test func repeatsAreIgnored() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: j, isRepeat: true), at: 0) == .ignored)
    }

    @Test func halfPagesAndEdges() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: d), at: 0) == .halfPage(.down))
        #expect(session.keyDown(KeyStroke(keyCode: u), at: 0) == .halfPage(.up))
        #expect(session.keyDown(KeyStroke(keyCode: g, modifiers: .shift), at: 0) == .bottom)
    }

    @Test func doubleGGoesToTopOnlyWithinTheTimeout() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 1.0) == .ignored)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 1.3) == .top)

        #expect(session.keyDown(KeyStroke(keyCode: g), at: 5.0) == .ignored)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 5.9) == .ignored)

        // Another key in between breaks the sequence.
        _ = session.keyDown(KeyStroke(keyCode: g), at: 10.0)
        _ = session.keyDown(KeyStroke(keyCode: d), at: 10.1)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 10.2) == .ignored)
    }

    @Test func cyclesThroughAreasAndWraps() {
        var session = ScrollSession(areaCount: 3)
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.tab), at: 0) == .selectArea(1))
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.downArrow), at: 0) == .selectArea(2))
        #expect(session.keyDown(KeyStroke(keyCode: n, modifiers: .control), at: 0) == .selectArea(0))
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.tab, modifiers: .shift), at: 0) == .selectArea(2))
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.upArrow), at: 0) == .selectArea(1))
        #expect(session.keyDown(KeyStroke(keyCode: p, modifiers: .control), at: 0) == .selectArea(0))
    }

    @Test func digitsJumpToExistingAreasOnly() {
        var session = ScrollSession(areaCount: 3)
        #expect(session.keyDown(KeyStroke(keyCode: two), at: 0) == .selectArea(2))
        #expect(session.areaIndex == 2)
        #expect(session.keyDown(KeyStroke(keyCode: nine), at: 0) == .ignored)
        #expect(session.areaIndex == 2)
    }

    @Test func exits() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.escape), at: 0) == .exit)
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.leftBracket, modifiers: .control), at: 0) == .exit)
    }
}

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
