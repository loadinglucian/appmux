import SwiftUI

/// The SwiftUI view for the tab bar content.
/// Displays tabs horizontally with app icons, titles, and close buttons.
struct TabBarView: View {
    let group: TabGroup

    /// Whether this tab bar is currently a valid drop target
    @State private var isDropTarget = false
    @State private var dropWindowID: CGWindowID?

    var body: some View {
        HStack(spacing: 0) {
            // Tab strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(group.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(
                            window: tab,
                            isActive: index == group.activeTabIndex,
                            onSelect: {
                                WindowManagerService.shared.activateTab(at: index, in: group)
                            },
                            onClose: {
                                WindowManagerService.shared.removeWindow(windowID: tab.windowID)
                            }
                        )
                    }

                    // Drop zone indicator (shown when dragging)
                    if isDropTarget {
                        DropZoneIndicator()
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 0)

            // Group controls
            HStack(spacing: 4) {
                // Add window button (placeholder for drag-drop target)
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isDropTarget ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .background(
                    isDropTarget ? Color.blue.opacity(0.2) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .help("Drag a window here to add it")

                // Minimize group button
                Button(action: {
                    WindowManagerService.shared.minimizeGroup(group)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help("Minimize group")

                // Dissolve group button
                Button(action: {
                    WindowManagerService.shared.dissolveGroup(group)
                }) {
                    Image(systemName: "rectangle.stack.badge.minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help("Ungroup all windows")
            }
            .padding(.horizontal, 8)
        }
        .frame(height: TabGroup.tabBarHeight)
        .background(
            ZStack {
                VisualEffectBlur(material: .menu, blendingMode: .behindWindow)

                // Highlight border when drop target
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onReceive(NotificationCenter.default.publisher(for: .dropTargetChanged)) { notification in
            handleDropTargetNotification(notification)
        }
    }

    private func handleDropTargetNotification(_ notification: Notification) {
        let targetGroupID = notification.userInfo?["groupID"] as? UUID
        let windowID = notification.userInfo?["windowID"] as? CGWindowID

        withAnimation(.easeInOut(duration: 0.15)) {
            isDropTarget = (targetGroupID == group.id && windowID != nil)
            dropWindowID = windowID
        }
    }
}

/// Visual indicator shown when a window can be dropped to add it to the group.
struct DropZoneIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
            Text("Drop to add")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .foregroundStyle(.blue.opacity(0.5))
                )
        )
        .transition(.scale.combined(with: .opacity))
    }
}

/// A visual effect blur view for the tab bar background.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
