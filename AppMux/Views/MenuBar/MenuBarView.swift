import SwiftUI

/// The content view for the menu bar extra dropdown.
/// Shows active groups and quick actions.
struct MenuBarView: View {
    @State private var windowManager = WindowManagerService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(.blue)
                Text("AppMux")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Active groups
            if windowManager.groups.isEmpty {
                Text("No active groups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
            } else {
                ForEach(windowManager.groups) { group in
                    GroupMenuItem(group: group)
                }
            }

            Divider()

            // Quick actions
            VStack(alignment: .leading, spacing: 0) {
                MenuButton(title: "New Group", shortcut: "⌃⌥⌘⇧G", systemImage: "plus.rectangle.on.rectangle") {
                    // Hotkey handles this - this is informational
                }
                .disabled(true)

                if !windowManager.groups.isEmpty {
                    MenuButton(title: "Restore All Groups", systemImage: "arrow.up.left.and.arrow.down.right") {
                        for group in windowManager.groups where group.isMinimized {
                            WindowManagerService.shared.restoreGroup(group)
                        }
                    }

                    MenuButton(title: "Dissolve All Groups", systemImage: "rectangle.stack.badge.minus") {
                        WindowManagerService.shared.dissolveAllGroups()
                    }
                }
            }

            Divider()

            // App controls
            MenuButton(title: "Quit AppMux", shortcut: "⌘Q", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 280)
    }
}

/// A single group item in the menu.
struct GroupMenuItem: View {
    let group: TabGroup

    @State private var isHovering = false

    var body: some View {
        HStack {
            // Active window icon
            if let icon = group.activeWindow?.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 12))
                    .frame(width: 16, height: 16)
            }

            // Group info
            VStack(alignment: .leading, spacing: 2) {
                Text(group.activeWindow?.appName ?? "Group")
                    .font(.body)
                    .lineLimit(1)

                Text("\(group.tabs.count) window\(group.tabs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            if group.isMinimized {
                Image(systemName: "minus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if group.isMinimized {
                WindowManagerService.shared.restoreGroup(group)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// A button styled for the menu bar dropdown.
struct MenuButton: View {
    let title: String
    var shortcut: String? = nil
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 16)

                Text(title)

                Spacer()

                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    MenuBarView()
        .frame(width: 280)
}
