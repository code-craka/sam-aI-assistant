import Foundation
import OSLog

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }
}

// MARK: - Log Entry
struct LogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let errorCode: String?
    let userInfo: [String: String]
    let stackTrace: String?
    let sessionId: String
    let appVersion: String
    let systemInfo: SystemInfo
    
    struct SystemInfo: Codable {
        let osVersion: String
        let deviceModel: String
        let appBuild: String
        let memoryUsage: Int64
        let diskSpace: Int64
    }
}

// MARK: - Error Logger
@MainActor
class ErrorLogger: ObservableObject {
    static let shared = ErrorLogger()
    
    @Published var recentErrors: [LogEntry] = []
    @Published var isLoggingEnabled: Bool = true
    @Published var logLevel: LogLevel = .info
    
    private let logger: Logger
    private let sessionId: String
    private let maxRecentErrors: Int = 100
    private let logFileURL: URL
    private let crashReportURL: URL
    
    private init() {
        self.logger = Logger(subsystem: "com.sam.assistant", category: "ErrorLogger")
        self.sessionId = UUID().uuidString
        
        // Setup log file URLs
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        // Create logs directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        self.logFileURL = logsDirectory.appendingPathComponent("sam_errors.log")
        self.crashReportURL = logsDirectory.appendingPathComponent("crash_reports")
        
        // Create crash reports directory
        try? FileManager.default.createDirectory(at: crashReportURL, withIntermediateDirectories: true)
        
        setupCrashHandler()
        loadRecentErrors()
    }
    
    // MARK: - Public Methods
    
    func log(_ error: SamError, category: String = "General", additionalInfo: [String: Any] = [:]) {
        guard isLoggingEnabled else { return }
        
        let level: LogLevel = error.severity == .critical ? .critical : .error
        let errorCode = getErrorCode(from: error)
        
        var userInfo = error.userInfo.mapValues { String(describing: $0) }
        for (key, value) in additionalInfo {
            userInfo[key] = String(describing: value)
        }
        
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: category,
            message: error.localizedDescription,
            errorCode: errorCode,
            userInfo: userInfo,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            sessionId: sessionId,
            appVersion: getAppVersion(),
            systemInfo: getCurrentSystemInfo()
        )
        
