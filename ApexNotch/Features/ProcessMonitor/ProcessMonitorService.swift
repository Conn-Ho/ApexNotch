import Foundation

actor ProcessMonitorService {
    func scan() async -> [ProjectGroup] {
        async let psOutput = ShellRunner.run(
            "ps -eo pid,ppid,etime,rss,args | grep -E 'node|npm|pnpm|vite|next|tsx|nodemon|webpack|turbo' | grep -v grep"
        )
        async let lsofOutput = ShellRunner.run(
            "lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep -E 'node|npm|pnpm'"
        )
        let (ps, lsof) = await (psOutput, lsofOutput)
        let portMap = parsePortMap(lsof)
        let processes = parseProcesses(ps)
        return groupByProject(processes, portMap: portMap)
    }

    func kill(pid: Int32) async {
        _ = await ShellRunner.run("kill \(pid)")
    }

    // MARK: - Parsing

    private func parsePortMap(_ output: String) -> [Int32: Int] {
        var map: [Int32: Int] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9,
                  let pid = Int32(parts[1]),
                  let portStr = line.range(of: #":(\d+) \(LISTEN\)"#, options: .regularExpression)
                      .map({ String(line[$0]) })
                      .flatMap({ $0.components(separatedBy: CharacterSet.decimalDigits.inverted).first(where: { !$0.isEmpty }) }),
                  let port = Int(portStr) else { continue }
            map[pid] = port
        }
        return map
    }

    private func parseProcesses(_ output: String) -> [DevProcess] {
        var result: [DevProcess] = []
        let regex = try? NSRegularExpression(pattern: #"^(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(.+)$"#)
        for line in output.split(separator: "\n") {
            let str = String(line).trimmingCharacters(in: .whitespaces)
            guard let match = regex?.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
                  match.numberOfRanges == 6 else { continue }

            func group(_ i: Int) -> String {
                guard let r = Range(match.range(at: i), in: str) else { return "" }
                return String(str[r])
            }

            guard let pid = Int32(group(1)),
                  let ppid = Int32(group(2)),
                  let rss = Int(group(4)) else { continue }
            let args = group(5)

            // Filter noise
            guard !args.contains("Electron"),
                  !args.contains("Notion"),
                  !args.contains("Claude"),
                  isDev(args) else { continue }

            result.append(DevProcess(
                pid: pid, ppid: ppid,
                runtime: group(3),
                memoryMB: rss / 1024,
                command: args,
                framework: detectFramework(args),
                type: detectType(args)
            ))
        }
        return result
    }

    private func groupByProject(_ processes: [DevProcess], portMap: [Int32: Int]) -> [ProjectGroup] {
        var map: [String: [DevProcess]] = [:]
        for proc in processes {
            let key = extractPath(proc.command) ?? "unknown"
            map[key, default: []].append(proc)
        }
        return map.map { path, procs in
            let name = path == "unknown" ? "Unknown" : URL(fileURLWithPath: path).lastPathComponent
            let ports = procs.compactMap { portMap[$0.pid] }
            let isZombie = procs.contains { runtimeSeconds($0.runtime) > 86400 }
            return ProjectGroup(name: name, path: path, processes: procs, ports: ports, isZombie: isZombie)
        }.sorted { $0.name < $1.name }
    }

    // MARK: - Helpers

    private func isDev(_ cmd: String) -> Bool {
        ["dev", "start", "vite", "next", "webpack", "nodemon", "tsx watch", "turbo", "serve"]
            .contains { cmd.contains($0) }
    }

    private func extractPath(_ cmd: String) -> String? {
        let pattern = #"/Users/[^\s]+?/(?:Workspace|projects|git)/[^/\s]+"#
        guard let range = cmd.range(of: pattern, options: .regularExpression) else { return nil }
        return String(cmd[range])
    }

    private func detectFramework(_ cmd: String) -> DevProcess.Framework {
        if cmd.contains("next") { return .nextjs }
        if cmd.contains("vite") { return .vite }
        if cmd.contains("webpack") { return .webpack }
        if cmd.contains("turbo") { return .turborepo }
        if cmd.contains("tsx") || cmd.contains("nodemon") { return .nodejs }
        return .unknown
    }

    private func detectType(_ cmd: String) -> DevProcess.ProcessType {
        if cmd.contains("pnpm dev") || cmd.contains("npm run dev") { return .root }
        if cmd.contains("turbo") { return .monorepo }
        if cmd.contains("next") || cmd.contains("vite") { return .frontend }
        if cmd.contains("tsx") || cmd.contains("nodemon") { return .backend }
        if cmd.contains("esbuild") { return .buildTool }
        return .worker
    }

    private func runtimeSeconds(_ time: String) -> Int {
        let parts = time.split(whereSeparator: { $0 == ":" || $0 == "-" }).compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] * 86400 + parts[1] * 3600 + parts[2] * 60
        case 2: return time.contains("-") ? parts[0] * 86400 + parts[1] * 3600 : parts[0] * 3600 + parts[1] * 60
        default: return 0
        }
    }
}
