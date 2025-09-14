import Foundation
import SwiftUI

// MARK: - App Constants
struct AppConstants {
    static let appName = "Sam AI Assistant"
    static let bundleIdentifier = "com.samassistant.Sam"
    static let version = "1.0.0"
    static let buildNumber = "1"
    
    // MARK: - URLs and Identifiers
    static let supportURL = URL(string: "https://samassistant.com/support")!
    static let privacyPolicyURL = URL(string: "https://samassistant.com/privacy")!
    static let termsOfServiceURL = URL(string: "https://samassistant.com/terms")!
    
    // MARK: - File System
    static let applicationSupportDirectory = "Sam AI Assistant"
    static let logsDirectory = "Logs"
    static let cacheDirectory = "Cache"
    static let workflowsDirectory = "Workflows"
    
    // MARK: - Core Data
    static let coreDataModelName = "SamDataModel"
    static let coreDataStoreType = "sqlite"
}

// MARK: - AI Configuration
struct AIConstants {
    // MARK: - OpenAI Configuration
    static let openAIBaseURL = "https://api.openai.com/v1"
    static let openAIMaxTokens = 4000
    static let openAITemperature: Float = 0.7
    static let openAITimeout: TimeInterval = 30.0
    
    // MARK: - Model Limits
    static let gpt4MaxTokens = 8192
    static let gpt4TurboMaxTokens = 128000
    static let gpt35TurboMaxTokens = 4096
    static let localModelMaxTokens = 2048
    
    // MARK: - Cost Tracking
    static let gpt4CostPerToken = 0.00003
    static let gpt4TurboCostPerToken = 0.00001
    static let gpt35TurboCostPerToken = 0.0000015
    
    // MARK: - Rate Limiting
    static let maxRequestsPerMinute = 60
    static let maxTokensPerMinute = 90000
    static let rateLimitWindowSeconds: TimeInterval = 60
}

// MARK: - Task Processing
struct TaskConstants {
    // MARK: - Classification Thresholds
    static let minimumConfidenceThreshold = 0.6
    static let localProcessingThreshold = 0.8
    static let confirmationRequiredThreshold = 0.9
    
    // MARK: - Execution Limits
    static let maxExecutionTime: TimeInterval = 300.0 // 5 minutes
    static let maxRetryAttempts = 3
    static let retryDelaySeconds: TimeInterval = 1.0
    
    // MARK: - File Operations
    static let maxBatchFileOperations = 100
    static let maxFileSize: Int64 = 1_000_000_000 // 1GB
    static let supportedFileExtensions = [
        "txt", "md", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg",
        "mp3", "wav", "aac", "m4a", "flac",
        "mp4", "mov", "avi", "mkv", "wmv",
        "zip", "rar", "7z", "tar", "gz"
    ]
    
    // MARK: - System Monitoring
    static let contextUpdateInterval: TimeInterval = 30.0
    static let systemInfoCacheTimeout: TimeInterval = 60.0
    static let maxConversationHistoryLength = 20
}

// MARK: - UI Constants
struct UIConstants {
    // MARK: - Window Dimensions
    static let minWindowWidth: CGFloat = 800
    static let minWindowHeight: CGFloat = 600
    static let defaultWindowWidth: CGFloat = 1000
    static let defaultWindowHeight: CGFloat = 700
    
    // MARK: - Sidebar
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 250
    static let sidebarMaxWidth: CGFloat = 300
    
    // MARK: - Chat Interface
    static let maxMessageWidth: CGFloat = 300
    static let messageCornerRadius: CGFloat = 18
    static let messagePadding: CGFloat = 16
    static let messageSpacing: CGFloat = 12
    
    // MARK: - Animation Durations
    static let shortAnimationDuration: TimeInterval = 0.2
    static let mediumAnimationDuration: TimeInterval = 0.3
    static let longAnimationDuration: TimeInterval = 0.5
    
