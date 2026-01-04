import ApplicationServices
import CoreGraphics

/// Errors that can occur when manipulating windows via the Accessibility API.
enum WindowAccessibilityError: Error {
    case cannotGetAttribute(String)
    case cannotSetAttribute(String)
    case cannotPerformAction(String)
    case invalidValue
}

/// Private API declaration for getting CGWindowID from AXUIElement.
/// This bridges the gap between CGWindowList (which enumerates windows) and
/// AXUIElement (which can manipulate them).
/// Returns the system AXError type from ApplicationServices.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

extension AXUIElement {

    // MARK: - Position

    /// Gets the current position of the window.
    func getPosition() throws -> CGPoint {
        var positionRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, kAXPositionAttribute as CFString, &positionRef)
        guard result == .success else {
            throw WindowAccessibilityError.cannotGetAttribute("position")
        }

        var position = CGPoint.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position) else {
            throw WindowAccessibilityError.invalidValue
        }
        return position
    }

    /// Sets the position of the window.
    func setPosition(_ point: CGPoint) throws {
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else {
            throw WindowAccessibilityError.invalidValue
        }
        let result = AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, value)
        guard result == .success else {
            throw WindowAccessibilityError.cannotSetAttribute("position")
        }
    }

    // MARK: - Size

    /// Gets the current size of the window.
    func getSize() throws -> CGSize {
        var sizeRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, kAXSizeAttribute as CFString, &sizeRef)
        guard result == .success else {
            throw WindowAccessibilityError.cannotGetAttribute("size")
        }

        var size = CGSize.zero
        guard AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            throw WindowAccessibilityError.invalidValue
        }
        return size
    }

    /// Sets the size of the window.
    func setSize(_ size: CGSize) throws {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else {
            throw WindowAccessibilityError.invalidValue
        }
        let result = AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, value)
        guard result == .success else {
            throw WindowAccessibilityError.cannotSetAttribute("size")
        }
    }

    // MARK: - Frame (convenience)

    /// Gets the window's frame (position + size).
    func getFrame() throws -> CGRect {
        let position = try getPosition()
        let size = try getSize()
        return CGRect(origin: position, size: size)
    }

    /// Sets the window's frame (position + size).
    func setFrame(_ frame: CGRect) throws {
        try setPosition(frame.origin)
        try setSize(frame.size)
    }

    // MARK: - Title

    /// Gets the title of the window, if available.
    func getTitle() -> String? {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &titleRef)
        guard result == .success else { return nil }
        return titleRef as? String
    }

    // MARK: - Minimize State

    /// Returns whether the window is minimized.
    var isMinimized: Bool {
        var minimizedRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, kAXMinimizedAttribute as CFString, &minimizedRef)
        guard result == .success else { return false }
        return (minimizedRef as? Bool) ?? false
    }

    /// Minimizes the window.
    func minimize() throws {
        let result = AXUIElementSetAttributeValue(self, kAXMinimizedAttribute as CFString, true as CFTypeRef)
        guard result == .success else {
            throw WindowAccessibilityError.cannotSetAttribute("minimized")
        }
    }

    /// Unminimizes (restores) the window.
    func unminimize() throws {
        let result = AXUIElementSetAttributeValue(self, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        guard result == .success else {
            throw WindowAccessibilityError.cannotSetAttribute("minimized")
        }
    }

    // MARK: - Visibility

    /// Hides the window by setting its alpha to 0 (for quick hiding without minimize animation).
    /// Note: This uses a private attribute and may not work on all windows.
    func hide() throws {
        // We use minimize instead as it's more reliable
        try minimize()
    }

    /// Shows the window by unminimizing it.
    func show() throws {
        try unminimize()
    }

    // MARK: - Actions

    /// Raises the window to the front of the window stack.
    func raise() throws {
        let result = AXUIElementPerformAction(self, kAXRaiseAction as CFString)
        guard result == .success else {
            throw WindowAccessibilityError.cannotPerformAction("raise")
        }
    }

    // MARK: - Fullscreen State

    /// Returns whether the window is in fullscreen mode.
    var isFullscreen: Bool {
        var fullscreenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, "AXFullScreen" as CFString, &fullscreenRef)
        guard result == .success else { return false }
        return (fullscreenRef as? Bool) ?? false
    }

    // MARK: - Window ID

    /// Gets the CGWindowID for this AXUIElement using the private API.
    /// This is needed to correlate with CGWindowListCopyWindowInfo results.
    func getWindowID() -> CGWindowID? {
        var windowID: CGWindowID = 0
        let result: AXError = _AXUIElementGetWindow(self, &windowID)
        guard result == .success else { return nil }
        return windowID
    }

    // MARK: - Owner PID

    /// Gets the process ID of the application that owns this element.
    func getOwnerPID() -> pid_t? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(self, &pid)
        guard result == .success else { return nil }
        return pid
    }
}
