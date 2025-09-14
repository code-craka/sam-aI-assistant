import Foundation
import CryptoKit
import CoreData

/// Service for encrypting and decrypting sensitive data
class DataEncryptionService {
    
    // MARK: - Singleton
    static let shared = DataEncryptionService()
    
    // MARK: - Private Properties
    private let keychainManager = KeychainManager.shared
    private var encryptionKey: SymmetricKey?
    
    // MARK: - Initialization
    private init() {
        loadEncryptionKey()
    }
    
    // MARK: - Key Management
    
    private func loadEncryptionKey() {
        if let keyData = keychainManager.getEncryptionKey() {
            encryptionKey = SymmetricKey(data: keyData)
        } else {
            generateNewEncryptionKey()
        }
    }
    
    private func generateNewEncryptionKey() {
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        if keychainManager.storeEncryptionKey(keyData) {
            encryptionKey = newKey
        } else {
            print("Failed to store encryption key in keychain")
        }
    }
    
    // MARK: - Encryption Methods
    
    /// Encrypt string data
    func encrypt(_ data: String) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.keyNotAvailable
        }
        
        guard let dataToEncrypt = data.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        do {
            let sealedBox = try AES.GCM.seal(dataToEncrypt, using: key)
            return sealedBox.combined ?? Data()
        } catch {
            throw EncryptionError.encryptionFailed(error)
        }
    }
    
    /// Encrypt data
    func encrypt(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.keyNotAvailable
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined ?? Data()
        } catch {
            throw EncryptionError.encryptionFailed(error)
        }
    }
    
    /// Decrypt to string
    func decryptToString(_ encryptedData: Data) throws -> String {
        let decryptedData = try decrypt(encryptedData)
        
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        return string
    }
    
    /// Decrypt data
    func decrypt(_ encryptedData: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.keyNotAvailable
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed(error)
        }
    }
    
    // MARK: - Chat Message Encryption
    
    /// Encrypt chat message content
    func encryptChatMessage(_ message: ChatMessage) throws {
        guard let content = message.content else { return }
        
        let encryptedData = try encrypt(content)
        message.encryptedContent = encryptedData
        message.content = nil // Clear plaintext
        message.isEncrypted = true
    }
    
    /// Decrypt chat message content
    func decryptChatMessage(_ message: ChatMessage) throws -> String {
        guard message.isEncrypted,
              let encryptedData = message.encryptedContent else {
            return message.content ?? ""
        }
        
        return try decryptToString(encryptedData)
    }
    
    /// Encrypt multiple chat messages
    func encryptChatMessages(_ messages: [ChatMessage]) throws {
        for message in messages {
            try encryptChatMessage(message)
        }
    }
    
    // MARK: - User Preferences Encryption
    
    /// Encrypt sensitive user preferences
    func encryptUserPreferences(_ preferences: UserPreferences) throws {
        // Encrypt sensitive fields
        if let apiKeys = preferences.apiKeys {
            let encryptedKeys = try encrypt(apiKeys)
            preferences.encryptedAPIKeys = encryptedKeys
            preferences.apiKeys = nil
        }
        
        if let customPrompts = preferences.customPrompts {
            let encryptedPrompts = try encrypt(customPrompts)
            preferences.encryptedCustomPrompts = encryptedPrompts
            preferences.customPrompts = nil
        }
        
        preferences.isEncrypted = true
    }
    
    /// Decrypt user preferences
    func decryptUserPreferences(_ preferences: UserPreferences) throws {
        guard preferences.isEncrypted else { return }
        
        // Decrypt API keys
        if let encryptedKeys = preferences.encryptedAPIKeys {
            preferences.apiKeys = try decryptToString(encryptedKeys)
        }
        
        // Decrypt custom prompts
        if let encryptedPrompts = preferences.encryptedCustomPrompts {
            preferences.customPrompts = try decryptToString(encryptedPrompts)
        }
    }
    
    // MARK: - Workflow Encryption
    
    /// Encrypt workflow data
    func encryptWorkflow(_ workflow: Workflow) throws {
        guard let stepsData = workflow.stepsData else { return }
        
        let encryptedData = try encrypt(stepsData)
        workflow.encryptedStepsData = encryptedData
        workflow.stepsData = nil
        workflow.isEncrypted = true
    }
    
    /// Decrypt workflow data
    func decryptWorkflow(_ workflow: Workflow) throws -> Data? {
        guard workflow.isEncrypted,
              let encryptedData = workflow.encryptedStepsData else {
            return workflow.stepsData
        }
        
        return try decrypt(encryptedData)
    }
    
    // MARK: - Batch Operations
    
    /// Encrypt all sensitive data in context
    func encryptAllSensitiveData(in context: NSManagedObjectContext) throws {
        // Encrypt chat messages
        let messageRequest: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        messageRequest.predicate = NSPredicate(format: "isEncrypted == NO")
        
        let messages = try context.fetch(messageRequest)
        try encryptChatMessages(messages)
        
        // Encrypt user preferences
        let preferencesRequest: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        preferencesRequest.predicate = NSPredicate(format: "isEncrypted == NO")
        
        let preferences = try context.fetch(preferencesRequest)
        for pref in preferences {
            try encryptUserPreferences(pref)
        }
        
        // Encrypt workflows
        let workflowRequest: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        workflowRequest.predicate = NSPredicate(format: "isEncrypted == NO")
        
        let workflows = try context.fetch(workflowRequest)
        for workflow in workflows {
            try encryptWorkflow(workflow)
        }
        
        try context.save()
    }
    
    /// Decrypt all data for migration or export
    func decryptAllData(in context: NSManagedObjectContext) throws {
        // Decrypt chat messages
        let messageRequest: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        messageRequest.predicate = NSPredicate(format: "isEncrypted == YES")
        
        let messages = try context.fetch(messageRequest)
        for message in messages {
            let decryptedContent = try decryptChatMessage(message)
            message.content = decryptedContent
            message.encryptedContent = nil
            message.isEncrypted = false
        }
        
        // Decrypt user preferences
        let preferencesRequest: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        preferencesRequest.predicate = NSPredicate(format: "isEncrypted == YES")
        
        let preferences = try context.fetch(preferencesRequest)
        for pref in preferences {
            try decryptUserPreferences(pref)
            pref.isEncrypted = false
        }
        
        // Decrypt workflows
        let workflowRequest: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        workflowRequest.predicate = NSPredicate(format: "isEncrypted == YES")
        
        let workflows = try context.fetch(workflowRequest)
        for workflow in workflows {
            if let decryptedData = try decryptWorkflow(workflow) {
                workflow.stepsData = decryptedData
                workflow.encryptedStepsData = nil
                workflow.isEncrypted = false
            }
        }
        
        try context.save()
    }
    
    // MARK: - Key Rotation
    
    /// Rotate encryption key (re-encrypt all data with new key)
    func rotateEncryptionKey() throws {
        let context = PersistenceController.shared.container.viewContext
        
        // First decrypt all data with old key
        try decryptAllData(in: context)
        
        // Generate new key
        generateNewEncryptionKey()
        
        // Re-encrypt all data with new key
        try encryptAllSensitiveData(in: context)
    }
    
    // MARK: - Utility Methods
    
    /// Check if encryption is available
    var isEncryptionAvailable: Bool {
        return encryptionKey != nil
    }
    
    /// Get encryption status summary
    func getEncryptionStatus() -> EncryptionStatus {
        let context = PersistenceController.shared.container.viewContext
        
        do {
            // Count encrypted vs unencrypted messages
            let totalMessages = try context.count(for: ChatMessage.fetchRequest())
            let encryptedMessages = try context.count(for: {
                let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
                request.predicate = NSPredicate(format: "isEncrypted == YES")
                return request
            }())
            
            // Count encrypted preferences
            let totalPreferences = try context.count(for: UserPreferences.fetchRequest())
            let encryptedPreferences = try context.count(for: {
                let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
                request.predicate = NSPredicate(format: "isEncrypted == YES")
                return request
            }())
            
            return EncryptionStatus(
                isEnabled: isEncryptionAvailable,
                encryptedMessages: encryptedMessages,
                totalMessages: totalMessages,
                encryptedPreferences: encryptedPreferences,
                totalPreferences: totalPreferences
            )
        } catch {
            return EncryptionStatus(
                isEnabled: isEncryptionAvailable,
                encryptedMessages: 0,
                totalMessages: 0,
                encryptedPreferences: 0,
                totalPreferences: 0
            )
        }
    }
}

