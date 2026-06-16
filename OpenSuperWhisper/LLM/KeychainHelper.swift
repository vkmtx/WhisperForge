import Foundation
import os
import Security

/// Minimal Keychain wrapper for storing LLM API keys.
/// Secrets must never live in UserDefaults (plaintext plist). Keys are scoped per
/// provider via the `account` field so each provider keeps its own credential.
enum KeychainHelper {
    static let service = "com.opensuperwhisper.llm"

    /// Stores (or clears, when `value` is empty) the secret for `account`.
    static func set(_ value: String, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Replace any existing item idempotently.
        SecItemDelete(base as CFDictionary)

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        // Most restrictive sensible class for an API key: only readable while the
        // device is unlocked, never synced or backed up off-device.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            Logger(subsystem: "com.opensuperwhisper", category: "Keychain")
                .error("Keychain write failed for account \(account, privacy: .public) (OSStatus \(status))")
        }
    }

    /// Returns the secret for `account`, or nil if none is stored.
    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
