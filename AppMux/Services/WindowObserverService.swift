import ApplicationServices
import AppKit

/// Protocol for receiving window observation events.
@MainActor
protocol WindowObserverDelegate: AnyObject {
    func windowWasDestroyed(windowID: CGWindowID)
    func windowWasMoved(windowID: CGWindowID)
    func windowWasResized(windowID: CGWindowID)
    func windowTitleChanged(windowID: CGWindowID, newTitle: String)
}

/// Service for observing changes to windows in groups.
/// Uses AXObserver to detect when windows are closed, moved, resized, or renamed.
final class WindowObserverService {
    static let shared = WindowObserverService()

    @MainActor weak var delegate: WindowObserverDelegate?

    /// Maps window IDs to their observers for cleanup.
    private var observers: [CGWindowID: AXObserver] = [:]
    /// Maps window IDs to their AXUIElements for event handling.
    private var elements: [CGWindowID: AXUIElement] = [:]

    private init() {
        // Also observe app termination
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    /// Starts observing a window for changes.
    func observe(window: ManagedWindow) {
        guard observers[window.windowID] == nil else { return }

        let pid = window.ownerPID
        var observer: AXObserver?

        // Create the observer
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            guard let refcon = refcon else { return }
            let service = Unmanaged<WindowObserverService>.fromOpaque(refcon).takeUnretainedValue()
            service.handleNotification(notification as String, for: element)
        }

        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success, let observer = observer else {
            print("AppMux: Failed to create observer for window \(window.windowID)")
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        // Register for notifications
        let notifications: [String] = [
            kAXUIElementDestroyedNotification as String,
            kAXMovedNotification as String,
            kAXResizedNotification as String,
            kAXTitleChangedNotification as String
        ]

        for notification in notifications {
            AXObserverAddNotification(observer, window.axElement, notification as CFString, refcon)
        }

        // Add to run loop
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers[window.windowID] = observer
        elements[window.windowID] = window.axElement
    }

    /// Stops observing a window.
    func stopObserving(windowID: CGWindowID) {
        guard let observer = observers[windowID],
              let element = elements[windowID] else { return }

        // Remove notifications
        let notifications: [String] = [
            kAXUIElementDestroyedNotification as String,
            kAXMovedNotification as String,
            kAXResizedNotification as String,
            kAXTitleChangedNotification as String
        ]

        for notification in notifications {
            AXObserverRemoveNotification(observer, element, notification as CFString)
        }

        // Remove from run loop
        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers.removeValue(forKey: windowID)
        elements.removeValue(forKey: windowID)
    }

    /// Stops observing all windows.
    func stopObservingAll() {
        for windowID in observers.keys {
            stopObserving(windowID: windowID)
        }
    }

    private func handleNotification(_ notification: String, for element: AXUIElement) {
        // Find the window ID for this element
        guard let windowID = element.getWindowID() else { return }

        switch notification {
        case kAXUIElementDestroyedNotification as String:
            stopObserving(windowID: windowID)
            Task { @MainActor [weak self] in
                self?.delegate?.windowWasDestroyed(windowID: windowID)
            }

        case kAXMovedNotification as String:
            Task { @MainActor [weak self] in
                self?.delegate?.windowWasMoved(windowID: windowID)
            }

        case kAXResizedNotification as String:
            Task { @MainActor [weak self] in
                self?.delegate?.windowWasResized(windowID: windowID)
            }

        case kAXTitleChangedNotification as String:
            let newTitle = element.getTitle() ?? ""
            Task { @MainActor [weak self] in
                self?.delegate?.windowTitleChanged(windowID: windowID, newTitle: newTitle)
            }

        default:
            break
        }
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let pid = app.processIdentifier

        // Find and remove all windows from this app
        for (windowID, element) in elements {
            if element.getOwnerPID() == pid {
                stopObserving(windowID: windowID)
                Task { @MainActor [weak self] in
                    self?.delegate?.windowWasDestroyed(windowID: windowID)
                }
            }
        }
    }
}
