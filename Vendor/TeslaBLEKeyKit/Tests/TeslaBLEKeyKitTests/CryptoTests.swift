import Testing
import Foundation
@testable import TeslaBLEKeyKit

// MARK: - AES128 Tests

@Suite("AES128")
struct AES128Tests {
    @Test("Rejects non-16-byte key")
    func invalidKeyLength() {
        #expect(throws: TeslaError.self) {
            _ = try AES128(key: Data(repeating: 0, count: 15))
        }
        #expect(throws: TeslaError.self) {
            _ = try AES128(key: Data(repeating: 0, count: 17))
        }
    }

    @Test("Rejects non-16-byte block")
    func invalidBlockLength() throws {
        let aes = try AES128(key: Data(repeating: 0, count: 16))
        #expect(throws: TeslaError.self) {
            _ = try aes.encryptBlock([UInt8](repeating: 0, count: 15))
        }
    }

    @Test("NIST AES-128 test vector")
    func nistTestVector() throws {
        let key = Data([
            0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
            0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
        ])
        let plaintext: [UInt8] = [
            0x32, 0x43, 0xf6, 0xa8, 0x88, 0x5a, 0x30, 0x8d,
            0x31, 0x31, 0x98, 0xa2, 0xe0, 0x37, 0x07, 0x34,
        ]
        let expected: [UInt8] = [
            0x39, 0x25, 0x84, 0x1d, 0x02, 0xdc, 0x09, 0xfb,
            0xdc, 0x11, 0x85, 0x97, 0x19, 0x6a, 0x0b, 0x32,
        ]
        let aes = try AES128(key: key)
        let ciphertext = try aes.encryptBlock(plaintext)
        #expect(ciphertext == expected)
    }

    @Test("Encrypting all zeros key and plaintext")
    func allZeros() throws {
        let key = Data(repeating: 0, count: 16)
        let plaintext = [UInt8](repeating: 0, count: 16)
        let aes = try AES128(key: key)
        let ciphertext = try aes.encryptBlock(plaintext)
        #expect(ciphertext != plaintext)
        #expect(ciphertext.count == 16)
    }

    @Test("Different keys produce different ciphertexts")
    func differentKeys() throws {
        let plaintext = [UInt8](repeating: 0x42, count: 16)
        let aes1 = try AES128(key: Data(repeating: 0x01, count: 16))
        let aes2 = try AES128(key: Data(repeating: 0x02, count: 16))
        let ct1 = try aes1.encryptBlock(plaintext)
        let ct2 = try aes2.encryptBlock(plaintext)
        #expect(ct1 != ct2)
    }
}

// MARK: - VariableNonceAESGCM Tests

@Suite("VariableNonceAESGCM")
struct VariableNonceAESGCMTests {
    @Test("Seal and open round-trip with 12-byte nonce")
    func roundTrip12Byte() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("Hello, Tesla!".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .standard12Byte)
        let decrypted = try gcm.open(sealed)
        #expect(decrypted == plaintext)
    }

    @Test("Seal and open round-trip with 4-byte nonce")
    func roundTrip4Byte() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("BLE protocol".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .teslaBLE4Byte)
        let decrypted = try gcm.open(sealed)
        #expect(decrypted == plaintext)
    }

    @Test("Seal and open with authenticated data")
    func withAAD() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("secret".utf8)
        let aad = Data("metadata".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, authenticatedData: aad, nonceMode: .standard12Byte)
        let decrypted = try gcm.open(sealed, authenticatedData: aad)
        #expect(decrypted == plaintext)
    }

    @Test("Open fails with wrong AAD")
    func wrongAAD() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("secret".utf8)
        let aad = Data("correct".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, authenticatedData: aad, nonceMode: .standard12Byte)
        #expect(throws: TeslaError.self) {
            _ = try gcm.open(sealed, authenticatedData: Data("wrong".utf8))
        }
    }

    @Test("Open fails with tampered ciphertext")
    func tamperedCiphertext() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("important data".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .standard12Byte)
        var tampered = sealed.ciphertext
        tampered[0] ^= 0xFF
        let tamperedBox = AESGCMSealedBox(nonce: sealed.nonce, ciphertext: tampered, tag: sealed.tag)
        #expect(throws: TeslaError.self) {
            _ = try gcm.open(tamperedBox)
        }
    }

    @Test("Open fails with wrong key")
    func wrongKey() throws {
        let key1 = try ByteUtilities.randomData(count: 16)
        let key2 = try ByteUtilities.randomData(count: 16)
        let gcm1 = try VariableNonceAESGCM(key: key1)
        let gcm2 = try VariableNonceAESGCM(key: key2)
        let plaintext = Data("test".utf8)
        let sealed = try gcm1.seal(plaintext: plaintext, nonceMode: .standard12Byte)
        #expect(throws: TeslaError.self) {
            _ = try gcm2.open(sealed)
        }
    }

    @Test("Empty nonce is rejected")
    func emptyNonce() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        #expect(throws: TeslaError.self) {
            _ = try gcm.seal(plaintext: Data("x".utf8), authenticatedData: Data(), nonce: Data())
        }
    }

    @Test("Seal empty plaintext")
    func emptyPlaintext() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let sealed = try gcm.seal(plaintext: Data(), nonceMode: .standard12Byte)
        #expect(sealed.ciphertext.isEmpty)
        let decrypted = try gcm.open(sealed)
        #expect(decrypted.isEmpty)
    }

    @Test("Tag length is always 16 bytes")
    func tagLength() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let sealed = try gcm.seal(plaintext: Data("data".utf8), nonceMode: .standard12Byte)
        #expect(sealed.tag.count == 16)
    }

    @Test("Custom nonce length round-trip")
    func customNonceRoundTrip() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("custom nonce test".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .custom(8))
        #expect(sealed.nonce.count == 8)
        let decrypted = try gcm.open(sealed)
        #expect(decrypted == plaintext)
    }

    @Test("Explicit nonce round-trip")
    func explicitNonceRoundTrip() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("explicit nonce".utf8)
        let nonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let sealed = try gcm.seal(plaintext: plaintext, nonce: nonce)
        #expect(sealed.nonce == nonce)
        let decrypted = try gcm.open(sealed)
        #expect(decrypted == plaintext)
    }

    @Test("Large plaintext (1024 bytes) round-trip")
    func largePlaintextRoundTrip() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = try ByteUtilities.randomData(count: 1024)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .standard12Byte)
        #expect(sealed.ciphertext.count == 1024)
        let decrypted = try gcm.open(sealed)
        #expect(decrypted == plaintext)
    }
}
