import Foundation
import CoreGraphics
import Observation

/// Represents a group of windows displayed under a unified tab bar.
/// Each group has its own tab bar panel and manages the visibility
/// of its member windows.
/// Named "TabGroup" to avoid collision with SwiftUI's WindowGroup.
///
/// IMPORTANT: All coordinates are stored in AX coordinate system
/// (origin at top-left of screen, Y increases downward).
@Observable
final class TabGroup: Identifiable {
    let id: UUID
    var tabs: [ManagedWindow]
    var activeTabIndex: Int
    /// The frame of the grouped window in AX coordinates (origin top-left, Y increases down).
    var frame: CGRect
    var isMinimized: Bool

    /// Height of the tab bar in points.
    static let tabBarHeight: CGFloat = 36

    init(initialWindow: ManagedWindow) {
        self.id = UUID()
        self.tabs = [initialWindow]
        self.activeTabIndex = 0
        self.isMinimized = false

        // Store the window's frame in AX coordinates (which is what we get from AXUIElement)
        self.frame = initialWindow.originalFrame
    }

    /// The currently active window, if any.
    var activeWindow: ManagedWindow? {
        guard activeTabIndex >= 0 && activeTabIndex < tabs.count else { return nil }
        return tabs[activeTabIndex]
    }

    /// A display name for the group, based on the active window's app name.
    var displayName: String {
        if let active = activeWindow {
            return "\(active.appName) - \(active.title)"
        }
        return "Empty Group"
    }

    /// Checks if a window is already in this group.
    func contains(windowID: CGWindowID) -> Bool {
        tabs.contains { $0.windowID == windowID }
    }

    /// Returns the index of a window in this group, if present.
    func indexOf(windowID: CGWindowID) -> Int? {
        tabs.firstIndex { $0.windowID == windowID }
    }
}
