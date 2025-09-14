import Foundation
import SwiftUI
import Combine
import AppKit

// Use UserPreferences from UserModels
typealias UserPreferences = UserModels.UserPreferences

@MainActor
class SettingsManager: ObservableObject {
    // MARK: - Shared Instance
    static let shared = SettingsManager()
    
    // MARK: - Published Properties
    @Published var userPreferences: UserPreferences
    @Published var hasAPIKey: Bool = false
    @Published var apiKeyValidationStatus: APIKeyValidationStatus = .unknown
    @Published var isValidatingAPIKey: Bool = false
    
    // MARK: - Private Properties
    private let keychainManager = KeychainManager.shared
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.userPreferences = Self.loadUserPreferences()
        self.hasAPIKey = keychainManager.hasAPIKey()
        
        setupObservers()
        validateStoredAPIKey()
    }
    
    // MARK: - API Key Management
    
    enum APIKeyValidationStatus {
        case unknown
        case valid
        case invalid
        case expired
        case rateLimited
        
        var displayText: String {
            switch self {
            case .unknown: return "Not validated"
            case .valid: return "Valid"
            case .invalid: return "Invalid"
            case .expired: return "Expired"
            case .rateLimited: return "Rate limited"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .valid: return .green
            case .invalid, .expired: return .red
            case .rateLimited: return .orange
            }
        }
    }
    
    func storeAPIKey(_ apiKey: String) async -> Bool {
        guard keychainManager.validateAPIKey(apiKey) else {
            apiKeyValidationStatus = .invalid
            return false
        }
        
        let success = keychainManager.storeAPIKey(apiKey)
        if success {
            hasAPIKey = true
            await validateAPIKey(apiKey)
            NotificationCenter.default.post(name: .apiKeyUpdated, object: nil)
        }
        
        return success
    }
    
    func getAPIKey() -> String? {
        return keychainManager.getAPIKey()
    }
    
    func deleteAPIKey() -> Bool {
        let success = keychainManager.deleteAPIKey()
        if success {
            hasAPIKey = false
            apiKeyValidationStatus = .unknown
            NotificationCenter.default.post(name: .apiKeyUpdated, object: nil)
        }
        return success
    }
    
    func validateStoredAPIKey() {
        guard let apiKey = getAPIKey() else {
            apiKeyValidationStatus = .unknown
            return
        }
        
        Task {
            await validateAPIKey(apiKey)
        }
    }
    
    private func validateAPIKey(_ apiKey: String) async {
        isValidatingAPIKey = true
        defer { isValidatingAPIKey = false }
        
        // Basic format validation
        guard keychainManager.validateAPIKey(apiKey) else {
            apiKeyValidationStatus = .invalid
            return
        }
        
        // TODO: Implement actual API validation call
        // For now, just mark as valid if format is correct
        apiKeyValidationStatus = .valid
    }
    
    // MARK: - User Preferences Management
    
    func updatePreferences(_ preferences: UserPreferences) {
        userPreferences = preferences
        saveUserPreferences(preferences)
        NotificationCenter.default.post(name: .settingsChanged, object: preferences)
    }
    
    func updateAIModel(_ model: UserModels.AIModel) {
        userPreferences.preferredModel = model
        saveUserPreferences(userPreferences)
    }
    
    func updateMaxTokens(_ tokens: Int) {
        let clampedTokens = max(100, min(tokens, userPreferences.preferredModel.maxTokens))
        userPreferences.maxTokens = clampedTokens
        saveUserPreferences(userPreferences)
    }
    
    func updateTemperature(_ temperature: Float) {
        let clampedTemperature = max(0.0, min(temperature, 2.0))
        userPreferences.temperature = clampedTemperature
        saveUserPreferences(userPreferences)
    }
    
    func updateThemeMode(_ themeMode: UserModels.ThemeMode) {
        userPreferences.themeMode = themeMode
        saveUserPreferences(userPreferences)
    }
    
    func updatePrivacySettings(_ privacySettings: PrivacySettings) {
        userPreferences.privacySettings = privacySettings
        saveUserPreferences(userPreferences)
    }
    
    func updateNotificationSettings(_ notificationSettings: NotificationSettings) {
        userPreferences.notificationSettings = notificationSettings
        saveUserPreferences(userPreferences)
    }
    
    // MARK: - Task Shortcuts Management
    
    func addTaskShortcut(_ shortcut: TaskShortcut) {
        userPreferences.shortcuts.append(shortcut)
        saveUserPreferences(userPreferences)
    }
    
    func removeTaskShortcut(_ shortcut: TaskShortcut) {
        userPreferences.shortcuts.removeAll { $0.id == shortcut.id }
        saveUserPreferences(userPreferences)
    }
    
    func updateTaskShortcut(_ shortcut: TaskShortcut) {
        if let index = userPreferences.shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            userPreferences.shortcuts[index] = shortcut
            saveUserPreferences(userPreferences)
        }
    }
    
    // MARK: - Reset and Export
    
    func resetToDefaults() {
        userPreferences = UserPreferences()
        saveUserPreferences(userPreferences)
        
        // Clear keychain
        _ = keychainManager.clearAllCredentials()
        hasAPIKey = false
        apiKeyValidationStatus = .unknown
        
        NotificationCenter.default.post(name: .settingsChanged, object: userPreferences)
    }
    
    func exportSettings() -> Data? {
        // Create exportable settings (excluding sensitive data)
        let exportableSettings = ExportableSettings(
            preferredModel: userPreferences.preferredModel,
            maxTokens: userPreferences.maxTokens,
            temperature: userPreferences.temperature,
            autoExecuteTasks: userPreferences.autoExecuteTasks,
            confirmDangerousOperations: userPreferences.confirmDangerousOperations,
            themeMode: userPreferences.themeMode,
            shortcuts: userPreferences.shortcuts,
            privacySettings: userPreferences.privacySettings,
            notificationSettings: userPreferences.notificationSettings
        )
        
        return try? JSONEncoder().encode(exportableSettings)
    }
    
    func importSettings(from data: Data) -> Bool {
        guard let importedSettings = try? JSONDecoder().decode(ExportableSettings.self, from: data) else {
            return false
        }
        
        // Update preferences with imported data
        userPreferences.preferredModel = importedSettings.preferredModel
        userPreferences.maxTokens = importedSettings.maxTokens
        userPreferences.temperature = importedSettings.temperature
        userPreferences.autoExecuteTasks = importedSettings.autoExecuteTasks
        userPreferences.confirmDangerousOperations = importedSettings.confirmDangerousOperations
        userPreferences.themeMode = importedSettings.themeMode
        userPreferences.shortcuts = importedSettings.shortcuts
        userPreferences.privacySettings = importedSettings.privacySettings
        userPreferences.notificationSettings = importedSettings.notificationSettings
        
        saveUserPreferences(userPreferences)
        NotificationCenter.default.post(name: .settingsChanged, object: userPreferences)
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe system theme changes
        DistributedNotificationCenter.default.publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in
                // Trigger UI update if using system theme
                if self?.userPreferences.themeMode == .system {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
    
    private static func loadUserPreferences() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: "userPreferences"),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences()
        }
        return preferences
    }
    
    private func saveUserPreferences(_ preferences: UserPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: "userPreferences")
        }
    }
}

