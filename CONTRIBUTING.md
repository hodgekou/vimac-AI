# Contributing to Keyfari

Bug reports, fixes and translations are welcome. Open an issue first for anything larger than a small fix, so the approach can be agreed before you spend time on it.

## Getting started

You need macOS 14 or later and a Swift 6 toolchain. The Command Line Tools are enough.

```sh
scripts/bundle.sh          # build build/Keyfari.app
scripts/test.sh            # run the unit tests
scripts/lint.sh            # check formatting and style
```

`scripts/test.sh` exists because the Command Line Tools keep the Swift Testing macro plugin outside the compiler's default search path. With Xcode installed, plain `swift test` works too.

## Before you open a pull request

- `scripts/test.sh` and `scripts/lint.sh` pass. CI runs both.
- The build has no warnings.
- New logic in `KeyfariCore` comes with unit tests.
- Changes to accessibility, input handling or the overlay are tried in a real application. These parts need system permissions and have no automated tests, so say in the pull request what you tried and in which application.

## Conventions

- **Swift 6 language mode** with strict concurrency. UI and mode state live on the main actor; accessibility calls are blocking cross-process requests and never run on the main thread.
- **Formatting** follows `.swift-format`: four spaces, 150 columns. `scripts/lint.sh --fix` applies it.
- **No force unwraps**, no force `try`, no implicitly unwrapped optionals. The linter enforces this.
- **Dependencies point one way**: `KeyfariApp` depends on the kits, the kits depend on `KeyfariCore`, and the kits do not depend on each other. Anything that can be decided without calling the system belongs in `KeyfariCore`, where it can be tested.
- **Comments say why**, not what. Leave a comment where a reader would otherwise have to guess: a workaround, a constraint, a non-obvious choice.
- **No third-party dependencies** so far. Raise an issue before adding one.
- **Every source file starts with** `// SPDX-License-Identifier: GPL-3.0-only`. Code adapted from Vimac keeps the note naming the original file and author.

## Adding or fixing a translation

Interface text lives in `Sources/KeyfariCore/Settings/Localization.swift`. The English text is the key; each entry carries the Chinese and Japanese text. Use `tr("English text")` in the app, and add an entry to the table. A unit test checks that every entry is translated and keeps its `%d` / `%@` placeholders.

To add a language, add a case to `Language` and `AppLanguage`, a field to `Localizer.Entry`, and its text to every entry.

## Debugging aids

Debug builds only:

- `pkill -USR1 -x Keyfari` toggles hint mode and `pkill -USR2 -x Keyfari` toggles scroll mode, so a mode can be driven from a terminal.
- `Keyfari --open-settings` opens the settings window at launch.
- `Keyfari --render-settings <directory>` writes a PNG of every settings pane in every language and exits. It uses a throwaway defaults domain, so it neither reads nor changes your settings.

Logs go to the unified log:

```sh
log stream --predicate 'subsystem == "app.keyfari.Keyfari"'
```

## The icon

`Resources/AppIcon.icns` is drawn by code:

```sh
swift scripts/make-icon.swift /tmp/AppIcon.iconset
iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
```

## Licence

By contributing you agree that your contribution is licensed under GPL-3.0, like the rest of the project.
