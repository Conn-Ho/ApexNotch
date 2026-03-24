import SwiftUI

enum AppSignal: Sendable {
    case idle
    case agentActive(toolName: String)
    case agentStalled
    case processCrash(String)
    case quotaWarning
    case fileStashed

    var color: Color {
        switch self {
        case .idle:
            return Color(hex: "#48484a")
        case .agentActive:
            return Color(hex: "#ff9f0a")
        case .agentStalled:
            return Color(hex: "#ff453a")
        case .processCrash:
            return Color(hex: "#ff453a")
        case .quotaWarning:
            return Color(hex: "#ffd60a")
        case .fileStashed:
            return Color(hex: "#30d158")
        }
    }

    var pulseSpeed: Double {
        switch self {
        case .idle:
            return 0.0
        case .agentActive:
            return 1.4
        case .agentStalled:
            return 0.6
        case .processCrash:
            return 0.5
        case .quotaWarning:
            return 0.8
        case .fileStashed:
            return 1.8
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .agentActive(let toolName):
            return toolName
        case .agentStalled:
            return "Stalled"
        case .processCrash(let name):
            return "\(name) crashed"
        case .quotaWarning:
            return "Quota warning"
        case .fileStashed:
            return "Stashed"
        }
    }
}
