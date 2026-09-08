import XCTest
@testable import Xiaote

final class LegacyMessageInboxTests: XCTestCase {
    func testTimeoutDoesNotKillTheNextDoorHandleChallenge() async throws {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        let inbox = LegacyMessageInbox(stream: stream)
        do { _ = try await inbox.next(timeout: 0.01); XCTFail("Expected timeout") }
        catch LegacyMessageInbox.InboxError.timedOut { }
        let challenge = Data([3, 20, 1])
        continuation.yield(challenge)
        let received = try await inbox.next(timeout: 1)
        XCTAssertEqual(received, challenge)
        await inbox.close()
    }

    func testCancellingAWaiterDoesNotCancelTheSharedStream() async throws {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        let inbox = LegacyMessageInbox(stream: stream)
        let cancelled = Task { try await inbox.next() }
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
        continuation.yield(Data([42]))
        let value = try await inbox.next(timeout: 1)
        XCTAssertEqual(value, Data([42]))
        await inbox.close()
    }

    func testBackToBackBootstrapAndChallengeStayInOrder() async throws {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        let inbox = LegacyMessageInbox(stream: stream)
        continuation.yield(Data([1]))
        continuation.yield(Data([2]))
        let bootstrap = try await inbox.next(timeout: 1)
        let challenge = try await inbox.next(timeout: 1)
        XCTAssertEqual(bootstrap, Data([1]))
        XCTAssertEqual(challenge, Data([2]))
        continuation.finish()
        do { _ = try await inbox.next(timeout: 1); XCTFail("Ended streams must be reported") }
        catch LegacyMessageInbox.InboxError.closed { }
    }
}
