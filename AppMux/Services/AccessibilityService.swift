import ApplicationServices
import AppKit

/// Service for managing Accessibility API permissions and providing
/// a high-level interface for checking accessibility state.
final class AccessibilityService {
    static let shared = AccessibilityService()

    private init() {}

    /// Returns true if the app has been granted accessibility permissions.
    /// This is required to manipulate windows from other applications.
    var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant accessibility permissions.
    /// This shows the system dialog that directs users to System Settings.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings directly to the Accessibility privacy pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Returns the AXUIElement for the frontmost application.
    func getFrontmostApplication() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    /// Returns the focused window of a given application.
    func getFocusedWindow(of app: AXUIElement) -> AXUIElement? {
        var focusedWindowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)
        guard result == .success else { return nil }
        return (focusedWindowRef as! AXUIElement)
    }

    /// Returns all windows of a given application.
    func getWindows(of app: AXUIElement) -> [AXUIElement] {
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success, let windows = windowsRef as? [AXUIElement] else { return [] }
        return windows
    }
}
