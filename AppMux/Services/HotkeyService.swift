import HotKey
import AppKit

/// Service for managing global keyboard shortcuts.
/// Registers the group creation hotkey (⌃⌥⌘⇧+G) that works
/// even when other applications are focused.
final class HotkeyService {
    private var groupHotkey: HotKey?

    /// Registers the global hotkey for creating window groups.
    func register() {
        // Control + Option + Command + Shift + G
        groupHotkey = HotKey(key: .g, modifiers: [.control, .option, .command, .shift])
        groupHotkey?.keyDownHandler = { [weak self] in
            self?.handleGroupHotkey()
        }
    }

    /// Unregisters all hotkeys.
    func unregister() {
        groupHotkey = nil
    }

    private func handleGroupHotkey() {
        // Check accessibility permissions first
        guard AccessibilityService.shared.isAccessibilityEnabled else {
            AccessibilityService.shared.requestAccessibility()
            return
        }

        // Get the frontmost application
        guard let app = AccessibilityService.shared.getFrontmostApplication() else {
            print("AppMux: No frontmost application")
            return
        }

        // Get the focused window
        guard let focusedWindow = AccessibilityService.shared.getFocusedWindow(of: app) else {
            print("AppMux: No focused window")
            return
        }

        // Don't group fullscreen windows
        if focusedWindow.isFullscreen {
            print("AppMux: Cannot group fullscreen window")
            return
        }

        // Check if window is already in a group
        if let windowID = focusedWindow.getWindowID(),
           WindowManagerService.shared.findGroup(containing: windowID) != nil {
            print("AppMux: Window already in a group")
            return
        }

        // Create a new group with this window
        WindowManagerService.shared.createGroup(from: focusedWindow)
    }
}
