import CoreData
import Foundation
import SwiftUI

// MARK: - UserPreferences Extensions
extension UserPreferences {
    
    /// Computed property for AI model enum
    var aiModel: AIModel {
        get {
            return AIModel(rawValue: preferredModel) ?? .gpt4Turbo
        }
        set {
            preferredModel = newValue.rawValue
        }
    }
    
    /// Computed property for theme mode enum
    var theme: ThemeMode {
        get {
            return ThemeMode(rawValue: themeMode) ?? .system
        }
        set {
            themeMode = newValue.rawValue
        }
    }
    
    /// Computed property for data sensitivity level enum
    var sensitivityLevel: DataSensitivityLevel {
        get {
            return DataSensitivityLevel(rawValue: dataSensitivityLevel) ?? .balanced
        }
        set {
            dataSensitivityLevel = newValue.rawValue
        }
    }
    
    /// Computed property for notification sound enum
    var sound: NotificationSound {
        get {
            return NotificationSound(rawValue: notificationSound) ?? .default
        }
        set {
            notificationSound = newValue.rawValue
        }
    }
    
    /// Get color scheme for SwiftUI
    var colorScheme: ColorScheme? {
        return theme.colorScheme
    }
    
    /// Check if cloud processing is allowed based on sensitivity level
    var allowsCloudProcessing: Bool {
        switch sensitivityLevel {
        case .strict:
            return false
        case .balanced, .permissive:
            return true
        }
    }
    
    /// Get maximum tokens for current model
    var effectiveMaxTokens: Int {
        let modelMaxTokens = aiModel.maxTokens
        return min(Int(maxTokens), modelMaxTokens)
    }
    
    /// Get cost per token for current model
    var costPerToken: Double {
        return aiModel.costPerToken
    }
    
    /// Sorted shortcuts by usage count
    var sortedShortcuts: [TaskShortcut] {
        let shortcutsSet = shortcuts as? Set<TaskShortcut> ?? []
        return shortcutsSet.sorted { $0.usageCount > $1.usageCount }
    }
    
    /// Active shortcuts only
    var activeShortcuts: [TaskShortcut] {
        return sortedShortcuts.filter { $0.isEnabled }
    }
    
    /// Sorted workflows by last executed date
    var sortedWorkflows: [Workflow] {
        let workflowsSet = workflows as? Set<Workflow> ?? []
        return workflowsSet.sorted { 
            ($0.lastExecuted ?? $0.createdAt) > ($1.lastExecuted ?? $1.createdAt)
        }
    }
    
    /// Active workflows only
    var activeWorkflows: [Workflow] {
        return sortedWorkflows.filter { $0.isEnabled }
    }
    
    /// Privacy settings summary
    var privacySummary: String {
        var components: [String] = []
        
        if !storeConversationHistory {
            components.append("No history storage")
        }
        
        if !allowsCloudProcessing {
            components.append("Local processing only")
        }
        
        if encryptLocalData {
            components.append("Encrypted storage")
        }
        
        if autoDeleteOldChats {
            components.append("Auto-delete after \(autoDeleteAfterDays) days")
        }
        
        return components.isEmpty ? "Standard privacy" : components.joined(separator: ", ")
    }
    
    /// Notification settings summary
    var notificationSummary: String {
        guard enableNotifications else { return "Disabled" }
        
        var components: [String] = []
        
        if taskCompletionNotifications {
            components.append("Task completion")
        }
        
        if errorNotifications {
            components.append("Errors")
        }
        
        if usageReportNotifications {
            components.append("Usage reports")
        }
        
        return components.isEmpty ? "Enabled" : components.joined(separator: ", ")
    }
    
    /// Add a new shortcut
    func addShortcut(_ shortcut: TaskShortcut) {
        shortcut.userPreferences = self
    }
    
    /// Remove a shortcut
    func removeShortcut(_ shortcut: TaskShortcut) {
        shortcut.userPreferences = nil
    }
    
    /// Add a new workflow
    func addWorkflow(_ workflow: Workflow) {
        workflow.userPreferences = self
    }
    
    /// Remove a workflow
    func removeWorkflow(_ workflow: Workflow) {
        workflow.userPreferences = nil
    }
    
    /// Reset to default values
    func resetToDefaults() {
        preferredModel = "gpt-4-turbo-preview"
        maxTokens = 4000
        temperature = 0.7
        autoExecuteTasks = false
        confirmDangerousOperations = true
        themeMode = "system"
        dataSensitivityLevel = "balanced"
        enableNotifications = true
        encryptLocalData = true
        storeConversationHistory = true
        autoDeleteOldChats = false
        autoDeleteAfterDays = 30
        shareUsageData = false
        taskCompletionNotifications = true
        errorNotifications = true
        usageReportNotifications = false
        soundEnabled = true
        notificationSound = "default"
    }
    
    /// Validation before saving
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validatePreferences()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validatePreferences()
    }
    
    private func validatePreferences() throws {
        // Validate max tokens
        if maxTokens <= 0 {
            throw PreferencesValidationError.invalidMaxTokens
        }
        
        // Validate temperature
        if temperature < 0 || temperature > 2 {
            throw PreferencesValidationError.invalidTemperature
        }
        
        // Validate auto delete days
        if autoDeleteAfterDays <= 0 {
            throw PreferencesValidationError.invalidAutoDeleteDays
        }
        
        // Validate model exists
        if AIModel(rawValue: preferredModel) == nil {
            throw PreferencesValidationError.invalidModel
        }
        
        // Validate theme mode exists
        if ThemeMode(rawValue: themeMode) == nil {
            throw PreferencesValidationError.invalidThemeMode
        }
        
        // Validate sensitivity level exists
        if DataSensitivityLevel(rawValue: dataSensitivityLevel) == nil {
            throw PreferencesValidationError.invalidSensitivityLevel
        }
        
        // Validate notification sound exists
        if NotificationSound(rawValue: notificationSound) == nil {
            throw PreferencesValidationError.invalidNotificationSound
        }
    }
}

// MARK: - Fetch Requests
extension UserPreferences {
    
    /// Fetch request for user preferences (should only be one)
    static var defaultRequest: NSFetchRequest<UserPreferences> {
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        return request
    }
}

// MARK: - Convenience Initializers
extension UserPreferences {
    
    /// Create default user preferences
    static func createDefault(in context: NSManagedObjectContext) -> UserPreferences {
        let preferences = UserPreferences(context: context)
        preferences.id = UUID()
        preferences.resetToDefaults()
        return preferences
    }
}

// MARK: - Preferences Validation Errors
enum PreferencesValidationError: LocalizedError {
    case invalidMaxTokens
    case invalidTemperature
    case invalidAutoDeleteDays
    case invalidModel
    case invalidThemeMode
    case invalidSensitivityLevel
    case invalidNotificationSound
    
    var errorDescription: String? {
        switch self {
        case .invalidMaxTokens:
            return "Max tokens must be greater than 0"
        case .invalidTemperature:
            return "Temperature must be between 0 and 2"
        case .invalidAutoDeleteDays:
            return "Auto delete days must be greater than 0"
        case .invalidModel:
            return "Invalid AI model selected"
        case .invalidThemeMode:
            return "Invalid theme mode selected"
        case .invalidSensitivityLevel:
            return "Invalid data sensitivity level selected"
        case .invalidNotificationSound:
            return "Invalid notification sound selected"
        }
    }
}