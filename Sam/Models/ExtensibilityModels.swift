import Foundation

// MARK: - Extensibility Framework Models

// MARK: - Plugin Registry
struct PluginRegistry: Codable {
    var plugins: [String: PluginInfo]
    var categories: [PluginCategory]
    var dependencies: [String: [String]]
    var conflicts: [String: [String]]
    
    struct PluginInfo: Codable {
        let identifier: String
        let name: String
        let version: String
        let author: String
        let description: String
        let category: PluginCategory
        let installDate: Date
        let lastUpdate: Date
        let isEnabled: Bool
        let permissions: [PluginPermission]
        let dependencies: [String]
        let minimumSamVersion: String
        let supportedPlatforms: [String]
        let downloadURL: String?
        let documentationURL: String?
        let sourceCodeURL: String?
    }
    
    enum PluginCategory: String, Codable, CaseIterable {
        case productivity = "productivity"
        case development = "development"
        case fileManagement = "file_management"
        case systemUtilities = "system_utilities"
        case communication = "communication"
        case media = "media"
        case automation = "automation"
        case integration = "integration"
        case customization = "customization"
        case experimental = "experimental"
        
        var displayName: String {
            switch self {
            case .productivity: return "Productivity"
            case .development: return "Development"
            case .fileManagement: return "File Management"
            case .systemUtilities: return "System Utilities"
            case .communication: return "Communication"
            case .media: return "Media"
            case .automation: return "Automation"
            case .integration: return "Integration"
            case .customization: return "Customization"
            case .experimental: return "Experimental"
            }
        }
    }
}

// MARK: - Command Extension Models
struct CommandExtensionRegistry: Codable {
    var extensions: [String: CommandExtensionInfo]
    var userCommands: [String: UserCommandInfo]
    var aliases: [String: String]
    var shortcuts: [String: KeyboardShortcut]
    
    struct CommandExtensionInfo: Codable {
        let identifier: String
        let name: String
        let description: String
        let version: String
        let author: String
        let category: CommandCategory
        let keywords: [String]
        let parameters: [CommandParameterInfo]
        let examples: [CommandExample]
        let installDate: Date
        let usageCount: Int
        let averageExecutionTime: TimeInterval
        let successRate: Double
    }
    
    struct UserCommandInfo: Codable {
        let name: String
        let description: String
        let script: String
        let parameters: [String]
        let category: CommandCategory
        let createdDate: Date
        let lastModified: Date
        let usageCount: Int
        let isEnabled: Bool
        let tags: [String]
    }
    
    struct CommandParameterInfo: Codable {
        let name: String
        let type: String
        let description: String
        let isRequired: Bool
        let defaultValue: String?
        let validationRules: [String]
        let examples: [String]
    }
    
    struct CommandExample: Codable {
        let description: String
        let command: String
        let expectedOutput: String?
        let notes: String?
    }
    
    struct KeyboardShortcut: Codable {
        let key: String
        let modifiers: [String]
        let command: String
        let description: String
    }
}

// MARK: - API Integration Models
struct APIIntegrationRegistry: Codable {
    var integrations: [String: APIIntegrationInfo]
    var connections: [String: APIConnectionInfo]
    var credentials: [String: String] // Encrypted credential references
    var rateLimits: [String: RateLimitInfo]
    var usage: [String: APIUsageInfo]
    
    struct APIIntegrationInfo: Codable {
        let identifier: String
        let name: String
        let description: String
        let version: String
        let baseURL: String
        let authType: String
        let supportedMethods: [String]
        let endpoints: [APIEndpointInfo]
        let documentation: String?
        let installDate: Date
        let isEnabled: Bool
        let category: APICategory
    }
    
    struct APIConnectionInfo: Codable {
        let identifier: String
        let apiIdentifier: String
        let name: String
        let isActive: Bool
        let lastConnected: Date?
        let connectionType: String
        let healthStatus: String
        let errorCount: Int
        let successCount: Int
    }
    
    struct APIEndpointInfo: Codable {
        let path: String
        let method: String
        let description: String
        let parameters: [APIParameterInfo]
        let responseSchema: String?
        let examples: [APIExample]
        let rateLimitTier: String?
    }
    
    struct APIParameterInfo: Codable {
        let name: String
        let type: String
        let description: String
        let required: Bool
        let defaultValue: String?
        let validation: String?
    }
    
    struct APIExample: Codable {
        let description: String
        let request: String
        let response: String
        let notes: String?
    }
    
    struct RateLimitInfo: Codable {
        let requestsPerMinute: Int
        let requestsPerHour: Int
        let requestsPerDay: Int
        let burstLimit: Int
        let currentUsage: Int
        let resetTime: Date?
    }
    
    struct APIUsageInfo: Codable {
        let totalRequests: Int
        let successfulRequests: Int
        let failedRequests: Int
        let averageResponseTime: TimeInterval
        let lastUsed: Date?
        let monthlyUsage: [String: Int] // Month -> Request count
    }
    
