import Foundation

// MARK: - ClaudeLogWatcher

actor ClaudeLogWatcher {

    // Called on the actor's executor whenever new data is parsed.
    var onUpdate: (@Sendable ([ToolCall], Int, Date) -> Void)?

    private let logsDirectory: URL
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var directoryFD: Int32 = -1
    private var isWatching = false

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        logsDirectory = home.appendingPathComponent(".claude/logs", isDirectory: true)
    }

    // MARK: - Public API

    func startWatching() async {
        guard !isWatching else { return }

        // Ensure directory exists
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: logsDirectory.path, isDirectory: &isDir),
              isDir.boolValue else {
            // Directory doesn't exist yet; poll every 10s until it appears
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    var d: ObjCBool = false
                    if FileManager.default.fileExists(atPath: self.logsDirectory.path, isDirectory: &d),
                       d.boolValue {
                        await self.startWatching()
                        break
                    }
                }
            }
            return
        }

        isWatching = true
        // Initial parse
        await performUpdate()

        // Set up DispatchSource for directory change monitoring
        let fd = open(logsDirectory.path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .link],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                await self.performUpdate()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            Task {
                let fd = await self.directoryFD
                if fd >= 0 { close(fd) }
            }
        }

        source.resume()
        dispatchSource = source
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
        isWatching = false
    }

    // MARK: - Parsing

    private func performUpdate() async {
        guard let (tools, tokens, lastActivity) = await parseLatestLog() else { return }
        onUpdate?(tools, tokens, lastActivity)
    }

    private func mostRecentLogFile() -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        return contents
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url -> (URL, Date)? in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return date.map { (url, $0) }
            }
            .sorted { $0.1 > $1.1 }
            .first?.0
    }

    private func parseLatestLog() async -> ([ToolCall], Int, Date)? {
        guard let logFile = mostRecentLogFile() else { return nil }

        var rawContent: String
        do {
            rawContent = try String(contentsOf: logFile, encoding: .utf8)
        } catch {
            return nil
        }

        var toolCalls: [ToolCall] = []
        var totalTokens = 0
        var lastActivity = Date.distantPast

        let lines = rawContent.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Track timestamp of this entry
            if let tsString = json["timestamp"] as? String {
                if let date = ISO8601DateFormatter().date(from: tsString) {
                    if date > lastActivity { lastActivity = date }
                }
            }

            // Look for tool_use in assistant messages
            // Pattern: {"type":"assistant","message":{"content":[{"type":"tool_use","name":"...","input":{}}]}}
            if let messageDict = json["message"] as? [String: Any],
               let contentArray = messageDict["content"] as? [[String: Any]] {
                for item in contentArray {
                    if let itemType = item["type"] as? String, itemType == "tool_use",
                       let name = item["name"] as? String {
                        let inputDict = item["input"] as? [String: Any]
                        let argsSummary = abbreviateArguments(inputDict)
                        let call = ToolCall(
                            id: UUID(),
                            toolName: name,
                            arguments: argsSummary,
                            status: .completed,
                            startedAt: lastActivity == .distantPast ? Date() : lastActivity,
                            endedAt: lastActivity == .distantPast ? Date() : lastActivity
                        )
                        toolCalls.append(call)
                    }
                }

                // Token counts
                if let usage = messageDict["usage"] as? [String: Any] {
                    let input  = usage["input_tokens"]  as? Int ?? 0
                    let output = usage["output_tokens"] as? Int ?? 0
                    totalTokens += input + output
                }
            }

            // Alternative flat structure: {"type":"tool_use","name":"..."}
            if let entryType = json["type"] as? String, entryType == "tool_use",
               let name = json["name"] as? String {
                let inputDict = json["input"] as? [String: Any]
                let argsSummary = abbreviateArguments(inputDict)
                let call = ToolCall(
                    id: UUID(),
                    toolName: name,
                    arguments: argsSummary,
                    status: .completed,
                    startedAt: lastActivity == .distantPast ? Date() : lastActivity,
                    endedAt: lastActivity == .distantPast ? Date() : lastActivity
                )
                toolCalls.append(call)
            }

            // Top-level usage field
            if let usage = json["usage"] as? [String: Any] {
                let input  = usage["input_tokens"]  as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                totalTokens += input + output
            }
        }

        let finalActivity = lastActivity == .distantPast ? Date() : lastActivity
        // Return last 20 tool calls at most
        let recentTools = Array(toolCalls.suffix(20))
        return (recentTools, totalTokens, finalActivity)
    }

    // MARK: - Helpers

    private func abbreviateArguments(_ input: [String: Any]?) -> String {
        guard let input, !input.isEmpty else { return "" }
        // Show the first key-value pair, truncated
        if let (key, value) = input.first {
            let valueStr = "\(value)"
            let truncated = valueStr.count > 60 ? String(valueStr.prefix(60)) + "…" : valueStr
            return "\(key): \(truncated)"
        }
        return ""
    }
}
