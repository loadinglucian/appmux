import AppKit
import SwiftUI

/// A floating panel that displays the tab bar for a window group.
/// This panel floats above normal windows and doesn't steal focus
/// from the applications being managed.
final class TabBarPanel: NSPanel {
    private let group: TabGroup
    private var hostingView: NSHostingView<TabBarView>?

    init(group: TabGroup) {
        self.group = group

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: TabGroup.tabBarHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        setupContent()
    }

    private func configurePanel() {
        // Float above normal windows
        level = .floating

        // Don't become key window (keeps target app focused)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true

        // Visual styling
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Allow dragging to move
        isMovableByWindowBackground = true

        // Collection behavior
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Don't show in Exposé or app switcher
        hidesOnDeactivate = false
    }

    deinit {
        dragTimer?.invalidate()
    }

    private func setupContent() {
        let tabBarView = TabBarView(group: group)
        hostingView = NSHostingView(rootView: tabBarView)
        hostingView?.translatesAutoresizingMaskIntoConstraints = false

        contentView = hostingView
    }

    /// Updates the tab bar content when tabs change.
    func refreshTabs() {
        // SwiftUI will automatically update via @Observable
        // But we can force a refresh if needed
        hostingView?.needsDisplay = true
    }

    // MARK: - Drag Tracking

    /// Timer for high-frequency window updates during tab bar drag.
    private var dragTimer: Timer?

    /// Starts tracking panel position to update window during drag.
    private func startDragTracking() {
        guard dragTimer == nil else { return }

        // Poll at 120Hz for smooth window following
        dragTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.syncWindowToPanel()
        }

        // Add to common modes so it fires during drag
        if let timer = dragTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Stops drag tracking.
    private func stopDragTracking() {
        dragTimer?.invalidate()
        dragTimer = nil
    }

    /// Updates the window position to match the panel.
    private func syncWindowToPanel() {
        WindowManagerService.shared.updateGroupFrame(group, panelFrame: frame)
    }

    // MARK: - NSWindow Overrides

    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        startDragTracking()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        stopDragTracking()

        // Final sync to ensure perfect alignment
        WindowManagerService.shared.updateGroupFrame(group, panelFrame: frame)
    }
}
