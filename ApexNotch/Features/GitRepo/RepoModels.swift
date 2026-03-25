import SwiftUI

// MARK: - RepoSyncState

enum RepoSyncState: Sendable, Equatable {
    case synced     // clean + up to date
    case ahead      // local commits not pushed
    case behind     // remote has commits to pull
    case diverged   // both ahead and behind
    case dirty      // uncommitted changes
    case noUpstream // no tracking branch configured

    var icon: String {
        switch self {
        case .synced:     "checkmark.square"
        case .ahead:      "arrow.up.square"
        case .behind:     "arrow.down.square"
        case .diverged:   "arrow.triangle.branch"
        case .dirty:      "exclamationmark.square"
        case .noUpstream: "questionmark.square"
        }
    }

    var color: Color {
        switch self {
        case .synced:     Color(hex: "#30d158")
        case .ahead:      Color(hex: "#64d2ff")
        case .behind:     Color(hex: "#ffd60a")
        case .diverged:   Color(hex: "#ff9f0a")
        case .dirty:      Color(hex: "#ff453a")
        case .noUpstream: .secondary
        }
    }

    var label: String {
        switch self {
        case .synced:     "Synced"
        case .ahead:      "Ahead"
        case .behind:     "Behind"
        case .diverged:   "Diverged"
        case .dirty:      "Dirty"
        case .noUpstream: "No upstream"
        }
    }
}

// MARK: - RepoStatus

struct RepoStatus: Sendable, Equatable {
    let repoName: String
    let branch: String
    let syncState: RepoSyncState
    let aheadCount: Int
    let behindCount: Int
    let addedCount: Int
    let modifiedCount: Int
    let deletedCount: Int

    var dirtyCount: Int { addedCount + modifiedCount + deletedCount }

    /// Compact sync detail, e.g. "↑2 ↓1" or "+3 ~1"
    var syncDetail: String {
        var parts: [String] = []
        if aheadCount  > 0 { parts.append("↑\(aheadCount)") }
        if behindCount > 0 { parts.append("↓\(behindCount)") }
        if addedCount    > 0 { parts.append("+\(addedCount)") }
        if modifiedCount > 0 { parts.append("~\(modifiedCount)") }
        if deletedCount  > 0 { parts.append("-\(deletedCount)") }
        return parts.joined(separator: " ")
    }
}
