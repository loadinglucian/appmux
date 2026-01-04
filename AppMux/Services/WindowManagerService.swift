import ApplicationServices
import AppKit
import Observation

/// The core service for managing window groups.
/// Handles creating, modifying, and dissolving groups, as well as
/// positioning windows and managing tab visibility.
@MainActor
@Observable
final class WindowManagerService: WindowObserverDelegate {
    static let shared = WindowManagerService()

    /// All active window groups.
    private(set) var groups: [TabGroup] = []

    /// Maps window IDs to their group for quick lookup.
    private var windowToGroup: [CGWindowID: UUID] = [:]

    /// Tab bar panels for each group.
    private var tabBarPanels: [UUID: TabBarPanel] = [:]

    private init() {
        WindowObserverService.shared.delegate = self
        setupDragTracker()
    }

    private func setupDragTracker() {
        WindowDragTracker.shared.onFrameUpdate = { [weak self] windowID, newFrame in
            self?.handleSmoothFrameUpdate(windowID: windowID, newFrame: newFrame)
        }
    }

    /// Called by WindowDragTracker at display refresh rate during window drags.
    /// This provides smooth, frame-synced tab bar movement.
    private func handleSmoothFrameUpdate(windowID: CGWindowID, newFrame: CGRect) {
        guard let group = findGroup(containing: windowID),
              group.activeWindow?.windowID == windowID else { return }

        // Update the group frame (stored in AX coordinates)
        group.frame = CGRect(
            x: newFrame.origin.x,
            y: newFrame.origin.y,
            width: newFrame.width,
            height: newFrame.height
        )

        // Reposition the tab bar panel (convert to Cocoa coords)
        if let panel = tabBarPanels[group.id] {
            let tabBarCocoaY = axYToCocoaY(newFrame.origin.y - TabGroup.tabBarHeight, height: TabGroup.tabBarHeight)

            let panelFrame = NSRect(
                x: newFrame.origin.x,
                y: tabBarCocoaY,
                width: newFrame.width,
                height: TabGroup.tabBarHeight
            )
            panel.setFrame(panelFrame, display: false, animate: false)
        }
    }

    // MARK: - Coordinate Conversion

    /// Converts a Y coordinate from AX (origin top-left) to Cocoa (origin bottom-left).
    /// - Parameters:
    ///   - axY: The Y coordinate in AX screen coordinates
    ///   - height: The height of the element being positioned
    /// - Returns: The Y coordinate in Cocoa screen coordinates
    private func axYToCocoaY(_ axY: CGFloat, height: CGFloat) -> CGFloat {
        guard let screenHeight = NSScreen.main?.frame.height else { return axY }
        return screenHeight - axY - height
    }

    /// Converts a Y coordinate from Cocoa (origin bottom-left) to AX (origin top-left).
    /// - Parameters:
    ///   - cocoaY: The Y coordinate in Cocoa screen coordinates
    ///   - height: The height of the element being positioned
    /// - Returns: The Y coordinate in AX screen coordinates
    private func cocoaYToAxY(_ cocoaY: CGFloat, height: CGFloat) -> CGFloat {
        guard let screenHeight = NSScreen.main?.frame.height else { return cocoaY }
        return screenHeight - cocoaY - height
    }

    // MARK: - Group Management

    /// Creates a new group with the given window as its first tab.
    @discardableResult
    func createGroup(from axElement: AXUIElement) -> TabGroup? {
        guard let windowID = axElement.getWindowID(),
              let pid = axElement.getOwnerPID() else {
            print("AppMux: Could not get window ID or PID")
            return nil
        }

        // Check if already in a group
        guard windowToGroup[windowID] == nil else {
            print("AppMux: Window already in a group")
            return nil
        }

        let managedWindow = ManagedWindow(axElement: axElement, windowID: windowID, ownerPID: pid)
        let group = TabGroup(initialWindow: managedWindow)

        // Start observing this window
        WindowObserverService.shared.observe(window: managedWindow)

        // Track the window
        windowToGroup[windowID] = group.id
        groups.append(group)

        // Create and show the tab bar panel
        let panel = TabBarPanel(group: group)
        tabBarPanels[group.id] = panel
        panel.orderFront(nil)

        // Layout the group
        layoutGroup(group)

        print("AppMux: Created group with window '\(managedWindow.title)'")
        return group
    }

