import SwiftUI

@Observable
@MainActor
final class AppState {
    var currentSignal: AppSignal = .idle
    var projects: [ProjectGroup] = []
    var isRefreshing: Bool = false

    private let processMonitor = ProcessMonitorService()
    private var refreshTask: Task<Void, Never>?

    func startAll() async {
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopAll() {
        refreshTask?.cancel()
    }

    func refresh() async {
        isRefreshing = true
        let result = await processMonitor.scan()
        projects = result
        isRefreshing = false
    }

    func kill(pid: Int32) async {
        await processMonitor.kill(pid: pid)
        await refresh()
    }

    func killProject(_ group: ProjectGroup) async {
        for proc in group.processes {
            await processMonitor.kill(pid: proc.pid)
        }
        await refresh()
    }

    func emit(_ signal: AppSignal) {
        currentSignal = signal
        // Auto-reset to idle after transient signals
        if case .processCrash = signal {
            Task {
                try? await Task.sleep(for: .seconds(5))
                currentSignal = .idle
            }
        }
    }
}
