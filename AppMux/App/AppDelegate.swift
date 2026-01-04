import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions on launch
        if !AccessibilityService.shared.isAccessibilityEnabled {
            AccessibilityService.shared.requestAccessibility()
        }

        // Register global hotkey
        hotkeyService = HotkeyService()
        hotkeyService?.register()

        // Start drag & drop monitoring
        DragDropService.shared.startMonitoring()
        DragDropService.shared.onDropTargetChanged = { targetGroup, windowID in
            // Post notification for UI updates
            NotificationCenter.default.post(
                name: .dropTargetChanged,
                object: nil,
                userInfo: [
                    "groupID": targetGroup?.id as Any,
                    "windowID": windowID as Any
                ]
            )
        }

        // Configure app to stay running when all windows are closed (menu bar app)
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running for menu bar access
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop monitoring
        DragDropService.shared.stopMonitoring()

        // Clean up all window groups, restoring windows to original positions
        WindowManagerService.shared.dissolveAllGroups()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dropTargetChanged = Notification.Name("AppMux.dropTargetChanged")
}
