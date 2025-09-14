import Foundation
import Security
import CryptoKit

// MARK: - Keychain Manager
class KeychainManager {
    
    // MARK: - Singleton
    static let shared = KeychainManager()
    
    // MARK: - Private Properties
    private let service = AppConstants.bundleIdentifier
    private let accessGroup: String? = nil // Can be set for app groups
    
    // MARK: - Security Configuration
    private let defaultAccessibility: AccessibilityOption = .whenUnlockedThisDeviceOnly
    private let sensitiveAccessibility: AccessibilityOption = .whenPasscodeSetThisDeviceOnly
    
    // MARK: - Initialization
    private init() {
        // Generate or retrieve master encryption key on first launch
        ensureMasterEncryptionKey()
    }
    
    // MARK: - Public Methods
    
    /// Store API key securely with enhanced protection
    func storeAPIKey(_ apiKey: String, provider: APIProvider = .openAI) -> Bool {
        guard validateAPIKey(apiKey, for: provider) else {
            return false
        }
        
        let keyName = provider.keychainKey
        
        // Encrypt API key before storage
        guard let encryptedData = encryptSensitiveData(apiKey) else {
            return false
        }
        
        return store(key: keyName, data: encryptedData, accessibility: sensitiveAccessibility)
    }
    
    /// Retrieve API key with decryption
    func getAPIKey(for provider: APIProvider = .openAI) -> String? {
        let keyName = provider.keychainKey
        
        guard let encryptedData = retrieveData(key: keyName),
              let decryptedKey = decryptSensitiveData(encryptedData) else {
            return nil
        }
        
        return decryptedKey
    }
    
    /// Delete API key
    func deleteAPIKey(for provider: APIProvider = .openAI) -> Bool {
        return delete(key: provider.keychainKey)
    }
    
    /// Store multiple API keys
    func storeAPIKeys(_ keys: [APIProvider: String]) -> Bool {
        var allSucceeded = true
        
        for (provider, key) in keys {
            if !storeAPIKey(key, provider: provider) {
                allSucceeded = false
            }
        }
        
        return allSucceeded
    }
    
    /// Retrieve all stored API keys
    func getAllAPIKeys() -> [APIProvider: String] {
        var keys: [APIProvider: String] = [:]
        
        for provider in APIProvider.allCases {
            if let key = getAPIKey(for: provider) {
                keys[provider] = key
            }
        }
        
        return keys
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
    
    /// Validate API key format for specific provider
    func validateAPIKey(_ apiKey: String, for provider: APIProvider = .openAI) -> Bool {
        switch provider {
        case .openAI:
            // OpenAI API keys start with "sk-" and are typically 51 characters long
            return apiKey.hasPrefix("sk-") && apiKey.count >= 20
        case .anthropic:
            // Anthropic API keys start with "sk-ant-"
            return apiKey.hasPrefix("sk-ant-") && apiKey.count >= 20
        case .google:
            // Google API keys are typically 39 characters
            return apiKey.count >= 20 && !apiKey.contains(" ")
        case .azure:
            // Azure OpenAI keys are typically 32 characters
            return apiKey.count >= 20 && !apiKey.contains(" ")
        }
    }
    
    /// Check API key strength and security
    func assessAPIKeySecurity(_ apiKey: String) -> APIKeySecurityAssessment {
        var issues: [String] = []
        var score = 100
        
        // Check length
        if apiKey.count < 32 {
            issues.append("API key is shorter than recommended")
            score -= 20
        }
        
        // Check for common patterns that might indicate a test key
        if apiKey.contains("test") || apiKey.contains("demo") || apiKey.contains("example") {
            issues.append("API key appears to be a test or example key")
            score -= 50
        }
        
        // Check entropy (randomness)
        let entropy = calculateEntropy(apiKey)
        if entropy < 4.0 {
            issues.append("API key has low entropy (may not be secure)")
            score -= 30
        }
        
        return APIKeySecurityAssessment(
            score: max(0, score),
            issues: issues,
            isSecure: score >= 70
        )
    }
    
    /// Clear all stored credentials
    func clearAllCredentials() -> Bool {
        let keys = [
            KeychainKeys.openAIAPIKey,
            KeychainKeys.anthropicAPIKey,
            KeychainKeys.googleAPIKey,
            KeychainKeys.azureAPIKey,
            KeychainKeys.encryptionKey,
            KeychainKeys.masterEncryptionKey,
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
    
    // MARK: - Encryption Methods
    
    /// Ensure master encryption key exists
    private func ensureMasterEncryptionKey() {
        if getMasterEncryptionKey() == nil {
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            _ = store(key: KeychainKeys.masterEncryptionKey, data: keyData, accessibility: sensitiveAccessibility)
        }
    }
    
    /// Get master encryption key
    private func getMasterEncryptionKey() -> SymmetricKey? {
        guard let keyData = retrieveData(key: KeychainKeys.masterEncryptionKey) else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }
    
    /// Encrypt sensitive data using master key
    private func encryptSensitiveData(_ data: String) -> Data? {
        guard let masterKey = getMasterEncryptionKey(),
              let dataToEncrypt = data.data(using: .utf8) else {
            return nil
        }
        
        do {
            let sealedBox = try AES.GCM.seal(dataToEncrypt, using: masterKey)
            return sealedBox.combined
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }
    
    /// Decrypt sensitive data using master key
    private func decryptSensitiveData(_ encryptedData: Data) -> String? {
        guard let masterKey = getMasterEncryptionKey() else {
            return nil
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: masterKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
    
    /// Calculate entropy of a string
    private func calculateEntropy(_ string: String) -> Double {
        var frequency: [Character: Int] = [:]
        
        for char in string {
            frequency[char, default: 0] += 1
        }
        
        let length = Double(string.count)
        var entropy = 0.0
        
        for count in frequency.values {
            let probability = Double(count) / length
            entropy -= probability * log2(probability)
        }
        
        return entropy
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
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.keychainValue
        ]
        
        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Supporting Types

/// API Provider enumeration
enum APIProvider: String, CaseIterable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case azure = "azure"
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .azure: return "Azure OpenAI"
        }
    }
    
    var keychainKey: String {
        switch self {
        case .openAI: return KeychainKeys.openAIAPIKey
        case .anthropic: return KeychainKeys.anthropicAPIKey
        case .google: return KeychainKeys.googleAPIKey
        case .azure: return KeychainKeys.azureAPIKey
        }
    }
}

/// API Key security assessment
struct APIKeySecurityAssessment {
    let score: Int
    let issues: [String]
    let isSecure: Bool
    
    var securityLevel: SecurityLevel {
        switch score {
        case 90...100: return .excellent
        case 70...89: return .good
        case 50...69: return .fair
        case 30...49: return .poor
        default: return .critical
        }
    }
    
    enum SecurityLevel: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "orange"
            case .critical: return "red"
            }
        }
    }
}