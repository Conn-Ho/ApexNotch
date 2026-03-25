import Foundation

// MARK: - AIAgentService

actor AIAgentService {

    private let logWatcher = ClaudeLogWatcher()
    private var sessionStarted: Date = Date()
    private var lastActivity: Date = Date()
    private var recentTools: [ToolCall] = []
    private var totalTokens: Int = 0
    private var isRunning = false

    // AsyncStream continuation for publishing session updates
    private var continuation: AsyncStream<AgentSession?>.Continuation?
    private var stream: AsyncStream<AgentSession?>?

    // Stall detection: > 3 minutes since last activity while claude process exists
    private static let stallInterval: TimeInterval = 180

    // MARK: - Public API

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Set up log watcher callback
        await logWatcher.startWatching()
        let capturedSelf = self
        await logWatcher.setOnUpdate { tools, tokens, date in
            Task {
                await capturedSelf.handleLogUpdate(tools: tools, tokens: tokens, lastActivity: date)
            }
        }

        // Polling loop for stall detection and periodic refresh
        Task {
            while await self.isRunning {
                await self.refreshSession()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        isRunning = false
        Task { await logWatcher.stopWatching() }
        continuation?.finish()
        continuation = nil
    }

    func getSession() async -> AgentSession? {
        return await buildSession()
    }

    /// Returns an AsyncStream that emits whenever the agent session state changes.
    func sessionStream() -> AsyncStream<AgentSession?> {
        if let existing = stream {
            return existing
        }
        let (newStream, cont) = AsyncStream<AgentSession?>.makeStream()
        self.stream = newStream
        self.continuation = cont
        return newStream
    }

    // MARK: - Internal

    private func handleLogUpdate(tools: [ToolCall], tokens: Int, lastActivity date: Date) {
        recentTools = tools
        totalTokens = tokens
        if date > lastActivity {
            lastActivity = date
        }
        publishUpdate()
    }

    private func refreshSession() async {
        let claudeRunning = await isClaudeProcessRunning()
        if !claudeRunning && recentTools.isEmpty {
            // No session
            continuation?.yield(nil)
            return
        }
        publishUpdate()
    }

    private func publishUpdate() {
        let session = buildSessionSync()
        continuation?.yield(session)
    }

    private func buildSession() async -> AgentSession? {
        let claudeRunning = await isClaudeProcessRunning()
        guard claudeRunning || !recentTools.isEmpty else { return nil }
        return buildSessionSync()
    }

    private func buildSessionSync() -> AgentSession? {
        guard !recentTools.isEmpty || totalTokens > 0 else { return nil }

        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastActivity)
        let stalled = timeSinceLast > Self.stallInterval

        let state: AgentState
        if stalled {
            state = .stalled
        } else if timeSinceLast < 90 {
            state = .active
        } else {
            state = .idle
        }

        // Build current tool: a running call if last activity < 30s ago
        var currentTool: ToolCall? = nil
        if state == .active, let last = recentTools.last, last.status == .running {
            currentTool = last
        }

        // Recent 6 completed/failed calls
        let recent = recentTools
            .filter { $0.status != .running }
            .suffix(6)
            .reversed()
            .map { $0 }

        return AgentSession(
            source: .claudeCode,
            state: state,
            currentTool: currentTool,
            recentTools: Array(recent),
            totalTokens: totalTokens,
            sessionStarted: sessionStarted
        )
    }

    private func isClaudeProcessRunning() async -> Bool {
        let output = await ShellRunner.run(#"pgrep -f "claude" | head -1"#)
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - ClaudeLogWatcher callback bridge

extension ClaudeLogWatcher {
    func setOnUpdate(_ callback: @escaping @Sendable ([ToolCall], Int, Date) -> Void) {
        onUpdate = callback
    }
}
