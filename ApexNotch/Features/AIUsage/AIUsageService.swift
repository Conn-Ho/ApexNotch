import Foundation

// MARK: - AIUsageService

actor AIUsageService {

    private let parser = ClaudeUsageParser()
    private var isRunning = false
    private var continuation: AsyncStream<UsageSnapshot?>.Continuation?
    private var stream: AsyncStream<UsageSnapshot?>?

    // MARK: - Public API

    func getSnapshot() async -> UsageSnapshot? {
        return await parser.parse()
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Initial fetch
        let initial = await parser.parse()
        continuation?.yield(initial)

        // Polling loop every 60 seconds
        Task {
            while await self.isRunning {
                try? await Task.sleep(for: .seconds(60))
                guard await self.isRunning else { break }
                let snapshot = await self.parser.parse()
                await self.publish(snapshot)
            }
        }
    }

    func stop() {
        isRunning = false
        continuation?.finish()
        continuation = nil
    }

    /// Returns an AsyncStream that emits whenever the usage snapshot is refreshed.
    func snapshotStream() -> AsyncStream<UsageSnapshot?> {
        if let existing = stream {
            return existing
        }
        let (newStream, cont) = AsyncStream<UsageSnapshot?>.makeStream()
        self.stream = newStream
        self.continuation = cont
        return newStream
    }

    // MARK: - Internal

    private func publish(_ snapshot: UsageSnapshot?) {
        continuation?.yield(snapshot)
    }
}