// MARK: - Exportable Settings
private struct ExportableSettings: Codable {
    let preferredModel: UserModels.AIModel
    let maxTokens: Int
    let temperature: Float
    let autoExecuteTasks: Bool
    let confirmDangerousOperations: Bool
    let themeMode: UserModels.ThemeMode
    let shortcuts: [TaskShortcut]
    let privacySettings: PrivacySettings
    let notificationSettings: NotificationSettings
}

// MARK: - Settings Validation
extension SettingsManager {
    func validateSettings() -> [SettingsValidationError] {
        var errors: [SettingsValidationError] = []
        
        // Validate token limits
        if userPreferences.maxTokens > userPreferences.preferredModel.maxTokens {
            errors.append(.tokenLimitExceedsModelCapacity)
        }
        
        // Validate temperature range
        if userPreferences.temperature < 0 || userPreferences.temperature > 2 {
            errors.append(.invalidTemperatureRange)
        }
        
        // Validate shortcuts for conflicts
        let shortcuts = userPreferences.shortcuts
        let keyboardShortcuts = shortcuts.compactMap { $0.keyboardShortcut }
        let duplicateShortcuts = Set(keyboardShortcuts).count != keyboardShortcuts.count
        if duplicateShortcuts {
            errors.append(.duplicateKeyboardShortcuts)
        }
        
        return errors
    }
    
    enum SettingsValidationError: LocalizedError {
        case tokenLimitExceedsModelCapacity
        case invalidTemperatureRange
        case duplicateKeyboardShortcuts
        
        var errorDescription: String? {
            switch self {
            case .tokenLimitExceedsModelCapacity:
                return "Token limit exceeds the selected model's capacity"
            case .invalidTemperatureRange:
                return "Temperature must be between 0.0 and 2.0"
            case .duplicateKeyboardShortcuts:
                return "Multiple shortcuts use the same keyboard combination"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .tokenLimitExceedsModelCapacity:
                return "Reduce the token limit or select a model with higher capacity"
            case .invalidTemperatureRange:
                return "Adjust the temperature to be within the valid range"
            case .duplicateKeyboardShortcuts:
                return "Assign unique keyboard shortcuts to each command"
            }
        }
    }
}

