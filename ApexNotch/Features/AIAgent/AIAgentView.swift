import SwiftUI

// MARK: - AIAgentView

struct AIAgentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if let session = appState.agentSession {
            VStack(spacing: 0) {
                currentToolRow(session: session)
                if !session.recentTools.isEmpty {
                    Divider()
                        .opacity(0.08)
                        .padding(.horizontal, 12)
                    recentToolsList(session: session)
                }
                statsRow(session: session)
            }
        } else {
            idleState
        }
    }

    // MARK: - Sub-views

    private func currentToolRow(session: AgentSession) -> some View {
        HStack(spacing: 10) {
            // Animated state indicator dot
            StateDot(state: session.state)

            VStack(alignment: .leading, spacing: 2) {
                if let tool = session.currentTool {
                    Text(tool.toolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    if !tool.arguments.isEmpty {
                        Text(tool.arguments)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    Text(stateLabel(session.state))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(stateColor(session.state))
                }
            }

            Spacer()

            // Source badge
            Text(session.source.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: "#ff9f0a"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "#ff9f0a").opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func recentToolsList(session: AgentSession) -> some View {
        VStack(spacing: 0) {
            ForEach(session.recentTools.prefix(5)) { tool in
                ToolCallRow(tool: tool)
            }
        }
    }

    private func statsRow(session: AgentSession) -> some View {
        HStack(spacing: 12) {
            // Session duration
            Label(formatDuration(session.sessionDuration), systemImage: "clock")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 10)
                .opacity(0.3)

            // Token count
            Label(formatTokens(session.totalTokens), systemImage: "cpu")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.12))
    }

    private var idleState: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "#48484a"))
                .frame(width: 6, height: 6)
            Text("No active agent session")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func stateLabel(_ state: AgentState) -> String {
        switch state {
        case .active:  return "Active"
        case .stalled: return "Stalled"
        case .idle:    return "Idle"
        }
    }

    private func stateColor(_ state: AgentState) -> Color {
        switch state {
        case .active:  return Color(hex: "#ff9f0a")
        case .stalled: return Color(hex: "#ff453a")
        case .idle:    return Color(hex: "#48484a")
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return String(format: "%.1fk tok", k)
        }
        return "\(count) tok"
    }
}

// MARK: - StateDot

private struct StateDot: View {
    let state: AgentState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let pulse: Double = {
                switch state {
                case .active:
                    return (sin(t * .pi * 2 * 1.4) + 1) / 2
                case .stalled:
                    return (sin(t * .pi * 2 * 0.6) + 1) / 2
                case .idle:
                    return 0.5
                }
            }()
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .shadow(color: dotColor.opacity(0.8 * pulse), radius: 4)
        }
    }

    private var dotColor: Color {
        switch state {
        case .active:  return Color(hex: "#ff9f0a")
        case .stalled: return Color(hex: "#ff453a")
        case .idle:    return Color(hex: "#48484a")
        }
    }
}

// MARK: - ToolCallRow

private struct ToolCallRow: View {
    let tool: ToolCall

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            statusIcon
                .font(.system(size: 8))
                .frame(width: 14)

            Text(tool.toolName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if let duration = tool.duration {
                Text(String(format: "%.1fs", duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch tool.status {
        case .running:
            Image(systemName: "circle.fill")
                .foregroundStyle(Color(hex: "#ff9f0a"))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: "#30d158"))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color(hex: "#ff453a"))
        }
    }
}