// MARK: - Supporting Types

/// Encryption errors
enum EncryptionError: LocalizedError {
    case keyNotAvailable
    case invalidData
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .keyNotAvailable:
            return "Encryption key is not available"
        case .invalidData:
            return "Invalid data format for encryption/decryption"
        case .encryptionFailed(let error):
            return "Encryption failed: \(error.localizedDescription)"
        case .decryptionFailed(let error):
            return "Decryption failed: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .keyNotAvailable:
            return "Try restarting the application to regenerate the encryption key"
        case .invalidData:
            return "Check the data format and try again"
        case .encryptionFailed, .decryptionFailed:
            return "This may indicate corrupted data or a key mismatch"
        }
    }
}

/// Encryption status information
struct EncryptionStatus {
    let isEnabled: Bool
    let encryptedMessages: Int
    let totalMessages: Int
    let encryptedPreferences: Int
    let totalPreferences: Int
    
    var messageEncryptionPercentage: Double {
        guard totalMessages > 0 else { return 0 }
        return Double(encryptedMessages) / Double(totalMessages) * 100
    }
    
    var preferencesEncryptionPercentage: Double {
        guard totalPreferences > 0 else { return 0 }
        return Double(encryptedPreferences) / Double(totalPreferences) * 100
    }
    
    var overallEncryptionPercentage: Double {
        let totalItems = totalMessages + totalPreferences
        let encryptedItems = encryptedMessages + encryptedPreferences
        
        guard totalItems > 0 else { return 0 }
        return Double(encryptedItems) / Double(totalItems) * 100
    }
}