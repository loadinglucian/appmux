import AppKit
import ApplicationServices
import CoreGraphics

/// Service for detecting window drag operations and enabling drop-to-group functionality.
/// Monitors global mouse events to detect when a window is being dragged near a tab bar.
@MainActor
final class DragDropService {
    static let shared = DragDropService()

    /// The currently detected draggable window (if any)
    private(set) var potentialDropWindow: AXUIElement?
    private(set) var potentialDropWindowID: CGWindowID?

    /// Callback when a valid drop target is detected
    var onDropTargetChanged: ((TabGroup?, CGWindowID?) -> Void)?

    private var mouseMonitor: Any?
    private var isDragging = false
    private var dragStartPoint: CGPoint?

    private init() {}

    /// Starts monitoring for drag operations.
    func startMonitoring() {
        guard mouseMonitor == nil else { return }

        // Monitor global mouse events
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseEvent(event)
            }
        }
    }

    /// Stops monitoring for drag operations.
    func stopMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDragged:
            handleDrag(at: NSEvent.mouseLocation)
        case .leftMouseUp:
            handleDrop(at: NSEvent.mouseLocation)
        default:
            break
        }
    }

    private func handleDrag(at screenPoint: NSPoint) {
        // Convert Cocoa screen coordinates to AX coordinates for window detection
        guard let screenHeight = NSScreen.main?.frame.height else { return }
        let axPoint = CGPoint(x: screenPoint.x, y: screenHeight - screenPoint.y)

        // Check if we're over any tab bar panel
        let targetGroup = findTabBarGroup(at: screenPoint)

        // Find the window being dragged (window under cursor that's not in a group)
        if let (windowID, axElement) = findDraggableWindow(at: axPoint) {
            potentialDropWindow = axElement
            potentialDropWindowID = windowID
            isDragging = true

            // Notify about potential drop target
            onDropTargetChanged?(targetGroup, windowID)
        } else if isDragging {
            // Still dragging but no valid window found
            onDropTargetChanged?(targetGroup, potentialDropWindowID)
        }
    }

    private func handleDrop(at screenPoint: NSPoint) {
        defer {
            // Reset state
            isDragging = false
            potentialDropWindow = nil
            potentialDropWindowID = nil
            onDropTargetChanged?(nil, nil)
        }

        guard isDragging,
              let windowID = potentialDropWindowID,
              let axElement = potentialDropWindow else { return }

        // Check if dropped over a tab bar
        guard let targetGroup = findTabBarGroup(at: screenPoint) else { return }

        // Don't add if already in this group
        guard !targetGroup.contains(windowID: windowID) else { return }

        // Add the window to the group
        WindowManagerService.shared.addWindow(axElement, to: targetGroup)
    }

    /// Finds the tab bar panel (and its group) at the given screen point (Cocoa coordinates).
    private func findTabBarGroup(at point: NSPoint) -> TabGroup? {
        for group in WindowManagerService.shared.groups {
            // Get the tab bar panel frame (in Cocoa coordinates)
            // The panel is stored in WindowManagerService, but we can check by coordinate
            // Convert group frame (AX) to Cocoa to compare
            guard let screenHeight = NSScreen.main?.frame.height else { continue }

            let tabBarCocoaY = screenHeight - (group.frame.origin.y - TabGroup.tabBarHeight) - TabGroup.tabBarHeight
            let tabBarFrame = NSRect(
                x: group.frame.origin.x,
                y: tabBarCocoaY,
                width: group.frame.width,
                height: TabGroup.tabBarHeight + 20 // Add some padding for easier drops
            )

            if tabBarFrame.contains(point) {
                return group
            }
        }
        return nil
    }

    /// Finds a draggable window at the given point (AX coordinates).
    /// Returns nil if the window is already in a group or is our own window.
    private func findDraggableWindow(at point: CGPoint) -> (CGWindowID, AXUIElement)? {
        // Get all windows at this point using CGWindowList
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Only consider normal windows (layer 0)
            guard layer == 0 else { continue }

            // Skip our own app's windows
            if ownerPID == ProcessInfo.processInfo.processIdentifier {
                continue
            }

            // Skip windows already in a group
            if WindowManagerService.shared.isWindowInGroup(windowID) {
                continue
            }

            // Check if point is within this window's bounds
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            if bounds.contains(point) {
                // Get the AXUIElement for this window
                if let axElement = axElement(for: windowID, pid: ownerPID) {
                    return (windowID, axElement)
                }
            }
        }

        return nil
    }

    /// Gets the AXUIElement for a window given its ID and owner PID.
    private func axElement(for windowID: CGWindowID, pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        let windows = AccessibilityService.shared.getWindows(of: app)

        for window in windows {
            if window.getWindowID() == windowID {
                return window
            }
        }

        return nil
    }
}
