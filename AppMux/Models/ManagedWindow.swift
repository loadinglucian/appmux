import ApplicationServices
import AppKit
import CoreGraphics

/// Represents a window from another application that has been added to a group.
/// Stores the accessibility element reference, metadata, and the original frame
/// for restoration when the window is ungrouped.
struct ManagedWindow: Identifiable, Equatable {
    let id: UUID
    let axElement: AXUIElement
    let windowID: CGWindowID
    let ownerPID: pid_t
    var title: String
    var appName: String
    var appIcon: NSImage?
    var originalFrame: CGRect

    init(axElement: AXUIElement, windowID: CGWindowID, ownerPID: pid_t) {
        self.id = UUID()
        self.axElement = axElement
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.title = axElement.getTitle() ?? "Untitled"
        self.originalFrame = (try? axElement.getFrame()) ?? .zero

        // Get app name and icon from the running application
        if let app = NSRunningApplication(processIdentifier: ownerPID) {
            self.appName = app.localizedName ?? "Unknown"
            self.appIcon = app.icon
        } else {
            self.appName = "Unknown"
            self.appIcon = nil
        }
    }

    /// Updates the title from the current window state.
    mutating func refreshTitle() {
        self.title = axElement.getTitle() ?? self.title
    }

    /// Updates the cached icon from the running application.
    mutating func refreshIcon() {
        if let app = NSRunningApplication(processIdentifier: ownerPID) {
            self.appIcon = app.icon
        }
    }

    static func == (lhs: ManagedWindow, rhs: ManagedWindow) -> Bool {
        lhs.id == rhs.id
    }
}