        logEntry(entry)
    }
    
    func log(level: LogLevel, category: String, message: String, userInfo: [String: Any] = [:]) {
        guard isLoggingEnabled && level.rawValue >= logLevel.rawValue else { return }
        
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            errorCode: nil,
            userInfo: userInfo.mapValues { String(describing: $0) },
            stackTrace: level == .error || level == .critical ? Thread.callStackSymbols.joined(separator: "\n") : nil,
            sessionId: sessionId,
            appVersion: getAppVersion(),
            systemInfo: getCurrentSystemInfo()
        )
        
        logEntry(entry)
    }
    
    func logCrash(error: Error, context: String = "") {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            sessionId: sessionId,
            appVersion: getAppVersion(),
            systemInfo: getCurrentSystemInfo(),
            error: error.localizedDescription,
            context: context,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )
        
        saveCrashReport(crashReport)
        
        // Also log as critical error
        log(
            level: .critical,
            category: "Crash",
            message: "Application crash: \(error.localizedDescription)",
            userInfo: ["context": context]
        )
    }
    
    func exportLogs() -> URL? {
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("sam_logs_export.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(recentErrors)
            try data.write(to: exportURL)
            
            return exportURL
        } catch {
            logger.error("Failed to export logs: \(error.localizedDescription)")
            return nil
        }
    }
    
    func clearLogs() {
        recentErrors.removeAll()
        
        // Clear log file
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        
        log(level: .info, category: "System", message: "Logs cleared by user")
    }
    
    func getLogStatistics() -> LogStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-24 * 60 * 60)
        let lastWeek = now.addingTimeInterval(-7 * 24 * 60 * 60)
        
        let recent24h = recentErrors.filter { $0.timestamp >= last24Hours }
        let recentWeek = recentErrors.filter { $0.timestamp >= lastWeek }
        
        return LogStatistics(
            totalErrors: recentErrors.count,
            errorsLast24Hours: recent24h.count,
            errorsLastWeek: recentWeek.count,
            criticalErrors: recentErrors.filter { $0.level == .critical }.count,
            mostCommonErrorCode: getMostCommonErrorCode(),
            sessionId: sessionId
        )
    }
    
    // MARK: - Private Methods
    
    private func logEntry(_ entry: LogEntry) {
        // Add to recent errors
        recentErrors.append(entry)
        
        // Keep only the most recent errors in memory
        if recentErrors.count > maxRecentErrors {
            recentErrors.removeFirst(recentErrors.count - maxRecentErrors)
        }
        
        // Log to system logger
        logger.log(level: entry.level.osLogType, "\(entry.category): \(entry.message)")
        
        // Append to log file
        appendToLogFile(entry)
    }
    
    private func appendToLogFile(_ entry: LogEntry) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(entry)
            let logLine = String(data: data, encoding: .utf8)! + "\n"
            
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logLine.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            logger.error("Failed to write to log file: \(error.localizedDescription)")
        }
    }
    
    private func loadRecentErrors() {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return }
        
        do {
            let logContent = try String(contentsOf: logFileURL)
            let lines = logContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var loadedErrors: [LogEntry] = []
            
            // Load the most recent entries
            let recentLines = Array(lines.suffix(maxRecentErrors))
            
            for line in recentLines {
                if let data = line.data(using: .utf8),
                   let entry = try? decoder.decode(LogEntry.self, from: data) {
                    loadedErrors.append(entry)
                }
            }
            
            recentErrors = loadedErrors
        } catch {
            logger.error("Failed to load recent errors: \(error.localizedDescription)")
        }
    }
    
    private func saveCrashReport(_ crashReport: CrashReport) {
        let fileName = "crash_\(crashReport.timestamp.timeIntervalSince1970).json"
        let crashFileURL = crashReportURL.appendingPathComponent(fileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(crashReport)
            try data.write(to: crashFileURL)
        } catch {
            logger.error("Failed to save crash report: \(error.localizedDescription)")
        }
    }
    
    private func setupCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                ErrorLogger.shared.logCrash(
                    error: NSError(domain: "UncaughtException", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception"
                    ]),
                    context: "Uncaught exception: \(exception.name.rawValue)"
                )
            }
        }
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
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private func getCurrentSystemInfo() -> LogEntry.SystemInfo {
        let processInfo = ProcessInfo.processInfo
        
        return LogEntry.SystemInfo(
            osVersion: processInfo.operatingSystemVersionString,
            deviceModel: getDeviceModel(),
            appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            memoryUsage: getMemoryUsage(),
            diskSpace: getDiskSpace()
        )
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
            logger.error("Failed to get disk space: \(error.localizedDescription)")
        }
        return 0
    }
    
    private func getMostCommonErrorCode() -> String? {
        let errorCodes = recentErrors.compactMap { $0.errorCode }
        let counts = Dictionary(grouping: errorCodes, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Supporting Types

struct CrashReport: Codable {
    let id: UUID
    let timestamp: Date
    let sessionId: String
    let appVersion: String
    let systemInfo: LogEntry.SystemInfo
    let error: String
    let context: String
    let stackTrace: String
}

struct LogStatistics {
    let totalErrors: Int
    let errorsLast24Hours: Int
    let errorsLastWeek: Int
    let criticalErrors: Int
    let mostCommonErrorCode: String?
    let sessionId: String
}

// MARK: - Convenience Extensions

extension ErrorLogger {
    func debug(_ message: String, category: String = "Debug", userInfo: [String: Any] = [:]) {
        log(level: .debug, category: category, message: message, userInfo: userInfo)
    }
    
    func info(_ message: String, category: String = "Info", userInfo: [String: Any] = [:]) {
        log(level: .info, category: category, message: message, userInfo: userInfo)
    }
    
    func warning(_ message: String, category: String = "Warning", userInfo: [String: Any] = [:]) {
        log(level: .warning, category: category, message: message, userInfo: userInfo)
    }
    
    func error(_ message: String, category: String = "Error", userInfo: [String: Any] = [:]) {
        log(level: .error, category: category, message: message, userInfo: userInfo)
    }
    
    func critical(_ message: String, category: String = "Critical", userInfo: [String: Any] = [:]) {
        log(level: .critical, category: category, message: message, userInfo: userInfo)
    }
}