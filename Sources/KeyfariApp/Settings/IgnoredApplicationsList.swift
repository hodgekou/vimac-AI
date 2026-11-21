// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

/// An application as shown in the ignore list: its name and icon, looked up from its bundle identifier.
struct ApplicationInfo: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage

    var id: String { bundleID }

    @MainActor
    init(bundleID: String) {
        self.bundleID = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            // Not installed any more, or never was: show the identifier itself.
            name = bundleID
            icon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
    }

    /// The applications with a Dock icon that are running now, by name.
    @MainActor
    static func running() -> [ApplicationInfo] {
        let own = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { $0 != own && seen.insert($0).inserted }
            .map(ApplicationInfo.init)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// The ignored applications with their icons, a button to remove each, and a menu to add one.
struct IgnoredApplicationsList: View {
    @Bindable var store: SettingsStore
    let tint: Color

    var body: some View {
        let ignored = store.settings.ignoredBundleIDs.filter { !$0.isEmpty }
        let candidates = ApplicationInfo.running().filter { !ignored.contains($0.bundleID) }

        VStack(alignment: .leading, spacing: 0) {
            if ignored.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(tr("No applications are ignored")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            ForEach(ignored.map(ApplicationInfo.init)) { application in
                HStack(spacing: 10) {
                    Image(nsImage: application.icon)
                        .resizable()
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(application.name).font(.system(size: 13))
                        Text(application.bundleID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.toggleIgnored(bundleID: application.bundleID)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .help(tr("Remove"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                RowDivider()
            }
            if ignored.isEmpty { RowDivider() }

            HStack(alignment: .top, spacing: 12) {
                Text(tr("Shortcuts do nothing while one of these applications is in front."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Menu {
                    if candidates.isEmpty {
                        Text(tr("No other applications are running"))
                    }
                    ForEach(candidates) { application in
                        Button {
                            store.toggleIgnored(bundleID: application.bundleID)
                        } label: {
                            Label {
                                Text(application.name)
                            } icon: {
                                Image(nsImage: application.icon)
                            }
                        }
                    }
                } label: {
                    Label(tr("Add application"), systemImage: "plus")
                }
                .menuStyle(.borderedButton)
                .fixedSize()
                .tint(tint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}
