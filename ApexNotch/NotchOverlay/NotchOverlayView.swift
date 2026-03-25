import SwiftUI
import AppKit

// MARK: - NotchOverlayView

struct NotchOverlayView: View {
    let appState: AppState

    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var hoverTask: Task<Void, Never>?

    private let spring = Animation.interactiveSpring(response: 0.38, dampingFraction: 1.0)

    // ── Corner radii (AgentNotch values) ──────────────────────────────
    private var topR:    CGFloat { isExpanded ? 19  : 6  }
    private var bottomR: CGFloat { isExpanded ? 24  : 14 }

    // ── Size constants ─────────────────────────────────────────────────
    private let wingW:       CGFloat = 100   // each wing (closed state)
    private let openW:       CGFloat = 520   // expanded panel width

    var body: some View {
        let notch   = closedNotchSize()
        let closedW = notch.width + wingW * 2
        let totalW  = isExpanded ? openW : closedW
        let headerH = notch.height

        // ZStack guarantees the panel is centered horizontally in the full-screen window
        ZStack(alignment: .top) {
            Color.clear  // expands to fill full-screen NSHostingView

            // Permanent notch cover — always the full closed-state shape, independent of
            // panel animation. Prevents the hardware notch border from showing during
            // spring overshoot when the animated panel briefly undershoots closedW.
            Color.black
                .frame(width: closedW, height: headerH)
                .mask(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))

            // Panel
            VStack(alignment: .leading, spacing: 0) {
                header(notchW: notch.width, headerH: headerH)
                    .frame(height: headerH)

                if isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                }
            }
            .frame(width: totalW)
            .background(Color.black)
            .mask(
                NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
                    .animation(spring, value: isExpanded)
            )
            .contentShape(
                NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
            )
            .overlay {
                let isIdle = { if case .idle = appState.currentSignal { return true }; return false }()
                NotchEffectBorder(topR: topR, bottomR: bottomR,
                                  color: appState.currentSignal.color,
                                  settings: appState.effectSettings)
                    .opacity(isIdle ? 0 : 1)
                    .animation(.easeInOut(duration: 0.6), value: isIdle)
            }
            .shadow(color: isExpanded ? .black.opacity(0.55) : .clear, radius: 14)
            .onHover { handleHover($0) }
            .animation(spring, value: isExpanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header  [left wing][notch gap][right wing]

    private func header(notchW: CGFloat, headerH: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Left wing — padding first, then frame (keeps padding INSIDE)
            HStack(spacing: 6) {
                pulseDot
                toolPill
                Spacer(minLength: 0)
            }
            .padding(.leading, isExpanded ? topR + 4 : 10)
            .padding(.trailing, 4)
            .frame(width: isExpanded ? (openW / 2 - notchW / 2) : wingW)

            // Camera notch gap — black fills over the hardware notch
            Color.black.frame(width: notchW)

            // Right wing
            HStack(spacing: 5) {
                Spacer(minLength: 0)
                tokenLabel
                stateIndicator
            }
            .padding(.trailing, isExpanded ? topR + 4 : 10)
            .padding(.leading, 4)
            .frame(width: isExpanded ? (openW / 2 - notchW / 2) : wingW)
        }
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session = appState.agentSession {
                section("Agent · \(session.source.rawValue)") { agentDetail(session) }
            }
            if let snap = appState.usageSnapshot {
                section("Usage · 5h window") { usageDetail(snap) }
            }
            if let repo = appState.repoStatus {
                section("Repo · \(repo.repoName)") { repoDetail(repo) }
            }
            if !appState.projects.isEmpty {
                section("Processes · \(appState.projects.count)") { processDetail }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, bottomR + 12)
    }

    // MARK: - Left wing views

