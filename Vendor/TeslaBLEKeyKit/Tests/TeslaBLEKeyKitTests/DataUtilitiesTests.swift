import Testing
import Foundation
@testable import TeslaBLEKeyKit

// MARK: - DataUtilities Tests

@Suite("DataUtilities")
struct DataUtilitiesTests {
    @Test("Data uint32 big endian encoding")
    func uint32BigEndian() {
        let data = Data(uint32BigEndian: 0x01020304)
        #expect(data == Data([0x01, 0x02, 0x03, 0x04]))
    }

    @Test("Data uint32 big endian zero")
    func uint32BigEndianZero() {
        let data = Data(uint32BigEndian: 0)
        #expect(data == Data([0x00, 0x00, 0x00, 0x00]))
    }

    @Test("Append uint32 big endian")
    func appendUInt32() {
        var data = Data([0xFF])
        data.appendUInt32BigEndian(256)
        #expect(data == Data([0xFF, 0x00, 0x00, 0x01, 0x00]))
    }

    @Test("SHA256 digest produces 32 bytes")
    func sha256Length() {
        let data = Data("hello".utf8)
        let digest = data.sha256Digest()
        #expect(digest.count == 32)
    }

    @Test("SHA256 digest is deterministic")
    func sha256Deterministic() {
        let data = Data("test".utf8)
        #expect(data.sha256Digest() == data.sha256Digest())
    }

    @Test("SHA1 digest produces 20 bytes")
    func sha1Length() {
        let data = Data("hello".utf8)
        let digest = data.sha1Digest()
        #expect(digest.count == 20)
    }

    @Test("HMAC-SHA256 produces 32 bytes")
    func hmacSHA256Length() {
        let data = Data("message".utf8)
        let key = Data("secret".utf8)
        let mac = data.hmacSHA256(key: key)
        #expect(mac.count == 32)
    }

    @Test("HMAC-SHA256 is deterministic")
    func hmacSHA256Deterministic() {
        let data = Data("message".utf8)
        let key = Data("key".utf8)
        #expect(data.hmacSHA256(key: key) == data.hmacSHA256(key: key))
    }

    @Test("Constant time equals with identical data")
    func constantTimeEqualsIdentical() {
        let a = Data([0x01, 0x02, 0x03])
        #expect(a.constantTimeEquals(a) == true)
    }

    @Test("Constant time equals with different data")
    func constantTimeEqualsDifferent() {
        let a = Data([0x01, 0x02, 0x03])
        let b = Data([0x01, 0x02, 0x04])
        #expect(a.constantTimeEquals(b) == false)
    }

    @Test("Constant time equals with different lengths")
    func constantTimeEqualsDifferentLength() {
        let a = Data([0x01, 0x02])
        let b = Data([0x01, 0x02, 0x03])
        #expect(a.constantTimeEquals(b) == false)
    }

    @Test("Hex string encoding")
    func hexString() {
        let data = Data([0x0A, 0xFF, 0x00, 0x1B])
        #expect(data.hexString() == "0aff001b")
    }

    @Test("XOR in place")
    func xorInPlace() {
        var a: [UInt8] = [0xFF, 0x00, 0xAA]
        let b: [UInt8] = [0x0F, 0xF0, 0x55]
        a.xorInPlace(b)
        #expect(a == [0xF0, 0xF0, 0xFF])
    }

    @Test("Random data produces correct length")
    func randomDataLength() throws {
        let data = try ByteUtilities.randomData(count: 32)
        #expect(data.count == 32)
    }

    @Test("Random data is not all zeros")
    func randomDataNotZero() throws {
        let data = try ByteUtilities.randomData(count: 16)
        #expect(data != Data(repeating: 0, count: 16))
    }

    @Test("Append uint64 big endian")
    func appendUInt64BigEndian() {
        var data = Data([0xFF])
        data.appendUInt64BigEndian(0x0102030405060708)
        #expect(data == Data([0xFF, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]))
    }

    @Test("Append uint64 big endian zero")
    func appendUInt64BigEndianZero() {
        var data = Data()
        data.appendUInt64BigEndian(0)
        #expect(data == Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
    }

    @Test("SHA1 known vector: 'abc'")
    func sha1KnownVector() {
        let data = Data("abc".utf8)
        let digest = data.sha1Digest()
        #expect(digest.hexString() == "a9993e364706816aba3e25717850c26c9cd0d89d")
    }
}
