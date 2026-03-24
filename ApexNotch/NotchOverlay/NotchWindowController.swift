import AppKit
import SwiftUI

// MARK: - NotchWindowController
// Creates a full-screen-width, 38pt-tall (expandable) window pinned to the top of the
// main display. The window lives above the menu bar and is transparent in the center
// (camera notch area), showing only the left/right wings.

@MainActor
final class NotchWindowController {

    private var window: NSWindow?
    private let appState: AppState

    /// Current window height — updated when the SwiftUI view expands.
    private var currentHeight: CGFloat = 38
    private let barHeight:     CGFloat = 38
    private let expandedHeight: CGFloat = 240   // bar + panel

    /// Global mouse-moved monitor (non-local, for tracking while other apps are active).
    private var mouseMonitor: Any?

    /// Delay before collapsing after mouse leaves the notch zone.
    private var collapseWorkItem: DispatchWorkItem?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    func show() {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0 else { return }  // notch screen only

        let frame = makeWindowFrame(screen: screen, height: barHeight)

        let win = NSWindow(
            contentRect: frame,
            styleMask:   .borderless,
            backing:     .buffered,
            defer:       false,
            screen:      screen
        )
        win.level           = .statusBar   // above menu bar
        win.backgroundColor = .clear
        win.isOpaque        = false
        win.hasShadow       = false
        win.ignoresMouseEvents = false     // we need clicks / hover for expansion
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.isReleasedWhenClosed = false

        let rootView = NotchOverlayView(appState: appState)
        win.contentView = NSHostingView(rootView: rootView)

        win.orderFrontRegardless()
        self.window = win

        startHoverTracking()
    }

    func updateHeight(_ height: CGFloat) {
        guard let window, let screen = NSScreen.main else { return }
        currentHeight = height
        let newFrame = makeWindowFrame(screen: screen, height: height)
        window.setFrame(newFrame, display: true, animate: false)
    }

    // MARK: - Window Frame

    private func makeWindowFrame(screen: NSScreen, height: CGFloat) -> NSRect {
        let screenFrame = screen.frame
        return NSRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - height,
            width: screenFrame.width,
            height: height
        )
    }

    // MARK: - Hover Tracking
    // Use a global mouse-moved event monitor so we detect mouse position
    // regardless of which application has focus.

    private func startHoverTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMoved(event: event)
            }
        }
    }

    private func stopHoverTracking() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func handleMouseMoved(event: NSEvent) {
        guard let screen = NSScreen.main, let window else { return }
        // Convert global mouse location to screen coordinates
        let mouse = NSEvent.mouseLocation
        let notchZone = notchHoverRect(screen: screen)

        if notchZone.contains(mouse) {
            // Cancel any pending collapse
            collapseWorkItem?.cancel()
            collapseWorkItem = nil

            if currentHeight < expandedHeight {
                expandWindow()
            }
        } else if window.frame.contains(mouse) {
            // Mouse is inside the window frame but outside the notch zone
            // (could be over a wing) — keep expanded
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
        } else {
            // Mouse left the notch / wing area — schedule collapse
            scheduleCollapse()
        }
    }

    private func notchHoverRect(screen: NSScreen) -> NSRect {
        // The camera notch is roughly centered, ~250pt wide × top 38pt of screen
        let cx = screen.frame.midX
        let notchWidth: CGFloat = 300
        let hitHeight: CGFloat  = currentHeight + 20  // small margin
        return NSRect(
            x: cx - notchWidth / 2,
            y: screen.frame.maxY - hitHeight,
            width: notchWidth,
            height: hitHeight
        )
    }

    // MARK: - Expand / Collapse

    private func expandWindow() {
        guard let screen = NSScreen.main else { return }
        currentHeight = expandedHeight
        let newFrame = makeWindowFrame(screen: screen, height: expandedHeight)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.30
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().setFrame(newFrame, display: true)
        }
    }

    private func scheduleCollapse() {
        guard collapseWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.collapseWindow()
                self?.collapseWorkItem = nil
            }
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    private func collapseWindow() {
        guard let screen = NSScreen.main else { return }
        currentHeight = barHeight
        let newFrame = makeWindowFrame(screen: screen, height: barHeight)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().setFrame(newFrame, display: true)
        }
    }

}
