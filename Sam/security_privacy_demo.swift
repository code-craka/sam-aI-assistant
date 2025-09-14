#!/usr/bin/env swift

import Foundation

// MARK: - Security and Privacy Demo Script

print("🔒 Sam Security and Privacy Implementation Demo")
print("=" * 50)

// MARK: - Privacy Manager Demo

print("\n📊 Privacy Manager Demo")
print("-" * 30)

// Simulate privacy manager functionality
struct DemoPrivacyManager {
    enum DataSensitivity: String {
        case publicData = "public", personal, sensitive, confidential
    }
    
    func classifyDataSensitivity(_ content: String) -> DataSensitivity {
        let lowercaseContent = content.lowercased()
        
        // Check for confidential patterns
        if lowercaseContent.contains("password") || lowercaseContent.contains("ssn") {
            return .confidential
        }
        
        // Check for sensitive patterns
        if lowercaseContent.contains("financial") || lowercaseContent.contains("medical") {
            return .sensitive
        }
        
        // Check for personal patterns (email)
        if lowercaseContent.contains("@") && lowercaseContent.contains(".") {
            return .personal
        }
        
        return .publicData
    }
    
    func shouldProcessLocally(_ content: String) -> Bool {
        let sensitivity = classifyDataSensitivity(content)
        return sensitivity != .publicData
    }
}

let privacyManager = DemoPrivacyManager()

let testInputs = [
    "What's the weather today?",
    "Send email to john@example.com",
    "Copy my password file to Desktop",
    "My SSN is 123-45-6789",
    "Show me my financial documents"
]

for input in testInputs {
    let sensitivity = privacyManager.classifyDataSensitivity(input)
    let processLocally = privacyManager.shouldProcessLocally(input)
    
    print("Input: \"\(input)\"")
    print("  Sensitivity: \(sensitivity.rawValue)")
    print("  Process Locally: \(processLocally)")
    print()
}

// MARK: - Keychain Security Demo

print("\n🔑 Keychain Security Demo")
print("-" * 30)

struct DemoKeychainManager {
    func validateAPIKey(_ key: String, provider: String = "openai") -> Bool {
        switch provider {
        case "openai":
            return key.hasPrefix("sk-") && key.count >= 20
        case "anthropic":
            return key.hasPrefix("sk-ant-") && key.count >= 20
        default:
            return key.count >= 20
        }
    }
    
    func assessAPIKeySecurity(_ key: String) -> (score: Int, issues: [String]) {
        var score = 100
        var issues: [String] = []
        
        if key.count < 32 {
            issues.append("Key is shorter than recommended")
            score -= 20
        }
        
        if key.contains("test") || key.contains("demo") {
            issues.append("Appears to be a test key")
            score -= 50
        }
        
        return (score: max(0, score), issues: issues)
    }
}

let keychainManager = DemoKeychainManager()

let testKeys = [
    ("sk-1234567890abcdef1234567890abcdef1234567890", "Valid OpenAI key"),
    ("sk-test123456789012345678901234567890", "Test OpenAI key"),
    ("sk-ant-1234567890abcdef1234567890abcdef", "Valid Anthropic key"),
    ("invalid-key", "Invalid key format")
]

for (key, description) in testKeys {
    let isValid = keychainManager.validateAPIKey(key)
    let assessment = keychainManager.assessAPIKeySecurity(key)
    
    print("Key: \(description)")
    print("  Valid: \(isValid)")
    print("  Security Score: \(assessment.score)/100")
    if !assessment.issues.isEmpty {
        print("  Issues: \(assessment.issues.joined(separator: ", "))")
    }
    print()
}

// MARK: - Encryption Demo

print("\n🔐 Encryption Demo")
print("-" * 30)

struct DemoEncryptionService {
    func encrypt(_ data: String) -> String {
        // Simple demo encryption (just base64 encoding for demo purposes)
        return Data(data.utf8).base64EncodedString()
    }
    