    /// Adds a window to an existing group.
    func addWindow(_ axElement: AXUIElement, to group: TabGroup) {
        guard let windowID = axElement.getWindowID(),
              let pid = axElement.getOwnerPID() else {
            return
        }

        // Check if already in a group
        guard windowToGroup[windowID] == nil else {
            print("AppMux: Window already in a group")
            return
        }

        let managedWindow = ManagedWindow(axElement: axElement, windowID: windowID, ownerPID: pid)

        // Hide the window (it's not the active tab)
        try? axElement.minimize()

        // Start observing
        WindowObserverService.shared.observe(window: managedWindow)

        // Add to group
        group.tabs.append(managedWindow)
        windowToGroup[windowID] = group.id

        // Update the tab bar panel
        tabBarPanels[group.id]?.refreshTabs()

        print("AppMux: Added window '\(managedWindow.title)' to group")
    }

    /// Removes a window from its group, restoring it to its original position.
    func removeWindow(windowID: CGWindowID) {
        guard let groupID = windowToGroup[windowID],
              let group = groups.first(where: { $0.id == groupID }),
              let index = group.indexOf(windowID: windowID) else {
            return
        }

        let window = group.tabs[index]

        // Stop observing
        WindowObserverService.shared.stopObserving(windowID: windowID)

        // Restore to original position
        do {
            try window.axElement.setFrame(window.originalFrame)
            try window.axElement.unminimize()
            try window.axElement.raise()
        } catch {
            print("AppMux: Failed to restore window: \(error)")
        }

        // Remove from group
        group.tabs.remove(at: index)
        windowToGroup.removeValue(forKey: windowID)

        // Adjust active tab index
        if group.tabs.isEmpty {
            dissolveGroup(group)
        } else {
            if index <= group.activeTabIndex && group.activeTabIndex > 0 {
                group.activeTabIndex -= 1
            }
            activateTab(at: group.activeTabIndex, in: group)
            tabBarPanels[group.id]?.refreshTabs()
        }

        print("AppMux: Removed window '\(window.title)' from group")
    }

    /// Switches to a different tab in the group.
    func activateTab(at index: Int, in group: TabGroup) {
        guard index >= 0 && index < group.tabs.count else { return }
        guard index != group.activeTabIndex || group.isMinimized else { return }

        // Hide the current active window
        if let current = group.activeWindow {
            try? current.axElement.minimize()
        }

        // Update active index
        group.activeTabIndex = index

        // Show and position the new active window
        if let newActive = group.activeWindow {
            do {
                try newActive.axElement.unminimize()
                try newActive.axElement.raise()
                layoutGroup(group)
            } catch {
                print("AppMux: Failed to activate tab: \(error)")
            }
        }

        // Update tab bar UI
        tabBarPanels[group.id]?.refreshTabs()
    }

    /// Minimizes a group, hiding all its windows.
    func minimizeGroup(_ group: TabGroup) {
        guard !group.isMinimized else { return }

        group.isMinimized = true

        // Hide all windows
        for tab in group.tabs {
            try? tab.axElement.minimize()
        }

        // Hide the tab bar panel
        tabBarPanels[group.id]?.orderOut(nil)

        print("AppMux: Minimized group")
    }

    /// Restores a minimized group.
    func restoreGroup(_ group: TabGroup) {
        guard group.isMinimized else { return }

        group.isMinimized = false

        // Show the tab bar panel
        tabBarPanels[group.id]?.orderFront(nil)

        // Show only the active window
        if let active = group.activeWindow {
            do {
                try active.axElement.unminimize()
                try active.axElement.raise()
                layoutGroup(group)
            } catch {
                print("AppMux: Failed to restore group: \(error)")
            }
        }

        print("AppMux: Restored group")
    }

    /// Dissolves a group, restoring all windows to their original positions.
    func dissolveGroup(_ group: TabGroup) {
        // Restore all windows
        for tab in group.tabs {
            WindowObserverService.shared.stopObserving(windowID: tab.windowID)
            windowToGroup.removeValue(forKey: tab.windowID)

            do {
                try tab.axElement.setFrame(tab.originalFrame)
                try tab.axElement.unminimize()
            } catch {
                print("AppMux: Failed to restore window during dissolve: \(error)")
            }
        }

        // Close the tab bar panel
        tabBarPanels[group.id]?.close()
        tabBarPanels.removeValue(forKey: group.id)

        // Remove from groups list
        groups.removeAll { $0.id == group.id }

        print("AppMux: Dissolved group")
    }

