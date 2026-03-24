import Foundation

struct UsageSnapshot: Sendable {
    let inputTokens: Int
    let outputTokens: Int
    var totalTokens: Int { inputTokens + outputTokens }

    let windowStart: Date       // 5-hour window start
    let windowEnd: Date         // windowStart + 5h

    /// Progress through the 5-hour window: 0.0 – 1.0
    var windowProgress: Double {
        let total = windowEnd.timeIntervalSince(windowStart)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(windowStart)
        return max(0, min(1, elapsed / total))
    }

    let estimatedCost: Double   // USD
    let model: String
}
