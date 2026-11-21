// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct LocalizationTests {
    @Test func explicitChoiceIgnoresTheSystem() {
        #expect(AppLanguage.japanese.resolved(preferredLanguages: ["zh-Hans-CN"]) == .japanese)
        #expect(AppLanguage.english.resolved(preferredLanguages: ["ja-JP"]) == .english)
        #expect(AppLanguage.chinese.resolved(preferredLanguages: []) == .chinese)
    }

    @Test func systemFollowsTheFirstSupportedPreference() {
        #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]) == .chinese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW"]) == .chinese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP", "en-US"]) == .japanese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["en-GB"]) == .english)
        // An unsupported first choice is skipped in favour of the next one.
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "ja-JP"]) == .japanese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == .english)
        #expect(AppLanguage.system.resolved(preferredLanguages: []) == .english)
    }

    @Test func englishIsTheKeyAndTheFallback() {
        #expect(Localizer.text("General", in: .english) == "General")
        #expect(Localizer.text("General", in: .chinese) == "通用")
        #expect(Localizer.text("General", in: .japanese) == "一般")
        #expect(Localizer.text("No such string", in: .chinese) == "No such string")
    }

    @Test func formatsArguments() {
        #expect(Localizer.text("%d matches", in: .english, [3]) == "3 matches")
        #expect(Localizer.text("%d matches", in: .chinese, [3]) == "3 个匹配")
        #expect(Localizer.text("Ignore %@", in: .japanese, ["Safari"]) == "Safari を除外")
    }

    @Test func everyEntryIsTranslatedAndKeepsItsPlaceholders() {
        func placeholders(_ text: String) -> [String] {
            var result: [String] = []
            var index = text.startIndex
            while let percent = text[index...].firstIndex(of: "%") {
                let next = text.index(after: percent)
                guard next < text.endIndex else { break }
                result.append(String(text[next]))
                index = text.index(after: next)
            }
            return result.sorted()
        }

        for (english, entry) in Localizer.table {
            #expect(!entry.chinese.isEmpty, "\(english) has no Chinese text")
            #expect(!entry.japanese.isEmpty, "\(english) has no Japanese text")
            #expect(placeholders(entry.chinese) == placeholders(english), "\(english): Chinese placeholders differ")
            #expect(placeholders(entry.japanese) == placeholders(english), "\(english): Japanese placeholders differ")
        }
    }

    @Test func languageSettingSurvivesEncoding() throws {
        var settings = Settings()
        #expect(settings.language == .system)
        settings.language = .japanese
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.language == .japanese)
    }
}
