import XCTest
@testable import TeslaBLEKeyKit

final class TeslaErrorXCTests: XCTestCase {

    func testMayHaveSucceeded() {
        XCTAssertTrue(TeslaError.timeout.mayHaveSucceeded)
        XCTAssertTrue(TeslaError.protocolFault(0).mayHaveSucceeded)
        XCTAssertTrue(TeslaError.protocolFault(25).mayHaveSucceeded)
        XCTAssertFalse(TeslaError.notConnected.mayHaveSucceeded)
        XCTAssertFalse(TeslaError.invalidVIN.mayHaveSucceeded)
        XCTAssertFalse(TeslaError.protocolFault(3).mayHaveSucceeded)
    }

    func testIsTemporary() {
        XCTAssertTrue(TeslaError.vehicleBusy.isTemporary)
        XCTAssertTrue(TeslaError.scanTimedOut.isTemporary)
        XCTAssertTrue(TeslaError.protocolFault(1).isTemporary)
        XCTAssertTrue(TeslaError.protocolFault(2).isTemporary)
        XCTAssertFalse(TeslaError.invalidVIN.isTemporary)
        XCTAssertFalse(TeslaError.keyNotPaired.isTemporary)
        XCTAssertFalse(TeslaError.timeout.isTemporary)
    }

    func testShouldRetryLogic() {
        XCTAssertTrue(shouldRetry(TeslaError.vehicleBusy))
        XCTAssertTrue(shouldRetry(TeslaError.scanTimedOut))
        XCTAssertFalse(shouldRetry(TeslaError.timeout))
        XCTAssertFalse(shouldRetry(TeslaError.notConnected))
        XCTAssertFalse(shouldRetry(nil))
    }

    func testShouldNotRetryNonProtocolError() {
        struct CustomError: Error {}
        XCTAssertFalse(shouldRetry(CustomError()))
    }

    func testErrorDescriptionsNotNil() {
        let allErrors: [TeslaError] = [
            .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff,
            .bluetoothUnsupported, .scanTimedOut, .vehicleNotFound("VIN"),
            .maxBLEConnectionsExceeded, .notConnected, .invalidVIN,
            .missingCharacteristic, .invalidFrame, .messageTooLarge(500),
            .malformedResponse("test"), .missingPrivateKey,
            .noSession(.vehicleSecurity), .keyNotPaired, .vehicleBusy,
            .replayedResponse, .protocolFault(1), .vcsecError("err"),
            .whitelistError(2), .crypto("fail"), .timeout,
        ]
        for error in allErrors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testEquatable() {
        XCTAssertEqual(TeslaError.timeout, TeslaError.timeout)
        XCTAssertEqual(TeslaError.messageTooLarge(100), TeslaError.messageTooLarge(100))
        XCTAssertNotEqual(TeslaError.messageTooLarge(100), TeslaError.messageTooLarge(200))
        XCTAssertNotEqual(TeslaError.timeout, TeslaError.notConnected)
    }
}

final class MetadataBuilderXCTests: XCTestCase {

    func testChecksumProduces32Bytes() {
        let meta = MetadataBuilder(context: .sha256)
        XCTAssertEqual(meta.checksum().count, 32)
    }

    func testChecksumDiffersWithMessage() throws {
        var meta = MetadataBuilder(context: .sha256)
        try meta.add(.signatureType, value: Data([0x05]))
        let without = meta.checksum()
        let with = meta.checksum(message: Data("msg".utf8))
        XCTAssertNotEqual(without, with)
    }

    func testHMACContextProduces32Bytes() {
        let meta = MetadataBuilder(context: .hmacSHA256(key: Data("secret".utf8)))
        XCTAssertEqual(meta.checksum().count, 32)
    }

    func testTagsMustBeAscending() throws {
        var meta = MetadataBuilder()
        try meta.add(.domain, value: Data([0x01]))
        XCTAssertThrowsError(try meta.add(.signatureType, value: Data([0x02])))
    }

    func testRejectsOversizedValue() {
        var meta = MetadataBuilder()
        let bigValue = Data(repeating: 0xAA, count: 256)
        XCTAssertThrowsError(try meta.add(.signatureType, value: bigValue))
    }

    func testNilValueIsSkipped() throws {
        var meta = MetadataBuilder()
        try meta.add(.signatureType, value: nil)
        try meta.add(.signatureType, value: Data([0x01]))
    }

    func testAddUInt32() throws {
        var meta = MetadataBuilder()
        try meta.addUInt32(.counter, value: 42)
        let checksum = meta.checksum()
        XCTAssertEqual(checksum.count, 32)
    }
}

final class DataUtilitiesXCTests: XCTestCase {

    func testUInt32BigEndian() {
        XCTAssertEqual(Data(uint32BigEndian: 0x01020304), Data([0x01, 0x02, 0x03, 0x04]))
        XCTAssertEqual(Data(uint32BigEndian: 0), Data([0x00, 0x00, 0x00, 0x00]))
        XCTAssertEqual(Data(uint32BigEndian: UInt32.max), Data([0xFF, 0xFF, 0xFF, 0xFF]))
    }

    func testAppendUInt32BigEndian() {
        var data = Data()
        data.appendUInt32BigEndian(1)
        XCTAssertEqual(data, Data([0x00, 0x00, 0x00, 0x01]))
    }

    func testAppendUInt64BigEndian() {
        var data = Data()
        data.appendUInt64BigEndian(1)
        XCTAssertEqual(data, Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]))
    }

    func testSHA1KnownVector() {
        let data = Data("abc".utf8)
        let digest = data.sha1Digest()
        XCTAssertEqual(digest.count, 20)
        XCTAssertEqual(digest.hexString(), "a9993e364706816aba3e25717850c26c9cd0d89d")
    }

    func testSHA256KnownVector() {
        let data = Data("abc".utf8)
        let digest = data.sha256Digest()
        XCTAssertEqual(digest.hexString(), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testHexString() {
        XCTAssertEqual(Data([0x00, 0xFF, 0x0A, 0xBC]).hexString(), "00ff0abc")
        XCTAssertEqual(Data().hexString(), "")
    }

    func testConstantTimeEquals() {
        let a = Data([0x01, 0x02, 0x03])
        XCTAssertTrue(a.constantTimeEquals(a))
        XCTAssertTrue(a.constantTimeEquals(Data([0x01, 0x02, 0x03])))
        XCTAssertFalse(a.constantTimeEquals(Data([0x01, 0x02, 0x04])))
        XCTAssertFalse(a.constantTimeEquals(Data([0x01, 0x02])))
    }

    func testXORInPlace() {
        var a: [UInt8] = [0xFF, 0x00, 0xAA, 0x55]
        a.xorInPlace([0xFF, 0xFF, 0x55, 0xAA])
        XCTAssertEqual(a, [0x00, 0xFF, 0xFF, 0xFF])
    }

    func testRandomDataLength() throws {
        for length in [0, 1, 16, 32, 64, 128] {
            let data = try ByteUtilities.randomData(count: length)
            XCTAssertEqual(data.count, length)
        }
    }

    func testRandomBytesLength() throws {
        let bytes = try ByteUtilities.randomBytes(count: 24)
        XCTAssertEqual(bytes.count, 24)
    }
}
