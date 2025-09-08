import Foundation
import SwiftUI

// MARK: - UserModels Namespace
enum UserModels {
    // This enum serves as a namespace for user-related models
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    let id: UUID
    var preferredModel: UserModels.AIModel
    var maxTokens: Int
    var temperature: Float
    var autoExecuteTasks: Bool
    var confirmDangerousOperations: Bool
    var themeMode: UserModels.ThemeMode
    var shortcuts: [TaskShortcut]
    var privacySettings: PrivacySettings
    var notificationSettings: NotificationSettings
    var interfacePreferences: InterfacePreferences
    var customThemeSettings: CustomThemeSettings?
    
    init(
        id: UUID = UUID(),
        preferredModel: UserModels.AIModel = .gpt4Turbo,
        maxTokens: Int = 4000,
        temperature: Float = 0.7,
        autoExecuteTasks: Bool = false,
        confirmDangerousOperations: Bool = true,
        themeMode: UserModels.ThemeMode = .system,
        shortcuts: [TaskShortcut] = [],
        privacySettings: PrivacySettings = PrivacySettings(),
        notificationSettings: NotificationSettings = NotificationSettings(),
        interfacePreferences: InterfacePreferences = InterfacePreferences(),
        customThemeSettings: CustomThemeSettings? = nil
    ) {
        self.id = id
        self.preferredModel = preferredModel
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.autoExecuteTasks = autoExecuteTasks
        self.confirmDangerousOperations = confirmDangerousOperations
        self.themeMode = themeMode
        self.shortcuts = shortcuts
        self.privacySettings = privacySettings
        self.notificationSettings = notificationSettings
        self.interfacePreferences = interfacePreferences
        self.customThemeSettings = customThemeSettings
    }
}

// MARK: - AI Model Configuration
extension UserModels {
    enum AIModel: String, CaseIterable, Codable {
    case gpt4 = "gpt-4"
    case gpt4Turbo = "gpt-4-turbo-preview"
    case gpt35Turbo = "gpt-3.5-turbo"
    case local = "local"
    
    var displayName: String {
        switch self {
        case .gpt4: return "GPT-4"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        case .local: return "Local Model"
        }
    }
    
    var costPerToken: Double {
        switch self {
        case .gpt4: return 0.00003
        case .gpt4Turbo: return 0.00001
        case .gpt35Turbo: return 0.0000015
        case .local: return 0.0
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .gpt4: return 8192
        case .gpt4Turbo: return 128000
        case .gpt35Turbo: return 4096
        case .local: return 2048
        }
    }
}

}

// MARK: - Theme Mode
extension UserModels {
    enum ThemeMode: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

}

// MARK: - Task Shortcut
struct TaskShortcut: Identifiable, Codable {
    let id: UUID
    let name: String
    let command: String
    let keyboardShortcut: String?
    let category: TaskType
    let createdAt: Date
    var usageCount: Int
    let isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        keyboardShortcut: String? = nil,
        category: TaskType,
        createdAt: Date = Date(),
        usageCount: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.keyboardShortcut = keyboardShortcut
        self.category = category
        self.createdAt = createdAt
        self.usageCount = usageCount
        self.isEnabled = isEnabled
    }
}

// MARK: - Privacy Settings
struct PrivacySettings: Codable {
    var allowCloudProcessing: Bool
    var shareUsageData: Bool
    var storeConversationHistory: Bool
    var encryptLocalData: Bool
    var autoDeleteOldChats: Bool
    var autoDeleteAfterDays: Int
    var dataSensitivityLevel: DataSensitivityLevel
    
    init(
        allowCloudProcessing: Bool = true,
        shareUsageData: Bool = false,
        storeConversationHistory: Bool = true,
        encryptLocalData: Bool = true,
        autoDeleteOldChats: Bool = false,
        autoDeleteAfterDays: Int = 30,
        dataSensitivityLevel: DataSensitivityLevel = .balanced
    ) {
        self.allowCloudProcessing = allowCloudProcessing
        self.shareUsageData = shareUsageData
        self.storeConversationHistory = storeConversationHistory
        self.encryptLocalData = encryptLocalData
        self.autoDeleteOldChats = autoDeleteOldChats
        self.autoDeleteAfterDays = autoDeleteAfterDays
        self.dataSensitivityLevel = dataSensitivityLevel
    }
}

