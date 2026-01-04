import SwiftUI

@main
struct AppMuxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var hasAccessibilityPermission = AccessibilityService.shared.isAccessibilityEnabled

    var body: some Scene {
        // Menu bar extra for quick access to groups
        MenuBarExtra("AppMux", systemImage: "square.stack.3d.up") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        // Main window - shown only when permissions needed
        WindowGroup {
            if hasAccessibilityPermission {
                MainContentView()
            } else {
                PermissionsView {
                    hasAccessibilityPermission = true
                }
            }
        }
        .windowResizability(.contentSize)
        .commands {
            // Remove the New Window command since we don't need multiple main windows
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// The main content view shown after permissions are granted.
/// This can be hidden - the app primarily runs from the menu bar.
struct MainContentView: View {
    @State private var windowManager = WindowManagerService.shared

    var body: some View {
        VStack(spacing: 20) {
            // App icon and status
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            Text("AppMux is Running")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Press ⌃⌥⌘⇧G on any window to create a group")
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Active groups summary
            VStack(spacing: 12) {
                HStack {
                    Text("Active Groups")
                        .font(.headline)
                    Spacer()
                    Text("\(windowManager.groups.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }

                if windowManager.groups.isEmpty {
                    Text("No groups yet. Focus a window and press ⌃⌥⌘⇧G to get started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(windowManager.groups) { group in
                        GroupRow(group: group)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )

            Spacer()

            // Hint
            Text("This window can be closed. AppMux will continue running in the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(minWidth: 450, minHeight: 400)
    }
}

/// A row displaying a single group in the main window.
struct GroupRow: View {
    let group: TabGroup

    var body: some View {
        HStack {
            // App icon
            if let icon = group.activeWindow?.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
            }

            // Group info
            VStack(alignment: .leading, spacing: 2) {
                Text(group.activeWindow?.title ?? "Untitled")
                    .font(.body)
                    .lineLimit(1)

                Text("\(group.tabs.count) tab\(group.tabs.count == 1 ? "" : "s") • \(group.isMinimized ? "Minimized" : "Active")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if group.isMinimized {
                    Button("Restore") {
                        WindowManagerService.shared.restoreGroup(group)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Minimize") {
                        WindowManagerService.shared.minimizeGroup(group)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("Ungroup") {
                    WindowManagerService.shared.dissolveGroup(group)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainContentView()
}
