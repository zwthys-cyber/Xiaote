import Foundation

/// Owns the one and only stream iterator. Timing out one request cancels its
/// waiter, never AsyncStream.next(), which would terminate the shared stream.
actor LegacyMessageInbox {
    enum InboxError: Error { case timedOut, closed }
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Data, Error>
        var timeout: Task<Void, Never>?
    }
    private let stream: AsyncStream<Data>
    private var receiver: Task<Void, Never>?
    private var buffer: [Data] = []
    private var waiters: [Waiter] = []
    private var finished = false

    init(stream: AsyncStream<Data>) { self.stream = stream }
    deinit { receiver?.cancel() }

    func next(timeout: TimeInterval? = nil) async throws -> Data {
        try Task.checkCancellation()
        if !buffer.isEmpty { return buffer.removeFirst() }
        guard !finished else { throw InboxError.closed }
        if receiver == nil {
            let stream = self.stream
            receiver = Task { [weak self] in
                for await message in stream {
                    guard !Task.isCancelled else { break }
                    await self?.receive(message)
                }
                await self?.close()
            }
        }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                var waiter = Waiter(id: id, continuation: continuation)
                if let timeout {
                    waiter.timeout = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(timeout)) } catch { return }
                        await self?.remove(id, error: InboxError.timedOut)
                    }
                }
                waiters.append(waiter)
            }
        } onCancel: {
            Task { await self.remove(id, error: CancellationError()) }
        }
    }

    func close() {
        guard !finished else { return }
        finished = true
        receiver?.cancel()
        receiver = nil
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.timeout?.cancel(); waiter.continuation.resume(throwing: InboxError.closed) }
    }

    private func receive(_ message: Data) {
        guard !finished else { return }
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.timeout?.cancel()
            waiter.continuation.resume(returning: message)
        } else {
            // Fail closed on an unexpected burst instead of silently dropping
            // an authentication challenge or allowing unbounded allocation.
            guard buffer.count < 64 else { close(); return }
            buffer.append(message)
        }
    }

    private func remove(_ id: UUID, error: Error) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.timeout?.cancel()
        waiter.continuation.resume(throwing: error)
    }
}
