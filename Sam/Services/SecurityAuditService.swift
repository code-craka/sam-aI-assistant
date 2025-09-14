import Foundation
import CoreData
import CryptoKit

/// Service for conducting security audits and monitoring
class SecurityAuditService {
    
    // MARK: - Singleton
    static let shared = SecurityAuditService()
    
    // MARK: - Private Properties
    private let privacyManager = PrivacyManager()
    private let permissionManager = PermissionManager()
    private let keychainManager = KeychainManager.shared
    private let encryptionService = DataEncryptionService.shared
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Security Audit
    
    /// Conduct comprehensive security audit
    func conductSecurityAudit() async -> SecurityAuditReport {
        let startTime = Date()
        
        // Gather all security metrics
        let permissionAudit = await auditPermissions()
        let encryptionAudit = await auditEncryption()
        let keychainAudit = await auditKeychain()
        let dataAudit = await auditDataSecurity()
        let networkAudit = await auditNetworkSecurity()
        let systemAudit = await auditSystemSecurity()
        
        // Calculate overall security score
        let overallScore = calculateOverallSecurityScore([
            permissionAudit.score,
            encryptionAudit.score,
            keychainAudit.score,
            dataAudit.score,
            networkAudit.score,
            systemAudit.score
        ])
        
        // Compile recommendations
        let recommendations = compileRecommendations([
            permissionAudit,
            encryptionAudit,
            keychainAudit,
            dataAudit,
            networkAudit,
            systemAudit
        ])
        
        let auditTime = Date().timeIntervalSince(startTime)
        
        return SecurityAuditReport(
            timestamp: Date(),
            overallScore: overallScore,
            auditDuration: auditTime,
            permissionAudit: permissionAudit,
            encryptionAudit: encryptionAudit,
            keychainAudit: keychainAudit,
            dataAudit: dataAudit,
            networkAudit: networkAudit,
            systemAudit: systemAudit,
            recommendations: recommendations
        )
    }
    
    // MARK: - Permission Audit
    
    private func auditPermissions() async -> PermissionAuditResult {
        await permissionManager.checkAllPermissions()
        let summary = permissionManager.getPermissionSummary()
        
        var issues: [SecurityIssue] = []
        var score = 100
        
        // Check for missing critical permissions
        let criticalPermissions: [PermissionType] = [.fileSystem, .accessibility, .automation]
        for permission in criticalPermissions {
            let status = permissionManager.permissionStatuses[permission] ?? .notDetermined
            if status != .granted {
                issues.append(SecurityIssue(
                    severity: .high,
                    category: .permissions,
                    title: "Missing Critical Permission",
                    description: "Permission '\(permission.displayName)' is required for core functionality",
                    recommendation: "Grant \(permission.displayName) permission in System Preferences"
                ))
                score -= 20
            }
        }
        
        // Check for denied permissions
        for (permission, status) in permissionManager.permissionStatuses {
            if status == .denied {
                issues.append(SecurityIssue(
                    severity: .medium,
                    category: .permissions,
                    title: "Denied Permission",
                    description: "Permission '\(permission.displayName)' has been denied",
                    recommendation: "Consider granting this permission for enhanced functionality"
                ))
                score -= 10
            }
        }
        
        return PermissionAuditResult(
            score: max(0, score),
            grantedPermissions: summary.grantedPermissions,
            totalPermissions: summary.totalPermissions,
            issues: issues
        )
    }
    
    // MARK: - Encryption Audit
    
    private func auditEncryption() async -> EncryptionAuditResult {
        let encryptionStatus = encryptionService.getEncryptionStatus()
        
        var issues: [SecurityIssue] = []
        var score = 100
        
        // Check if encryption is enabled
        if !encryptionStatus.isEnabled {
            issues.append(SecurityIssue(
                severity: .critical,
                category: .encryption,
                title: "Encryption Disabled",
                description: "Data encryption is not available or configured",
                recommendation: "Enable data encryption in privacy settings"
            ))
            score -= 50
        }
        
        // Check encryption coverage
        let overallEncryption = encryptionStatus.overallEncryptionPercentage
        if overallEncryption < 100 {
            let severity: SecurityIssue.Severity = overallEncryption < 50 ? .high : .medium
            issues.append(SecurityIssue(
                severity: severity,
                category: .encryption,
                title: "Incomplete Data Encryption",
                description: "Only \(Int(overallEncryption))% of sensitive data is encrypted",
                recommendation: "Encrypt all sensitive data for maximum security"
            ))
            score -= Int((100 - overallEncryption) / 2)
        }
        
        return EncryptionAuditResult(
            score: max(0, score),
            isEnabled: encryptionStatus.isEnabled,
            encryptionPercentage: overallEncryption,
            encryptedMessages: encryptionStatus.encryptedMessages,
            totalMessages: encryptionStatus.totalMessages,
            issues: issues
        )
    }
    
