import Foundation

enum ShellRunner {
    static func run(_ command: String) async -> String {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", command]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
