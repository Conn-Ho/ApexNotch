import Foundation
import Security

actor GitHubService {

    private let keychainService = "com.apexnotch.github"
    private let keychainAccount = "token"
    private var pollTask: Task<Void, Never>?
    private var onUpdate: (@Sendable (GitHubRepoInfo?) -> Void)?

    func setCallback(_ callback: @escaping @Sendable (GitHubRepoInfo?) -> Void) {
        onUpdate = callback
    }

    // MARK: - Token management

    func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    var isAuthenticated: Bool { loadToken() != nil }

    // MARK: - Polling

    func start(repoStatusProvider: @escaping @Sendable () -> RepoStatus?) async {
        await poll(repoStatusProvider: repoStatusProvider)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await self?.poll(repoStatusProvider: repoStatusProvider)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(repoStatusProvider: @escaping @Sendable () -> RepoStatus?) async {
        await poll(repoStatusProvider: repoStatusProvider)
    }

    private func poll(repoStatusProvider: @escaping @Sendable () -> RepoStatus?) async {
        guard let token = loadToken() else { onUpdate?(nil); return }
        guard let repoStatus = repoStatusProvider() else { onUpdate?(nil); return }

        guard let repoPath = await getRepoPath(repoName: repoStatus.repoName),
              let remoteURL = await gitRemoteURL(at: repoPath),
              let (owner, repo) = parseGitHubRepo(from: remoteURL) else {
            onUpdate?(nil)
            return
        }

        let info = await fetchRepoInfo(owner: owner, repo: repo, token: token)
        onUpdate?(info)
    }

    // MARK: - Git helpers

    private func getRepoPath(repoName: String) async -> String? {
        // Offload synchronous file system work to avoid Swift 6 async context restrictions
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: Self.findCwdFromJSONL())
            }
        }
    }

    private static func findCwdFromJSONL() -> String? {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        guard let enumerator = FileManager.default.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var best: (URL, Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if best == nil || mod > best!.1 { best = (url, mod) }
        }
        guard let jsonlFile = best?.0 else { return nil }

        guard let fh = try? FileHandle(forReadingFrom: jsonlFile) else { return nil }
        defer { try? fh.close() }
        let fileSize = (try? fh.seekToEnd()) ?? 0
        let tailSize: UInt64 = 4096
        let offset = fileSize > tailSize ? fileSize - tailSize : 0
        try? fh.seek(toOffset: offset)
        guard let data = try? fh.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: "\n").reversed() {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let cwd = json["cwd"] as? String, !cwd.isEmpty else { continue }
            return cwd
        }
        return nil
    }

    private func gitRemoteURL(at path: String) async -> String? {
        let p = path.replacingOccurrences(of: "'", with: "'\\''")
        let url = await ShellRunner.run("git -C '\(p)' remote get-url origin 2>/dev/null")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }

    private func parseGitHubRepo(from remoteURL: String) -> (String, String)? {
        let cleaned = remoteURL
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("https://github.com/") {
            let parts = cleaned.dropFirst("https://github.com/".count).components(separatedBy: "/")
            if parts.count >= 2 { return (parts[0], parts[1]) }
        } else if cleaned.hasPrefix("git@github.com:") {
            let parts = cleaned.dropFirst("git@github.com:".count).components(separatedBy: "/")
            if parts.count >= 2 { return (parts[0], parts[1]) }
        }
        return nil
    }

    // MARK: - GitHub API

    private func fetchRepoInfo(owner: String, repo: String, token: String) async -> GitHubRepoInfo? {
        let repoData = await apiGet("https://api.github.com/repos/\(owner)/\(repo)", token: token)
        let runsData = await apiGet("https://api.github.com/repos/\(owner)/\(repo)/actions/runs?per_page=1", token: token)
        let commitsData = await apiGet("https://api.github.com/repos/\(owner)/\(repo)/commits?per_page=5", token: token)

        guard let repoJSON = repoData as? [String: Any] else { return nil }

        let stars = repoJSON["stargazers_count"] as? Int ?? 0
        let forks = repoJSON["forks_count"] as? Int ?? 0
        let openIssuesRaw = repoJSON["open_issues_count"] as? Int ?? 0
        let description = repoJSON["description"] as? String
        let defaultBranch = repoJSON["default_branch"] as? String ?? "main"

        // Fetch PR count separately
        let openPRs = await fetchPRCount(owner: owner, repo: repo, token: token)
        // Issues = total open_issues minus PRs (GitHub counts PRs in open_issues_count)
        let openIssues = max(0, openIssuesRaw - openPRs)

        // Latest CI run
        let latestRun: CIRun?
        if let runsJSON = runsData as? [String: Any],
           let runs = runsJSON["workflow_runs"] as? [[String: Any]],
           let first = runs.first {
            let name = first["name"] as? String ?? "CI"
            let status = first["status"] as? String ?? "unknown"
            let conclusion = first["conclusion"] as? String
            let updatedStr = first["updated_at"] as? String ?? ""
            let updatedAt = ISO8601DateFormatter().date(from: updatedStr) ?? Date()
            latestRun = CIRun(name: name, status: status, conclusion: conclusion, updatedAt: updatedAt)
        } else {
            latestRun = nil
        }

        // Recent commits
        var recentCommits: [GitHubCommit] = []
        if let commitsArray = commitsData as? [[String: Any]] {
            for c in commitsArray.prefix(5) {
                guard let sha = c["sha"] as? String,
                      let commitObj = c["commit"] as? [String: Any],
                      let message = commitObj["message"] as? String else { continue }
                let firstLine = message.components(separatedBy: "\n").first ?? message
                let author = (commitObj["author"] as? [String: Any])?["name"] as? String ?? "Unknown"
                let dateStr = (commitObj["author"] as? [String: Any])?["date"] as? String ?? ""
                let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
                recentCommits.append(GitHubCommit(
                    id: String(sha.prefix(7)),
                    message: firstLine,
                    author: author,
                    date: date
                ))
            }
        }

        return GitHubRepoInfo(
            fullName: "\(owner)/\(repo)",
            description: description,
            stars: stars,
            forks: forks,
            openIssues: openIssues,
            openPRs: openPRs,
            defaultBranch: defaultBranch,
            latestRun: latestRun,
            recentCommits: recentCommits
        )
    }

    private func fetchPRCount(owner: String, repo: String, token: String) async -> Int {
        guard let data = await apiGetRaw(
            "https://api.github.com/repos/\(owner)/\(repo)/pulls?state=open&per_page=100",
            token: token
        ),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        return arr.count
    }

    private func apiGet(_ urlString: String, token: String) async -> Any? {
        guard let data = await apiGetRaw(urlString, token: token) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private func apiGetRaw(_ urlString: String, token: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("ApexNotch/1.0", forHTTPHeaderField: "User-Agent")
        return try? await URLSession.shared.data(for: request).0
    }
}
