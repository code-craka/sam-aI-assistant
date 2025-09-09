import Foundation
import SwiftUI

// MARK: - Error Handling Service
@MainActor
class ErrorHandlingService: ObservableObject {
    static let shared = ErrorHandlingService()
    
    @Published var currentError: SamError?
    @Published var errorHistory: [ErrorHistoryEntry] = []
    @Published var isShowingErrorDialog = false
    
    private let errorLogger = ErrorLogger.shared
    private let retryManager = RetryManager()
    private let degradationManager = GracefulDegradationManager.shared
    private let circuitBreaker = CircuitBreaker()
    
    private let maxErrorHistory = 50
    
    private init() {
        setupErrorHandling()
    }
    
    // MARK: - Public Methods
    
    func handle(_ error: SamError, context: String = "", showToUser: Bool = true) {
        // Log the error
        errorLogger.log(error, category: "ErrorHandling", additionalInfo: [
            "context": context,
            "showToUser": showToUser
        ])
        
        // Add to error history
        let historyEntry = ErrorHistoryEntry(
            id: UUID(),
            error: error,
            context: context,
            timestamp: Date(),
            wasShownToUser: showToUser,
            wasRetried: false,
            wasResolved: false
        )
        
        addToErrorHistory(historyEntry)
        
        // Handle based on error severity and type
        handleErrorBasedOnSeverity(error, context: context, showToUser: showToUser)
        
        // Update feature availability if needed
        updateFeatureAvailability(for: error, context: context)
    }
    
    func handleWithRetry<T>(
        operation: @escaping () async throws -> T,
        context: String = "",
        maxAttempts: Int = 3
    ) async -> Result<T, SamError> {
        let result = await retryManager.retry(operation, maxAttempts: maxAttempts)
        
        switch result {
        case .success(let value):
            return .success(value)
        case .failure(let error, let attempts):
            // Mark as retried in history
            if let lastEntry = errorHistory.last {
                updateErrorHistoryEntry(lastEntry.id, wasRetried: true)
            }
            
            handle(error, context: "\(context) (after \(attempts) attempts)")
            return .failure(error)
        case .cancelled:
            let cancelledError = SamError.unknown("Operation was cancelled")
            handle(cancelledError, context: context)
            return .failure(cancelledError)
        }
    }
    
    func handleWithDegradation<T>(
        feature: String,
        primaryOperation: @escaping () async throws -> T,
        fallbackOperation: @escaping () async throws -> T,
        context: String = ""
    ) async -> Result<T, SamError> {
        let result = await degradationManager.executeWithDegradation(
            feature: feature,
            primaryOperation: primaryOperation,
            fallbackOperation: fallbackOperation
        )
        
        switch result {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            handle(error, context: "\(context) (feature: \(feature))")
            return .failure(error)
        }
    }
    
    func handleWithCircuitBreaker<T>(
        operation: @escaping () async throws -> T,
        context: String = ""
    ) async -> Result<T, SamError> {
        do {
            let result = try await circuitBreaker.execute(operation)
            return .success(result)
        } catch let error as SamError {
            handle(error, context: "\(context) (circuit breaker)")
            return .failure(error)
        } catch {
            let samError = SamError.unknown(error.localizedDescription)
            handle(samError, context: "\(context) (circuit breaker)")
            return .failure(samError)
        }
    }
    
    func resolveError(_ errorId: UUID) {
        if let index = errorHistory.firstIndex(where: { $0.id == errorId }) {
            errorHistory[index] = ErrorHistoryEntry(
                id: errorHistory[index].id,
                error: errorHistory[index].error,
                context: errorHistory[index].context,
                timestamp: errorHistory[index].timestamp,
                wasShownToUser: errorHistory[index].wasShownToUser,
                wasRetried: errorHistory[index].wasRetried,
                wasResolved: true
            )
        }
        
        // Clear current error if it matches
        if let currentError = currentError,
           let currentEntry = errorHistory.first(where: { $0.error.localizedDescription == currentError.localizedDescription }) {
            if currentEntry.id == errorId {
                self.currentError = nil
                self.isShowingErrorDialog = false
            }
        }
    }
    
    func dismissCurrentError() {
        currentError = nil
        isShowingErrorDialog = false
    }
    
