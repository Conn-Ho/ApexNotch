import SwiftUI
import Foundation

// MARK: - PopoverContentView

struct PopoverContentView: View {
    @Environment(AppState.self) var appState
    @State private var lastRefreshed = Date()
    @State private var showGitHubConnect = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── AI Agent section ────────────────────────────────
                    if appState.agentSession != nil {
                        sectionHeader(
                            icon: "cpu",
                            title: "AI Agent",
                            badge: agentBadge
                        )
                        AIAgentView()
                        sectionDivider
                    }

                    // ── Usage section ───────────────────────────────────
                    if appState.usageSnapshot != nil {
                        sectionHeader(
                            icon: "chart.bar.xaxis",
                            title: "Usage",
                            badge: usageBadge
                        )
                        AIUsageView()
                        sectionDivider
                    }

                    // ── GitHub section ──────────────────────────────────
                    sectionHeader(
                        icon: "chevron.left.forwardslash.chevron.right",
                        title: "GitHub",
                        badge: githubBadge
                    )
                    GitHubSectionView(showConnect: $showGitHubConnect)
                    sectionDivider

                    // ── Effects section ─────────────────────────────────
                    sectionHeader(icon: "wand.and.sparkles", title: "Notch Effect", badge: EmptyView())
                    EffectSettingsView(settings: appState.effectSettings)
                    sectionDivider

