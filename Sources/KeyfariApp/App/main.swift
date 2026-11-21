// SPDX-License-Identifier: GPL-3.0-only

import AppKit

#if DEBUG
// `Keyfari --render-settings <directory>` writes one PNG per settings pane and exits.
// It lets the layout be checked without opening the window or capturing the screen.
if let flag = CommandLine.arguments.firstIndex(of: "--render-settings"),
    CommandLine.arguments.indices.contains(flag + 1)
{
    SettingsSnapshot.render(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true))
    exit(0)
}
#endif

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