    private var pulseDot: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t     = tl.date.timeIntervalSinceReferenceDate
            let speed = appState.currentSignal.pulseSpeed
            let pulse = speed > 0 ? (sin(t * .pi * 2 * speed) + 1) / 2 : 0.6
            Circle()
                .fill(appState.currentSignal.color)
                .frame(width: 7, height: 7)
                .shadow(color: appState.currentSignal.color.opacity(pulse), radius: 4)
        }
    }

    private var toolPill: some View {
        let label: String = {
            if case .agentActive(let n) = appState.currentSignal { return n }
            return appState.currentSignal.displayText
        }()
        return Text(label.isEmpty ? "idle" : label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.10), in: Capsule())
    }

    // MARK: - Right wing views

    private var tokenLabel: some View {
        Group {
            if let s = appState.agentSession {
                Text(fmt(s.totalTokens)).foregroundStyle(Color(hex: "#ff9f0a"))
            } else if let snap = appState.usageSnapshot {
                Text(fmt(snap.totalTokens)).foregroundStyle(Color(hex: "#ffd60a"))
            } else {
                Text("—").foregroundStyle(.white.opacity(0.3))
            }
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
    }

    @ViewBuilder
    private var stateIndicator: some View {
        if let s = appState.agentSession {
            switch s.state {
            case .active:
                TimelineView(.animation(minimumInterval: 1)) { _ in
                    Text(fmtDur(s.sessionDuration))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color(hex: "#ff9f0a").opacity(0.8))
                }
            case .stalled:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9)).foregroundStyle(Color(hex: "#ff453a"))
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9)).foregroundStyle(Color(hex: "#30d158"))
            }
        } else {
            Image(systemName: "circle.dotted")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.25))
        }
    }

    // MARK: - Section card

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
    }

    private func agentDetail(_ s: AgentSession) -> some View {
        VStack(spacing: 3) {
            ForEach(s.recentTools.prefix(3)) { tool in
                HStack(spacing: 6) {
                    Circle().fill(toolColor(tool.status)).frame(width: 4, height: 4)
                    Text(tool.toolName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    if let d = tool.duration {
                        Text(String(format: "%.1fs", d))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            HStack(spacing: 6) {
                Text(fmtDur(s.sessionDuration))
                Text("·").foregroundStyle(.white.opacity(0.3))
                Text(fmt(s.totalTokens))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.top, 2)
        }
    }

    private func usageDetail(_ snap: UsageSnapshot) -> some View {
        VStack(spacing: 6) {
            Text(fmt(snap.totalTokens) + " tokens")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 3)
                    Capsule().fill(gaugeColor(snap.windowProgress))
                        .frame(width: g.size.width * snap.windowProgress, height: 3)
                }
            }
            .frame(height: 3)
        }
    }

    private func repoDetail(_ repo: RepoStatus) -> some View {
        VStack(spacing: 4) {
            // Branch + sync state
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
                Text(repo.branch)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                Image(systemName: repo.syncState.icon)
                    .font(.system(size: 9))
                    .foregroundStyle(repo.syncState.color)
                Text(repo.syncState.label)
                    .font(.system(size: 9))
                    .foregroundStyle(repo.syncState.color.opacity(0.85))
            }
            // Ahead / behind / dirty detail
            if !repo.syncDetail.isEmpty {
                HStack {
                    Text(repo.syncDetail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
            }
        }
    }

    private var processDetail: some View {
        VStack(spacing: 2) {
            ForEach(appState.projects.prefix(4)) { g in
                HStack(spacing: 6) {
                    Circle()
                        .fill(g.isZombie ? Color(hex: "#ff453a") : Color(hex: "#30d158"))
                        .frame(width: 4, height: 4)
                    Text(g.name).font(.system(size: 10)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("\(g.processes.count)p · \(g.totalMemoryMB)MB")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Hover

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        if hovering {
            isHovering = true
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard isHovering else { return }
                    withAnimation(spring) { isExpanded = true }
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isHovering = false
                    withAnimation(spring) { isExpanded = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000)
            : n >= 1_000 ? String(format: "%.1fk", Double(n) / 1_000)
            : "\(n)"
    }
    private func fmtDur(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
    private func toolColor(_ s: ToolCallStatus) -> Color {
        switch s {
        case .running:   Color(hex: "#ff9f0a")
        case .completed: Color(hex: "#30d158")
        case .failed:    Color(hex: "#ff453a")
        }
    }
    private func gaugeColor(_ p: Double) -> Color {
        p > 0.85 ? Color(hex: "#ff453a") : p > 0.65 ? Color(hex: "#ffd60a") : Color(hex: "#30d158")
    }
}