    func getErrorSuggestions(for error: SamError) -> [ErrorSuggestion] {
        var suggestions: [ErrorSuggestion] = []
        
        // Add recovery suggestion from error
        if let recoverySuggestion = error.recoverySuggestion {
            suggestions.append(ErrorSuggestion(
                title: "Suggested Fix",
                description: recoverySuggestion,
                action: .none
            ))
        }
        
        // Add specific suggestions based on error type
        switch error {
        case .aiService(.apiKeyMissing), .aiService(.apiKeyInvalid):
            suggestions.append(ErrorSuggestion(
                title: "Open Settings",
                description: "Configure your OpenAI API key in settings",
                action: .openSettings
            ))
            
        case .permission:
            suggestions.append(ErrorSuggestion(
                title: "Open System Preferences",
                description: "Grant required permissions in System Preferences",
                action: .openSystemPreferences
            ))
            
        case .network:
            suggestions.append(ErrorSuggestion(
                title: "Check Connection",
                description: "Verify your internet connection and try again",
                action: .retry
            ))
            
        case .fileOperation(.fileNotFound):
            suggestions.append(ErrorSuggestion(
                title: "Browse Files",
                description: "Select the correct file location",
                action: .browseFiles
            ))
            
        default:
            if error.isRecoverable {
                suggestions.append(ErrorSuggestion(
                    title: "Try Again",
                    description: "Retry the operation",
                    action: .retry
                ))
            }
        }
        
        // Add help suggestion
        suggestions.append(ErrorSuggestion(
            title: "Get Help",
            description: "View documentation or contact support",
            action: .getHelp
        ))
        
        return suggestions
    }
    
    func exportErrorReport() -> URL? {
        let report = ErrorReport(
            timestamp: Date(),
            systemHealth: degradationManager.getSystemHealthReport(),
            errorHistory: Array(errorHistory.suffix(20)), // Last 20 errors
            logStatistics: errorLogger.getLogStatistics(),
            appVersion: getAppVersion(),
            systemInfo: getSystemInfo()
        )
        
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("sam_error_report.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(report)
            try data.write(to: exportURL)
            
            return exportURL
        } catch {
            errorLogger.error("Failed to export error report: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func setupErrorHandling() {
        // Configure retry manager
        retryManager.configuration = .default
        
        // Register for degradation manager notifications
        // This would be implemented with proper notification handling
    }
    
    private func handleErrorBasedOnSeverity(_ error: SamError, context: String, showToUser: Bool) {
        switch error.severity {
        case .low:
            // Log only, don't show to user unless explicitly requested
            if showToUser {
                showErrorToUser(error)
            }
            
        case .medium:
            // Show to user with option to dismiss
            if showToUser {
                showErrorToUser(error)
            }
            
        case .high:
            // Always show to user, suggest actions
            showErrorToUser(error)
            
        case .critical:
            // Show critical error dialog, log crash report
            showCriticalError(error, context: context)
            errorLogger.logCrash(error: error, context: context)
        }
    }
    
    private func showErrorToUser(_ error: SamError) {
        currentError = error
        isShowingErrorDialog = true
    }
    
    private func showCriticalError(_ error: SamError, context: String) {
        currentError = error
        isShowingErrorDialog = true
        
        // Additional critical error handling
        degradationManager.markFeatureUnavailable("critical_system", reason: error.localizedDescription)
    }
    
    private func updateFeatureAvailability(for error: SamError, context: String) {
        let feature = extractFeatureFromContext(context)
        
        switch error.severity {
        case .low, .medium:
            // Don't change feature availability for low/medium errors
            break
            
        case .high:
            if let feature = feature {
                degradationManager.markFeatureDegraded(feature, reason: error.localizedDescription)
            }
            
        case .critical:
            if let feature = feature {
                degradationManager.markFeatureUnavailable(feature, reason: error.localizedDescription)
            }
        }
    }
    
    private func extractFeatureFromContext(_ context: String) -> String? {
        let contextLower = context.lowercased()
        
        if contextLower.contains("ai") || contextLower.contains("openai") {
            return "ai_service"
        } else if contextLower.contains("file") {
            return "file_operations"
        } else if contextLower.contains("app") || contextLower.contains("integration") {
            return "app_integration"
        } else if contextLower.contains("system") {
            return "system_info"
        } else if contextLower.contains("workflow") {
            return "workflow_execution"
        } else if contextLower.contains("network") {
            return "network_operations"
        }
        
        return nil
    }
    
    private func addToErrorHistory(_ entry: ErrorHistoryEntry) {
        errorHistory.append(entry)
        
        // Keep only the most recent errors
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst(errorHistory.count - maxErrorHistory)
        }
    }
    
    private func updateErrorHistoryEntry(_ id: UUID, wasRetried: Bool = false, wasResolved: Bool = false) {
        if let index = errorHistory.firstIndex(where: { $0.id == id }) {
            let entry = errorHistory[index]
            errorHistory[index] = ErrorHistoryEntry(
                id: entry.id,
                error: entry.error,
                context: entry.context,
                timestamp: entry.timestamp,
                wasShownToUser: entry.wasShownToUser,
                wasRetried: wasRetried || entry.wasRetried,
                wasResolved: wasResolved || entry.wasResolved
            )
        }
    }
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private func getSystemInfo() -> [String: String] {
        let processInfo = ProcessInfo.processInfo
        
        return [
            "osVersion": processInfo.operatingSystemVersionString,
            "deviceModel": getDeviceModel(),
            "memoryUsage": "\(getMemoryUsage() / 1024 / 1024) MB",
            "diskSpace": "\(getDiskSpace() / 1024 / 1024 / 1024) GB"
        ]
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func getDiskSpace() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                return freeSpace.int64Value
            }
        } catch {
            errorLogger.error("Failed to get disk space: \(error.localizedDescription)")
        }
        return 0
    }
}

