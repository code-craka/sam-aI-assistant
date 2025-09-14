import Foundation
import CryptoKit
import NaturalLanguage

/// Manages privacy and data sensitivity classification for Sam
@MainActor
class PrivacyManager: ObservableObject {
    
    // MARK: - Data Sensitivity Classification
    
    enum DataSensitivity: Int, CaseIterable {
        case public = 0
        case personal = 1
        case sensitive = 2
        case confidential = 3
        
        var description: String {
            switch self {
            case .public:
                return "Public information safe for cloud processing"
            case .personal:
                return "Personal information requiring user consent"
            case .sensitive:
                return "Sensitive data preferring local processing"
            case .confidential:
                return "Confidential data requiring local-only processing"
            }
        }
        
        var allowsCloudProcessing: Bool {
            switch self {
            case .public, .personal:
                return true
            case .sensitive, .confidential:
                return false
            }
        }
    }
    
    // MARK: - Privacy Settings
    
    @Published var allowCloudProcessing = true
    @Published var requireConfirmationForSensitive = true
    @Published var logDataAccess = true
    @Published var encryptLocalData = true
    
    // MARK: - Data Classification Patterns
    
    private let personalInfoPatterns = [
        // Email addresses
        #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
        // Phone numbers
        #"(\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,
        // Social Security Numbers
        #"\b\d{3}-?\d{2}-?\d{4}\b"#,
        // Credit card numbers (basic pattern)
        #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#
    ]
    
    private let sensitiveKeywords = [
        "password", "secret", "key", "token", "credential", "login",
        "bank", "account", "financial", "medical", "health", "diagnosis",
        "salary", "income", "tax", "ssn", "social security",
        "private", "confidential", "classified"
    ]
    
    private let filePathKeywords = [
        "documents", "desktop", "downloads", "pictures", "movies",
        "music", "library", "applications", "system", "users"
    ]
    
    // MARK: - Initialization
    
    init() {
        loadPrivacySettings()
    }
    
    // MARK: - Data Sensitivity Classification
    
    func classifyDataSensitivity(_ content: String) -> DataSensitivity {
        let lowercaseContent = content.lowercased()
        
        // Check for confidential patterns first
        if containsConfidentialData(content) {
            return .confidential
        }
        
        // Check for sensitive information
        if containsSensitiveData(lowercaseContent) {
            return .sensitive
        }
        
        // Check for personal information
        if containsPersonalInfo(content) {
            return .personal
        }
        
        // Default to public if no sensitive patterns found
        return .public
    }
    
