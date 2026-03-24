import SwiftUI

enum AppSignal: Sendable {
    case idle
    case agentActive
    case agentStalled
    case processCrash(String)
    case quotaWarning
    case fileStashed

    var color: Color {
        switch self {
        case .idle:            return .green
        case .agentActive:     return .green
        case .agentStalled:    return .yellow
        case .processCrash:    return .red
        case .quotaWarning:    return .orange
        case .fileStashed:     return .purple
        }
    }

    var pulseSpeed: Double {
        switch self {
        case .idle:            return 0.6
        case .agentActive:     return 1.2
        case .agentStalled:    return 2.5
        case .processCrash:    return 4.0
        case .quotaWarning:    return 1.8
        case .fileStashed:     return 1.0
        }
    }
}
