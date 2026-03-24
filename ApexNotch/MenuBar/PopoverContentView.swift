import SwiftUI

// MARK: - PopoverContentView

struct PopoverContentView: View {
    @Environment(AppState.self) var appState
    @State private var lastRefreshed = Date()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── AI Agent section ────────────────────────────────
                    if appState.agentSession != nil {
                        sectionHeader(
                            icon: "sparkles",
                            title: "AI Agent",
                            badge: agentBadge
                        )
                        AIAgentView()
                        sectionDivider
                    }

                    // ── Usage section ───────────────────────────────────
                    if appState.usageSnapshot != nil {
                        sectionHeader(
                            icon: "chart.bar.fill",
                            title: "Usage",
                            badge: usageBadge
                        )
                        AIUsageView()
                        sectionDivider
                    }

                    // ── Processes section ────────────────────────────────
                    sectionHeader(
                        icon: "bolt.fill",
                        title: "Processes",
                        badge: processBadge
                    )
                    ProcessMonitorView()
                }
            }

            footer
        }
        .frame(width: 360)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // App name
            HStack(spacing: 6) {
                Text("⚡")
                    .font(.system(size: 14))
                Text("ApexNotch")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            // Stats badges
            HStack(spacing: 6) {
                if let session = appState.agentSession {
                    statBadge(
                        text: session.state == .active ? "active" : "idle",
                        color: session.state == .active
                            ? Color(hex: "#ff9f0a")
                            : Color(hex: "#48484a")
                    )
                }

                statBadge(
                    text: "\(appState.projects.count) proj",
                    color: Color(hex: "#64d2ff")
                )

                // Refresh button
                Button {
                    Task {
                        await appState.refresh()
                        lastRefreshed = Date()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .rotationEffect(.degrees(appState.isRefreshing ? 360 : 0))
                        .animation(
                            appState.isRefreshing
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: appState.isRefreshing
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.1)
        }
    }

    // MARK: - Section Headers

    private func sectionHeader(
        icon: String,
        title: String,
        badge: some View
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            badge
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var sectionDivider: some View {
        Divider()
            .opacity(0.1)
            .padding(.vertical, 2)
    }

    // MARK: - Badges

    @ViewBuilder
    private var agentBadge: some View {
        if let session = appState.agentSession {
            Text(session.source.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: "#ff9f0a"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "#ff9f0a").opacity(0.15))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var usageBadge: some View {
        if let snapshot = appState.usageSnapshot {
            let pct = Int(snapshot.windowProgress * 100)
            Text("\(pct)%")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(usageBadgeColor(snapshot.windowProgress))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(usageBadgeColor(snapshot.windowProgress).opacity(0.15))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var processBadge: some View {
        let count = appState.projects.reduce(0) { $0 + $1.processes.count }
        Text("\(count)")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Updated \(lastRefreshed, format: .dateTime.hour().minute().second())")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Divider().opacity(0.08)
        }
    }

    // MARK: - Helpers

    private func statBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func usageBadgeColor(_ progress: Double) -> Color {
        if progress > 0.85 { return Color(hex: "#ff453a") }
        if progress > 0.65 { return Color(hex: "#ffd60a") }
        return Color(hex: "#30d158")
    }
}
