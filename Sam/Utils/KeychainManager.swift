import Foundation
import Security

// MARK: - Keychain Manager
class KeychainManager {
    
    // MARK: - Singleton
    static let shared = KeychainManager()
    
    // MARK: - Private Properties
    private let service = AppConstants.bundleIdentifier
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Store API key securely
    func storeAPIKey(_ apiKey: String) -> Bool {
        return store(key: KeychainKeys.openAIAPIKey, value: apiKey)
    }
    
    /// Retrieve API key
    func getAPIKey() -> String? {
        return retrieve(key: KeychainKeys.openAIAPIKey)
    }
    
    /// Delete API key
    func deleteAPIKey() -> Bool {
        return delete(key: KeychainKeys.openAIAPIKey)
    }
    
    /// Store encryption key
    func storeEncryptionKey(_ key: Data) -> Bool {
        return store(key: KeychainKeys.encryptionKey, data: key)
    }
    
    /// Retrieve encryption key
    func getEncryptionKey() -> Data? {
        return retrieveData(key: KeychainKeys.encryptionKey)
    }
    
    /// Store user identifier
    func storeUserIdentifier(_ identifier: String) -> Bool {
        return store(key: KeychainKeys.userIdentifier, value: identifier)
    }
    
    /// Retrieve user identifier
    func getUserIdentifier() -> String? {
        return retrieve(key: KeychainKeys.userIdentifier)
    }
    
    /// Check if API key exists
    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
    
    /// Validate API key format
    func validateAPIKey(_ apiKey: String) -> Bool {
        // OpenAI API keys start with "sk-" and are typically 51 characters long
        return apiKey.hasPrefix("sk-") && apiKey.count >= 20
    }
    
    /// Clear all stored credentials
    func clearAllCredentials() -> Bool {
        let keys = [
            KeychainKeys.openAIAPIKey,
            KeychainKeys.encryptionKey,
            KeychainKeys.userIdentifier
        ]
        
        var allSucceeded = true
        for key in keys {
            if !delete(key: key) {
                allSucceeded = false
            }
        }
        
        return allSucceeded
    }
}

// MARK: - Private Methods
private extension KeychainManager {
    
    /// Store string value in keychain
    func store(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        return store(key: key, data: data)
    }
    
    /// Store data in keychain
    func store(key: String, data: Data) -> Bool {
        // Delete existing item first
        _ = delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve string value from keychain
    func retrieve(key: String) -> String? {
        guard let data = retrieveData(key: key) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Retrieve data from keychain
    func retrieveData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return result as? Data
    }
    
    /// Delete item from keychain
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Update existing item in keychain
    func update(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        return status == errSecSuccess
    }
}

// MARK: - Keychain Error
enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidItemFormat
    case unexpectedStatus(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found in the keychain."
        case .duplicateItem:
            return "An item with the same key already exists in the keychain."
        case .invalidItemFormat:
            return "The item format is invalid."
        case .unexpectedStatus(let status):
            return "Unexpected keychain status: \(status)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .itemNotFound:
            return "Make sure the item was previously stored in the keychain."
        case .duplicateItem:
            return "Try updating the existing item instead of creating a new one."
        case .invalidItemFormat:
            return "Check the format of the data being stored."
        case .unexpectedStatus:
            return "This may be a system-level issue. Try restarting the application."
        }
    }
}

// MARK: - Keychain Accessibility Options
extension KeychainManager {
    
    enum AccessibilityOption {
        case whenUnlocked
        case whenUnlockedThisDeviceOnly
        case afterFirstUnlock
        case afterFirstUnlockThisDeviceOnly
        case whenPasscodeSetThisDeviceOnly
        
        var keychainValue: CFString {
            switch self {
            case .whenUnlocked:
                return kSecAttrAccessibleWhenUnlocked
            case .whenUnlockedThisDeviceOnly:
                return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .afterFirstUnlock:
                return kSecAttrAccessibleAfterFirstUnlock
            case .afterFirstUnlockThisDeviceOnly:
                return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whenPasscodeSetThisDeviceOnly:
                return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            }
        }
    }
    
    /// Store data with specific accessibility option
    func store(key: String, data: Data, accessibility: AccessibilityOption) -> Bool {
        // Delete existing item first
        _ = delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.keychainValue
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}