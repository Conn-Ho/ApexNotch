import SwiftUI

@Observable
@MainActor
final class AppState {
    var currentSignal: AppSignal = .idle
    var projects: [ProjectGroup] = []
    var isRefreshing: Bool = false
    var agentSession: AgentSession? = nil
    var usageSnapshot: UsageSnapshot? = nil

    private let processMonitor = ProcessMonitorService()
    private let agentService = AIAgentService()
    private let usageService = AIUsageService()

    private var refreshTask: Task<Void, Never>?
    private var agentTask: Task<Void, Never>?
    private var usageTask: Task<Void, Never>?

    func startAll() async {
        // Start process monitor loop
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }

        // Start AI agent service and observe updates
        await agentService.start()
        let agentStream = await agentService.sessionStream()
        agentTask = Task { [weak self] in
            for await session in agentStream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self else { return }
                    self.agentSession = session
                    if let session {
                        switch session.state {
                        case .active:
                            if let tool = session.currentTool {
                                self.emit(.agentActive(toolName: tool.toolName))
                            } else {
                                self.emit(.agentActive(toolName: "thinking"))
                            }
                        case .stalled:
                            self.emit(.agentStalled)
                        case .idle:
                            self.emit(.idle)
                        }
                    } else {
                        self.emit(.idle)
                    }
                }
            }
        }

        // Start usage service and observe updates
        await usageService.start()
        let usageStream = await usageService.snapshotStream()
        usageTask = Task { [weak self] in
            for await snapshot in usageStream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self else { return }
                    self.usageSnapshot = snapshot
                    if let snapshot, snapshot.windowProgress > 0.8 {
                        self.emit(.quotaWarning)
                    }
                }
            }
        }
    }

    func stopAll() {
        refreshTask?.cancel()
        refreshTask = nil
        agentTask?.cancel()
        agentTask = nil
        usageTask?.cancel()
        usageTask = nil
        Task {
            await agentService.stop()
            await usageService.stop()
        }
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
        // Auto-reset transient signals to idle after 5s
        if case .processCrash = signal {
            Task {
                try? await Task.sleep(for: .seconds(5))
                if case .processCrash = self.currentSignal {
                    self.currentSignal = .idle
                }
            }
        }
        if case .fileStashed = signal {
            Task {
                try? await Task.sleep(for: .seconds(3))
                if case .fileStashed = self.currentSignal {
                    self.currentSignal = .idle
                }
            }
        }
    }
}