    // MARK: - Keychain Audit
    
    private func auditKeychain() async -> KeychainAuditResult {
        var issues: [SecurityIssue] = []
        var score = 100
        var storedKeys: [APIProvider] = []
        var keySecurityScores: [APIProvider: Int] = [:]
        
        // Check stored API keys
        for provider in APIProvider.allCases {
            if let apiKey = keychainManager.getAPIKey(for: provider) {
                storedKeys.append(provider)
                
                // Assess key security
                let assessment = keychainManager.assessAPIKeySecurity(apiKey)
                keySecurityScores[provider] = assessment.score
                
                if !assessment.isSecure {
                    let severity: SecurityIssue.Severity = assessment.score < 30 ? .critical : .medium
                    issues.append(SecurityIssue(
                        severity: severity,
                        category: .apiKeys,
                        title: "Insecure API Key",
                        description: "API key for \(provider.displayName) has security issues: \(assessment.issues.joined(separator: ", "))",
                        recommendation: "Replace with a secure API key from the provider"
                    ))
                    score -= (100 - assessment.score) / 4
                }
            }
        }
        
        // Check if any API keys are stored
        if storedKeys.isEmpty {
            issues.append(SecurityIssue(
                severity: .low,
                category: .apiKeys,
                title: "No API Keys Configured",
                description: "No API keys are currently stored",
                recommendation: "Configure API keys for AI services in settings"
            ))
            score -= 10
        }
        
        return KeychainAuditResult(
            score: max(0, score),
            storedKeys: storedKeys,
            keySecurityScores: keySecurityScores,
            issues: issues
        )
    }
    
    // MARK: - Data Security Audit
    
    private func auditDataSecurity() async -> DataSecurityAuditResult {
        let context = PersistenceController.shared.container.viewContext
        
        var issues: [SecurityIssue] = []
        var score = 100
        var sensitiveDataCount = 0
        var unencryptedSensitiveCount = 0
        
        do {
            // Audit chat messages
            let messageRequest: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
            let messages = try context.fetch(messageRequest)
            
            for message in messages {
                if message.containsSensitiveData {
                    sensitiveDataCount += 1
                    if !message.isEncrypted {
                        unencryptedSensitiveCount += 1
                    }
                }
            }
            
            // Audit user preferences
            let preferencesRequest: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
            let preferences = try context.fetch(preferencesRequest)
            
            for pref in preferences {
                if pref.shouldBeEncrypted {
                    sensitiveDataCount += 1
                    if !pref.isEncrypted {
                        unencryptedSensitiveCount += 1
                    }
                }
            }
            
            // Audit workflows
            let workflowRequest: NSFetchRequest<Workflow> = Workflow.fetchRequest()
            let workflows = try context.fetch(workflowRequest)
            
            for workflow in workflows {
                if workflow.containsSensitiveData {
                    sensitiveDataCount += 1
                    if !workflow.isEncrypted {
                        unencryptedSensitiveCount += 1
                    }
                }
            }
            
        } catch {
            issues.append(SecurityIssue(
                severity: .medium,
                category: .dataProtection,
                title: "Data Audit Failed",
                description: "Unable to complete data security audit: \(error.localizedDescription)",
                recommendation: "Check Core Data integrity and try again"
            ))
            score -= 20
        }
        
        // Check for unencrypted sensitive data
        if unencryptedSensitiveCount > 0 {
            let percentage = Double(unencryptedSensitiveCount) / Double(sensitiveDataCount) * 100
            let severity: SecurityIssue.Severity = percentage > 50 ? .high : .medium
            
            issues.append(SecurityIssue(
                severity: severity,
                category: .dataProtection,
                title: "Unencrypted Sensitive Data",
                description: "\(unencryptedSensitiveCount) of \(sensitiveDataCount) sensitive items are not encrypted",
                recommendation: "Enable automatic encryption for sensitive data"
            ))
            score -= Int(percentage / 2)
        }
        
        return DataSecurityAuditResult(
            score: max(0, score),
            sensitiveDataCount: sensitiveDataCount,
            encryptedSensitiveCount: sensitiveDataCount - unencryptedSensitiveCount,
            issues: issues
        )
    }
    
