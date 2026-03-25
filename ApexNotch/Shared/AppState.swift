import SwiftUI

@Observable
@MainActor
final class AppState {
    var currentSignal: AppSignal = .idle
    var projects: [ProjectGroup] = []
    var isRefreshing: Bool = false
    var agentSession: AgentSession? = nil
    var usageSnapshot: UsageSnapshot? = nil
    var repoStatus: RepoStatus? = nil
    var isNotchExpanded: Bool = false
    var githubRepoInfo: GitHubRepoInfo? = nil
    var isGitHubAuthenticated: Bool = false

    let effectSettings = EffectSettings()

    private let processMonitor = ProcessMonitorService()
    private let agentService = AIAgentService()
    private let usageService = AIUsageService()
    private let gitRepoService = GitRepoService()
    private let gitHubService = GitHubService()

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

        // Start git repo service
        await gitRepoService.setCallback { [weak self] (status: RepoStatus?) async in
            await MainActor.run { self?.repoStatus = status }
        }
        await gitRepoService.start()

        // Start GitHub service
        isGitHubAuthenticated = await gitHubService.isAuthenticated
        await gitHubService.setCallback { [weak self] info in
            Task { @MainActor [weak self] in
                self?.githubRepoInfo = info
            }
        }
        if isGitHubAuthenticated {
            let repoStatusProvider: @Sendable () -> RepoStatus? = { [weak self] in
                // Access from MainActor - we capture a snapshot
                // This closure is called from GitHubService actor, so we need a nonisolated way
                // We'll return nil here; the actual refresh uses refreshGitHub()
                nil
            }
            await gitHubService.start(repoStatusProvider: repoStatusProvider)
            // Trigger an immediate refresh with real repoStatus
            await refreshGitHub()
        }
    }

    func refreshGitHub() async {
        let currentStatus = repoStatus
        await gitHubService.refresh(repoStatusProvider: { currentStatus })
        isGitHubAuthenticated = await gitHubService.isAuthenticated
    }

    func connectGitHub(token: String) async {
        await gitHubService.saveToken(token)
        isGitHubAuthenticated = true
        await refreshGitHub()
        // Also start polling
        let currentStatus = repoStatus
        await gitHubService.start(repoStatusProvider: { currentStatus })
    }

    func disconnectGitHub() async {
        await gitHubService.deleteToken()
        await gitHubService.stop()
        isGitHubAuthenticated = false
        githubRepoInfo = nil
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
            await gitRepoService.stop()
            await gitHubService.stop()
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
