//
//  DataTransparencyManager.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import SwiftUI
import Combine

/// Manages data usage transparency and user control over cloud processing
@MainActor
class DataTransparencyManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var cloudProcessingEnabled: Bool = false
    @Published var dataMinimizationEnabled: Bool = true
    @Published var showDataUsageNotifications: Bool = true
    @Published var currentCloudRequests: [CloudRequest] = []
    @Published var cloudUsageStats: CloudUsageStats = CloudUsageStats()
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let auditLogger = AuditLogger.shared
    private let consentManager: ConsentManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cloud Request
    
    struct CloudRequest: Identifiable {
        let id = UUID()
        let timestamp: Date
        let provider: String
        let queryType: String
        let dataSize: Int
        let purpose: String
        let status: Status
        let estimatedTokens: Int?
        
        enum Status {
            case pending
            case processing
            case completed
            case failed
            case cancelled
        }
        
        var statusColor: Color {
            switch status {
            case .pending:
                return .orange
            case .processing:
                return .blue
            case .completed:
                return .green
            case .failed:
                return .red
            case .cancelled:
                return .gray
            }
        }
        
        var statusIcon: String {
            switch status {
            case .pending:
                return "clock"
            case .processing:
                return "arrow.clockwise"
            case .completed:
                return "checkmark.circle"
            case .failed:
                return "xmark.circle"
            case .cancelled:
                return "minus.circle"
            }
        }
    }
    
    // MARK: - Cloud Usage Stats
    
    struct CloudUsageStats: Codable {
        var totalRequests: Int = 0
        var totalTokensUsed: Int = 0
        var totalDataSent: Int = 0 // in bytes
        var requestsByProvider: [String: Int] = [:]
        var requestsByType: [String: Int] = [:]
        var lastResetDate: Date = Date()
        
        var averageTokensPerRequest: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(totalTokensUsed) / Double(totalRequests)
        }
        
        var averageDataPerRequest: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(totalDataSent) / Double(totalRequests)
        }
    }
    
    // MARK: - Data Processing Options
    
    enum DataProcessingOption: String, CaseIterable {
        case localOnly = "local_only"
        case cloudWithConsent = "cloud_with_consent"
        case cloudAutomatic = "cloud_automatic"
        
        var displayName: String {
            switch self {
            case .localOnly:
                return "Local Processing Only"
            case .cloudWithConsent:
                return "Cloud with Consent"
            case .cloudAutomatic:
                return "Automatic Cloud Processing"
            }
        }
        
        var description: String {
            switch self {
            case .localOnly:
                return "Process all requests locally. Some complex queries may not be supported."
            case .cloudWithConsent:
                return "Ask for permission before sending data to cloud services."
            case .cloudAutomatic:
                return "Automatically use cloud services for complex queries."
            }
        }
    }
    
    // MARK: - Initialization
    
    init(consentManager: ConsentManager) {
        self.consentManager = consentManager
        loadSettings()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Request permission for cloud processing with transparency
    func requestCloudProcessing(
        provider: String,
        queryType: String,
        dataSize: Int,
        purpose: String,
        estimatedTokens: Int? = nil
    ) async -> Bool {
        // Check if cloud processing is enabled
        guard cloudProcessingEnabled else {
            return false
        }
        
        // Create cloud request
        let request = CloudRequest(
            timestamp: Date(),
            provider: provider,
            queryType: queryType,
            dataSize: dataSize,
            purpose: purpose,
            status: .pending,
            estimatedTokens: estimatedTokens
        )
        
        currentCloudRequests.append(request)
        
        // Show notification if enabled
        if showDataUsageNotifications {
            await showCloudProcessingNotification(request: request)
        }
        
        // Request consent if needed
        let hasConsent = await consentManager.requestConsent(
            for: .cloudProcessing,
            context: "Processing \(queryType) query via \(provider)"
        )
        
        if hasConsent {
            await updateRequestStatus(request.id, status: .processing)
            await logCloudRequest(request)
            return true
        } else {
            await updateRequestStatus(request.id, status: .cancelled)
            return false
        }
    }
    
    /// Complete a cloud processing request
    func completeCloudRequest(
        requestId: UUID,
        success: Bool,
        actualTokens: Int? = nil
    ) async {
        guard let index = currentCloudRequests.firstIndex(where: { $0.id == requestId }) else {
            return
        }
        
        let request = currentCloudRequests[index]
        let newStatus: CloudRequest.Status = success ? .completed : .failed
        
        await updateRequestStatus(requestId, status: newStatus)
        
        if success {
            await updateUsageStats(request: request, actualTokens: actualTokens)
        }
        
        // Remove completed/failed requests after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.currentCloudRequests.removeAll { $0.id == requestId }
        }
    }
    
    /// Get data usage summary for a time period
    func getDataUsageSummary(for period: TimeInterval) async -> DataUsageSummary {
        let events = await auditLogger.getAuditEvents(
            from: Date().addingTimeInterval(-period),
            to: Date()
        )
        
        let cloudEvents = events.filter { $0.type == .cloudProcessing }
        
        var summary = DataUsageSummary()
        summary.totalRequests = cloudEvents.count
        
        for event in cloudEvents {
            if let provider = event.metadata["provider"] {
                summary.requestsByProvider[provider, default: 0] += 1
            }
            
            if let tokenCount = event.metadata["token_count"],
               let tokens = Int(tokenCount) {
                summary.totalTokens += tokens
            }
        }
        
        return summary
    }
    
    /// Reset usage statistics
    func resetUsageStats() async {
        cloudUsageStats = CloudUsageStats()
        saveSettings()
        
        await auditLogger.logSettingsChange(
            setting: "cloud_usage_stats",
            oldValue: "existing_stats",
            newValue: "reset"
        )
    }
    
    /// Export data usage report
    func exportDataUsageReport() async -> URL? {
        let summary = await getDataUsageSummary(for: 30 * 24 * 3600) // 30 days
        
        let report = DataUsageReport(
            generatedDate: Date(),
            period: "Last 30 days",
            summary: summary,
            currentStats: cloudUsageStats,
            settings: DataUsageSettings(
                cloudProcessingEnabled: cloudProcessingEnabled,
                dataMinimizationEnabled: dataMinimizationEnabled,
                showNotifications: showDataUsageNotifications
            )
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(report)
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("data_usage_report_\(Date().timeIntervalSince1970).json")
            
            try data.write(to: tempURL)
            
            await auditLogger.logDataExport(
                dataType: "data_usage_report",
                exportPath: tempURL.path,
                recordCount: 1
            )
            
            return tempURL
        } catch {
            await auditLogger.logError(error: error, context: "Data usage report export")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        cloudProcessingEnabled = userDefaults.bool(forKey: "cloud_processing_enabled")
        dataMinimizationEnabled = userDefaults.bool(forKey: "data_minimization_enabled")
        showDataUsageNotifications = userDefaults.bool(forKey: "show_data_usage_notifications")
        
        if let statsData = userDefaults.data(forKey: "cloud_usage_stats"),
           let stats = try? JSONDecoder().decode(CloudUsageStats.self, from: statsData) {
            cloudUsageStats = stats
        }
    }
    
    private func saveSettings() {
        userDefaults.set(cloudProcessingEnabled, forKey: "cloud_processing_enabled")
        userDefaults.set(dataMinimizationEnabled, forKey: "data_minimization_enabled")
        userDefaults.set(showDataUsageNotifications, forKey: "show_data_usage_notifications")
        
        if let statsData = try? JSONEncoder().encode(cloudUsageStats) {
            userDefaults.set(statsData, forKey: "cloud_usage_stats")
        }
    }
    
    private func setupBindings() {
        // Save settings when they change
        Publishers.CombineLatest3(
            $cloudProcessingEnabled,
            $dataMinimizationEnabled,
            $showDataUsageNotifications
        )
        .dropFirst()
        .sink { [weak self] _, _, _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)
        
        // Sync with consent manager
        consentManager.$cloudProcessingConsent
            .sink { [weak self] granted in
                self?.cloudProcessingEnabled = granted
            }
            .store(in: &cancellables)
    }
    
    private func updateRequestStatus(_ requestId: UUID, status: CloudRequest.Status) async {
        if let index = currentCloudRequests.firstIndex(where: { $0.id == requestId }) {
            var request = currentCloudRequests[index]
            request = CloudRequest(
                timestamp: request.timestamp,
                provider: request.provider,
                queryType: request.queryType,
                dataSize: request.dataSize,
                purpose: request.purpose,
                status: status,
                estimatedTokens: request.estimatedTokens
            )
            currentCloudRequests[index] = request
        }
    }
    
    private func logCloudRequest(_ request: CloudRequest) async {
        await auditLogger.logCloudProcessing(
            provider: request.provider,
            queryType: request.queryType,
            tokenCount: request.estimatedTokens
        )
    }
    
    private func updateUsageStats(request: CloudRequest, actualTokens: Int?) async {
        cloudUsageStats.totalRequests += 1
        cloudUsageStats.totalDataSent += request.dataSize
        cloudUsageStats.requestsByProvider[request.provider, default: 0] += 1
        cloudUsageStats.requestsByType[request.queryType, default: 0] += 1
        
        if let tokens = actualTokens ?? request.estimatedTokens {
            cloudUsageStats.totalTokensUsed += tokens
        }
        
        saveSettings()
    }
    
    private func showCloudProcessingNotification(request: CloudRequest) async {
        // This would show a system notification
        // Implementation depends on notification framework
        print("Cloud processing notification: \(request.purpose) via \(request.provider)")
    }
}

// MARK: - Supporting Types

struct DataUsageSummary: Codable {
    var totalRequests: Int = 0
    var totalTokens: Int = 0
    var requestsByProvider: [String: Int] = [:]
    var requestsByType: [String: Int] = [:]
}

struct DataUsageReport: Codable {
    let generatedDate: Date
    let period: String
    let summary: DataUsageSummary
    let currentStats: DataTransparencyManager.CloudUsageStats
    let settings: DataUsageSettings
}

struct DataUsageSettings: Codable {
    let cloudProcessingEnabled: Bool
    let dataMinimizationEnabled: Bool
    let showNotifications: Bool
}