    // MARK: - Network Security Audit
    
    private func auditNetworkSecurity() async -> NetworkSecurityAuditResult {
        var issues: [SecurityIssue] = []
        var score = 100
        
        // Check privacy settings
        if privacyManager.allowCloudProcessing {
            if !privacyManager.requireConfirmationForSensitive {
                issues.append(SecurityIssue(
                    severity: .medium,
                    category: .networkSecurity,
                    title: "Automatic Cloud Processing",
                    description: "Sensitive data may be sent to cloud services without confirmation",
                    recommendation: "Enable confirmation for sensitive data processing"
                ))
                score -= 15
            }
        }
        
        // Check if local processing is preferred for sensitive data
        let testSensitiveContent = "password: secret123"
        if !privacyManager.shouldProcessLocally(testSensitiveContent) {
            issues.append(SecurityIssue(
                severity: .high,
                category: .networkSecurity,
                title: "Sensitive Data Cloud Processing",
                description: "Sensitive data is configured to be processed in the cloud",
                recommendation: "Configure sensitive data to be processed locally only"
            ))
            score -= 25
        }
        
        return NetworkSecurityAuditResult(
            score: max(0, score),
            allowsCloudProcessing: privacyManager.allowCloudProcessing,
            requiresConfirmation: privacyManager.requireConfirmationForSensitive,
            issues: issues
        )
    }
    
    // MARK: - System Security Audit
    
    private func auditSystemSecurity() async -> SystemSecurityAuditResult {
        var issues: [SecurityIssue] = []
        var score = 100
        
        // Check macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        
        // Check if running on supported macOS version
        if osVersion.majorVersion < 13 {
            issues.append(SecurityIssue(
                severity: .high,
                category: .systemSecurity,
                title: "Outdated macOS Version",
                description: "Running on macOS \(versionString), which may have security vulnerabilities",
                recommendation: "Update to the latest macOS version for security patches"
            ))
            score -= 30
        }
        
        // Check app sandbox status
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        if !isSandboxed {
            issues.append(SecurityIssue(
                severity: .medium,
                category: .systemSecurity,
                title: "App Not Sandboxed",
                description: "Application is not running in a sandbox environment",
                recommendation: "Enable app sandboxing for additional security"
            ))
            score -= 15
        }
        
        return SystemSecurityAuditResult(
            score: max(0, score),
            macOSVersion: versionString,
            isSandboxed: isSandboxed,
            issues: issues
        )
    }
    
    // MARK: - Utility Methods
    
    private func calculateOverallSecurityScore(_ scores: [Int]) -> Int {
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }
    