    // MARK: - Colors
    static let accentColor = Color.blue
    static let successColor = Color.green
    static let warningColor = Color.orange
    static let errorColor = Color.red
    static let secondaryTextColor = Color.secondary
    static let tertiaryTextColor = Color(NSColor.tertiaryLabelColor)
}

// MARK: - Keyboard Shortcuts
struct KeyboardShortcuts {
    static let newChat = "n"
    static let sendMessage = "return"
    static let sendMessageModifier = "command"
    static let openSettings = ","
    static let openHelp = "?"
    static let clearChat = "k"
    static let exportChat = "e"
    static let toggleSidebar = "s"
}

// MARK: - Notification Names
extension Notification.Name {
    static let taskCompleted = Notification.Name("TaskCompleted")
    static let taskFailed = Notification.Name("TaskFailed")
    static let contextUpdated = Notification.Name("ContextUpdated")
    static let workflowStarted = Notification.Name("WorkflowStarted")
    static let workflowCompleted = Notification.Name("WorkflowCompleted")
    static let settingsChanged = Notification.Name("SettingsChanged")
    static let apiKeyUpdated = Notification.Name("APIKeyUpdated")
}

// MARK: - User Defaults Keys
struct UserDefaultsKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let preferredAIModel = "preferredAIModel"
    static let maxTokens = "maxTokens"
    static let temperature = "temperature"
    static let autoExecuteTasks = "autoExecuteTasks"
    static let confirmDangerousOperations = "confirmDangerousOperations"
    static let themeMode = "themeMode"
    static let allowCloudProcessing = "allowCloudProcessing"
    static let storeConversationHistory = "storeConversationHistory"
    static let lastUsedVersion = "lastUsedVersion"
    static let usageStatistics = "usageStatistics"
}

// MARK: - Keychain Keys
struct KeychainKeys {
    static let openAIAPIKey = "openai_api_key"
    static let anthropicAPIKey = "anthropic_api_key"
    static let googleAPIKey = "google_api_key"
    static let azureAPIKey = "azure_api_key"
    static let encryptionKey = "local_encryption_key"
    static let masterEncryptionKey = "master_encryption_key"
    static let userIdentifier = "user_identifier"
    static let biometricAuthKey = "biometric_auth_key"
}

// MARK: - Error Codes
struct ErrorCodes {
    static let taskClassificationFailed = 1001
    static let fileOperationFailed = 1002
    static let systemAccessDenied = 1003
    static let appIntegrationFailed = 1004
    static let aiServiceError = 1005
    static let workflowExecutionFailed = 1006
    static let networkError = 1007
    static let authenticationError = 1008
    static let permissionDenied = 1009
    static let invalidInput = 1010
}

// MARK: - File Paths
struct FilePaths {
    static let logFile = "sam.log"
    static let crashReportFile = "crash_report.log"
    static let usageStatsFile = "usage_stats.json"
    static let workflowsFile = "workflows.json"
    static let preferencesFile = "preferences.plist"
}

// MARK: - System Requirements
struct SystemRequirements {
    static let minimumMacOSVersion = "13.0"
    static let minimumRAM: Int64 = 4_000_000_000 // 4GB
    static let minimumDiskSpace: Int64 = 1_000_000_000 // 1GB
    static let recommendedRAM: Int64 = 8_000_000_000 // 8GB
    static let recommendedDiskSpace: Int64 = 5_000_000_000 // 5GB
}

// MARK: - Feature Flags
struct FeatureFlags {
    static let enableLocalAI = true
    static let enableWorkflows = true
    static let enableAdvancedFileOperations = true
    static let enableSystemIntegration = true
    static let enableAppAutomation = true
    static let enableUsageAnalytics = false
    static let enableCrashReporting = true
    static let enableBetaFeatures = false
}

// MARK: - Debug Settings
#if DEBUG
struct DebugSettings {
    static let enableVerboseLogging = true
    static let enablePerformanceMonitoring = true
    static let enableMemoryDebugging = true
    static let simulateSlowNetwork = false
    static let simulateAPIErrors = false
    static let mockSystemInfo = true
}
#endif