// MARK: - Supporting Types

struct ErrorHistoryEntry: Codable, Identifiable {
    let id: UUID
    let error: SamError
    let context: String
    let timestamp: Date
    let wasShownToUser: Bool
    let wasRetried: Bool
    let wasResolved: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, context, timestamp, wasShownToUser, wasRetried, wasResolved
        case errorDescription, errorCode, severity
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(error.localizedDescription, forKey: .errorDescription)
        try container.encode(getErrorCode(from: error), forKey: .errorCode)
        try container.encode(error.severity.rawValue, forKey: .severity)
        try container.encode(context, forKey: .context)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(wasShownToUser, forKey: .wasShownToUser)
        try container.encode(wasRetried, forKey: .wasRetried)
        try container.encode(wasResolved, forKey: .wasResolved)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let errorDescription = try container.decode(String.self, forKey: .errorDescription)
        error = SamError.unknown(errorDescription) // Simplified for decoding
        context = try container.decode(String.self, forKey: .context)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        wasShownToUser = try container.decode(Bool.self, forKey: .wasShownToUser)
        wasRetried = try container.decode(Bool.self, forKey: .wasRetried)
        wasResolved = try container.decode(Bool.self, forKey: .wasResolved)
    }
    
    init(id: UUID, error: SamError, context: String, timestamp: Date, wasShownToUser: Bool, wasRetried: Bool, wasResolved: Bool) {
        self.id = id
        self.error = error
        self.context = context
        self.timestamp = timestamp
        self.wasShownToUser = wasShownToUser
        self.wasRetried = wasRetried
        self.wasResolved = wasResolved
    }
    
    private func getErrorCode(from error: SamError) -> String {
        switch error {
        case .taskClassification(let tcError):
            return tcError.errorCode
        case .fileOperation(let foError):
            return foError.errorCode
        case .systemAccess(let saError):
            return saError.errorCode
        case .appIntegration(let aiError):
            return aiError.errorCode
        case .aiService(let asError):
            return asError.errorCode
        case .workflow(let wfError):
            return wfError.errorCode
        case .network(let neError):
            return neError.errorCode
        case .permission(let peError):
            return peError.errorCode
        case .validation(let veError):
            return veError.errorCode
        case .unknown:
            return "UE001"
        }
    }
}

struct ErrorSuggestion {
    let title: String
    let description: String
    let action: ErrorAction
    
    enum ErrorAction {
        case none
        case retry
        case openSettings
        case openSystemPreferences
        case browseFiles
        case getHelp
    }
}

struct ErrorReport: Codable {
    let timestamp: Date
    let systemHealth: SystemHealthReport
    let errorHistory: [ErrorHistoryEntry]
    let logStatistics: LogStatistics
    let appVersion: String
    let systemInfo: [String: String]
}