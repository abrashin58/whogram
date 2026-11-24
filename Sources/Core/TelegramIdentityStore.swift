import Foundation
import Security

enum TelegramIdentityStore {
    private static func item(_ account: String) -> [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.whomakson.whogram.telegram.identity",
        kSecAttrAccount as String: account,
        kSecAttrSynchronizable as String: false
    ] }

    private static func read(_ account: String) throws -> Data? {
        var query = item(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw StoreError.unavailable }
        return data
    }

    static func loadCatalog() throws -> SessionCatalog {
        if let data = try read("profiles-v2") {
            return try JSONDecoder().decode(SessionCatalog.self, from: data).validated()
        }
        let legacy = try read("identity-v1").map { try JSONDecoder().decode(TelegramAppIdentity.self, from: $0) }
        return SessionCatalog(legacyIdentity: legacy)
    }

    static func saveCatalog(_ catalog: SessionCatalog) throws {
        let data = try JSONEncoder().encode(catalog.validated())
        let item = item("profiles-v2")
        var fields = item
        fields[kSecValueData as String] = data
        fields[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(fields as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updated = SecItemUpdate(item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updated == errSecSuccess else { throw StoreError.unavailable }
        } else if status != errSecSuccess {
            throw StoreError.unavailable
        }
    }

    static func makeDatabaseKey() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBufferPointer { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw SessionCatalogError.storage }
        return Data(bytes)
    }

    private enum StoreError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Не удалось открыть связку ключей iPhone. Проверьте, что устройство разблокировано." }
    }
}