    enum APICategory: String, Codable, CaseIterable {
        case productivity = "productivity"
        case communication = "communication"
        case development = "development"
        case storage = "storage"
        case analytics = "analytics"
        case social = "social"
        case ecommerce = "ecommerce"
        case finance = "finance"
        case media = "media"
        case custom = "custom"
    }
}

// MARK: - Telemetry Models
struct TelemetryConfiguration: Codable {
    var isEnabled: Bool
    var dataRetentionDays: Int
    var batchSize: Int
    var flushInterval: TimeInterval
    var privacyLevel: PrivacyLevel
    var allowedEventTypes: Set<String>
    var excludedProperties: Set<String>
    var anonymizationRules: [AnonymizationRule]
    
    enum PrivacyLevel: String, Codable, CaseIterable {
        case minimal = "minimal"
        case standard = "standard"
        case detailed = "detailed"
        case full = "full"
        
        var description: String {
            switch self {
            case .minimal:
                return "Only essential error and performance data"
            case .standard:
                return "Basic usage patterns and feature adoption"
            case .detailed:
                return "Detailed usage analytics for improvement"
            case .full:
                return "Complete telemetry for development and research"
            }
        }
    }
    
    struct AnonymizationRule: Codable {
        let pattern: String
        let replacement: String
        let isRegex: Bool
    }
}

struct TelemetryMetrics: Codable {
    var eventCounts: [String: Int]
    var errorRates: [String: Double]
    var performanceMetrics: [String: PerformanceMetric]
    var featureAdoption: [String: FeatureAdoptionMetric]
    var userBehavior: UserBehaviorMetrics
    var systemHealth: SystemHealthMetrics
    
    struct PerformanceMetric: Codable {
        let averageTime: TimeInterval
        let medianTime: TimeInterval
        let p95Time: TimeInterval
        let p99Time: TimeInterval
        let minTime: TimeInterval
        let maxTime: TimeInterval
        let sampleCount: Int
    }
    
    struct FeatureAdoptionMetric: Codable {
        let totalUsers: Int
        let activeUsers: Int
        let adoptionRate: Double
        let retentionRate: Double
        let averageUsagePerUser: Double
        let firstUsageDate: Date?
        let lastUsageDate: Date?
    }
    
    struct UserBehaviorMetrics: Codable {
        let averageSessionDuration: TimeInterval
        let averageCommandsPerSession: Double
        let mostUsedCommands: [String: Int]
        let commandSequencePatterns: [String: Int]
        let errorRecoveryPatterns: [String: Int]
        let helpUsageFrequency: Double
    }
    
    struct SystemHealthMetrics: Codable {
        let memoryUsage: MemoryUsageMetric
        let cpuUsage: CPUUsageMetric
        let diskUsage: DiskUsageMetric
        let networkUsage: NetworkUsageMetric
        let crashRate: Double
        let startupTime: TimeInterval
        
        struct MemoryUsageMetric: Codable {
            let average: Int64
            let peak: Int64
            let leakDetected: Bool
        }
        
        struct CPUUsageMetric: Codable {
            let average: Double
            let peak: Double
            let backgroundUsage: Double
        }
        
        struct DiskUsageMetric: Codable {
            let totalSpace: Int64
            let usedSpace: Int64
            let cacheSize: Int64
            let logSize: Int64
        }
        
        struct NetworkUsageMetric: Codable {
            let totalRequests: Int
            let failedRequests: Int
            let averageLatency: TimeInterval
            let dataTransferred: Int64
        }
    }
}

// MARK: - Extension Marketplace Models
struct ExtensionMarketplace: Codable {
    var featuredExtensions: [String]
    var categories: [MarketplaceCategory]
    var searchIndex: [String: [String]]
    var reviews: [String: [ExtensionReview]]
    var downloads: [String: Int]
    var ratings: [String: ExtensionRating]
    
    struct MarketplaceCategory: Codable {
        let name: String
        let description: String
        let extensions: [String]
        let icon: String?
    }
    
    struct ExtensionReview: Codable {
        let id: String
        let userId: String
        let rating: Int
        let title: String
        let content: String
        let date: Date
        let helpful: Int
        let version: String
    }
    
    struct ExtensionRating: Codable {
        let averageRating: Double
        let totalRatings: Int
        let ratingDistribution: [Int: Int] // Rating -> Count
    }
}

// MARK: - Security Models
struct ExtensionSecurity: Codable {
    var trustedPublishers: Set<String>
    var blockedExtensions: Set<String>
    var securityPolicies: [SecurityPolicy]
    var permissionGrants: [String: Set<String>]
    var auditLog: [SecurityAuditEntry]
    
    struct SecurityPolicy: Codable {
        let name: String
        let description: String
        let rules: [SecurityRule]
        let isEnabled: Bool
    }
    
    struct SecurityRule: Codable {
        let type: String
        let condition: String
        let action: String
        let severity: String
    }
    
    struct SecurityAuditEntry: Codable {
        let timestamp: Date
        let extensionId: String
        let action: String
        let result: String
        let details: String?
    }
}

