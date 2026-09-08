import XCTest
import Security
import TeslaBLEKeyKit
@testable import Xiaote

final class PhoneKeyStorageTests: XCTestCase {
    func testNewPhoneKeyIsAvailableAfterFirstUnlockAndRemainsDeviceOnly() throws {
        let store = LocalTeslaKeyStore(service: "xiaote.tests.\(UUID())")
        defer { try? store.delete(for: "car") }
        let created = try store.loadOrCreate(for: "car")
        let loaded = try store.load(for: "car")
        XCTAssertEqual(created.rawRepresentation, loaded.rawRepresentation)
        let item = try attributes(service: store.service)
        XCTAssertEqual(item[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func testLegacyEnrolledKeyMigratesWithoutChangingKeyMaterial() throws {
        let service = "xiaote.tests.\(UUID())"
        let store = LocalTeslaKeyStore(service: service)
        defer { try? store.delete(for: "car") }
        let oldKey = TeslaPrivateKey.generate()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "car",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: oldKey.rawRepresentation]
        XCTAssertEqual(SecItemAdd(query as CFDictionary, nil), errSecSuccess)
        let migrated = try store.loadOrCreate(for: "car")
        XCTAssertEqual(oldKey.rawRepresentation, migrated.rawRepresentation)
        XCTAssertEqual(try attributes(service: service)[kSecAttrAccessible as String] as? String,
                       kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        XCTAssertEqual(try store.load(for: "car").rawRepresentation, oldKey.rawRepresentation)
    }

    func testMissingKeyLoadDoesNotCreateAnUnpairedReplacement() throws {
        let store = LocalTeslaKeyStore(service: "xiaote.tests.\(UUID())")
        XCTAssertThrowsError(try store.load(for: "car"))
        XCTAssertThrowsError(try attributes(service: store.service))
    }

    private func attributes(service: String) throws -> [String: Any] {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "car", kSecReturnAttributes as String: true]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return try XCTUnwrap(result as? [String: Any])
    }
}
