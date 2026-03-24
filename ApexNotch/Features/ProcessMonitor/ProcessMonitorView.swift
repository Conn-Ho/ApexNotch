import SwiftUI

struct ProcessMonitorView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            if appState.projects.isEmpty {
                emptyState
            } else {
                ForEach(appState.projects) { group in
                    ProjectRowView(group: group)
                    Divider().opacity(0.1)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No dev processes running")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct ProjectRowView: View {
    @Environment(AppState.self) var appState
    let group: ProjectGroup
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        if group.isZombie {
                            Text("zombie")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color(hex: "#ff453a"))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#ff453a").opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text("\(group.frameworkNames) · \(group.processes.count) proc\(group.processes.count == 1 ? "" : "s") · \(group.totalMemoryMB) MB")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Port badges
                ForEach(group.ports, id: \.self) { port in
                    Link(":\(port)", destination: URL(string: "http://localhost:\(port)")!)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#64d2ff"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#64d2ff").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Kill all button
                Button {
                    Task { await appState.killProject(group) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color(hex: "#ff453a"))
                        .frame(width: 20, height: 20)
                        .background(Color(hex: "#ff453a").opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(duration: 0.2)) { expanded.toggle() } }

            // Expanded process list
            if expanded {
                VStack(spacing: 0) {
                    ForEach(group.processes) { proc in
                        ProcessItemView(proc: proc)
                    }
                }
                .background(Color.black.opacity(0.15))
            }
        }
    }
}

struct ProcessItemView: View {
    @Environment(AppState.self) var appState
    let proc: DevProcess
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(proc.type.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(typeColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(typeColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text("#\(proc.pid)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.quaternary)

            Text("\(proc.memoryMB) MB")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)

            Text(proc.runtime)
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)

            Spacer()

            Text(proc.command.components(separatedBy: "/").last?.components(separatedBy: " ").first ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            if hovered {
                Button {
                    Task { await appState.kill(pid: proc.pid) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color(hex: "#ff453a"))
                        .frame(width: 14, height: 14)
                        .background(Color(hex: "#ff453a").opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 14, height: 14)
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .onHover { hovered = $0 }
    }

    private var typeColor: Color {
        switch proc.type {
        case .root:      return Color(hex: "#0a84ff")
        case .frontend:  return Color(hex: "#bf5af2")
        case .backend:   return Color(hex: "#34c759")
        case .monorepo:  return Color(hex: "#ff9f0a")
        case .buildTool: return Color(hex: "#ff453a")
        case .worker:    return Color(hex: "#64d2ff")
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