// MARK: - Command Aliases Management
extension SettingsManager {
    
    func addCommandAlias(_ alias: String, for command: String) {
        // Add to shortcuts as a special type
        let aliasShortcut = TaskShortcut(
            name: "Alias: \(alias)",
            command: command,
            keyboardShortcut: nil,
            category: .settings,
            isEnabled: true
        )
        addTaskShortcut(aliasShortcut)
    }
    
    func removeCommandAlias(_ alias: String) {
        userPreferences.shortcuts.removeAll { shortcut in
            shortcut.name == "Alias: \(alias)" && shortcut.category == .settings
        }
        saveUserPreferences(userPreferences)
    }
    
    func getCommandAliases() -> [String: String] {
        var aliases: [String: String] = [:]
        for shortcut in userPreferences.shortcuts where shortcut.category == .settings && shortcut.name.hasPrefix("Alias: ") {
            let alias = String(shortcut.name.dropFirst(7)) // Remove "Alias: " prefix
            aliases[alias] = shortcut.command
        }
        return aliases
    }
    
    // MARK: - Theme Customization
    
    func updateCustomThemeSettings(_ settings: CustomThemeSettings) {
        // Store custom theme settings in user preferences
        // This would extend UserPreferences to include custom theme settings
        saveUserPreferences(userPreferences)
    }
    
    // MARK: - Interface Preferences
    
    func updateInterfacePreferences(_ preferences: InterfacePreferences) {
        // Store interface customization preferences
        saveUserPreferences(userPreferences)
    }
    
    // MARK: - Data Export/Import Enhancements
    
    func exportUserData() -> Data? {
        // Export all user data including conversation history
        let exportData = UserDataExport(
            preferences: userPreferences,
            conversationHistory: [], // TODO: Get from Core Data
            customSettings: [:] // TODO: Add custom settings
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    func importUserData(from data: Data) -> Bool {
        guard let importedData = try? JSONDecoder().decode(UserDataExport.self, from: data) else {
            return false
        }
        
        // Import preferences
        userPreferences = importedData.preferences
        saveUserPreferences(userPreferences)
        
        // TODO: Import conversation history to Core Data
        // TODO: Import custom settings
        
        NotificationCenter.default.post(name: .settingsChanged, object: userPreferences)
        return true
    }
    
    // MARK: - Privacy Controls
    
    func deleteAllUserData() {
        // Reset preferences
        userPreferences = UserPreferences()
        saveUserPreferences(userPreferences)
        
        // Clear keychain
        _ = keychainManager.clearAllCredentials()
        hasAPIKey = false
        apiKeyValidationStatus = .unknown
        
        // TODO: Clear Core Data
        // TODO: Clear any cached files
        
        NotificationCenter.default.post(name: .settingsChanged, object: userPreferences)
    }
    
    func getDataUsageSummary() -> DataUsageSummary {
        // Calculate data usage statistics
        return DataUsageSummary(
            conversationCount: 0, // TODO: Get from Core Data
            totalMessages: 0, // TODO: Get from Core Data
            shortcutsCount: userPreferences.shortcuts.count,
            storageUsed: 0, // TODO: Calculate actual storage
            lastBackup: nil // TODO: Track backup dates
        )
    }
}

// MARK: - Supporting Data Structures

struct CustomThemeSettings: Codable {
    var accentColor: String
    var backgroundColor: String
    var textColor: String
    var messageBackgroundColor: String
    var borderRadius: Double
    var fontSize: Double
}

struct InterfacePreferences: Codable {
    var compactMode: Bool
    var showTimestamps: Bool
    var groupMessages: Bool
    var animationsEnabled: Bool
    var soundEffectsEnabled: Bool
}

struct UserDataExport: Codable {
    let preferences: UserPreferences
    let conversationHistory: [String] // Simplified for now
    let customSettings: [String: String]
    let exportDate: Date
    
    init(preferences: UserPreferences, conversationHistory: [String], customSettings: [String: String]) {
        self.preferences = preferences
        self.conversationHistory = conversationHistory
        self.customSettings = customSettings
        self.exportDate = Date()
    }
}

struct DataUsageSummary: Codable {
    let conversationCount: Int
    let totalMessages: Int
    let shortcutsCount: Int
    let storageUsed: Int64 // in bytes
    let lastBackup: Date?
}