import Foundation

// MARK: - ClaudeUsageParser

actor ClaudeUsageParser {

    private let claudeDirectory: URL

    /// Approximate cost per 1M tokens (blended input+output, claude-3.5-sonnet estimate)
    private static let costPer1MTokens: Double = 4.50

    init() {
        claudeDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
    }

    // MARK: - Public API

    func parse() async -> UsageSnapshot? {
        // Collect all JSONL entries from ~/.claude/ and subdirectories
        var entries: [UsageEntry] = []

        // 1. Try ~/.claude/usage.json or similar flat file first
        if let flatEntries = parseUsageJSON() {
            entries.append(contentsOf: flatEntries)
        }

        // 2. Walk JSONL files in ~/.claude/ (logs subdirectory included)
        let jsonlEntries = parseAllJSONL()
        entries.append(contentsOf: jsonlEntries)

        guard !entries.isEmpty else { return nil }

        // Filter to 5-hour rolling window
        let windowEnd = Date()
        let windowStart = windowEnd.addingTimeInterval(-5 * 3600)
        let windowEntries = entries.filter { $0.timestamp >= windowStart }

        let inputTokens  = windowEntries.reduce(0) { $0 + $1.inputTokens }
        let outputTokens = windowEntries.reduce(0) { $0 + $1.outputTokens }
        let total = inputTokens + outputTokens

        guard total > 0 else { return nil }

        // Detect model from most recent entry
        let model = entries
            .sorted { $0.timestamp > $1.timestamp }
            .first?.model ?? "claude-3-5-sonnet"

        // Rough cost estimate
        let cost = Double(total) / 1_000_000.0 * Self.costPer1MTokens

        return UsageSnapshot(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            windowStart: windowStart,
            windowEnd: windowEnd,
            estimatedCost: cost,
            model: model
        )
    }

    // MARK: - Parsing Helpers

    private struct UsageEntry {
        let timestamp: Date
        let inputTokens: Int
        let outputTokens: Int
        let model: String
    }

    private func parseUsageJSON() -> [UsageEntry]? {
        // Try common flat usage file paths
        let candidates = [
            claudeDirectory.appendingPathComponent("usage.json"),
            claudeDirectory.appendingPathComponent("usage.jsonl")
        ]
        for url in candidates {
            if let data = try? Data(contentsOf: url) {
                if let entries = parseJSONLData(data) {
                    return entries
                }
                // Try as a JSON array
                if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    return array.compactMap { entryFromDict($0) }
                }
            }
        }
        return nil
    }

    private func parseAllJSONL() -> [UsageEntry] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: claudeDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [UsageEntry] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if let data = try? Data(contentsOf: url),
               let entries = parseJSONLData(data) {
                result.append(contentsOf: entries)
            }
        }
        return result
    }

    private func parseJSONLData(_ data: Data) -> [UsageEntry]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var entries: [UsageEntry] = []
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            if let entry = entryFromDict(json, iso: iso, isoBasic: isoBasic) {
                entries.append(entry)
            }
        }
        return entries.isEmpty ? nil : entries
    }

    private func entryFromDict(
        _ json: [String: Any],
        iso: ISO8601DateFormatter = ISO8601DateFormatter(),
        isoBasic: ISO8601DateFormatter = ISO8601DateFormatter()
    ) -> UsageEntry? {
        // Resolve timestamp
        var timestamp = Date()
        if let tsString = json["timestamp"] as? String {
            timestamp = iso.date(from: tsString)
                ?? isoBasic.date(from: tsString)
                ?? Date()
        }

        // Look for usage in nested message.usage or top-level usage
        var inputTokens = 0
        var outputTokens = 0
        var model = "claude-3-5-sonnet"

        func extractUsage(_ dict: [String: Any]) {
            if let u = dict["usage"] as? [String: Any] {
                inputTokens  += u["input_tokens"]  as? Int ?? 0
                outputTokens += u["output_tokens"] as? Int ?? 0
            }
        }

        // Top-level usage
        extractUsage(json)

        // message.usage
        if let msg = json["message"] as? [String: Any] {
            extractUsage(msg)
            if let m = msg["model"] as? String { model = m }
        }

        // Direct token fields (some formats)
        if inputTokens == 0 {
            inputTokens  = json["input_tokens"]  as? Int ?? 0
            outputTokens = json["output_tokens"] as? Int ?? 0
        }

        if let m = json["model"] as? String { model = m }

        guard inputTokens > 0 || outputTokens > 0 else { return nil }
        return UsageEntry(timestamp: timestamp, inputTokens: inputTokens, outputTokens: outputTokens, model: model)
    }
}
