//
//  AuditLogger.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import OSLog

/// Provides comprehensive audit logging for privacy-sensitive operations
actor AuditLogger {
    
    static let shared = AuditLogger()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.sam.assistant", category: "audit")
    private let fileManager = FileManager.default
    private let auditLogURL: URL
    private let maxLogFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles: Int = 5
    
    // MARK: - Audit Event Types
    
    enum AuditEventType: String, CaseIterable {
        case consentGranted = "consent_granted"
        case consentRevoked = "consent_revoked"
        case consentUsage = "consent_usage"
        case consentChange = "consent_change"
        case dataAccess = "data_access"
        case dataExport = "data_export"
        case dataDelete = "data_delete"
        case fileOperation = "file_operation"
        case systemAccess = "system_access"
        case cloudProcessing = "cloud_processing"
        case privacyReset = "privacy_reset"
        case settingsChange = "settings_change"
        case apiKeyAccess = "api_key_access"
        case networkRequest = "network_request"
        case errorOccurred = "error_occurred"
    }
    
    // MARK: - Audit Event
    
    struct AuditEvent: Codable {
        let id: UUID
        let timestamp: Date
        let type: AuditEventType
        let description: String
        let metadata: [String: String]
        let severity: Severity
        let userInitiated: Bool
        
        enum Severity: String, Codable {
            case low = "low"
            case medium = "medium"
            case high = "high"
            case critical = "critical"
        }
        
        init(
            type: AuditEventType,
            description: String,
            metadata: [String: String] = [:],
            severity: Severity = .medium,
            userInitiated: Bool = true
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.type = type
            self.description = description
            self.metadata = metadata
            self.severity = severity
            self.userInitiated = userInitiated
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Create audit log directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let samDirectory = appSupport.appendingPathComponent("Sam")
        let auditDirectory = samDirectory.appendingPathComponent("AuditLogs")
        
        try? fileManager.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        
        self.auditLogURL = auditDirectory.appendingPathComponent("audit.log")
        
        // Log audit system initialization
        Task {
            await logEvent(
                type: .settingsChange,
                description: "Audit logging system initialized",
                severity: .low,
                userInitiated: false
            )
        }
    }
    
    // MARK: - Public Logging Methods
    
    /// Log consent granted event
    func logConsentGranted(type: ConsentManager.ConsentType, context: String) async {
        await logEvent(
            type: .consentGranted,
            description: "User granted consent for \(type.title)",
            metadata: [
                "consent_type": type.rawValue,
                "context": context,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            severity: .medium
        )
    }
    
    /// Log consent revoked event
    func logConsentRevoked(type: ConsentManager.ConsentType) async {
        await logEvent(
            type: .consentRevoked,
            description: "User revoked consent for \(type.title)",
            metadata: [
                "consent_type": type.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            severity: .medium
        )
    }
    
    /// Log consent usage event
    func logConsentUsage(type: ConsentManager.ConsentType, context: String, granted: Bool) async {
        await logEvent(
            type: .consentUsage,
            description: "Consent \(granted ? "used" : "denied") for \(type.title)",
            metadata: [
                "consent_type": type.rawValue,
                "context": context,
                "granted": String(granted)
            ],
            severity: .low
        )
    }
    
    /// Log consent change event
    func logConsentChange(type: ConsentManager.ConsentType, granted: Bool) async {
        await logEvent(
            type: .consentChange,
            description: "Consent \(granted ? "enabled" : "disabled") for \(type.title)",
            metadata: [
                "consent_type": type.rawValue,
                "new_state": String(granted)
            ],
            severity: .medium
        )
    }
    
    /// Log data access event
    func logDataAccess(dataType: String, operation: String, filePath: String? = nil) async {
        var metadata: [String: String] = [
            "data_type": dataType,
            "operation": operation
        ]
        
        if let filePath = filePath {
            metadata["file_path"] = filePath
        }
        
        await logEvent(
            type: .dataAccess,
            description: "Data access: \(operation) on \(dataType)",
            metadata: metadata,
            severity: .medium
        )
    }
    
    /// Log data export event
    func logDataExport(dataType: String, exportPath: String, recordCount: Int) async {
        await logEvent(
            type: .dataExport,
            description: "Data exported: \(dataType) (\(recordCount) records)",
            metadata: [
                "data_type": dataType,
                "export_path": exportPath,
                "record_count": String(recordCount)
            ],
            severity: .high
        )
    }
    
    /// Log data deletion event
    func logDataDeletion(dataType: String, recordCount: Int, permanent: Bool) async {
        await logEvent(
            type: .dataDelete,
            description: "Data deleted: \(dataType) (\(recordCount) records, permanent: \(permanent))",
            metadata: [
                "data_type": dataType,
                "record_count": String(recordCount),
                "permanent": String(permanent)
            ],
            severity: .high
        )
    }
    
    /// Log file operation event
    func logFileOperation(operation: String, filePath: String, success: Bool) async {
        await logEvent(
            type: .fileOperation,
            description: "File operation: \(operation) on \(filePath) - \(success ? "Success" : "Failed")",
            metadata: [
                "operation": operation,
                "file_path": filePath,
                "success": String(success)
            ],
            severity: success ? .low : .medium
        )
    }
    
    /// Log system access event
    func logSystemAccess(accessType: String, data: String) async {
        await logEvent(
            type: .systemAccess,
            description: "System access: \(accessType)",
            metadata: [
                "access_type": accessType,
                "data_accessed": data
            ],
            severity: .low
        )
    }
    
    /// Log cloud processing event
    func logCloudProcessing(provider: String, queryType: String, tokenCount: Int? = nil) async {
        var metadata: [String: String] = [
            "provider": provider,
            "query_type": queryType
        ]
        
        if let tokenCount = tokenCount {
            metadata["token_count"] = String(tokenCount)
        }
        
        await logEvent(
            type: .cloudProcessing,
            description: "Cloud processing request to \(provider)",
            metadata: metadata,
            severity: .medium
        )
    }
    
    /// Log privacy reset event
    func logPrivacyReset() async {
        await logEvent(
            type: .privacyReset,
            description: "Complete privacy reset performed",
            severity: .critical
        )
    }
    
    /// Log settings change event
    func logSettingsChange(setting: String, oldValue: String?, newValue: String) async {
        var metadata: [String: String] = [
            "setting": setting,
            "new_value": newValue
        ]
        
        if let oldValue = oldValue {
            metadata["old_value"] = oldValue
        }
        
        await logEvent(
            type: .settingsChange,
            description: "Settings changed: \(setting)",
            metadata: metadata,
            severity: .low
        )
    }
    
    /// Log API key access event
    func logAPIKeyAccess(service: String, operation: String) async {
        await logEvent(
            type: .apiKeyAccess,
            description: "API key \(operation) for \(service)",
            metadata: [
                "service": service,
                "operation": operation
            ],
            severity: .high
        )
    }
    
    /// Log network request event
    func logNetworkRequest(url: String, method: String, success: Bool) async {
        await logEvent(
            type: .networkRequest,
            description: "Network request: \(method) \(url) - \(success ? "Success" : "Failed")",
            metadata: [
                "url": url,
                "method": method,
                "success": String(success)
            ],
            severity: .low
        )
    }
    
    /// Log error event
    func logError(error: Error, context: String) async {
        await logEvent(
            type: .errorOccurred,
            description: "Error occurred: \(error.localizedDescription)",
            metadata: [
                "error_type": String(describing: type(of: error)),
                "context": context,
                "error_description": error.localizedDescription
            ],
            severity: .medium,
            userInitiated: false
        )
    }
    
    // MARK: - Audit Log Management
    
    /// Get audit events for a specific date range
    func getAuditEvents(from startDate: Date, to endDate: Date) async -> [AuditEvent] {
        let allEvents = await getAllAuditEvents()
        return allEvents.filter { event in
            event.timestamp >= startDate && event.timestamp <= endDate
        }
    }
    
    /// Get audit events by type
    func getAuditEvents(ofType type: AuditEventType) async -> [AuditEvent] {
        let allEvents = await getAllAuditEvents()
        return allEvents.filter { $0.type == type }
    }
    
    /// Get all audit events
    func getAllAuditEvents() async -> [AuditEvent] {
        guard fileManager.fileExists(atPath: auditLogURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: auditLogURL)
            let logContent = String(data: data, encoding: .utf8) ?? ""
            let lines = logContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            var events: [AuditEvent] = []
            for line in lines {
                if let data = line.data(using: .utf8),
                   let event = try? JSONDecoder().decode(AuditEvent.self, from: data) {
                    events.append(event)
                }
            }
            
            return events.sorted { $0.timestamp > $1.timestamp }
        } catch {
            logger.error("Failed to read audit log: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Export audit log to specified URL
    func exportAuditLog(to url: URL) async throws {
        guard fileManager.fileExists(atPath: auditLogURL.path) else {
            throw AuditError.noLogFile
        }
        
        try fileManager.copyItem(at: auditLogURL, to: url)
        
        await logEvent(
            type: .dataExport,
            description: "Audit log exported",
            metadata: [
                "export_path": url.path,
                "file_size": String(try? auditLogURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            ],
            severity: .high
        )
    }
    
    /// Clear audit log (with confirmation)
    func clearAuditLog() async throws {
        // Log the clearing action first
        await logEvent(
            type: .dataDelete,
            description: "Audit log cleared by user request",
            severity: .critical
        )
        
        // Clear the log file
        try "".write(to: auditLogURL, atomically: true, encoding: .utf8)
    }
    
    /// Get audit log statistics
    func getAuditStatistics() async -> AuditStatistics {
        let events = await getAllAuditEvents()
        
        var eventCounts: [AuditEventType: Int] = [:]
        var severityCounts: [AuditEvent.Severity: Int] = [:]
        
        for event in events {
            eventCounts[event.type, default: 0] += 1
            severityCounts[event.severity, default: 0] += 1
        }
        
        let fileSize = try? auditLogURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        
        return AuditStatistics(
            totalEvents: events.count,
            eventCounts: eventCounts,
            severityCounts: severityCounts,
            oldestEvent: events.last?.timestamp,
            newestEvent: events.first?.timestamp,
            logFileSize: fileSize ?? 0
        )
    }
    
    // MARK: - Private Methods
    
    private func logEvent(
        type: AuditEventType,
        description: String,
        metadata: [String: String] = [:],
        severity: AuditEvent.Severity = .medium,
        userInitiated: Bool = true
    ) async {
        let event = AuditEvent(
            type: type,
            description: description,
            metadata: metadata,
            severity: severity,
            userInitiated: userInitiated
        )
        
        // Log to system logger
        logger.info("[\(type.rawValue)] \(description)")
        
        // Write to audit log file
        await writeEventToFile(event)
        
        // Rotate log files if necessary
        await rotateLogFilesIfNeeded()
    }
    
    private func writeEventToFile(_ event: AuditEvent) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let eventData = try encoder.encode(event)
            let eventLine = String(data: eventData, encoding: .utf8)! + "\n"
            
            if fileManager.fileExists(atPath: auditLogURL.path) {
                let fileHandle = try FileHandle(forWritingTo: auditLogURL)
                defer { try? fileHandle.close() }
                
                fileHandle.seekToEndOfFile()
                fileHandle.write(eventLine.data(using: .utf8)!)
            } else {
                try eventLine.write(to: auditLogURL, atomically: true, encoding: .utf8)
            }
        } catch {
            logger.error("Failed to write audit event: \(error.localizedDescription)")
        }
    }
    
    private func rotateLogFilesIfNeeded() async {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: auditLogURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            
            if fileSize > maxLogFileSize {
                await rotateLogFiles()
            }
        } catch {
            logger.error("Failed to check log file size: \(error.localizedDescription)")
        }
    }
    
    private func rotateLogFiles() async {
        let directory = auditLogURL.deletingLastPathComponent()
        let baseName = auditLogURL.deletingPathExtension().lastPathComponent
        let extension = auditLogURL.pathExtension
        
        // Move existing numbered files
        for i in (1..<maxLogFiles).reversed() {
            let currentFile = directory.appendingPathComponent("\(baseName).\(i).\(extension)")
            let nextFile = directory.appendingPathComponent("\(baseName).\(i + 1).\(extension)")
            
            if fileManager.fileExists(atPath: currentFile.path) {
                try? fileManager.removeItem(at: nextFile)
                try? fileManager.moveItem(at: currentFile, to: nextFile)
            }
        }
        
        // Move current log to .1
        let firstRotated = directory.appendingPathComponent("\(baseName).1.\(extension)")
        try? fileManager.moveItem(at: auditLogURL, to: firstRotated)
        
        // Log rotation event
        await logEvent(
            type: .settingsChange,
            description: "Audit log rotated",
            severity: .low,
            userInitiated: false
        )
    }
}

// MARK: - Supporting Types

struct AuditStatistics {
    let totalEvents: Int
    let eventCounts: [AuditLogger.AuditEventType: Int]
    let severityCounts: [AuditLogger.AuditEvent.Severity: Int]
    let oldestEvent: Date?
    let newestEvent: Date?
    let logFileSize: Int
}

enum AuditError: LocalizedError {
    case noLogFile
    case exportFailed(Error)
    case clearFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noLogFile:
            return "No audit log file exists"
        case .exportFailed(let error):
            return "Failed to export audit log: \(error.localizedDescription)"
        case .clearFailed(let error):
            return "Failed to clear audit log: \(error.localizedDescription)"
        }
    }
}