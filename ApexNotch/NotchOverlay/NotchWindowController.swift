import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        let hasNotch = screen.safeAreaInsets.top > 0
        guard hasNotch else { return }

        let w: CGFloat = 260
        let h: CGFloat = 38
        let x = screen.frame.midX - w / 2
        let y = screen.frame.maxY - h

        let win = NSWindow(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.isReleasedWhenClosed = false

        let overlayView = NotchOverlayView(signal: appState.currentSignal)
        win.contentView = NSHostingView(rootView: overlayView.environmentObject(ObservableSignal(appState: appState)))
        win.orderFrontRegardless()
        self.window = win
    }
}

// Bridge to allow NotchOverlayView to observe AppState signal changes
final class ObservableSignal: ObservableObject {
    @Published var signal: AppSignal = .idle
    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
        // Poll for signal changes
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.signal = appState.currentSignal
            }
        }
    }
}