    private func containsConfidentialData(_ content: String) -> Bool {
        // Check for patterns that should never leave the device
        let confidentialPatterns = [
            #"\b\d{3}-?\d{2}-?\d{4}\b"#, // SSN
            #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#, // Credit cards
            #"(?i)(password|secret|key|token)\s*[:=]\s*\S+"# // Credentials
        ]
        
        return confidentialPatterns.contains { pattern in
            content.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    private func containsSensitiveData(_ content: String) -> Bool {
        // Check for sensitive keywords
        let containsSensitiveKeywords = sensitiveKeywords.contains { keyword in
            content.contains(keyword)
        }
        
        // Check for file paths that might contain sensitive data
        let containsFilePaths = filePathKeywords.contains { keyword in
            content.contains(keyword) && content.contains("/")
        }
        
        return containsSensitiveKeywords || containsFilePaths
    }
    
    private func containsPersonalInfo(_ content: String) -> Bool {
        return personalInfoPatterns.contains { pattern in
            content.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    // MARK: - Processing Decision Logic
    
    func shouldProcessLocally(_ content: String) -> Bool {
        let sensitivity = classifyDataSensitivity(content)
        
        // Always process locally if cloud processing is disabled
        if !allowCloudProcessing {
            return true
        }
        
        // Process locally for sensitive and confidential data
        return !sensitivity.allowsCloudProcessing
    }
    
    func requiresUserConsent(_ content: String) -> Bool {
        let sensitivity = classifyDataSensitivity(content)
        
        return requireConfirmationForSensitive && 
               (sensitivity == .sensitive || sensitivity == .confidential)
    }
    
    // MARK: - Data Sanitization
    
    func sanitizeForLogging(_ content: String) -> String {
        var sanitized = content
        
        // Replace email addresses
        sanitized = sanitized.replacingOccurrences(
            of: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            with: "[EMAIL]",
            options: .regularExpression
        )
        
        // Replace phone numbers
        sanitized = sanitized.replacingOccurrences(
            of: #"(\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,
            with: "[PHONE]",
            options: .regularExpression
        )
        
        // Replace potential passwords/tokens
        sanitized = sanitized.replacingOccurrences(
            of: #"(?i)(password|secret|key|token)\s*[:=]\s*\S+"#,
            with: "$1: [REDACTED]",
            options: .regularExpression
        )
        
        return sanitized
    }
    
    // MARK: - Privacy Settings Management
    
    private func loadPrivacySettings() {
        let defaults = UserDefaults.standard
        
        allowCloudProcessing = defaults.object(forKey: "privacy.allowCloudProcessing") as? Bool ?? true
        requireConfirmationForSensitive = defaults.object(forKey: "privacy.requireConfirmationForSensitive") as? Bool ?? true
        logDataAccess = defaults.object(forKey: "privacy.logDataAccess") as? Bool ?? true
        encryptLocalData = defaults.object(forKey: "privacy.encryptLocalData") as? Bool ?? true
    }
    
    func savePrivacySettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(allowCloudProcessing, forKey: "privacy.allowCloudProcessing")
        defaults.set(requireConfirmationForSensitive, forKey: "privacy.requireConfirmationForSensitive")
        defaults.set(logDataAccess, forKey: "privacy.logDataAccess")
        defaults.set(encryptLocalData, forKey: "privacy.encryptLocalData")
    }
    
    // MARK: - Data Access Logging
    
    func logDataAccess(_ operation: String, dataType: String, sensitivity: DataSensitivity) {
        guard logDataAccess else { return }
        
        let logEntry = DataAccessLog(
            timestamp: Date(),
            operation: operation,
            dataType: dataType,
            sensitivity: sensitivity,
            wasProcessedLocally: !sensitivity.allowsCloudProcessing || !allowCloudProcessing
        )
        
        // Store in secure log (implementation would depend on logging framework)
        storeSecureLog(logEntry)
    }
    
    private func storeSecureLog(_ log: DataAccessLog) {
        // Implementation for secure logging
        // This could write to encrypted local storage or system log
        print("Privacy Log: \(log.operation) - \(log.dataType) - \(log.sensitivity)")
    }
}

// MARK: - Supporting Types

struct DataAccessLog {
    let timestamp: Date
    let operation: String
    let dataType: String
    let sensitivity: PrivacyManager.DataSensitivity
    let wasProcessedLocally: Bool
}

// MARK: - Privacy Extensions

extension PrivacyManager {
    
    /// Determines if content should be encrypted before storage
    func shouldEncryptForStorage(_ content: String) -> Bool {
        guard encryptLocalData else { return false }
        
        let sensitivity = classifyDataSensitivity(content)
        return sensitivity != .public
    }
    
    /// Creates a privacy summary for user transparency
    func createPrivacySummary(for content: String) -> String {
        let sensitivity = classifyDataSensitivity(content)
        let processLocally = shouldProcessLocally(content)
        let requiresConsent = requiresUserConsent(content)
        
        var summary = "Privacy Analysis:\n"
        summary += "• Data Sensitivity: \(sensitivity.description)\n"
        summary += "• Processing Location: \(processLocally ? "Local" : "Cloud")\n"
        
        if requiresConsent {
            summary += "• User consent required for processing\n"
        }
        
        return summary
    }
}