import Foundation

struct GitHubRepoInfo: Sendable {
    let fullName: String       // "owner/repo"
    let description: String?
    let stars: Int
    let forks: Int
    let openIssues: Int
    let openPRs: Int
    let defaultBranch: String
    let latestRun: CIRun?
    let recentCommits: [GitHubCommit]
}

struct CIRun: Sendable {
    let name: String
    let status: String      // "queued" | "in_progress" | "completed"
    let conclusion: String? // "success" | "failure" | "cancelled" | nil
    let updatedAt: Date

    var isSuccess: Bool { conclusion == "success" }
    var isFailed: Bool { conclusion == "failure" || conclusion == "cancelled" }
    var isRunning: Bool { status != "completed" }
}

struct GitHubCommit: Sendable, Identifiable {
    let id: String   // sha (short)
    let message: String
    let author: String
    let date: Date
}