    /// Dissolves all groups (called on app quit).
    func dissolveAllGroups() {
        for group in groups {
            dissolveGroup(group)
        }
    }

    // MARK: - Layout

    /// Positions the tab bar and active window for a group.
    /// The group stores the window frame in AX coordinates (origin top-left).
    /// We convert to Cocoa coordinates for the NSPanel.
    func layoutGroup(_ group: TabGroup) {
        guard let panel = tabBarPanels[group.id],
              let active = group.activeWindow else { return }

        // group.frame stores the AX frame of the window (origin top-left, y increases down)
        let axWindowFrame = group.frame

        // Tab bar should be positioned directly above the window
        // In AX coords: tab bar Y = window Y - tabBarHeight (above the window)
        // Convert to Cocoa coords for NSPanel
        let tabBarCocoaY = axYToCocoaY(axWindowFrame.origin.y - TabGroup.tabBarHeight, height: TabGroup.tabBarHeight)

        let panelFrame = NSRect(
            x: axWindowFrame.origin.x,
            y: tabBarCocoaY,
            width: axWindowFrame.width,
            height: TabGroup.tabBarHeight
        )
        panel.setFrame(panelFrame, display: true)

        // The window position stays in AX coordinates (no conversion needed for AXUIElement)
        // The window should be at its stored position
        let windowFrame = CGRect(
            x: axWindowFrame.origin.x,
            y: axWindowFrame.origin.y,
            width: axWindowFrame.width,
            height: active.originalFrame.height
        )
        try? active.axElement.setFrame(windowFrame)
    }

    /// Updates the group frame when the tab bar is moved (by user dragging).
    /// The NSPanel gives us Cocoa coordinates, we convert back to AX.
    func updateGroupFrame(_ group: TabGroup, panelFrame: NSRect) {
        // Convert panel's Cocoa Y to AX coordinates
        // The panel is at the top, so the window's AX Y is below it
        let axTabBarY = cocoaYToAxY(panelFrame.origin.y, height: panelFrame.height)

        // The window's top edge is at the bottom of the tab bar
        // In AX coords (y increases down): window Y = tabBar Y + tabBarHeight
        let axWindowY = axTabBarY + TabGroup.tabBarHeight

        group.frame = CGRect(
            x: panelFrame.origin.x,
            y: axWindowY,
            width: panelFrame.width,
            height: group.activeWindow?.originalFrame.height ?? group.frame.height
        )

        // Reposition the window to match the new tab bar position
        if let active = group.activeWindow {
            let windowFrame = CGRect(
                x: group.frame.origin.x,
                y: group.frame.origin.y,
                width: group.frame.width,
                height: active.originalFrame.height
            )
            try? active.axElement.setFrame(windowFrame)
        }
    }

    // MARK: - Queries

    /// Finds the group containing a window.
    func findGroup(containing windowID: CGWindowID) -> TabGroup? {
        guard let groupID = windowToGroup[windowID] else { return nil }
        return groups.first { $0.id == groupID }
    }

    /// Checks if any group contains the given window.
    func isWindowInGroup(_ windowID: CGWindowID) -> Bool {
        windowToGroup[windowID] != nil
    }

    // MARK: - WindowObserverDelegate

    func windowWasDestroyed(windowID: CGWindowID) {
        // Remove the window from its group
        removeWindow(windowID: windowID)
    }

    func windowWasMoved(windowID: CGWindowID) {
        // If the active window is moved externally, update the group frame and tab bar
        guard let group = findGroup(containing: windowID),
              group.activeWindow?.windowID == windowID else { return }

        guard let active = group.activeWindow else { return }

        // Register for high-frequency tracking (timer-based polling during drags)
        WindowDragTracker.shared.registerWindow(windowID: windowID, element: active.axElement)

        // Also do an immediate update for the initial notification
        if let newFrame = try? active.axElement.getFrame() {
            handleSmoothFrameUpdate(windowID: windowID, newFrame: newFrame)
        }
    }

    func windowWasResized(windowID: CGWindowID) {
        // Similar to moved - update group frame if active window resized
        windowWasMoved(windowID: windowID)
    }

    func windowTitleChanged(windowID: CGWindowID, newTitle: String) {
        guard let group = findGroup(containing: windowID),
              let index = group.indexOf(windowID: windowID) else { return }

        group.tabs[index].title = newTitle
        tabBarPanels[group.id]?.refreshTabs()
    }
}
