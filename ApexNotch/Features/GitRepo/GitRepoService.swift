import Foundation

// MARK: - GitRepoService
// Detects the active Claude Code project by reading the `cwd` field from
// the most-recently-modified JSONL file under ~/.claude/projects/, then
// polls git status for that directory every 3 seconds.

actor GitRepoService {

    private var onUpdate: (@Sendable (RepoStatus?) -> Void)?

    func setCallback(_ callback: @escaping @Sendable (RepoStatus?) async -> Void) {
        onUpdate = { (status: RepoStatus?) in Task { await callback(status) } }
    }

    private let projectsDir: URL
    private var pollTask: Task<Void, Never>?

    init() {
        projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    // MARK: - Public API

    func start() async {
        await poll()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.poll()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Core

    private func poll() async {
        let status = await currentStatus()
        onUpdate?(status)
    }

    private func currentStatus() async -> RepoStatus? {
        guard let jsonlFile = mostRecentJSONL(),
              let projectDir = cwdFromJSONL(jsonlFile) else { return nil }
        return await gitStatus(at: projectDir)
    }

    // MARK: - JSONL discovery

    /// Finds the most recently modified JSONL under ~/.claude/projects/
    private func mostRecentJSONL() -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var best: (URL, Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if best == nil || mod > best!.1 { best = (url, mod) }
        }
        return best?.0
    }

    /// Reads the tail of a JSONL file to extract the most recent `cwd` field.
    /// Claude Code JSONL entries look like: {"cwd":"/path/to/project","gitBranch":"main",...}
    private func cwdFromJSONL(_ jsonlFile: URL) -> URL? {
        guard let fh = try? FileHandle(forReadingFrom: jsonlFile) else { return nil }
        defer { try? fh.close() }

        // Seek to last 8 KB — enough for several recent entries
        let tailSize: UInt64 = 8192
        let fileSize = (try? fh.seekToEnd()) ?? 0
        let offset = fileSize > tailSize ? fileSize - tailSize : 0
        try? fh.seek(toOffset: offset)
        guard let data = try? fh.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return nil }

        // Scan lines from the end; first valid cwd wins
        for line in text.components(separatedBy: "\n").reversed() {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let cwd = json["cwd"] as? String, !cwd.isEmpty else { continue }
            if FileManager.default.fileExists(atPath: cwd) {
                return URL(fileURLWithPath: cwd)
            }
        }
        return nil
    }

    // MARK: - Git commands

    private func gitStatus(at dir: URL) async -> RepoStatus? {
        let p = dir.path.replacingOccurrences(of: "'", with: "'\\''")

        // Confirm git repo + get root (handles cwd being a parent of the actual repo)
        let root = await ShellRunner.run("git -C '\(p)' rev-parse --show-toplevel 2>/dev/null")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else { return nil }

        let repoName = URL(fileURLWithPath: root).lastPathComponent

        // Branch
        let branch = await ShellRunner.run(
            "git -C '\(p)' rev-parse --abbrev-ref HEAD 2>/dev/null"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Ahead / behind
        let aheadBehindRaw = await ShellRunner.run(
            "git -C '\(p)' rev-list --left-right --count @{u}...HEAD 2>/dev/null"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        var aheadCount = 0, behindCount = 0, hasUpstream = false
        let parts = aheadBehindRaw.components(separatedBy: "\t")
        if parts.count == 2, let b = Int(parts[0]), let a = Int(parts[1]) {
            behindCount = b; aheadCount = a; hasUpstream = true
        }

        // Dirty files  (--porcelain gives 2-char XY status per line)
        let porcelain = await ShellRunner.run(
            "git -C '\(p)' status --porcelain 2>/dev/null"
        )
        var added = 0, modified = 0, deleted = 0
        for line in porcelain.components(separatedBy: "\n") {
            guard line.count >= 2 else { continue }
            let xy = String(line.prefix(2))
            if xy.contains("?") || xy.contains("A") { added    += 1 }
            else if xy.contains("D")                 { deleted  += 1 }
            else if !xy.trimmingCharacters(in: .whitespaces).isEmpty { modified += 1 }
        }

        let isDirty = (added + modified + deleted) > 0
        let syncState: RepoSyncState
        switch (isDirty, hasUpstream, aheadCount > 0, behindCount > 0) {
        case (true,  _,     _,    _):    syncState = .dirty
        case (false, false, _,    _):    syncState = .noUpstream
        case (false, true,  true, true): syncState = .diverged
        case (false, true,  true, false):syncState = .ahead
        case (false, true,  false, true):syncState = .behind
        default:                         syncState = .synced
        }

        return RepoStatus(
            repoName: repoName,
            branch: branch.isEmpty ? "HEAD" : branch,
            syncState: syncState,
            aheadCount: aheadCount,
            behindCount: behindCount,
            addedCount: added,
            modifiedCount: modified,
            deletedCount: deleted
        )
    }
}
