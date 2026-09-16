import XCTest
@testable import TeslaBLEKeyKit

final class TeslaPrivateKeyXCTests: XCTestCase {

    func testGenerateProducesValidKey() {
        let key = TeslaPrivateKey.generate()
        XCTAssertEqual(key.rawRepresentation.count, 32)
        XCTAssertEqual(key.publicKey.count, 65)
        XCTAssertEqual(key.publicKey[0], 0x04)
    }

    func testRawRepresentationRoundTrip() throws {
        let original = TeslaPrivateKey.generate()
        let restored = try TeslaPrivateKey(rawRepresentation: original.rawRepresentation)
        XCTAssertEqual(restored.publicKey, original.publicKey)
        XCTAssertEqual(restored.rawRepresentation, original.rawRepresentation)
    }

    func testDERRepresentationRoundTrip() throws {
        let original = TeslaPrivateKey.generate()
        let restored = try TeslaPrivateKey(derRepresentation: original.derRepresentation)
        XCTAssertEqual(restored.publicKey, original.publicKey)
    }

    func testPEMRepresentationRoundTrip() throws {
        let original = TeslaPrivateKey.generate()
        let pem = original.pemRepresentation
        XCTAssertTrue(pem.hasPrefix("-----BEGIN PRIVATE KEY-----"))
        XCTAssertTrue(pem.hasSuffix("-----END PRIVATE KEY-----\n") || pem.hasSuffix("-----END PRIVATE KEY-----"))
        let restored = try TeslaPrivateKey(pemRepresentation: pem)
        XCTAssertEqual(restored.publicKey, original.publicKey)
    }

    func testTwoKeysAreDifferent() {
        let key1 = TeslaPrivateKey.generate()
        let key2 = TeslaPrivateKey.generate()
        XCTAssertNotEqual(key1.publicKey, key2.publicKey)
        XCTAssertNotEqual(key1.rawRepresentation, key2.rawRepresentation)
    }

    func testSharedAESKeyLength() throws {
        let alice = TeslaPrivateKey.generate()
        let bob = TeslaPrivateKey.generate()
        let shared = try alice.sharedAESKey(with: bob.publicKey)
        XCTAssertEqual(shared.count, 16)
    }

    func testSharedAESKeyDeterministic() throws {
        let alice = TeslaPrivateKey.generate()
        let bob = TeslaPrivateKey.generate()
        let shared1 = try alice.sharedAESKey(with: bob.publicKey)
        let shared2 = try alice.sharedAESKey(with: bob.publicKey)
        XCTAssertEqual(shared1, shared2)
    }

    func testSharedAESKeyDiffersPerPeer() throws {
        let alice = TeslaPrivateKey.generate()
        let bob = TeslaPrivateKey.generate()
        let carol = TeslaPrivateKey.generate()
        let sharedAB = try alice.sharedAESKey(with: bob.publicKey)
        let sharedAC = try alice.sharedAESKey(with: carol.publicKey)
        XCTAssertNotEqual(sharedAB, sharedAC)
    }

    func testInvalidRawRepresentationThrows() {
        XCTAssertThrowsError(try TeslaPrivateKey(rawRepresentation: Data([0x01, 0x02])))
        XCTAssertThrowsError(try TeslaPrivateKey(rawRepresentation: Data()))
    }

    func testInvalidPublicKeyForSharedSecret() {
        let key = TeslaPrivateKey.generate()
        XCTAssertThrowsError(try key.sharedAESKey(with: Data([0x04] + [UInt8](repeating: 0, count: 63))))
    }
}

final class VehicleAdvertisementXCTests: XCTestCase {

    func testLocalNameFormat() throws {
        let name = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000000")
        XCTAssertTrue(name.hasPrefix("S"))
        XCTAssertTrue(name.hasSuffix("C"))
        XCTAssertEqual(name.count, 18)
    }

    func testLocalNameDeterministic() throws {
        let vin = "LRW3E7FA5NC000001"
        let name1 = try vehicleLocalName(forVIN: vin)
        let name2 = try vehicleLocalName(forVIN: vin)
        XCTAssertEqual(name1, name2)
    }

    func testDifferentVINsDifferentNames() throws {
        let name1 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000001")
        let name2 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000002")
        XCTAssertNotEqual(name1, name2)
    }

    func testEmptyVINThrows() {
        XCTAssertThrowsError(try vehicleLocalName(forVIN: "")) { error in
            XCTAssertEqual(error as? TeslaError, .invalidVIN)
        }
    }

    func testLocalNameContainsOnlyHexAndPrefixSuffix() throws {
        let name = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000000")
        let hexPart = String(name.dropFirst().dropLast())
        let validHex = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(hexPart.unicodeScalars.allSatisfy { validHex.contains($0) })
    }
}
