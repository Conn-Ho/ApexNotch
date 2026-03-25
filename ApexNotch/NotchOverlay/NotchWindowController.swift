import AppKit
import SwiftUI

// MARK: - NotchWindowController
// Small NSPanel centered on the physical notch (not full-screen-width).
// Uses level = .mainMenu + 3 and isFloatingPanel = true so .onHover works
// even when other apps are in focus — same approach as AgentNotch.

@MainActor
final class NotchWindowController {

    private var panel: NSPanel?
    private let appState: AppState
    private var spaceObserver: NSObjectProtocol?

    // Window includes shadow padding so the glow has room to render
    private let shadowPadding: CGFloat = 20

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    func show() {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0 else { return }  // notch screen only

        let frame = windowFrame(for: screen)

        let p = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel          = true
        p.isOpaque                 = false
        p.titleVisibility          = .hidden
        p.titlebarAppearsTransparent = true
        p.backgroundColor          = .clear
        p.isMovable                = false
        p.level                    = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        p.hasShadow                = false
        p.isReleasedWhenClosed     = false
        p.appearance               = NSAppearance(named: .darkAqua)   // always dark
        p.collectionBehavior       = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]

        let rootView = NotchOverlayView(appState: appState)
        p.contentView = NSHostingView(rootView: rootView)
        p.orderFrontRegardless()
        self.panel = p

        // Re-order front after every Space switch so the panel never disappears.
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.panel?.orderFrontRegardless()
        }
    }

    // MARK: - Sizing helpers (called by NotchOverlayView via AppState)

    /// Full-screen-width window, short enough just for the expanded notch panel.
    /// Using full screen width (AgentNotch / DynamicNotchKit approach) avoids all
    /// centering math — the SwiftUI view centers the panel naturally on screen.
    private func windowFrame(for screen: NSScreen) -> NSRect {
        let openHeight: CGFloat = 480
        let totalH = openHeight + shadowPadding
        return NSRect(x: screen.frame.minX,
                      y: screen.frame.maxY - totalH,
                      width: screen.frame.width,
                      height: totalH)
    }
}

// MARK: - Shared notch sizing (used by both controller and view)

@MainActor
func closedNotchSize(screen: NSScreen? = nil) -> CGSize {
    let s = screen ?? NSScreen.main
    var w: CGFloat = 185
    var h: CGFloat = 32
    if let s {
        if let l = s.auxiliaryTopLeftArea?.width,
           let r = s.auxiliaryTopRightArea?.width {
            w = s.frame.width - l - r + 4   // +4 slight overlap to hide gap
        }
        if s.safeAreaInsets.top > 0 {
            h = s.safeAreaInsets.top
        }
    }
    return CGSize(width: w, height: h + 2)   // +2 overlap
}