enum DataSensitivityLevel: String, CaseIterable, Codable {
    case strict = "strict"
    case balanced = "balanced"
    case permissive = "permissive"
    
    var displayName: String {
        switch self {
        case .strict: return "Strict (Local Only)"
        case .balanced: return "Balanced"
        case .permissive: return "Permissive"
        }
    }
    
    var description: String {
        switch self {
        case .strict: return "All processing happens locally. No data sent to cloud services."
        case .balanced: return "Simple tasks processed locally, complex tasks use cloud services."
        case .permissive: return "Uses cloud services for optimal performance and capabilities."
        }
    }
}

// MARK: - Notification Settings
struct NotificationSettings: Codable {
    var enableNotifications: Bool
    var taskCompletionNotifications: Bool
    var errorNotifications: Bool
    var usageReportNotifications: Bool
    var soundEnabled: Bool
    var notificationSound: NotificationSound
    
    init(
        enableNotifications: Bool = true,
        taskCompletionNotifications: Bool = true,
        errorNotifications: Bool = true,
        usageReportNotifications: Bool = false,
        soundEnabled: Bool = true,
        notificationSound: NotificationSound = .default
    ) {
        self.enableNotifications = enableNotifications
        self.taskCompletionNotifications = taskCompletionNotifications
        self.errorNotifications = errorNotifications
        self.usageReportNotifications = usageReportNotifications
        self.soundEnabled = soundEnabled
        self.notificationSound = notificationSound
    }
}

enum NotificationSound: String, CaseIterable, Codable {
    case `default` = "default"
    case glass = "Glass"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case tink = "Tink"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Workflow Definition
struct WorkflowModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let steps: [WorkflowStep]
    let createdAt: Date
    var lastExecuted: Date?
    var executionCount: Int
    let isEnabled: Bool
    let category: TaskType
    let estimatedDuration: TimeInterval
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        steps: [WorkflowStep] = [],
        createdAt: Date = Date(),
        lastExecuted: Date? = nil,
        executionCount: Int = 0,
        isEnabled: Bool = true,
        category: TaskType = .automation,
        estimatedDuration: TimeInterval = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.createdAt = createdAt
        self.lastExecuted = lastExecuted
        self.executionCount = executionCount
        self.isEnabled = isEnabled
        self.category = category
        self.estimatedDuration = estimatedDuration
    }
}

// MARK: - Workflow Step
struct WorkflowStep: Identifiable, Codable {
    let id: UUID
    let type: StepType
    let parameters: [String: String]
    let continueOnError: Bool
    let retryCount: Int
    let description: String
    
    init(
        id: UUID = UUID(),
        type: StepType,
        parameters: [String: String] = [:],
        continueOnError: Bool = false,
        retryCount: Int = 0,
        description: String
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.continueOnError = continueOnError
        self.retryCount = retryCount
        self.description = description
    }
    
    enum StepType: String, Codable {
        case fileOperation = "file_operation"
        case systemCommand = "system_command"
        case appIntegration = "app_integration"
        case userInput = "user_input"
        case conditional = "conditional"
        case delay = "delay"
        case notification = "notification"
    }
}

// MARK: - Interface Preferences
struct InterfacePreferences: Codable {
    var compactMode: Bool
    var showTimestamps: Bool
    var groupMessages: Bool
    var animationsEnabled: Bool
    var soundEffectsEnabled: Bool
    var messageSpacing: MessageSpacing
    var fontScale: FontScale
    var showTypingIndicators: Bool
    var autoScrollToBottom: Bool
    
    init(
        compactMode: Bool = false,
        showTimestamps: Bool = true,
        groupMessages: Bool = true,
        animationsEnabled: Bool = true,
        soundEffectsEnabled: Bool = true,
        messageSpacing: MessageSpacing = .normal,
        fontScale: FontScale = .normal,
        showTypingIndicators: Bool = true,
        autoScrollToBottom: Bool = true
    ) {
        self.compactMode = compactMode
        self.showTimestamps = showTimestamps
        self.groupMessages = groupMessages
        self.animationsEnabled = animationsEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.messageSpacing = messageSpacing
        self.fontScale = fontScale
        self.showTypingIndicators = showTypingIndicators
        self.autoScrollToBottom = autoScrollToBottom
    }
}

