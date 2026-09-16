import XCTest
@testable import TeslaBLEKeyKit

final class CryptoXCTests: XCTestCase {

    // MARK: - AES128

    func testAES128NISTVector() throws {
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
        let result = try aes.encryptBlock(plaintext)
        XCTAssertEqual(result, expected)
    }

    func testAES128InvalidKeyLength() {
        XCTAssertThrowsError(try AES128(key: Data(repeating: 0, count: 10)))
        XCTAssertThrowsError(try AES128(key: Data(repeating: 0, count: 32)))
    }

    func testAES128InvalidBlockLength() throws {
        let aes = try AES128(key: Data(repeating: 0, count: 16))
        XCTAssertThrowsError(try aes.encryptBlock([UInt8](repeating: 0, count: 8)))
    }

    func testAES128Deterministic() throws {
        let key = Data(repeating: 0x42, count: 16)
        let plaintext = [UInt8](repeating: 0x11, count: 16)
        let aes = try AES128(key: key)
        let ct1 = try aes.encryptBlock(plaintext)
        let ct2 = try aes.encryptBlock(plaintext)
        XCTAssertEqual(ct1, ct2)
    }

    // MARK: - VariableNonceAESGCM

    func testGCMRoundTrip12ByteNonce() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("Hello, World!".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .standard12Byte)
        let decrypted = try gcm.open(sealed)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testGCMRoundTrip4ByteNonce() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("Tesla BLE".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .teslaBLE4Byte)
        let decrypted = try gcm.open(sealed)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testGCMWithAAD() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("payload".utf8)
        let aad = Data("header".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, authenticatedData: aad)
        let decrypted = try gcm.open(sealed, authenticatedData: aad)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testGCMFailsWithWrongAAD() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let sealed = try gcm.seal(plaintext: Data("x".utf8), authenticatedData: Data("a".utf8))
        XCTAssertThrowsError(try gcm.open(sealed, authenticatedData: Data("b".utf8)))
    }

    func testGCMFailsWithTamperedTag() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let sealed = try gcm.seal(plaintext: Data("data".utf8))
        var badTag = sealed.tag
        badTag[0] ^= 0xFF
        let tampered = AESGCMSealedBox(nonce: sealed.nonce, ciphertext: sealed.ciphertext, tag: badTag)
        XCTAssertThrowsError(try gcm.open(tampered))
    }

    func testGCMFailsWithWrongKey() throws {
        let key1 = try ByteUtilities.randomData(count: 16)
        let key2 = try ByteUtilities.randomData(count: 16)
        let gcm1 = try VariableNonceAESGCM(key: key1)
        let gcm2 = try VariableNonceAESGCM(key: key2)
        let sealed = try gcm1.seal(plaintext: Data("secret".utf8))
        XCTAssertThrowsError(try gcm2.open(sealed))
    }

    func testGCMEmptyPlaintext() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let sealed = try gcm.seal(plaintext: Data())
        XCTAssertTrue(sealed.ciphertext.isEmpty)
        let decrypted = try gcm.open(sealed)
        XCTAssertTrue(decrypted.isEmpty)
    }

    func testGCMLargePlaintext() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = try ByteUtilities.randomData(count: 1024)
        let sealed = try gcm.seal(plaintext: plaintext)
        let decrypted = try gcm.open(sealed)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testGCMCustomNonceLength() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let plaintext = Data("custom nonce".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonceMode: .custom(7))
        XCTAssertEqual(sealed.nonce.count, 7)
        let decrypted = try gcm.open(sealed)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testGCMExplicitNonce() throws {
        let key = try ByteUtilities.randomData(count: 16)
        let gcm = try VariableNonceAESGCM(key: key)
        let nonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C])
        let plaintext = Data("explicit".utf8)
        let sealed = try gcm.seal(plaintext: plaintext, nonce: nonce)
        XCTAssertEqual(sealed.nonce, nonce)
        let decrypted = try gcm.open(sealed)
        XCTAssertEqual(decrypted, plaintext)
    }
}
