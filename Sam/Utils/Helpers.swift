import Foundation
import SwiftUI
import AppKit

// MARK: - String Extensions
extension String {
    /// Trims whitespace and newlines from the string
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Checks if the string is empty after trimming whitespace
    var isBlank: Bool {
        return self.trimmed.isEmpty
    }
    
    /// Capitalizes the first letter of the string
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).capitalized + dropFirst()
    }
    
    /// Truncates the string to a specified length with ellipsis
    func truncated(to length: Int, trailing: String = "...") -> String {
        guard self.count > length else { return self }
        return String(self.prefix(length)) + trailing
    }
    
    /// Extracts file paths from the string using regex
    func extractFilePaths() -> [String] {
        let pattern = #"(?:~\/|\/)[^\s]*"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: self.utf16.count)
        let matches = regex?.matches(in: self, options: [], range: range) ?? []
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: self) else { return nil }
            return String(self[range])
        }
    }
    
    /// Extracts app names from the string
    func extractAppNames() -> [String] {
        let commonApps = [
            "Safari", "Chrome", "Firefox", "Mail", "Calendar", "Contacts",
            "Finder", "Terminal", "Xcode", "VS Code", "Photoshop", "Illustrator",
            "Word", "Excel", "PowerPoint", "Keynote", "Pages", "Numbers",
            "Spotify", "iTunes", "Music", "Photos", "Preview", "TextEdit"
        ]
        
        return commonApps.filter { app in
            self.localizedCaseInsensitiveContains(app)
        }
    }
}

// MARK: - Date Extensions
extension Date {
    /// Returns a human-readable relative time string
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns a formatted date string for display
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Checks if the date is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// Checks if the date is yesterday
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
}

// MARK: - URL Extensions
extension URL {
    /// Returns the file size in bytes
    var fileSize: Int64 {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    /// Returns the file creation date
    var creationDate: Date? {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.creationDateKey])
            return resourceValues.creationDate
        } catch {
            return nil
        }
    }
    
    /// Returns the file modification date
    var modificationDate: Date? {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.contentModificationDateKey])
            return resourceValues.contentModificationDate
        } catch {
            return nil
        }
    }
    
    /// Checks if the URL points to a directory
    var isDirectory: Bool {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues.isDirectory ?? false
        } catch {
            return false
        }
    }
    
    /// Returns a user-friendly path string
    var userFriendlyPath: String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        if self.path.hasPrefix(homeDirectory.path) {
            return "~" + String(self.path.dropFirst(homeDirectory.path.count))
        }
        return self.path
    }
}

// MARK: - FileManager Extensions
extension FileManager {
    /// Returns the application support directory for the app
    var applicationSupportDirectory: URL {
        let urls = self.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls.first!.appendingPathComponent(AppConstants.applicationSupportDirectory)
        
        if !fileExists(atPath: appSupportURL.path) {
            try? createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appSupportURL
    }
    
    /// Returns the logs directory for the app
    var logsDirectory: URL {
        let logsURL = applicationSupportDirectory.appendingPathComponent(AppConstants.logsDirectory)
        
        if !fileExists(atPath: logsURL.path) {
            try? createDirectory(at: logsURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return logsURL
    }
    
    /// Returns the cache directory for the app
    var cacheDirectory: URL {
        let cacheURL = applicationSupportDirectory.appendingPathComponent(AppConstants.cacheDirectory)
        
        if !fileExists(atPath: cacheURL.path) {
            try? createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return cacheURL
    }
    
    /// Safely moves a file to trash
    func moveToTrash(_ url: URL) throws {
        var trashedURL: NSURL?
        try (self as NSFileManager).trashItem(at: url, resultingItemURL: &trashedURL)
    }
    
    /// Gets the size of a directory recursively
    func directorySize(at url: URL) -> Int64 {
        guard url.isDirectory else { return url.fileSize }
        
        var totalSize: Int64 = 0
        
        if let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                totalSize += fileURL.fileSize
            }
        }
        
        return totalSize
    }
}

// MARK: - ByteCountFormatter Helper
struct ByteFormatter {
    static let shared = ByteCountFormatter()
    
    static func format(_ bytes: Int64) -> String {
        shared.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        shared.countStyle = .file
        return shared.string(fromByteCount: bytes)
    }
    
    static func formatShort(_ bytes: Int64) -> String {
        shared.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        shared.countStyle = .abbreviated
        return shared.string(fromByteCount: bytes)
    }
}

// MARK: - Color Extensions
extension Color {
    /// Creates a color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Returns the hex string representation of the color
    var hexString: String {
        guard let components = NSColor(self).cgColor.components else { return "#000000" }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applies a conditional modifier with else clause
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if trueTransform: (Self) -> TrueContent,
        else falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }
    
    /// Adds a border with rounded corners
    func roundedBorder(_ color: Color = .gray, lineWidth: CGFloat = 1, cornerRadius: CGFloat = 8) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: lineWidth)
        )
    }
    
    /// Adds a subtle shadow
    func subtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Task Utilities
struct TaskUtils {
    /// Executes a task with timeout
    static func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TaskTimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TaskTimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Retries a task with exponential backoff
    static func withRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts {
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? TaskRetryError()
    }
}

// MARK: - Logging Utilities
struct Logger {
    enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    static func log(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "\(timestamp) \(level.emoji) [\(level.rawValue)] \(filename):\(line) \(function) - \(message)"
        
        print(logMessage)
        
        // Write to log file in production
        #if !DEBUG
        writeToLogFile(logMessage)
        #endif
    }
    
    private static func writeToLogFile(_ message: String) {
        let logURL = FileManager.default.logsDirectory.appendingPathComponent(FilePaths.logFile)
        
        do {
            let logEntry = message + "\n"
            if FileManager.default.fileExists(atPath: logURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logEntry.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try logEntry.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Error Types
struct TaskTimeoutError: LocalizedError {
    var errorDescription: String? {
        return "Task timed out"
    }
}

struct TaskRetryError: LocalizedError {
    var errorDescription: String? {
        return "Task failed after maximum retry attempts"
    }
}

// MARK: - Performance Monitoring
struct PerformanceMonitor {
    static func measure<T>(_ operation: () throws -> T, name: String = "Operation") rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        Logger.log("Performance: \(name) took \(String(format: "%.3f", timeElapsed))s", level: .debug)
        
        return result
    }
    
    static func measureAsync<T>(_ operation: () async throws -> T, name: String = "Async Operation") async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        Logger.log("Performance: \(name) took \(String(format: "%.3f", timeElapsed))s", level: .debug)
        
        return result
    }
}

// MARK: - Memory Utilities
struct MemoryUtils {
    static func getCurrentMemoryUsage() -> Int64 {
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
    
    static func logMemoryUsage(_ context: String = "") {
        let memoryUsage = getCurrentMemoryUsage()
        let formattedMemory = ByteFormatter.format(memoryUsage)
        Logger.log("Memory usage\(context.isEmpty ? "" : " (\(context))"): \(formattedMemory)", level: .debug)
    }
}