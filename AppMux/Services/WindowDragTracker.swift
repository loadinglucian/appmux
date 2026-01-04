import ApplicationServices
import AppKit

/// Tracks window movement with high-frequency polling for smooth tab bar updates.
/// Uses a timer on the main run loop to poll window position during drags.
@MainActor
final class WindowDragTracker {
    static let shared = WindowDragTracker()

    /// Callback invoked on each frame while tracking, with the new window frame.
    var onFrameUpdate: ((CGWindowID, CGRect) -> Void)?

    /// The window currently being tracked.
    private var trackedWindowID: CGWindowID?
    private var trackedElement: AXUIElement?

    /// Last known frame to detect actual movement.
    private var lastFrame: CGRect = .zero

    /// High-frequency timer for polling during drags.
    private var pollTimer: Timer?

    /// Tracks consecutive polls without movement to detect drag end.
    private var stationaryCount = 0
    private let stationaryThreshold = 8 // ~133ms at 60fps

    /// Whether mouse is currently down.
    private var isMouseDown = false

    /// Mouse event monitors.
    nonisolated(unsafe) private var mouseDownMonitor: Any?
    nonisolated(unsafe) private var mouseUpMonitor: Any?

    private init() {
        setupMouseMonitors()
    }

    deinit {
        pollTimer?.invalidate()
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Mouse Monitoring

    private func setupMouseMonitors() {
        // Monitor mouse down - use DispatchQueue for lower latency than Task
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isMouseDown = true
                self?.startPollingIfNeeded()
            }
        }

        // Monitor mouse up
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isMouseDown = false
            }
        }
    }

    // MARK: - Tracking Control

    /// Registers a window for potential tracking. Call when window move is detected.
    func registerWindow(windowID: CGWindowID, element: AXUIElement) {
        trackedWindowID = windowID
        trackedElement = element
        stationaryCount = 0

        if let frame = try? element.getFrame() {
            lastFrame = frame
        }

        startPollingIfNeeded()
    }

    /// Checks if a window is currently being tracked.
    func isTrackingWindow(_ windowID: CGWindowID) -> Bool {
        trackedWindowID == windowID && pollTimer != nil
    }

    private func startPollingIfNeeded() {
        guard trackedElement != nil,
              isMouseDown,
              pollTimer == nil else { return }

        // Poll at ~120Hz for smooth tracking (faster than display refresh)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.pollWindowPosition()
        }

        // Add to common run loop modes so it fires during tracking
        if let timer = pollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        trackedWindowID = nil
        trackedElement = nil
        stationaryCount = 0
    }

    private func pollWindowPosition() {
        guard let element = trackedElement,
              let windowID = trackedWindowID else {
            stopPolling()
            return
        }

        // Get current frame
        guard let currentFrame = try? element.getFrame() else {
            stopPolling()
            return
        }

        // Check if window actually moved
        if currentFrame.origin != lastFrame.origin || currentFrame.size != lastFrame.size {
            lastFrame = currentFrame
            stationaryCount = 0
            onFrameUpdate?(windowID, currentFrame)
        } else {
            stationaryCount += 1

            // Stop if stationary and mouse is up
            if stationaryCount >= stationaryThreshold && !isMouseDown {
                stopPolling()
            }
        }
    }
}
