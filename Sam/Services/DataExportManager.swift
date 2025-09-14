//
//  DataExportManager.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import CoreData
import SwiftUI

/// Manages data export and deletion functionality for user privacy
@MainActor
class DataExportManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportStatus: String = ""
    @Published var lastExportDate: Date?
    
    // MARK: - Private Properties
    
    private let auditLogger = AuditLogger.shared
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Data Types
    
    enum DataType: String, CaseIterable {
        case chatHistory = "chat_history"
        case userSettings = "user_settings"
        case workflows = "workflows"
        case auditLogs = "audit_logs"
        case apiKeys = "api_keys"
        case fileMetadata = "file_metadata"
        case systemInfo = "system_info"
        
        var displayName: String {
            switch self {
            case .chatHistory:
                return "Chat History"
            case .userSettings:
                return "User Settings"
            case .workflows:
                return "Workflows"
            case .auditLogs:
                return "Audit Logs"
            case .apiKeys:
                return "API Keys"
            case .fileMetadata:
                return "File Metadata"
            case .systemInfo:
                return "System Information"
            }
        }
        
        var description: String {
            switch self {
            case .chatHistory:
                return "All conversation history and messages"
            case .userSettings:
                return "App preferences and configuration"
            case .workflows:
                return "Custom workflows and automation rules"
            case .auditLogs:
                return "Privacy and security audit logs"
            case .apiKeys:
                return "Encrypted API keys and credentials"
            case .fileMetadata:
                return "File operation history and metadata"
            case .systemInfo:
                return "System access logs and information"
            }
        }
    }
    
    // MARK: - Export Format
    
    enum ExportFormat: String, CaseIterable {
        case json = "json"
        case csv = "csv"
        case txt = "txt"
        
        var displayName: String {
            switch self {
            case .json:
                return "JSON"
            case .csv:
                return "CSV"
            case .txt:
                return "Plain Text"
            }
        }
        
        var fileExtension: String {
            return rawValue
        }
    }
    
    // MARK: - Export Result
    
    struct ExportResult {
        let success: Bool
        let exportPath: URL?
        let recordCount: Int
        let fileSize: Int64
        let error: Error?
        
        static func success(path: URL, recordCount: Int, fileSize: Int64) -> ExportResult {
            return ExportResult(
                success: true,
                exportPath: path,
                recordCount: recordCount,
                fileSize: fileSize,
                error: nil
            )
        }
        
        static func failure(error: Error) -> ExportResult {
            return ExportResult(
                success: false,
                exportPath: nil,
                recordCount: 0,
                fileSize: 0,
                error: error
            )
        }
    }
    
    // MARK: - Deletion Result
    
    struct DeletionResult {
        let success: Bool
        let recordsDeleted: Int
        let error: Error?
        
        static func success(recordsDeleted: Int) -> DeletionResult {
            return DeletionResult(success: true, recordsDeleted: recordsDeleted, error: nil)
        }
        
        static func failure(error: Error) -> DeletionResult {
            return DeletionResult(success: false, recordsDeleted: 0, error: error)
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadLastExportDate()
    }
    
    // MARK: - Export Methods
    
    /// Export all user data to a specified directory
    func exportAllData(to directory: URL, format: ExportFormat = .json) async -> ExportResult {
        isExporting = true
        exportProgress = 0.0
        exportStatus = "Starting export..."
        
        do {
            // Create export directory with timestamp
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let exportDir = directory.appendingPathComponent("Sam_Export_\(timestamp)")
            try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
            
            var totalRecords = 0
            var totalSize: Int64 = 0
            let dataTypes = DataType.allCases
            
            for (index, dataType) in dataTypes.enumerated() {
                exportStatus = "Exporting \(dataType.displayName)..."
                exportProgress = Double(index) / Double(dataTypes.count)
                
                let result = await exportData(type: dataType, to: exportDir, format: format)
                if result.success {
                    totalRecords += result.recordCount
                    totalSize += result.fileSize
                } else if let error = result.error {
                    await auditLogger.logError(error: error, context: "Data export for \(dataType.rawValue)")
                }
                
                // Small delay to show progress
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Create export manifest
            let manifest = createExportManifest(
                exportDate: Date(),
                format: format,
                totalRecords: totalRecords,
                dataTypes: dataTypes
            )
            
            let manifestURL = exportDir.appendingPathComponent("export_manifest.json")
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(to: manifestURL)
            
            exportStatus = "Export completed successfully"
            exportProgress = 1.0
            
            // Update last export date
            lastExportDate = Date()
            userDefaults.set(lastExportDate, forKey: "last_export_date")
            
            // Log export completion
            await auditLogger.logDataExport(
                dataType: "all_data",
                exportPath: exportDir.path,
                recordCount: totalRecords
            )
            
            isExporting = false
            return ExportResult.success(path: exportDir, recordCount: totalRecords, fileSize: totalSize)
            
        } catch {
            exportStatus = "Export failed: \(error.localizedDescription)"
            isExporting = false
            await auditLogger.logError(error: error, context: "Complete data export")
            return ExportResult.failure(error: error)
        }
    }
    
    /// Export specific data type
    func exportData(type: DataType, to directory: URL, format: ExportFormat) async -> ExportResult {
        do {
            let fileName = "\(type.rawValue).\(format.fileExtension)"
            let fileURL = directory.appendingPathComponent(fileName)
            
            switch type {
            case .chatHistory:
                return await exportChatHistory(to: fileURL, format: format)
            case .userSettings:
                return await exportUserSettings(to: fileURL, format: format)
            case .workflows:
                return await exportWorkflows(to: fileURL, format: format)
            case .auditLogs:
                return await exportAuditLogs(to: fileURL, format: format)
            case .apiKeys:
                return await exportAPIKeys(to: fileURL, format: format)
            case .fileMetadata:
                return await exportFileMetadata(to: fileURL, format: format)
            case .systemInfo:
                return await exportSystemInfo(to: fileURL, format: format)
            }
        } catch {
            return ExportResult.failure(error: error)
        }
    }
    
    // MARK: - Deletion Methods
    
    /// Delete all user data (complete privacy reset)
    func deleteAllData() async -> DeletionResult {
        var totalDeleted = 0
        
        do {
            // Delete each data type
            for dataType in DataType.allCases {
                let result = await deleteData(type: dataType)
                if result.success {
                    totalDeleted += result.recordsDeleted
                }
            }
            
            // Clear UserDefaults
            let domain = Bundle.main.bundleIdentifier!
            userDefaults.removePersistentDomain(forName: domain)
            
            // Clear Keychain
            try await clearKeychain()
            
            // Log privacy reset
            await auditLogger.logPrivacyReset()
            
            return DeletionResult.success(recordsDeleted: totalDeleted)
            
        } catch {
            await auditLogger.logError(error: error, context: "Complete data deletion")
            return DeletionResult.failure(error: error)
        }
    }
    
    /// Delete specific data type
    func deleteData(type: DataType) async -> DeletionResult {
        do {
            var recordsDeleted = 0
            
            switch type {
            case .chatHistory:
                recordsDeleted = await deleteChatHistory()
            case .userSettings:
                recordsDeleted = await deleteUserSettings()
            case .workflows:
                recordsDeleted = await deleteWorkflows()
            case .auditLogs:
                recordsDeleted = await deleteAuditLogs()
            case .apiKeys:
                recordsDeleted = await deleteAPIKeys()
            case .fileMetadata:
                recordsDeleted = await deleteFileMetadata()
            case .systemInfo:
                recordsDeleted = await deleteSystemInfo()
            }
            
            await auditLogger.logDataDeletion(
                dataType: type.rawValue,
                recordCount: recordsDeleted,
                permanent: true
            )
            
            return DeletionResult.success(recordsDeleted: recordsDeleted)
            
        } catch {
            await auditLogger.logError(error: error, context: "Data deletion for \(type.rawValue)")
            return DeletionResult.failure(error: error)
        }
    }
    
    // MARK: - Private Export Methods
    
    private func exportChatHistory(to url: URL, format: ExportFormat) async -> ExportResult {
        // Implementation would depend on Core Data model
        // For now, return a placeholder
        let placeholder = ["message": "Chat history export not yet implemented"]
        return await writeDataToFile(data: placeholder, url: url, format: format)
    }
    
    private func exportUserSettings(to url: URL, format: ExportFormat) async -> ExportResult {
        let settings = userDefaults.dictionaryRepresentation()
        let filteredSettings = settings.filter { key, _ in
            !key.contains("api_key") && !key.contains("password")
        }
        return await writeDataToFile(data: filteredSettings, url: url, format: format)
    }
    
    private func exportWorkflows(to url: URL, format: ExportFormat) async -> ExportResult {
        // Implementation would depend on workflow storage
        let placeholder = ["message": "Workflows export not yet implemented"]
        return await writeDataToFile(data: placeholder, url: url, format: format)
    }
    
    private func exportAuditLogs(to url: URL, format: ExportFormat) async -> ExportResult {
        let events = await auditLogger.getAllAuditEvents()
        let eventDicts = events.map { event in
            [
                "id": event.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                "type": event.type.rawValue,
                "description": event.description,
                "severity": event.severity.rawValue,
                "userInitiated": String(event.userInitiated),
                "metadata": event.metadata
            ]
        }
        return await writeDataToFile(data: eventDicts, url: url, format: format)
    }
    
    private func exportAPIKeys(to url: URL, format: ExportFormat) async -> ExportResult {
        // Export API key metadata only (not actual keys)
        let keychain = KeychainManager()
        let services = ["openai", "anthropic", "google"]
        
        var keyInfo: [[String: Any]] = []
        for service in services {
            if keychain.hasKey(for: service) {
                keyInfo.append([
                    "service": service,
                    "hasKey": true,
                    "note": "Actual key not exported for security"
                ])
            }
        }
        
        return await writeDataToFile(data: keyInfo, url: url, format: format)
    }
    
    private func exportFileMetadata(to url: URL, format: ExportFormat) async -> ExportResult {
        // Implementation would depend on file metadata storage
        let placeholder = ["message": "File metadata export not yet implemented"]
        return await writeDataToFile(data: placeholder, url: url, format: format)
    }
    
    private func exportSystemInfo(to url: URL, format: ExportFormat) async -> ExportResult {
        let systemInfo = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "deviceModel": ProcessInfo.processInfo.hostName
        ]
        return await writeDataToFile(data: systemInfo, url: url, format: format)
    }
    
    // MARK: - Private Deletion Methods
    
    private func deleteChatHistory() async -> Int {
        // Implementation would depend on Core Data model
        return 0
    }
    
    private func deleteUserSettings() async -> Int {
        let settingsCount = userDefaults.dictionaryRepresentation().count
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        return settingsCount
    }
    
    private func deleteWorkflows() async -> Int {
        // Implementation would depend on workflow storage
        return 0
    }
    
    private func deleteAuditLogs() async -> Int {
        do {
            let events = await auditLogger.getAllAuditEvents()
            try await auditLogger.clearAuditLog()
            return events.count
        } catch {
            return 0
        }
    }
    
    private func deleteAPIKeys() async -> Int {
        let keychain = KeychainManager()
        let services = ["openai", "anthropic", "google"]
        var deletedCount = 0
        
        for service in services {
            if keychain.deleteKey(for: service) {
                deletedCount += 1
            }
        }
        
        return deletedCount
    }
    
    private func deleteFileMetadata() async -> Int {
        // Implementation would depend on file metadata storage
        return 0
    }
    
    private func deleteSystemInfo() async -> Int {
        // Clear system-related UserDefaults keys
        let systemKeys = ["last_system_check", "system_permissions", "system_cache"]
        var deletedCount = 0
        
        for key in systemKeys {
            if userDefaults.object(forKey: key) != nil {
                userDefaults.removeObject(forKey: key)
                deletedCount += 1
            }
        }
        
        return deletedCount
    }
    
    // MARK: - Helper Methods
    
    private func writeDataToFile(data: Any, url: URL, format: ExportFormat) async -> ExportResult {
        do {
            var content: String
            var recordCount = 0
            
            switch format {
            case .json:
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                content = String(data: jsonData, encoding: .utf8) ?? ""
                recordCount = (data as? [Any])?.count ?? 1
                
            case .csv:
                content = convertToCSV(data: data)
                recordCount = content.components(separatedBy: .newlines).count - 1 // Subtract header
                
            case .txt:
                content = convertToText(data: data)
                recordCount = content.components(separatedBy: .newlines).count
            }
            
            try content.write(to: url, atomically: true, encoding: .utf8)
            
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            return ExportResult.success(path: url, recordCount: recordCount, fileSize: fileSize)
            
        } catch {
            return ExportResult.failure(error: error)
        }
    }
    
    private func convertToCSV(data: Any) -> String {
        // Simple CSV conversion - would need more sophisticated implementation
        if let array = data as? [[String: Any]], !array.isEmpty {
            let headers = Array(array[0].keys).sorted()
            var csv = headers.joined(separator: ",") + "\n"
            
            for item in array {
                let values = headers.map { key in
                    let value = item[key] ?? ""
                    return "\"\(value)\""
                }
                csv += values.joined(separator: ",") + "\n"
            }
            
            return csv
        }
        
        return "No data available\n"
    }
    
    private func convertToText(data: Any) -> String {
        // Simple text conversion
        if let dict = data as? [String: Any] {
            return dict.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        } else if let array = data as? [Any] {
            return array.map { "\($0)" }.joined(separator: "\n")
        }
        
        return "\(data)"
    }
    
    private func createExportManifest(
        exportDate: Date,
        format: ExportFormat,
        totalRecords: Int,
        dataTypes: [DataType]
    ) -> [String: Any] {
        return [
            "exportDate": ISO8601DateFormatter().string(from: exportDate),
            "format": format.rawValue,
            "totalRecords": totalRecords,
            "dataTypes": dataTypes.map { $0.rawValue },
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "exportVersion": "1.0"
        ]
    }
    
    private func clearKeychain() async throws {
        let keychain = KeychainManager()
        let services = ["openai", "anthropic", "google", "user_encryption_key"]
        
        for service in services {
            _ = keychain.deleteKey(for: service)
        }
    }
    
    private func loadLastExportDate() {
        lastExportDate = userDefaults.object(forKey: "last_export_date") as? Date
    }
}

// MARK: - Export Errors

enum DataExportError: LocalizedError {
    case invalidDirectory
    case exportFailed(String)
    case deletionFailed(String)
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .invalidDirectory:
            return "Invalid export directory"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .deletionFailed(let reason):
            return "Deletion failed: \(reason)"
        case .insufficientPermissions:
            return "Insufficient permissions for operation"
        }
    }
}