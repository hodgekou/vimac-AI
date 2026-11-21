# Vimac-AI

Keyboard-driven navigation for macOS: type a short label to click any button, link or menu item, and scroll with HJKL.

This is a rewrite of [Vimac](https://github.com/nchudleigh/vimac) by Dexter Leng, which stopped receiving code changes in April 2021.

## Status

Working:

- **Hint mode** (`⌘⇧Space`): labels on every clickable element of the focused window, the menu bar and menu bar extras. Type a label to click. Hold `Shift` on the last letter for a right click, `Command` for a double click, `Control` for a command-click, `Option` to only move the cursor. `Delete` removes a letter, `Space` flips overlapping labels, `Esc` leaves.
- **Scroll mode** (`⌘⇧J`): `h j k l` scroll, with `Shift` for speed, `d` / `u` half a page, `gg` / `G` top and bottom, `Tab` or `0`–`9` to switch scroll areas, `Esc` leaves.
- **Search mode** (`⌘⇧/`): type part of an element's text to filter, `Tab` / arrows / `Ctrl-N` `Ctrl-P` to move the focus, `Shift` + label to jump, `Return` to click (twice for a double click), `Shift-Return` right click, `Command-Return` command-click. `*` or `;` matches everything.
- **Click chains**: optionally stay in the mode after a click.
- **Other ways to activate**: hold `Space`, or type a key sequence such as `fd`. Both are off by default.
- **Custom shortcuts** for all three modes, recorded in the settings window.
- **Search by pinyin**: Chinese text matches its pinyin in full or as initials, so `baocun` and `bc` both find 保存.
- **Stable labels**: an element keeps the label it had when you last clicked it.
- **Label themes** (yellow, dark, light), size and corner radius.
- **Notification buttons** get labels while a notification is on screen.
- **On-screen text detection** (off by default): recognises text in the window's pixels, on the device, and labels what the accessibility tree does not expose. Needs the Screen Recording permission.
- Settings window, ignored applications, launch at login.

Not yet: detection of icon-only buttons, automatic updates.

## Requirements

- macOS 14 or later
- Swift 6 toolchain. The Command Line Tools are enough; Xcode is optional.

## Build and run

```sh
scripts/bundle.sh          # builds build/Vimac-AI.app (debug)
open build/Vimac-AI.app
```

Grant the permission under System Settings > Privacy & Security > Accessibility. To watch the log:

```sh
log stream --predicate 'subsystem == "dev.vimac-ai.Vimac"'
```

The bundle is signed ad hoc by default, so macOS may ask for the permission again after a rebuild. Set `VIMAC_SIGN_IDENTITY` to a code signing identity from your keychain to keep it.

## Test

```sh
scripts/test.sh
```

## Layout

| Target | Purpose |
| --- | --- |
| `VimacCore` | Pure logic: label generation, geometry. No system permissions needed, fully unit tested. |
| `AXKit` | Accessibility (`AXUIElement`) access. |
| `InputKit` | Event taps, activators, synthesized mouse and scroll events. |
| `OverlayKit` | Transparent per-screen panels that draw hints and borders. |
| `VimacApp` | The executable: lifecycle, menu bar item, permission onboarding. |

## License

GPL-3.0, the same license as Vimac. Portions are derived from Vimac, Copyright © 2019–2021 Dexter Leng.
