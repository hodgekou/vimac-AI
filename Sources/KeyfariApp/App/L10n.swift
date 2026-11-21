// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KeyfariCore

/// The language the interface is shown in. Set from the settings.
@MainActor
enum L10n {
    static var language = Language.english
}

/// Translates interface text into the current language. The English text is the key.
@MainActor
func tr(_ english: String) -> String {
    Localizer.text(english, in: L10n.language)
}

/// Translates a format string into the current language and fills in its arguments.
@MainActor
func tr(_ english: String, _ arguments: any CVarArg...) -> String {
    Localizer.text(english, in: L10n.language, arguments)
}
