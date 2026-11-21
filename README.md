# Keyfari

Keyboard-driven navigation for macOS. Press a shortcut, and every button, link and menu item gets a short label; type the label to click it. Scroll with `H J K L`. No mouse needed.

Keyfari is a rewrite of [Vimac](https://github.com/nchudleigh/vimac) by Dexter Leng, which stopped receiving code changes in April 2021. It is not affiliated with Vimac or its author.

## Features

- **Hint mode** (`⌘⇧Space`): labels on every clickable element of the focused window, the menu bar, menu bar extras and notifications. Type a label to click. Hold `Shift` on the last letter for a right click, `Command` for a double click, `Control` for a command-click, `Option` to only move the cursor. `Delete` removes a letter, `Space` flips overlapping labels, `Esc` leaves.
- **Search mode** (`⌘⇧/`): type part of an element's text to filter, `Tab` / arrows / `Ctrl-N` `Ctrl-P` to move the focus, `Shift` + label to jump, `Return` to click (twice for a double click), `Shift-Return` right click, `Command-Return` command-click. `*` or `;` matches everything. Chinese text matches its pinyin in full or as initials, so `baocun` and `bc` both find 保存.
- **Scroll mode** (`⌘⇧J`): `h j k l` scroll, with `Shift` for speed, `d` / `u` half a page, `gg` / `G` top and bottom, `Tab` or `0`–`9` to switch scroll areas, `Esc` leaves.
- **On-screen text detection**: recognises text in the window's pixels, on the device, and labels what the accessibility tree does not expose. The regular labels appear at once and the detected ones are added a moment later.
- **Other ways to activate**: hold `Space`, or type a key sequence such as `fd`. Both are off by default.
- **Customisable**: shortcuts, label characters, themes, size and corner radius, scroll speed, click chains, stable labels, ignored applications, launch at login.
- **Interface in English, Chinese and Japanese**, following the system language unless you choose one.

Not yet: detection of icon-only buttons, automatic updates.

## Requirements

- macOS 14 or later
- Swift 6 toolchain. The Command Line Tools are enough; Xcode is optional.

## Build and run

```sh
scripts/bundle.sh          # builds build/Keyfari.app (debug)
open build/Keyfari.app
```

Pass `release` for an optimised build.

Keyfari appears in the menu bar. On first launch it asks for the **Accessibility** permission, which it needs to read the interface of other applications and to send clicks. On-screen text detection also needs the **Screen Recording** permission; it stays idle until that is granted.

The bundle is signed ad hoc by default, so macOS asks for the permissions again after every rebuild. Set `KEYFARI_SIGN_IDENTITY` to a code signing identity from your keychain to keep them.

## Privacy

Keyfari has no telemetry and makes no network requests. Screenshots taken for text detection are processed on the device with Apple's Vision framework and exist only in memory. Settings and remembered labels are stored locally in the user defaults.

## Project layout

| Path | Contents |
| --- | --- |
| `Sources/KeyfariCore` | Pure logic: label generation, input state machines, settings, translations. No system permissions needed; fully unit tested. |
| `Sources/AXKit` | Accessibility tree access and traversal. |
| `Sources/InputKit` | Event taps, hot keys, activators, synthesized mouse and scroll events. |
| `Sources/OverlayKit` | Transparent per-screen panels that draw labels, the search bar and scroll outlines. |
| `Sources/ScreenVision` | Screenshot text recognition. |
| `Sources/KeyfariApp` | The executable: `App` (lifecycle, menu bar), `Modes` (hint, search, scroll), `Settings` (settings window). |
| `Tests/KeyfariCoreTests` | Unit tests, one file per suite. |
| `Resources` | `Info.plist` and the application icon. |
| `scripts` | Building, testing, linting and drawing the icon. |

## Development

```sh
scripts/test.sh            # unit tests
scripts/lint.sh            # formatting and style; --fix rewrites in place
log stream --predicate 'subsystem == "app.keyfari.Keyfari"'
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions, debugging aids and how to add a translation.

## License

[GPL-3.0](LICENSE), the same license as Vimac. Portions are derived from Vimac, Copyright © 2019–2021 Dexter Leng; the files concerned say so at the top.
