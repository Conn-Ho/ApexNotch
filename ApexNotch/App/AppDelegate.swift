import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var notchWindowController: NotchWindowController?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController(appState: appState)
        notchWindowController = NotchWindowController(appState: appState)
        notchWindowController?.show()
        Task { await appState.startAll() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stopAll()
    }
}