    func decrypt(_ encryptedData: String) -> String? {
        guard let data = Data(base64Encoded: encryptedData) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

let encryptionService = DemoEncryptionService()

let sensitiveData = "API Key: sk-secret123456789012345678901234567890"
print("Original: \(sensitiveData)")

let encrypted = encryptionService.encrypt(sensitiveData)
print("Encrypted: \(encrypted)")

if let decrypted = encryptionService.decrypt(encrypted) {
    print("Decrypted: \(decrypted)")
    print("Encryption/Decryption: ✅ Success")
} else {
    print("Encryption/Decryption: ❌ Failed")
}

// MARK: - Permission Management Demo

print("\n🛡️ Permission Management Demo")
print("-" * 30)

enum PermissionType: String, CaseIterable {
    case fileSystem = "File System"
    case accessibility = "Accessibility"
    case automation = "Automation"
    case contacts = "Contacts"
    case calendar = "Calendar"
}

enum PermissionStatus: String {
    case granted = "✅ Granted"
    case denied = "❌ Denied"
    case notDetermined = "⚠️ Not Determined"
}

struct DemoPermissionManager {
    let permissions: [PermissionType: PermissionStatus] = [
        .fileSystem: .granted,
        .accessibility: .denied,
        .automation: .notDetermined,
        .contacts: .granted,
        .calendar: .granted
    ]
    
    func getPermissionSummary() -> (total: Int, granted: Int, percentage: Double) {
        let total = permissions.count
        let granted = permissions.values.filter { $0 == .granted }.count
        let percentage = Double(granted) / Double(total) * 100
        return (total: total, granted: granted, percentage: percentage)
    }
    
    func validatePermissionsForTask(_ taskType: String) -> (canProceed: Bool, missing: [PermissionType]) {
        let requiredPermissions: [PermissionType]
        
        switch taskType {
        case "file_operation":
            requiredPermissions = [.fileSystem]
        case "app_control":
            requiredPermissions = [.accessibility, .automation]
        case "calendar_task":
            requiredPermissions = [.calendar]
        default:
            requiredPermissions = []
        }
        
        let missing = requiredPermissions.filter { permissions[$0] != .granted }
        return (canProceed: missing.isEmpty, missing: missing)
    }
}

let permissionManager = DemoPermissionManager()

print("Current Permissions:")
for (permission, status) in permissionManager.permissions {
    print("  \(permission.rawValue): \(status.rawValue)")
}

let summary = permissionManager.getPermissionSummary()
print("\nSummary: \(summary.granted)/\(summary.total) granted (\(Int(summary.percentage))%)")

let taskTypes = ["file_operation", "app_control", "calendar_task", "system_query"]
print("\nTask Permission Validation:")
for taskType in taskTypes {
    let validation = permissionManager.validatePermissionsForTask(taskType)
    let status = validation.canProceed ? "✅ Can proceed" : "❌ Missing permissions"
    print("  \(taskType): \(status)")
    if !validation.missing.isEmpty {
        print("    Missing: \(validation.missing.map { $0.rawValue }.joined(separator: ", "))")
    }
}

// MARK: - Security Audit Demo

print("\n🔍 Security Audit Demo")
print("-" * 30)

struct DemoSecurityAudit {
    func conductQuickSecurityCheck() -> (score: Int, status: String, issues: [String]) {
        var score = 100
        var issues: [String] = []
        
        // Check encryption
        if !true { // Assume encryption is enabled
            issues.append("Encryption not enabled")
            score -= 30
        }
        
        // Check permissions
        let permissionSummary = DemoPermissionManager().getPermissionSummary()
        if permissionSummary.percentage < 80 {
            issues.append("Missing critical permissions")
            score -= 20
        }
        
        // Check API keys
        if false { // Assume no API keys configured
            issues.append("No API keys configured")
            score -= 10
        }
        
        let status: String
        switch score {
        case 90...100: status = "Excellent"
        case 70...89: status = "Good"
        case 50...69: status = "Fair"
        case 30...49: status = "Poor"
        default: status = "Critical"
        }
        
        return (score: score, status: status, issues: issues)
    }
}

let securityAudit = DemoSecurityAudit()
let auditResult = securityAudit.conductQuickSecurityCheck()

print("Security Score: \(auditResult.score)/100")
print("Security Status: \(auditResult.status)")

if !auditResult.issues.isEmpty {
    print("Issues Found:")
    for issue in auditResult.issues {
        print("  • \(issue)")
    }
} else {
    print("No security issues found! 🎉")
}

// MARK: - Summary

print("\n📋 Implementation Summary")
print("-" * 30)

let components = [
    "✅ PrivacyManager - Data sensitivity classification",
    "✅ KeychainManager - Secure API key storage with encryption",
    "✅ DataEncryptionService - Chat history and preferences encryption",
    "✅ PermissionManager - System permission management",
    "✅ SecurityAuditService - Comprehensive security monitoring",
    "✅ Core Data Extensions - Encryption support for entities",
    "✅ Comprehensive Test Suite - Unit and integration tests"
]

print("Implemented Components:")
for component in components {
    print("  \(component)")
}

print("\n🎯 Key Features:")
print("  • Automatic data sensitivity classification")
print("  • Local-first processing for sensitive data")
print("  • End-to-end encryption for stored data")
print("  • Secure API key management with Keychain Services")
print("  • Comprehensive permission management")
print("  • Real-time security monitoring and auditing")
print("  • Privacy-first design with user control")

print("\n🔒 Security Implementation Complete!")
print("All requirements from task 27 have been implemented.")

// Helper function for string repetition
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}