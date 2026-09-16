import XCTest
@testable import TeslaBLEKeyKit

final class BLEFramerXCTests: XCTestCase {

    func testEncodeProducesLengthPrefix() throws {
        let message = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let framed = try BLEFramer.encode(message)
        XCTAssertEqual(framed.count, message.count + 2)
        XCTAssertEqual(framed[framed.startIndex], 0x00)
        XCTAssertEqual(framed[framed.index(after: framed.startIndex)], 0x05)
        XCTAssertEqual(Data(framed.dropFirst(2)), message)
    }

    func testEncodeMaximumSizeMessage() throws {
        let message = Data(repeating: 0xAB, count: BLEFramer.maximumMessageSize)
        let framed = try BLEFramer.encode(message)
        XCTAssertEqual(framed.count, BLEFramer.maximumMessageSize + 2)
    }

    func testEncodeRejectsOversizedMessage() {
        let oversized = Data(repeating: 0x00, count: BLEFramer.maximumMessageSize + 1)
        XCTAssertThrowsError(try BLEFramer.encode(oversized)) { error in
            XCTAssertEqual(error as? TeslaError, .messageTooLarge(BLEFramer.maximumMessageSize + 1))
        }
    }

    func testReceiveSingleCompleteMessage() throws {
        var framer = BLEFramer()
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let chunk = Data([0x00, 0x04]) + payload
        let messages = try framer.receive(chunk)
        XCTAssertEqual(messages, [payload])
    }

    func testReceiveIncompleteMessageBuffers() throws {
        var framer = BLEFramer()
        let partial = Data([0x00, 0x05, 0x01, 0x02])
        let messages = try framer.receive(partial)
        XCTAssertTrue(messages.isEmpty)
    }

    func testReceiveCompletesAfterSecondChunk() throws {
        var framer = BLEFramer()
        _ = try framer.receive(Data([0x00, 0x03, 0xAA]))
        let messages = try framer.receive(Data([0xBB, 0xCC]))
        XCTAssertEqual(messages, [Data([0xAA, 0xBB, 0xCC])])
    }

    func testReceiveMultipleMessagesInOneChunk() throws {
        var framer = BLEFramer()
        let chunk = Data([0x00, 0x02, 0x11, 0x22, 0x00, 0x01, 0x33])
        let messages = try framer.receive(chunk)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], Data([0x11, 0x22]))
        XCTAssertEqual(messages[1], Data([0x33]))
    }

    func testReceiveResetsOnTimeout() throws {
        var framer = BLEFramer(chunkTimeout: 0.1)
        let t0 = Date()
        _ = try framer.receive(Data([0x00, 0x05, 0x01]), now: t0)
        let t1 = t0.addingTimeInterval(0.5)
        let messages = try framer.receive(Data([0x00, 0x02, 0xAA, 0xBB]), now: t1)
        XCTAssertEqual(messages, [Data([0xAA, 0xBB])])
    }

    func testReceiveRejectsInvalidLength() {
        var framer = BLEFramer()
        let badLength = BLEFramer.maximumMessageSize + 10
        let chunk = Data([UInt8((badLength >> 8) & 0xFF), UInt8(badLength & 0xFF)])
        XCTAssertThrowsError(try framer.receive(chunk)) { error in
            XCTAssertEqual(error as? TeslaError, .invalidFrame)
        }
    }
}

final class SlidingWindowXCTests: XCTestCase {

    func testSequentialCountersAccepted() {
        var window = SlidingWindow()
        XCTAssertTrue(window.update(1))
        XCTAssertTrue(window.update(2))
        XCTAssertTrue(window.update(3))
        XCTAssertTrue(window.update(4))
    }

    func testDuplicateRejected() {
        var window = SlidingWindow()
        XCTAssertTrue(window.update(10))
        XCTAssertFalse(window.update(10))
    }

    func testOutOfOrderWithinWindow() {
        var window = SlidingWindow(size: 16)
        XCTAssertTrue(window.update(10))
        XCTAssertTrue(window.update(5))
        XCTAssertTrue(window.update(8))
        XCTAssertFalse(window.update(5))
    }

    func testCounterBeyondWindowRejected() {
        var window = SlidingWindow(size: 8)
        XCTAssertTrue(window.update(20))
        XCTAssertFalse(window.update(10))
    }

    func testLargeJumpResetsWindow() {
        var window = SlidingWindow(size: 16)
        XCTAssertTrue(window.update(5))
        XCTAssertTrue(window.update(3))
        XCTAssertTrue(window.update(200))
        XCTAssertFalse(window.update(3))
        XCTAssertFalse(window.update(5))
    }

    func testZeroCounter() {
        var window = SlidingWindow()
        XCTAssertTrue(window.update(0))
        XCTAssertFalse(window.update(0))
    }
}