enum MessageSpacing: String, CaseIterable, Codable {
    case compact = "compact"
    case normal = "normal"
    case comfortable = "comfortable"
    
    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .normal: return "Normal"
        case .comfortable: return "Comfortable"
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .compact: return 8
        case .normal: return 12
        case .comfortable: return 16
        }
    }
}

enum FontScale: String, CaseIterable, Codable {
    case small = "small"
    case normal = "normal"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .normal: return "Normal"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .small: return 0.9
        case .normal: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        }
    }
}

// MARK: - Custom Theme Settings
struct CustomThemeSettings: Codable {
    var accentColor: String
    var backgroundColor: String
    var textColor: String
    var messageBackgroundColor: String
    var borderRadius: Double
    var useCustomColors: Bool
    
    init(
        accentColor: String = "#007AFF",
        backgroundColor: String = "#FFFFFF",
        textColor: String = "#000000",
        messageBackgroundColor: String = "#F2F2F7",
        borderRadius: Double = 18.0,
        useCustomColors: Bool = false
    ) {
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.messageBackgroundColor = messageBackgroundColor
        self.borderRadius = borderRadius
        self.useCustomColors = useCustomColors
    }
}

// MARK: - Keyboard Shortcut Configuration
struct KeyboardShortcutConfiguration: Codable {
    var globalShortcuts: [String: String] // Action -> Key combination
    var chatShortcuts: [String: String]
    var customShortcuts: [String: String]
    
    init() {
        self.globalShortcuts = [
            "newChat": "⌘N",
            "openSettings": "⌘,",
            "toggleSidebar": "⌘S",
            "clearChat": "⌘K"
        ]
        
        self.chatShortcuts = [
            "sendMessage": "⌘↩",
            "newLine": "⇧↩",
            "focusInput": "⌘L",
            "scrollToTop": "⌘↑",
            "scrollToBottom": "⌘↓"
        ]
        
        self.customShortcuts = [:]
    }
}

// MARK: - Command Alias
struct CommandAlias: Identifiable, Codable {
    let id: UUID
    let alias: String
    let command: String
    let description: String
    let category: TaskType
    let isEnabled: Bool
    let createdAt: Date
    var usageCount: Int
    
    init(
        id: UUID = UUID(),
        alias: String,
        command: String,
        description: String = "",
        category: TaskType = .settings,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.alias = alias
        self.command = command
        self.description = description
        self.category = category
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.usageCount = usageCount
    }
}

// MARK: - Data Usage Summary
struct DataUsageSummary: Codable {
    let conversationCount: Int
    let totalMessages: Int
    let shortcutsCount: Int
    let aliasesCount: Int
    let storageUsed: Int64 // in bytes
    let lastBackup: Date?
    let dataRetentionDays: Int
    
    init(
        conversationCount: Int = 0,
        totalMessages: Int = 0,
        shortcutsCount: Int = 0,
        aliasesCount: Int = 0,
        storageUsed: Int64 = 0,
        lastBackup: Date? = nil,
        dataRetentionDays: Int = 30
    ) {
        self.conversationCount = conversationCount
        self.totalMessages = totalMessages
        self.shortcutsCount = shortcutsCount
        self.aliasesCount = aliasesCount
        self.storageUsed = storageUsed
        self.lastBackup = lastBackup
        self.dataRetentionDays = dataRetentionDays
    }
}

// MARK: - User Data Export
struct UserDataExport: Codable {
    let preferences: UserPreferences
    let shortcuts: [TaskShortcut]
    let aliases: [CommandAlias]
    let customSettings: [String: String]
    let exportDate: Date
    let version: String
    
    init(
        preferences: UserPreferences,
        shortcuts: [TaskShortcut] = [],
        aliases: [CommandAlias] = [],
        customSettings: [String: String] = [:],
        version: String = "1.0.0"
    ) {
        self.preferences = preferences
        self.shortcuts = shortcuts
        self.aliases = aliases
        self.customSettings = customSettings
        self.exportDate = Date()
        self.version = version
    }
}