                    // ── Processes section ────────────────────────────────
                    sectionHeader(
                        icon: "square.3.layers.3d",
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
        .sheet(isPresented: $showGitHubConnect) {
            GitHubConnectSheet(isPresented: $showGitHubConnect)
                .environment(appState)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // App name
            HStack(spacing: 6) {
                Image(systemName: "rectangle.topthird.inset.filled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
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
    private var githubBadge: some View {
        if appState.isGitHubAuthenticated {
            if let info = appState.githubRepoInfo {
                Text(info.fullName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(hex: "#64d2ff"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#64d2ff").opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Text("connected")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(hex: "#30d158"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#30d158").opacity(0.15))
                    .clipShape(Capsule())
            }
        } else {
            Text("not connected")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.05))
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

    @ViewBuilder
    private func repoBadge(_ repo: RepoStatus) -> some View {
        Text(repo.syncState.label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(repo.syncState.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(repo.syncState.color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func usageBadgeColor(_ progress: Double) -> Color {
        if progress > 0.85 { return Color(hex: "#ff453a") }
        if progress > 0.65 { return Color(hex: "#ffd60a") }
        return Color(hex: "#30d158")
    }
}

// MARK: - RepoDetailView

private struct RepoDetailView: View {
    let repo: RepoStatus

    var body: some View {
        VStack(spacing: 6) {
            // Branch row
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(repo.branch)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: repo.syncState.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(repo.syncState.color)
                Text(repo.syncState.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(repo.syncState.color)
            }

            // Dirty / ahead / behind detail
            if !repo.syncDetail.isEmpty {
                HStack(spacing: 4) {
                    if repo.aheadCount > 0 {
                        statChip("↑\(repo.aheadCount)", color: Color(hex: "#64d2ff"))
                    }
                    if repo.behindCount > 0 {
                        statChip("↓\(repo.behindCount)", color: Color(hex: "#ffd60a"))
                    }
                    if repo.addedCount > 0 {
                        statChip("+\(repo.addedCount)", color: Color(hex: "#30d158"))
                    }
                    if repo.modifiedCount > 0 {
                        statChip("~\(repo.modifiedCount)", color: Color(hex: "#ff9f0a"))
                    }
                    if repo.deletedCount > 0 {
                        statChip("-\(repo.deletedCount)", color: Color(hex: "#ff453a"))
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statChip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - EffectSettingsView

private struct EffectSettingsView: View {
    @Bindable var settings: EffectSettings

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(spacing: 10) {
            // Style grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NotchEffectStyle.allCases) { style in
                    effectButton(style)
                }
            }

            Divider().opacity(0.1)

            // Intensity slider
            sliderRow(
                label: "Intensity",
                icon: "sun.max",
                value: $settings.intensity,
                range: 0.2...1.0
            )

            // Speed slider
            sliderRow(
                label: "Speed",
                icon: "hare",
                value: $settings.speed,
                range: 0.25...3.0
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func effectButton(_ style: NotchEffectStyle) -> some View {
        let selected = settings.style == style
        return Button {
            settings.style = style
        } label: {
            VStack(spacing: 3) {
                Image(systemName: style.icon)
                    .font(.system(size: 13))
                Text(style.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color(hex: "#ff9f0a") : .secondary)
            .background(
                selected
                    ? Color(hex: "#ff9f0a").opacity(0.15)
                    : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color(hex: "#ff9f0a").opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sliderRow(label: String, icon: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            Slider(value: value, in: range)
                .controlSize(.mini)
        }
    }
}

// MARK: - GitHubSectionView

private struct GitHubSectionView: View {
    @Environment(AppState.self) var appState
    @Binding var showConnect: Bool

    var body: some View {
        if appState.isGitHubAuthenticated {
            if let info = appState.githubRepoInfo {
                GitHubInfoView(info: info, onDisconnect: {
                    Task { await appState.disconnectGitHub() }
                }, onRefresh: {
                    Task { await appState.refreshGitHub() }
                })
            } else {
                // Authenticated but no info yet (loading or no git remote)
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading GitHub info...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Disconnect") {
                        Task { await appState.disconnectGitHub() }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        } else {
            // Not authenticated - show connect button
            HStack {
                Text("Connect to see CI, PRs and commits")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Connect") {
                    showConnect = true
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: "#64d2ff"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "#64d2ff").opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - GitHubInfoView

private struct GitHubInfoView: View {
    let info: GitHubRepoInfo
    let onDisconnect: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Repo name + actions row
            HStack(spacing: 6) {
                Text(info.fullName)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Button(action: onDisconnect) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }

            // CI status row
            if let run = info.latestRun {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ciColor(run))
                        .frame(width: 7, height: 7)
                    Text(run.name)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(ciLabel(run))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ciColor(run))
                    Spacer()
                    Text(run.updatedAt, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            // Stats row: stars, forks, PRs, issues
            HStack(spacing: 8) {
                statChip("star", value: info.stars, color: Color(hex: "#ffd60a"))
                statChip("tuningfork", value: info.forks, color: Color(hex: "#64d2ff"))
                statChip("arrow.triangle.pull", value: info.openPRs, color: Color(hex: "#bf5af2"))
                statChip("exclamationmark.circle", value: info.openIssues, color: Color(hex: "#ff453a"))
                Spacer()
            }

            // Recent commits
            if !info.recentCommits.isEmpty {
                VStack(spacing: 3) {
                    ForEach(info.recentCommits) { commit in
                        HStack(spacing: 6) {
                            Text(commit.id)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color(hex: "#64d2ff"))
                                .frame(width: 42, alignment: .leading)
                            Text(commit.message)
                                .font(.system(size: 10))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text(commit.date, style: .relative)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func ciColor(_ run: CIRun) -> Color {
        if run.isRunning { return Color(hex: "#ffd60a") }
        if run.isSuccess { return Color(hex: "#30d158") }
        if run.isFailed  { return Color(hex: "#ff453a") }
        return .secondary
    }

    private func ciLabel(_ run: CIRun) -> String {
        if run.isRunning { return "Running" }
        if run.isSuccess { return "Passed" }
        if run.isFailed  { return "Failed" }
        return run.conclusion ?? run.status
    }

    private func statChip(_ icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text("\(value)")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - GitHubConnectSheet  (OAuth Device Flow)

private struct GitHubConnectSheet: View {
    @Environment(AppState.self) var appState
    @Binding var isPresented: Bool

    @State private var flow = GitHubDeviceFlow()
    @State private var flowState: GitHubDeviceFlow.FlowState = .idle
    @State private var userCode: String = ""
    @State private var verificationURI: String = "https://github.com/login/device"

    var body: some View {
        VStack(spacing: 24) {

            // ── Header ──
            VStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(hex: "#6e40c9"))
                Text("Connect GitHub")
                    .font(.system(size: 17, weight: .semibold))
            }

            // ── State-specific content ──
            switch flowState {

            case .idle:
                VStack(spacing: 16) {
                    Text("点击按钮，浏览器将自动打开 GitHub 授权页面。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("使用 GitHub 登录") { startFlow() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#6e40c9"))
                }

            case .awaitingUserCode, .polling:
                VStack(spacing: 16) {
                    Text("在浏览器中输入以下授权码：")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    // 授权码大字显示
                    Text(userCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { copyCode() }

                    Button("复制") { copyCode() }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("等待授权中…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Button("重新打开浏览器") {
                        if let url = URL(string: verificationURI) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(hex: "#64d2ff"))
                }

            case .success:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "#30d158"))
                    Text("授权成功！")
                        .font(.system(size: 14, weight: .semibold))
                }

            case .expired:
                VStack(spacing: 12) {
                    Text("授权码已过期")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("重新开始") { startFlow() }
                        .buttonStyle(.borderedProminent)
                }

            case .error(let msg):
                VStack(spacing: 12) {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#ff453a"))
                        .multilineTextAlignment(.center)
                    Button("重试") { startFlow() }
                        .buttonStyle(.borderedProminent)
                }
            }

            // ── Cancel ──
            if case .success = flowState { EmptyView() } else {
                Button("取消") {
                    Task { await flow.cancel() }
                    isPresented = false
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 360)
        .onAppear { setupFlow() }
        .onDisappear { Task { await flow.cancel() } }
    }

    private func setupFlow() {
        Task {
            await flow.setStateCallback { @Sendable state in
                Task { @MainActor in
                    flowState = state
                    if case .awaitingUserCode(let resp) = state {
                        userCode = resp.userCode
                        verificationURI = resp.verificationURI
                    }
                    if case .success(let token) = state {
                        await appState.connectGitHub(token: token)
                        try? await Task.sleep(for: .milliseconds(800))
                        isPresented = false
                    }
                }
            }
        }
    }

    private func startFlow() {
        Task { await flow.start() }
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(userCode, forType: .string)
    }
}
