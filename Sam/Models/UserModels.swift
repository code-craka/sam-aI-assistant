import Foundation
import SwiftUI

// MARK: - User Preferences
struct UserPreferences: Codable {
    let id: UUID
    var preferredModel: AIModel
    var maxTokens: Int
    var temperature: Float
    var autoExecuteTasks: Bool
    var confirmDangerousOperations: Bool
    var themeMode: ThemeMode
    var shortcuts: [TaskShortcut]
    var privacySettings: PrivacySettings
    var notificationSettings: NotificationSettings
    
    init(
        id: UUID = UUID(),
        preferredModel: AIModel = .gpt4Turbo,
        maxTokens: Int = 4000,
        temperature: Float = 0.7,
        autoExecuteTasks: Bool = false,
        confirmDangerousOperations: Bool = true,
        themeMode: ThemeMode = .system,
        shortcuts: [TaskShortcut] = [],
        privacySettings: PrivacySettings = PrivacySettings(),
        notificationSettings: NotificationSettings = NotificationSettings()
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
    }
}

// MARK: - AI Model Configuration
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

// MARK: - Theme Mode
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
struct Workflow: Identifiable, Codable {
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