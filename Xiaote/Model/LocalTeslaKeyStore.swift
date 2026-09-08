import Foundation
import Security
import TeslaBLEKeyKit

struct LocalTeslaKeyStore {
    let service: String

    private enum StoreError: LocalizedError {
        case missingKey
        var errorDescription: String? { "本机车辆密钥已丢失，请重新配对" }
    }

    func loadOrCreate(for identifier: String) throws -> TeslaPrivateKey {
        if let existing = try loadOptional(for: identifier) { return existing }
        let key = TeslaPrivateKey.generate()
        try save(key, for: identifier)
        return key
    }

    func load(for identifier: String) throws -> TeslaPrivateKey {
        guard let key = try loadOptional(for: identifier) else { throw StoreError.missingKey }
        return key
    }

    private func query(for identifier: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: identifier]
    }

    private func loadOptional(for identifier: String) throws -> TeslaPrivateKey? {
        var lookup = query(for: identifier)
        lookup[kSecReturnData as String] = true
        lookup[kSecReturnAttributes as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        guard let item = result as? [String: Any], let data = item[kSecValueData as String] as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecDecode))
        }
        let key = try TeslaPrivateKey(rawRepresentation: data)
        // Migrate the existing enrolled key in place on the first unlocked
        // launch after upgrading. Never delete or regenerate a paired key.
        if item[kSecAttrAccessible as String] as? String != kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String {
            let attributes = [kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
            let migration = SecItemUpdate(query(for: identifier) as CFDictionary, attributes as CFDictionary)
            guard migration == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(migration)) }
        }
        return key
    }

    private func save(_ key: TeslaPrivateKey, for identifier: String) throws {
        var item = query(for: identifier)
        item[kSecValueData as String] = key.rawRepresentation
        // Background Phone Key recovery must work with the display locked.
        // The item remains device-only and unavailable before the first
        // unlock following a reboot; it does not sync through iCloud.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    func delete(for identifier: String) throws {
        let status = SecItemDelete(query(for: identifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