// MARK: - Update Management Models
struct ExtensionUpdateManager: Codable {
    var updateChannels: [String: UpdateChannel]
    var pendingUpdates: [String: PendingUpdate]
    var updateHistory: [String: [UpdateHistoryEntry]]
    var autoUpdateSettings: AutoUpdateSettings
    
    struct UpdateChannel: Codable {
        let name: String
        let description: String
        let stability: String
        let frequency: String
    }
    
    struct PendingUpdate: Codable {
        let extensionId: String
        let currentVersion: String
        let newVersion: String
        let releaseNotes: String
        let size: Int64
        let isSecurityUpdate: Bool
        let availableDate: Date
    }
    
    struct UpdateHistoryEntry: Codable {
        let version: String
        let updateDate: Date
        let changeLog: String
        let wasSuccessful: Bool
        let rollbackAvailable: Bool
    }
    
    struct AutoUpdateSettings: Codable {
        let isEnabled: Bool
        let includeBeta: Bool
        let securityUpdatesOnly: Bool
        let updateSchedule: String
        let excludedExtensions: Set<String>
    }
}

// MARK: - Development Tools Models
struct ExtensionDevelopmentKit: Codable {
    var templates: [ExtensionTemplate]
    var debuggingTools: [DebuggingTool]
    var testingFramework: TestingFramework
    var documentation: [DocumentationResource]
    
    struct ExtensionTemplate: Codable {
        let name: String
        let description: String
        let category: String
        let files: [TemplateFile]
        let dependencies: [String]
    }
    
    struct TemplateFile: Codable {
        let path: String
        let content: String
        let isExecutable: Bool
    }
    
    struct DebuggingTool: Codable {
        let name: String
        let description: String
        let command: String
        let parameters: [String]
    }
    
    struct TestingFramework: Codable {
        let name: String
        let version: String
        let testTypes: [String]
        let mockingSupport: Bool
        let coverageReporting: Bool
    }
    
    struct DocumentationResource: Codable {
        let title: String
        let url: String
        let type: String
        let lastUpdated: Date
    }
}

// MARK: - Configuration Models
struct ExtensibilityConfiguration: Codable {
    var pluginSettings: PluginSettings
    var commandSettings: CommandSettings
    var apiSettings: APISettings
    var telemetrySettings: TelemetryConfiguration
    var securitySettings: SecuritySettings
    var updateSettings: UpdateSettings
    
    struct PluginSettings: Codable {
        var maxPlugins: Int
        var allowExperimentalPlugins: Bool
        var pluginTimeout: TimeInterval
        var sandboxingEnabled: Bool
        var resourceLimits: ResourceLimits
    }
    
    struct CommandSettings: Codable {
        var maxCustomCommands: Int
        var commandTimeout: TimeInterval
        var allowScriptExecution: Bool
        var historySize: Int
    }
    
    struct APISettings: Codable {
        var maxConnections: Int
        var defaultTimeout: TimeInterval
        var retryAttempts: Int
        var rateLimitingEnabled: Bool
    }
    
    struct SecuritySettings: Codable {
        var requireSignedExtensions: Bool
        var allowNetworkAccess: Bool
        var allowFileSystemAccess: Bool
        var permissionPrompts: Bool
    }
    
    struct UpdateSettings: Codable {
        var checkFrequency: TimeInterval
        var autoUpdate: Bool
        var betaChannel: Bool
        var backupBeforeUpdate: Bool
    }
    
    struct ResourceLimits: Codable {
        var maxMemoryMB: Int
        var maxCPUPercent: Double
        var maxDiskSpaceMB: Int
        var maxNetworkBandwidthKBps: Int
    }
}

// MARK: - Error Models
enum ExtensibilityError: LocalizedError {
    case pluginNotFound(String)
    case pluginLoadFailed(String, Error)
    case commandNotFound(String)
    case commandExecutionFailed(String, Error)
    case apiConnectionFailed(String, Error)
    case permissionDenied(String)
    case resourceLimitExceeded(String)
    case securityViolation(String)
    case updateFailed(String, Error)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .pluginNotFound(let id):
            return "Plugin not found: \(id)"
        case .pluginLoadFailed(let id, let error):
            return "Failed to load plugin \(id): \(error.localizedDescription)"
        case .commandNotFound(let command):
            return "Command not found: \(command)"
        case .commandExecutionFailed(let command, let error):
            return "Command execution failed for \(command): \(error.localizedDescription)"
        case .apiConnectionFailed(let api, let error):
            return "API connection failed for \(api): \(error.localizedDescription)"
        case .permissionDenied(let resource):
            return "Permission denied for: \(resource)"
        case .resourceLimitExceeded(let resource):
            return "Resource limit exceeded: \(resource)"
        case .securityViolation(let details):
            return "Security violation: \(details)"
        case .updateFailed(let extension, let error):
            return "Update failed for \(extension): \(error.localizedDescription)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }
}