import Foundation

// MARK: - ClaudeLogWatcher
// Watches ~/.claude/projects/ for changes and parses tool calls + token usage
// from the most recently modified JSONL file (Claude Code conversation format).

actor ClaudeLogWatcher {

    var onUpdate: (@Sendable ([ToolCall], Int, Date) -> Void)?

    private let projectsDirectory: URL
    private var pollTask: Task<Void, Never>?
    private var isWatching = false
    private var lastParsedFile: URL?
    private var lastParsedModTime: Date = .distantPast

    init() {
        projectsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    // MARK: - Public API

    func startWatching() async {
        guard !isWatching else { return }
        isWatching = true

        // Initial parse
        await performUpdate()

        // Poll every 2 seconds for new activity
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await self?.performUpdate()
            }
        }
    }

    func stopWatching() {
        pollTask?.cancel()
        pollTask = nil
        isWatching = false
    }

    // MARK: - Core Logic

    private func performUpdate() async {
        guard let result = parseActiveSession() else { return }
        onUpdate?(result.tools, result.tokens, result.lastActivity)
    }

    private struct ParseResult {
        let tools: [ToolCall]
        let tokens: Int
        let lastActivity: Date
    }

    /// Finds the most recently modified JSONL under ~/.claude/projects/ and parses it.
    private func parseActiveSession() -> ParseResult? {
        guard let latestFile = mostRecentJSONL() else { return nil }

        // Only re-parse if file has been modified since last parse
        let modTime = (try? latestFile.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        guard modTime > lastParsedModTime || latestFile != lastParsedFile else { return nil }

        lastParsedFile = latestFile
        lastParsedModTime = modTime

        return parseJSONL(at: latestFile)
    }

    private func mostRecentJSONL() -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var best: (URL, Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if best == nil || mod > best!.1 {
                best = (url, mod)
            }
        }
        return best?.0
    }

    private func parseJSONL(at url: URL) -> ParseResult? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var toolCalls: [ToolCall] = []
        var totalTokens = 0
        var lastActivity = Date.distantPast
        let iso = ISO8601DateFormatter()

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Track timestamp
            if let ts = json["timestamp"] as? String,
               let date = iso.date(from: ts), date > lastActivity {
                lastActivity = date
            }

            guard let msg = json["message"] as? [String: Any] else { continue }

            // Tool use entries in assistant messages
            if let content = msg["content"] as? [[String: Any]] {
                for item in content {
                    guard let itemType = item["type"] as? String,
                          itemType == "tool_use",
                          let name = item["name"] as? String else { continue }

                    let args = abbreviate(item["input"] as? [String: Any])
                    let ts   = lastActivity == .distantPast ? Date() : lastActivity
                    toolCalls.append(ToolCall(
                        id: UUID(), toolName: name, arguments: args,
                        status: .completed, startedAt: ts, endedAt: ts
                    ))
                }
            }

            // Token counts (include cache tokens for accurate total)
            if let usage = msg["usage"] as? [String: Any] {
                totalTokens += usage["input_tokens"]                as? Int ?? 0
                totalTokens += usage["output_tokens"]               as? Int ?? 0
                totalTokens += usage["cache_read_input_tokens"]     as? Int ?? 0
                totalTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
            }
        }

        guard !toolCalls.isEmpty || totalTokens > 0 else { return nil }
        let activity = lastActivity == .distantPast ? Date() : lastActivity
        return ParseResult(tools: Array(toolCalls.suffix(20)), tokens: totalTokens, lastActivity: activity)
    }

    private func abbreviate(_ input: [String: Any]?) -> String {
        guard let input, let (key, val) = input.first else { return "" }
        let s = "\(val)"
        return "\(key): \(s.count > 60 ? String(s.prefix(60)) + "…" : s)"
    }
}
