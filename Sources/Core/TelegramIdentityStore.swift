import Foundation
import Security

enum TelegramIdentityStore {
    private static let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.whomakson.whogram.telegram.identity",
        kSecAttrAccount as String: "identity-v1",
        kSecAttrSynchronizable as String: false
    ]

    static func load() throws -> TelegramAppIdentity? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw StoreError.unavailable }
        return try JSONDecoder().decode(TelegramAppIdentity.self, from: data)
    }

    static func save(_ identity: TelegramAppIdentity) throws {
        let data = try JSONEncoder().encode(identity)
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

    private enum StoreError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Не удалось открыть связку ключей iPhone. Проверьте, что устройство разблокировано." }
    }
}
