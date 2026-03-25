import SwiftUI

// MARK: - AIUsageView

struct AIUsageView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if let snapshot = appState.usageSnapshot {
            VStack(spacing: 10) {
                usageGauge(snapshot: snapshot)
                tokenBreakdown(snapshot: snapshot)
                footerRow(snapshot: snapshot)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        } else {
            noDataState
        }
    }

    // MARK: - Sub-views

    private func usageGauge(snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("5h Window Usage")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTokens(snapshot.totalTokens))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(gaugeColor(snapshot.windowProgress))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: gaugeGradient(snapshot.windowProgress),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(snapshot.windowProgress), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: snapshot.windowProgress)
                }
            }
            .frame(height: 6)

            HStack {
                Text(String(format: "%.0f%% of window", snapshot.windowProgress * 100))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(windowTimeRemaining(snapshot: snapshot))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    private func tokenBreakdown(snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 0) {
            tokenCell(label: "Input", value: snapshot.inputTokens, color: Color(hex: "#64d2ff"))
            Divider()
                .frame(height: 28)
                .opacity(0.15)
            tokenCell(label: "Output", value: snapshot.outputTokens, color: Color(hex: "#bf5af2"))
            Divider()
                .frame(height: 28)
                .opacity(0.15)
            tokenCell(label: "Total", value: snapshot.totalTokens, color: Color(hex: "#ff9f0a"))
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func tokenCell(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(formatTokens(value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }

    private func footerRow(snapshot: UsageSnapshot) -> some View {
        HStack {
            // Model badge
            Text(snapshot.model.components(separatedBy: "-").prefix(3).joined(separator: "-"))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

            Spacer()
        }
    }

    private var noDataState: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text("No usage data found in ~/.claude/")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

    private func gaugeColor(_ progress: Double) -> Color {
        if progress > 0.85 { return Color(hex: "#ff453a") }
        if progress > 0.65 { return Color(hex: "#ffd60a") }
        return Color(hex: "#30d158")
    }

    private func gaugeGradient(_ progress: Double) -> [Color] {
        if progress > 0.85 {
            return [Color(hex: "#ff9f0a"), Color(hex: "#ff453a")]
        } else if progress > 0.65 {
            return [Color(hex: "#30d158"), Color(hex: "#ffd60a")]
        }
        return [Color(hex: "#30d158"), Color(hex: "#64d2ff")]
    }


    private func windowTimeRemaining(snapshot: UsageSnapshot) -> String {
        let remaining = snapshot.windowEnd.timeIntervalSince(Date())
        guard remaining > 0 else { return "expired" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }
}
