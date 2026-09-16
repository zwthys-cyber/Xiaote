import Testing
import Foundation
@testable import TeslaBLEKeyKit

// MARK: - TeslaPrivateKey Tests

@Suite("TeslaPrivateKey")
struct TeslaPrivateKeyTests {
    @Test("Generate produces valid key")
    func generate() {
        let key = TeslaPrivateKey.generate()
        #expect(key.rawRepresentation.count == 32)
        #expect(!key.publicKey.isEmpty)
    }

    @Test("Public key is 65 bytes (uncompressed P-256)")
    func publicKeyLength() {
        let key = TeslaPrivateKey.generate()
        #expect(key.publicKey.count == 65)
    }

    @Test("Round-trip via raw representation")
    func rawRoundTrip() throws {
        let original = TeslaPrivateKey.generate()
        let restored = try TeslaPrivateKey(rawRepresentation: original.rawRepresentation)
        #expect(restored.publicKey == original.publicKey)
    }

    @Test("Round-trip via DER representation")
    func derRoundTrip() throws {
        let original = TeslaPrivateKey.generate()
        let restored = try TeslaPrivateKey(derRepresentation: original.derRepresentation)
        #expect(restored.publicKey == original.publicKey)
    }

    @Test("Round-trip via PEM representation")
    func pemRoundTrip() throws {
        let original = TeslaPrivateKey.generate()
        let restored = try TeslaPrivateKey(pemRepresentation: original.pemRepresentation)
        #expect(restored.publicKey == original.publicKey)
    }

    @Test("Two generated keys are different")
    func uniqueKeys() {
        let key1 = TeslaPrivateKey.generate()
        let key2 = TeslaPrivateKey.generate()
        #expect(key1.publicKey != key2.publicKey)
    }

    @Test("Shared AES key is deterministic for same key pair")
    func sharedKeyDeterministic() throws {
        let alice = TeslaPrivateKey.generate()
        let bob = TeslaPrivateKey.generate()
        let shared1 = try alice.sharedAESKey(with: bob.publicKey)
        let shared2 = try alice.sharedAESKey(with: bob.publicKey)
        #expect(shared1 == shared2)
    }

    @Test("Shared AES key is 16 bytes")
    func sharedKeyLength() throws {
        let alice = TeslaPrivateKey.generate()
        let bob = TeslaPrivateKey.generate()
        let shared = try alice.sharedAESKey(with: bob.publicKey)
        #expect(shared.count == 16)
    }

    @Test("Invalid raw representation throws")
    func invalidRaw() {
        #expect(throws: Error.self) {
            _ = try TeslaPrivateKey(rawRepresentation: Data([0x01, 0x02, 0x03]))
        }
    }
}

// MARK: - VehicleAdvertisement Tests

@Suite("VehicleAdvertisement")
struct VehicleAdvertisementTests {
    @Test("Vehicle local name from VIN")
    func localNameFromVIN() throws {
        let name = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000000")
        #expect(name.hasPrefix("S"))
        #expect(name.hasSuffix("C"))
        #expect(name.count == 18)
    }

    @Test("Same VIN produces same local name")
    func localNameDeterministic() throws {
        let name1 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000000")
        let name2 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000000")
        #expect(name1 == name2)
    }

    @Test("Different VINs produce different local names")
    func localNameUnique() throws {
        let name1 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000001")
        let name2 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000002")
        #expect(name1 != name2)
    }

    @Test("Empty VIN throws invalidVIN")
    func emptyVIN() {
        #expect(throws: TeslaError.self) {
            _ = try vehicleLocalName(forVIN: "")
        }
    }

    @Test("Known VIN produces exact local name")
    func knownVINLocalName() throws {
        let name = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000000")
        #expect(name == "S9f2bfe28ae1284efC")
    }
}

// MARK: - TeslaError Tests

@Suite("TeslaError")
struct TeslaErrorTests {
    @Test("Timeout may have succeeded")
    func timeoutMayHaveSucceeded() {
        #expect(TeslaError.timeout.mayHaveSucceeded == true)
    }

    @Test("Not connected has not succeeded")
    func notConnectedNotSucceeded() {
        #expect(TeslaError.notConnected.mayHaveSucceeded == false)
    }

    @Test("Vehicle busy is temporary")
    func vehicleBusyIsTemporary() {
        #expect(TeslaError.vehicleBusy.isTemporary == true)
    }

    @Test("Invalid VIN is not temporary")
    func invalidVINNotTemporary() {
        #expect(TeslaError.invalidVIN.isTemporary == false)
    }

    @Test("shouldRetry returns true for temporary non-succeeded errors")
    func shouldRetryTemporary() {
        #expect(shouldRetry(TeslaError.vehicleBusy) == true)
    }

    @Test("shouldRetry returns false for timeout")
    func shouldRetryTimeout() {
        #expect(shouldRetry(TeslaError.timeout) == false)
    }

    @Test("shouldRetry returns false for nil")
    func shouldRetryNil() {
        #expect(shouldRetry(nil) == false)
    }