    private func compileRecommendations(_ audits: [SecurityAuditComponent]) -> [SecurityRecommendation] {
        var recommendations: [SecurityRecommendation] = []
        
        // Collect all issues and prioritize
        var allIssues: [SecurityIssue] = []
        for audit in audits {
            allIssues.append(contentsOf: audit.issues)
        }
        
        // Sort by severity
        allIssues.sort { $0.severity.priority > $1.severity.priority }
        
        // Convert top issues to recommendations
        for issue in allIssues.prefix(10) {
            recommendations.append(SecurityRecommendation(
                priority: issue.severity.priority,
                category: issue.category,
                title: issue.title,
                description: issue.description,
                action: issue.recommendation,
                estimatedImpact: issue.severity.impactDescription
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Quick Security Check
    
    /// Perform a quick security status check
    func quickSecurityCheck() -> QuickSecurityStatus {
        let hasAPIKey = keychainManager.hasAPIKey()
        let encryptionEnabled = encryptionService.isEncryptionAvailable
        let criticalPermissions = [PermissionType.fileSystem, .accessibility, .automation]
        let hasPermissions = criticalPermissions.allSatisfy { 
            permissionManager.permissionStatuses[$0] == .granted 
        }
        
        let score: Int
        switch (hasAPIKey, encryptionEnabled, hasPermissions) {
        case (true, true, true): score = 100
        case (true, true, false): score = 75
        case (true, false, true): score = 70
        case (false, true, true): score = 65
        case (true, false, false): score = 50
        case (false, true, false): score = 45
        case (false, false, true): score = 40
        case (false, false, false): score = 0
        }
        
        return QuickSecurityStatus(
            score: score,
            hasAPIKey: hasAPIKey,
            encryptionEnabled: encryptionEnabled,
            hasRequiredPermissions: hasPermissions
        )
    }
}

// MARK: - Supporting Types

protocol SecurityAuditComponent {
    var score: Int { get }
    var issues: [SecurityIssue] { get }
}

struct SecurityAuditReport {
    let timestamp: Date
    let overallScore: Int
    let auditDuration: TimeInterval
    let permissionAudit: PermissionAuditResult
    let encryptionAudit: EncryptionAuditResult
    let keychainAudit: KeychainAuditResult
    let dataAudit: DataSecurityAuditResult
    let networkAudit: NetworkSecurityAuditResult
    let systemAudit: SystemSecurityAuditResult
    let recommendations: [SecurityRecommendation]
    
    var securityLevel: SecurityLevel {
        switch overallScore {
        case 90...100: return .excellent
        case 70...89: return .good
        case 50...69: return .fair
        case 30...49: return .poor
        default: return .critical
        }
    }
}

struct PermissionAuditResult: SecurityAuditComponent {
    let score: Int
    let grantedPermissions: Int
    let totalPermissions: Int
    let issues: [SecurityIssue]
}

struct EncryptionAuditResult: SecurityAuditComponent {
    let score: Int
    let isEnabled: Bool
    let encryptionPercentage: Double
    let encryptedMessages: Int
    let totalMessages: Int
    let issues: [SecurityIssue]
}

struct KeychainAuditResult: SecurityAuditComponent {
    let score: Int
    let storedKeys: [APIProvider]
    let keySecurityScores: [APIProvider: Int]
    let issues: [SecurityIssue]
}

struct DataSecurityAuditResult: SecurityAuditComponent {
    let score: Int
    let sensitiveDataCount: Int
    let encryptedSensitiveCount: Int
    let issues: [SecurityIssue]
}

struct NetworkSecurityAuditResult: SecurityAuditComponent {
    let score: Int
    let allowsCloudProcessing: Bool
    let requiresConfirmation: Bool
    let issues: [SecurityIssue]
}

struct SystemSecurityAuditResult: SecurityAuditComponent {
    let score: Int
    let macOSVersion: String
    let isSandboxed: Bool
    let issues: [SecurityIssue]
}

struct SecurityIssue {
    let severity: Severity
    let category: Category
    let title: String
    let description: String
    let recommendation: String
    
    enum Severity: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        var priority: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
        
        var color: String {
            switch self {
            case .low: return "blue"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
        
        var impactDescription: String {
            switch self {
            case .low: return "Minor security improvement"
            case .medium: return "Moderate security enhancement"
            case .high: return "Significant security improvement"
            case .critical: return "Critical security fix required"
            }
        }
    }
    
    enum Category: String, CaseIterable {
        case permissions = "permissions"
        case encryption = "encryption"
        case apiKeys = "api_keys"
        case dataProtection = "data_protection"
        case networkSecurity = "network_security"
        case systemSecurity = "system_security"
        
        var displayName: String {
            switch self {
            case .permissions: return "Permissions"
            case .encryption: return "Encryption"
            case .apiKeys: return "API Keys"
            case .dataProtection: return "Data Protection"
            case .networkSecurity: return "Network Security"
            case .systemSecurity: return "System Security"
            }
        }
    }
}

struct SecurityRecommendation {
    let priority: Int
    let category: SecurityIssue.Category
    let title: String
    let description: String
    let action: String
    let estimatedImpact: String
}

struct QuickSecurityStatus {
    let score: Int
    let hasAPIKey: Bool
    let encryptionEnabled: Bool
    let hasRequiredPermissions: Bool
    
    var status: String {
        switch score {
        case 90...100: return "Excellent"
        case 70...89: return "Good"
        case 50...69: return "Fair"
        case 30...49: return "Poor"
        default: return "Critical"
        }
    }
}

enum SecurityLevel: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .critical: return "Critical"
        }
    }
    
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