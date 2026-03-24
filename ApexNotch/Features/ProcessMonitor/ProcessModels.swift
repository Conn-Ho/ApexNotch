import Foundation

struct DevProcess: Identifiable, Sendable {
    let id = UUID()
    let pid: Int32
    let ppid: Int32
    let runtime: String
    let memoryMB: Int
    let command: String
    let framework: Framework
    let type: ProcessType

    enum Framework: String, Sendable {
        case nextjs = "Next.js"
        case vite = "Vite"
        case webpack = "Webpack"
        case turborepo = "Turborepo"
        case nodejs = "Node.js"
        case unknown = "Unknown"
    }

    enum ProcessType: String, Sendable {
        case root, frontend, backend, monorepo, buildTool = "build", worker
    }
}

struct ProjectGroup: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let processes: [DevProcess]
    let ports: [Int]
    let isZombie: Bool

    var totalMemoryMB: Int { processes.reduce(0) { $0 + $1.memoryMB } }
    var frameworkNames: String {
        let names = Set(processes.map { $0.framework.rawValue }).filter { $0 != "Unknown" }
        return names.isEmpty ? "Node.js" : names.sorted().joined(separator: ", ")
    }
}
