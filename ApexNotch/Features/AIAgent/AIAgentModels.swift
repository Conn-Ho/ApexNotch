import Foundation

// MARK: - ToolCallStatus

enum ToolCallStatus: String, Sendable {
    case running
    case completed
    case failed
}

// MARK: - ToolCall

struct ToolCall: Identifiable, Sendable {
    let id: UUID
    let toolName: String
    let arguments: String   // abbreviated / truncated for display
    let status: ToolCallStatus
    let startedAt: Date
    var endedAt: Date?

    var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }
}

// MARK: - AgentSession

struct AgentSession: Sendable {
    let source: AgentSource
    var state: AgentState
    var currentTool: ToolCall?
    var recentTools: [ToolCall]     // last 6 completed/failed calls
    var totalTokens: Int
    var sessionStarted: Date

    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStarted)
    }
}

// MARK: - AgentSource / AgentState

enum AgentSource: String, Sendable {
    case claudeCode = "Claude Code"
    case cursor     = "Cursor"
    case unknown    = "Unknown"
}

enum AgentState: Sendable {
    case active
    case stalled
    case idle
}