    @Test("Error descriptions are not empty")
    func errorDescriptions() {
        let errors: [TeslaError] = [
            .bluetoothUnavailable, .notConnected, .invalidVIN,
            .timeout, .messageTooLarge(100), .crypto("test"),
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("protocolFault(0) mayHaveSucceeded is true")
    func protocolFaultZeroMayHaveSucceeded() {
        #expect(TeslaError.protocolFault(0).mayHaveSucceeded == true)
    }

    @Test("protocolFault(25) mayHaveSucceeded is true")
    func protocolFault25MayHaveSucceeded() {
        #expect(TeslaError.protocolFault(25).mayHaveSucceeded == true)
    }

    @Test("protocolFault(3) mayHaveSucceeded is false")
    func protocolFault3NotMayHaveSucceeded() {
        #expect(TeslaError.protocolFault(3).mayHaveSucceeded == false)
    }

    @Test("Temporary fault codes [1,2,5,6,11,15,17,20] are all isTemporary")
    func temporaryFaultCodes() {
        let temporaryCodes = [1, 2, 5, 6, 11, 15, 17, 20]
        for code in temporaryCodes {
            #expect(TeslaError.protocolFault(code).isTemporary == true, "Expected protocolFault(\(code)) to be temporary")
        }
    }

    @Test("protocolFault(3) isTemporary is false")
    func protocolFault3NotTemporary() {
        #expect(TeslaError.protocolFault(3).isTemporary == false)
    }

    @Test("scanTimedOut shouldRetry is true")
    func scanTimedOutShouldRetry() {
        #expect(shouldRetry(TeslaError.scanTimedOut) == true)
    }
}

// MARK: - MetadataBuilder Tests

@Suite("MetadataBuilder")
struct MetadataBuilderTests {
    @Test("Checksum produces 32 bytes for SHA256 context")
    func checksumLength() {
        let meta = MetadataBuilder(context: .sha256)
        let checksum = meta.checksum()
        #expect(checksum.count == 32)
    }

    @Test("Checksum with message differs from without")
    func checksumWithMessage() throws {
        var meta = MetadataBuilder(context: .sha256)
        try meta.add(.signatureType, value: Data([0x01]))
        let without = meta.checksum()
        let with = meta.checksum(message: Data("payload".utf8))
        #expect(without != with)
    }

    @Test("HMAC context produces 32 bytes")
    func hmacContext() {
        let meta = MetadataBuilder(context: .hmacSHA256(key: Data("key".utf8)))
        let checksum = meta.checksum()
        #expect(checksum.count == 32)
    }

    @Test("Tags must be in ascending order")
    func tagOrder() throws {
        var meta = MetadataBuilder()
        try meta.add(.domain, value: Data([0x02]))
        #expect(throws: TeslaError.self) {
            try meta.add(.signatureType, value: Data([0x01]))
        }
    }

    @Test("nil value does not advance tag order")
    func nilValueDoesNotAdvanceTagOrder() throws {
        var meta = MetadataBuilder()
        // Adding nil for .domain should not record the tag, so adding .domain with a real value after should succeed
        try meta.add(.domain, value: nil)
        // Now add .domain with a real value — should not throw
        try meta.add(.domain, value: Data([0x01]))
        // And adding a higher tag should also work
        try meta.add(.personalization, value: Data([0x02]))
        let checksum = meta.checksum()
        #expect(checksum.count == 32)
    }

    @Test("addUInt32 encodes value as 4-byte big endian")
    func addUInt32Encoding() throws {
        var meta1 = MetadataBuilder()
        try meta1.addUInt32(.signatureType, value: 0x01020304)

        var meta2 = MetadataBuilder()
        try meta2.add(.signatureType, value: Data([0x01, 0x02, 0x03, 0x04]))

        #expect(meta1.checksum() == meta2.checksum())
    }
}

// MARK: - AESGCMNonceMode Tests

@Suite("AESGCMNonceMode")
struct AESGCMNonceModeTests {
    @Test("Standard 12 byte length")
    func standard12() {
        #expect(AESGCMNonceMode.standard12Byte.length == 12)
    }

    @Test("Tesla BLE 4 byte length")
    func teslaBLE4() {
        #expect(AESGCMNonceMode.teslaBLE4Byte.length == 4)
    }

    @Test("Custom length")
    func custom() {
        #expect(AESGCMNonceMode.custom(7).length == 7)
    }

    @Test("Equatable: same cases are equal")
    func equatableSameCases() {
        #expect(AESGCMNonceMode.standard12Byte == .standard12Byte)
        #expect(AESGCMNonceMode.teslaBLE4Byte == .teslaBLE4Byte)
        #expect(AESGCMNonceMode.custom(4) == .custom(4))
    }

    @Test("Equatable: custom with different lengths are not equal")
    func equatableDifferentCustom() {
        #expect(AESGCMNonceMode.custom(4) != .custom(8))
    }

    @Test("Equatable: different enum cases are not equal")
    func equatableDifferentCases() {
        #expect(AESGCMNonceMode.standard12Byte != .teslaBLE4Byte)
        #expect(AESGCMNonceMode.standard12Byte != .custom(12))
    }
}
