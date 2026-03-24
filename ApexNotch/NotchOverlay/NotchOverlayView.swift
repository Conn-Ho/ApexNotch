import SwiftUI

// MARK: - NotchOverlayView
// Full-screen-width overlay that sits above the menu bar.
// Closed state: 38pt tall with two wings flanking the camera notch.
// Expanded state: ~200pt, reveals a frosted glass panel below.

struct NotchOverlayView: View {
    let appState: AppState

    @State private var isExpanded = false
    @State private var isHovered  = false

    // Wing fixed widths
    private let wingWidth:  CGFloat = 160
    // Height constants
    private let barHeight:  CGFloat = 38
    private let panelHeight: CGFloat = 180

    var body: some View {
        VStack(spacing: 0) {
            // ── Top bar: wings + transparent camera gap ──────────────────
            HStack(spacing: 0) {
                leftWing
                Spacer()     // transparent camera bump
                rightWing
            }
            .frame(height: barHeight)

            // ── Expansion panel ──────────────────────────────────────────
            if isExpanded {
                expansionPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(
            .interactiveSpring(response: 0.38, dampingFraction: 0.8),
            value: isExpanded
        )
        .onHover { hovering in
            isHovered = hovering
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                isExpanded = hovering
            }
        }
    }

    // MARK: - Left Wing
    // Shows: colored status dot + tool name pill

    private var leftWing: some View {
        HStack(spacing: 7) {
            // Status pulse dot
            pulseDot

            // Tool name pill
            if case .agentActive(let toolName) = appState.currentSignal {
                toolPill(toolName)
            } else {
                toolPill(appState.currentSignal.displayText)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(width: wingWidth, height: barHeight)
        .background(wingBackground, in: NotchBgShape(cornerRadius: 12, bottomCornersOnly: true))
        .overlay(
            NotchBgShape(cornerRadius: 12, bottomCornersOnly: true)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
        )
        .overlay(wingGlow, alignment: .bottom)
    }

    // MARK: - Right Wing
    // Shows: token count (monospaced) + live timer or checkmark

    private var rightWing: some View {
        HStack(spacing: 7) {
            Spacer(minLength: 0)

            // Token count
            if let session = appState.agentSession {
                Text(formatTokens(session.totalTokens))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#ff9f0a"))
            } else if let snapshot = appState.usageSnapshot {
                Text(formatTokens(snapshot.totalTokens))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#ffd60a"))
            } else {
                Text("—")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }

            // Timer or state indicator
            rightWingIndicator
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(width: wingWidth, height: barHeight)
        .background(wingBackground, in: NotchBgShape(cornerRadius: 12, bottomCornersOnly: true))
        .overlay(
            NotchBgShape(cornerRadius: 12, bottomCornersOnly: true)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
        )
        .overlay(wingGlow, alignment: .bottom)
    }

    @ViewBuilder
    private var rightWingIndicator: some View {
        if let session = appState.agentSession {
            switch session.state {
            case .active:
                // Running timer
                TimelineView(.animation(minimumInterval: 1)) { _ in
                    Text(formatDuration(session.sessionDuration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(hex: "#ff9f0a").opacity(0.8))
                }
            case .stalled:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#ff453a"))
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#30d158"))
            }
        } else {
            Image(systemName: "circle.dotted")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Expansion Panel

    private var expansionPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // AI Agent section
                if let session = appState.agentSession {
                    panelSectionHeader("Agent · \(session.source.rawValue)")
                    agentSummary(session: session)
                    Divider().opacity(0.1).padding(.horizontal, 12)
                }

                // Usage section
                if let snapshot = appState.usageSnapshot {
                    panelSectionHeader("Usage · 5h window")
                    usageSummary(snapshot: snapshot)
                    Divider().opacity(0.1).padding(.horizontal, 12)
                }

                // Processes section
                if !appState.projects.isEmpty {
                    panelSectionHeader("Processes · \(appState.projects.count)")
                    processSummary
                }
            }
            .padding(.bottom, 6)
        }
        .frame(height: panelHeight)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 4)
        .shadow(color: Color.black.opacity(0.5), radius: 16, y: 8)
    }

    // MARK: - Panel Sections

    private func panelSectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 3)
    }

    private func agentSummary(session: AgentSession) -> some View {
        VStack(spacing: 3) {
            ForEach(session.recentTools.prefix(3)) { tool in
                HStack(spacing: 6) {
                    Circle()
                        .fill(toolStatusColor(tool.status))
                        .frame(width: 5, height: 5)
                    Text(tool.toolName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                    Spacer()
                    if let dur = tool.duration {
                        Text(String(format: "%.1fs", dur))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
            }
            HStack(spacing: 8) {
                Text(formatDuration(session.sessionDuration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("·")
                    .foregroundStyle(.quaternary)
                Text(formatTokens(session.totalTokens))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
        }
        .padding(.bottom, 6)
    }

    private func usageSummary(snapshot: UsageSnapshot) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(formatTokens(snapshot.totalTokens) + " tokens")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "$%.4f", snapshot.estimatedCost))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#30d158"))
            }
            .padding(.horizontal, 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(usageGaugeColor(snapshot.windowProgress))
                        .frame(width: geo.size.width * CGFloat(snapshot.windowProgress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 8)
    }

    private var processSummary: some View {
        VStack(spacing: 0) {
            ForEach(appState.projects.prefix(3)) { group in
                HStack(spacing: 6) {
                    Circle()
                        .fill(group.isZombie ? Color(hex: "#ff453a") : Color(hex: "#30d158"))
                        .frame(width: 5, height: 5)
                    Text(group.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(group.processes.count) proc · \(group.totalMemoryMB)MB")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 3)
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Shared Components

    private var pulseDot: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let speed = appState.currentSignal.pulseSpeed
            let pulse: Double = speed > 0
                ? (sin(t * .pi * 2 * speed) + 1) / 2
                : 0.6
            Circle()
                .fill(appState.currentSignal.color)
                .frame(width: 8, height: 8)
                .shadow(
                    color: appState.currentSignal.color.opacity(0.9 * pulse),
                    radius: 5
                )
        }
    }

    private func toolPill(_ text: String) -> some View {
        Text(text.isEmpty ? "idle" : text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08), in: ToolPillShape())
            .overlay(ToolPillShape().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }

    private var wingBackground: some ShapeStyle {
        AnyShapeStyle(Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 0.85))
    }

    /// Subtle glow line at the bottom edge of each wing when active
    @ViewBuilder
    private var wingGlow: some View {
        if case .idle = appState.currentSignal {
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let speed = appState.currentSignal.pulseSpeed
                let pulse: Double = speed > 0
                    ? (sin(t * .pi * 2 * speed) + 1) / 2
                    : 0.5
                Capsule()
                    .fill(appState.currentSignal.color.opacity(0.6 * pulse))
                    .frame(height: 2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 1)
            }
        }
    }

    // MARK: - Helpers

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func toolStatusColor(_ status: ToolCallStatus) -> Color {
        switch status {
        case .running:   return Color(hex: "#ff9f0a")
        case .completed: return Color(hex: "#30d158")
        case .failed:    return Color(hex: "#ff453a")
        }
    }

    private func usageGaugeColor(_ progress: Double) -> Color {
        if progress > 0.85 { return Color(hex: "#ff453a") }
        if progress > 0.65 { return Color(hex: "#ffd60a") }
        return Color(hex: "#30d158")
    }
}
