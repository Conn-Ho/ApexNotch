import SwiftUI

struct PopoverContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    sectionHeader("⚡ Processes", count: appState.projects.reduce(0) { $0 + $1.processes.count })
                    ProcessMonitorView()
                    // Future sections: AI Agent, GitHub, Music…
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

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Text("⚡")
                    .font(.system(size: 14))
                Text("ApexNotch")
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            HStack(spacing: 8) {
                Text("\(appState.projects.count) projects")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1))
                    .clipShape(Capsule())

                Button {
                    Task { await appState.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .rotationEffect(.degrees(appState.isRefreshing ? 360 : 0))
                        .animation(appState.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isRefreshing)
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

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack {
            Text("Updated \(Date(), format: .dateTime.hour().minute().second())")
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
}
