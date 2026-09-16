import Testing
import Foundation
@testable import TeslaBLEKeyKit

// MARK: - BLEFramer Tests

@Suite("BLEFramer")
struct BLEFramerTests {
    @Test("Encode produces length-prefixed frame")
    func encodeBasic() throws {
        let message = Data([0x01, 0x02, 0x03])
        let framed = try BLEFramer.encode(message)
        #expect(framed == Data([0x00, 0x03, 0x01, 0x02, 0x03]))
    }

    @Test("Encode empty message")
    func encodeEmpty() throws {
        let framed = try BLEFramer.encode(Data())
        #expect(framed == Data([0x00, 0x00]))
    }

    @Test("Encode rejects oversized message")
    func encodeOversized() {
        let oversized = Data(repeating: 0xAA, count: BLEFramer.maximumMessageSize + 1)
        #expect(throws: TeslaError.self) {
            _ = try BLEFramer.encode(oversized)
        }
    }

    @Test("Receive complete single message")
    func receiveSingleMessage() throws {
        var framer = BLEFramer()
        let payload = Data([0x0A, 0x0B, 0x0C])
        let chunk = Data([0x00, 0x03]) + payload
        let messages = try framer.receive(chunk)
        #expect(messages == [payload])
    }

    @Test("Receive fragmented message across chunks")
    func receiveFragmented() throws {
        var framer = BLEFramer()
        let messages1 = try framer.receive(Data([0x00, 0x04, 0x01, 0x02]))
        #expect(messages1.isEmpty)
        let messages2 = try framer.receive(Data([0x03, 0x04]))
        #expect(messages2 == [Data([0x01, 0x02, 0x03, 0x04])])
    }

    @Test("Receive multiple messages in one chunk")
    func receiveMultiple() throws {
        var framer = BLEFramer()
        let chunk = Data([0x00, 0x01, 0xAA, 0x00, 0x02, 0xBB, 0xCC])
        let messages = try framer.receive(chunk)
        #expect(messages == [Data([0xAA]), Data([0xBB, 0xCC])])
    }

    @Test("Chunk timeout resets buffer")
    func chunkTimeout() throws {
        var framer = BLEFramer(chunkTimeout: 0.5)
        let t0 = Date()
        _ = try framer.receive(Data([0x00, 0x04, 0x01, 0x02]), now: t0)
        let t1 = t0.addingTimeInterval(1.0)
        let messages = try framer.receive(Data([0x00, 0x01, 0xFF]), now: t1)
        #expect(messages == [Data([0xFF])])
    }

    @Test("Invalid frame length resets buffer")
    func invalidFrameLength() throws {
        var framer = BLEFramer()
        let oversizedLength = BLEFramer.maximumMessageSize + 1
        let chunk = Data([UInt8((oversizedLength >> 8) & 0xFF), UInt8(oversizedLength & 0xFF)])
        #expect(throws: TeslaError.self) {
            _ = try framer.receive(chunk)
        }
    }
}

// MARK: - SlidingWindow Tests

@Suite("SlidingWindow")
struct SlidingWindowTests {
    @Test("Accepts sequential counters")
    func sequential() {
        var window = SlidingWindow()
        #expect(window.update(1) == true)
        #expect(window.update(2) == true)
        #expect(window.update(3) == true)
    }

    @Test("Rejects duplicate counter")
    func duplicate() {
        var window = SlidingWindow()
        #expect(window.update(5) == true)
        #expect(window.update(5) == false)
    }

    @Test("Accepts out-of-order within window")
    func outOfOrder() {
        var window = SlidingWindow()
        #expect(window.update(10) == true)
        #expect(window.update(8) == true)
        #expect(window.update(9) == true)
    }

    @Test("Rejects counter too far behind")
    func tooOld() {
        var window = SlidingWindow(size: 8)
        #expect(window.update(10) == true)
        #expect(window.update(1) == false)
    }

    @Test("Large jump resets window")
    func largeJump() {
        var window = SlidingWindow(size: 8)
        #expect(window.update(5) == true)
        #expect(window.update(100) == true)
        #expect(window.update(5) == false)
    }
}
