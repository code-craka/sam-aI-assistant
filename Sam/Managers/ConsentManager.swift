//
//  ConsentManager.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import SwiftUI
import Combine

/// Manages user consent and permission flows for privacy-sensitive operations
@MainActor
class ConsentManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var cloudProcessingConsent: Bool = false
    @Published var fileAccessConsent: Bool = false
    @Published var systemAccessConsent: Bool = false
    @Published var dataCollectionConsent: Bool = false
    @Published var showingConsentDialog: Bool = false
    @Published var pendingConsentRequest: ConsentRequest?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let auditLogger = AuditLogger.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Consent Types
    
    enum ConsentType: String, CaseIterable {
        case cloudProcessing = "cloud_processing"
        case fileAccess = "file_access"
        case systemAccess = "system_access"
        case dataCollection = "data_collection"
        case automation = "automation"
        case networkAccess = "network_access"
        
        var title: String {
            switch self {
            case .cloudProcessing:
                return "Cloud Processing"
            case .fileAccess:
                return "File System Access"
            case .systemAccess:
                return "System Information Access"
            case .dataCollection:
                return "Data Collection"
            case .automation:
                return "App Automation"
            case .networkAccess:
                return "Network Access"
            }
        }
        
        var description: String {
            switch self {
            case .cloudProcessing:
                return "Allow Sam to send anonymized queries to cloud AI services for complex processing. Your data is never stored on external servers."
            case .fileAccess:
                return "Allow Sam to read, write, and organize files on your Mac. Sam will always ask for confirmation before making changes."
            case .systemAccess:
                return "Allow Sam to read system information like battery level, memory usage, and running applications."
            case .dataCollection:
                return "Allow Sam to collect anonymous usage statistics to improve the app. No personal data is included."
            case .automation:
                return "Allow Sam to control other applications on your Mac to perform tasks like sending emails or creating calendar events."
            case .networkAccess:
                return "Allow Sam to access the internet for AI processing and app updates. All connections use secure encryption."
            }
        }
        
        var risks: [String] {
            switch self {
            case .cloudProcessing:
                return [
                    "Query content may be processed by third-party AI services",
                    "Network requests are logged by service providers",
                    "Processing may be slower during network issues"
                ]
            case .fileAccess:
                return [
                    "Sam can read file contents and metadata",
                    "Accidental file modifications are possible",
                    "File operations cannot be undone in some cases"
                ]
            case .systemAccess:
                return [
                    "Sam can see running applications and processes",
                    "System performance metrics are accessible",
                    "Some system information may be sensitive"
                ]
            case .dataCollection:
                return [
                    "Usage patterns are tracked anonymously",
                    "Feature usage statistics are collected",
                    "Error reports may include system information"
                ]
            case .automation:
                return [
                    "Sam can control other applications",
                    "Unintended actions may occur in other apps",
                    "Some apps may not work as expected"
                ]
            case .networkAccess:
                return [
                    "Network requests can be monitored",
                    "Data usage may apply on metered connections",
                    "Service availability depends on internet connection"
                ]
            }
        }
        
        var benefits: [String] {
            switch self {
            case .cloudProcessing:
                return [
                    "Access to advanced AI capabilities",
                    "Better understanding of complex queries",
                    "Improved response quality and accuracy"
                ]
            case .fileAccess:
                return [
                    "Automated file organization and management",
                    "Quick file searches and operations",
                    "Streamlined workflow automation"
                ]
            case .systemAccess:
                return [
                    "Real-time system monitoring",
                    "Quick access to system information",
                    "Automated system maintenance tasks"
                ]
            case .dataCollection:
                return [
                    "Improved app performance and stability",
                    "Better feature recommendations",
                    "Faster bug fixes and updates"
                ]
            case .automation:
                return [
                    "Seamless integration with other apps",
                    "Automated multi-app workflows",
                    "Increased productivity and efficiency"
                ]
            case .networkAccess:
                return [
                    "Access to latest AI models and features",
                    "Automatic app updates and improvements",
                    "Real-time information and services"
                ]
            }
        }
    }
    
    // MARK: - Consent Request
    
    struct ConsentRequest: Identifiable {
        let id = UUID()
        let type: ConsentType
        let context: String
        let isRequired: Bool
        let onApprove: () -> Void
        let onDeny: () -> Void
        
        init(type: ConsentType, context: String, isRequired: Bool = false, onApprove: @escaping () -> Void, onDeny: @escaping () -> Void) {
            self.type = type
            self.context = context
            self.isRequired = isRequired
            self.onApprove = onApprove
            self.onDeny = onDeny
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadConsentStates()
        setupConsentTracking()
    }
    
    // MARK: - Public Methods
    
    /// Request user consent for a specific operation
    func requestConsent(
        for type: ConsentType,
        context: String,
        isRequired: Bool = false
    ) async -> Bool {
        // Check if consent already granted
        if hasConsent(for: type) {
            await auditLogger.logConsentUsage(type: type, context: context, granted: true)
            return true
        }
        
        // Create consent request
        return await withCheckedContinuation { continuation in
            let request = ConsentRequest(
                type: type,
                context: context,
                isRequired: isRequired,
                onApprove: {
                    Task {
                        await self.grantConsent(for: type, context: context)
                        continuation.resume(returning: true)
                    }
                },
                onDeny: {
                    Task {
                        await self.auditLogger.logConsentUsage(type: type, context: context, granted: false)
                        continuation.resume(returning: false)
                    }
                }
            )
            
            DispatchQueue.main.async {
                self.pendingConsentRequest = request
                self.showingConsentDialog = true
            }
        }
    }
    
    /// Check if user has granted consent for a specific type
    func hasConsent(for type: ConsentType) -> Bool {
        switch type {
        case .cloudProcessing:
            return cloudProcessingConsent
        case .fileAccess:
            return fileAccessConsent
        case .systemAccess:
            return systemAccessConsent
        case .dataCollection:
            return dataCollectionConsent
        case .automation:
            return userDefaults.bool(forKey: "consent_\(type.rawValue)")
        case .networkAccess:
            return userDefaults.bool(forKey: "consent_\(type.rawValue)")
        }
    }
    
    /// Grant consent for a specific type
    func grantConsent(for type: ConsentType, context: String) async {
        userDefaults.set(true, forKey: "consent_\(type.rawValue)")
        userDefaults.set(Date(), forKey: "consent_\(type.rawValue)_date")
        
        // Update published properties
        switch type {
        case .cloudProcessing:
            cloudProcessingConsent = true
        case .fileAccess:
            fileAccessConsent = true
        case .systemAccess:
            systemAccessConsent = true
        case .dataCollection:
            dataCollectionConsent = true
        case .automation, .networkAccess:
            break // Handled by UserDefaults
        }
        
        await auditLogger.logConsentGranted(type: type, context: context)
    }
    
    /// Revoke consent for a specific type
    func revokeConsent(for type: ConsentType) async {
        userDefaults.set(false, forKey: "consent_\(type.rawValue)")
        userDefaults.removeObject(forKey: "consent_\(type.rawValue)_date")
        
        // Update published properties
        switch type {
        case .cloudProcessing:
            cloudProcessingConsent = false
        case .fileAccess:
            fileAccessConsent = false
        case .systemAccess:
            systemAccessConsent = false
        case .dataCollection:
            dataCollectionConsent = false
        case .automation, .networkAccess:
            break // Handled by UserDefaults
        }
        
        await auditLogger.logConsentRevoked(type: type)
    }
    
    /// Get consent date for a specific type
    func getConsentDate(for type: ConsentType) -> Date? {
        return userDefaults.object(forKey: "consent_\(type.rawValue)_date") as? Date
    }
    
    /// Reset all consents (for privacy reset)
    func resetAllConsents() async {
        for type in ConsentType.allCases {
            await revokeConsent(for: type)
        }
        await auditLogger.logPrivacyReset()
    }
    
    // MARK: - Private Methods
    
    private func loadConsentStates() {
        cloudProcessingConsent = userDefaults.bool(forKey: "consent_cloud_processing")
        fileAccessConsent = userDefaults.bool(forKey: "consent_file_access")
        systemAccessConsent = userDefaults.bool(forKey: "consent_system_access")
        dataCollectionConsent = userDefaults.bool(forKey: "consent_data_collection")
    }
    
    private func setupConsentTracking() {
        // Track consent changes for audit logging
        $cloudProcessingConsent
            .dropFirst()
            .sink { [weak self] granted in
                Task {
                    await self?.auditLogger.logConsentChange(
                        type: .cloudProcessing,
                        granted: granted
                    )
                }
            }
            .store(in: &cancellables)
        
        $fileAccessConsent
            .dropFirst()
            .sink { [weak self] granted in
                Task {
                    await self?.auditLogger.logConsentChange(
                        type: .fileAccess,
                        granted: granted
                    )
                }
            }
            .store(in: &cancellables)
        
        $systemAccessConsent
            .dropFirst()
            .sink { [weak self] granted in
                Task {
                    await self?.auditLogger.logConsentChange(
                        type: .systemAccess,
                        granted: granted
                    )
                }
            }
            .store(in: &cancellables)
        
        $dataCollectionConsent
            .dropFirst()
            .sink { [weak self] granted in
                Task {
                    await self?.auditLogger.logConsentChange(
                        type: .dataCollection,
                        granted: granted
                    )
                }
            }
            .store(in: &cancellables)
    }
}