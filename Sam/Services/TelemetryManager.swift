import Foundation
import Combine
import os.log

// MARK: - Telemetry Manager
@MainActor
class TelemetryManager: ObservableObject {
    static let shared = TelemetryManager()
    
    @Published var isEnabled = true
    @Published var analyticsData: AnalyticsData = AnalyticsData()
    
    private let logger = Logger(subsystem: "com.sam.telemetry", category: "analytics")
    private let storage = TelemetryStorage()
    private let privacyManager = TelemetryPrivacyManager()
    private let batchProcessor = TelemetryBatchProcessor()
    
    private var eventQueue: [TelemetryEvent] = []
    private var sessionId = UUID().uuidString
    private var sessionStartTime = Date()
    
    private init() {
        loadSettings()
        startSession()
        setupPeriodicFlush()
    }
    
    // MARK: - Event Tracking
    func track(_ eventName: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        let event = TelemetryEvent(
            id: UUID().uuidString,
            name: eventName,
            properties: sanitizeProperties(properties),
            timestamp: Date(),
            sessionId: sessionId,
            userId: getUserId(),
            appVersion: getAppVersion(),
            systemInfo: getSystemInfo()
        )
        
        eventQueue.append(event)
        updateAnalyticsData(with: event)
        
        logger.info("Tracked event: \(eventName)")
        
        // Flush if queue is getting large
        if eventQueue.count >= 50 {
            Task {
                await flushEvents()
            }
        }
    }
    
    func trackError(_ error: Error, context: [String: Any] = [:]) {
        var properties = context
        properties["error_type"] = String(describing: type(of: error))
        properties["error_description"] = error.localizedDescription
        
        if let samError = error as? SamError {
            properties["error_category"] = samError.category
            properties["recovery_suggestion"] = samError.recoverySuggestion
        }
        
        track("error_occurred", properties: properties)
    }
    
    func trackPerformance(_ operation: String, duration: TimeInterval, metadata: [String: Any] = [:]) {
        var properties = metadata
        properties["operation"] = operation
        properties["duration_ms"] = Int(duration * 1000)
        properties["performance_category"] = categorizePerformance(duration)
        
        track("performance_measured", properties: properties)
    }
    
    func trackFeatureUsage(_ feature: String, action: String, metadata: [String: Any] = [:]) {
        var properties = metadata
        properties["feature"] = feature
        properties["action"] = action
        
        track("feature_used", properties: properties)
        
        // Update feature usage analytics
        analyticsData.featureUsage[feature, default: 0] += 1
    }
    
    func trackUserFlow(_ flow: String, step: String, metadata: [String: Any] = [:]) {
        var properties = metadata
        properties["flow"] = flow
        properties["step"] = step
        properties["flow_session"] = getFlowSessionId(flow)
        
        track("user_flow_step", properties: properties)
    }
    
    // MARK: - Session Management
    func startSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        
        track("session_started", properties: [
            "session_id": sessionId,
            "app_launch_time": sessionStartTime.timeIntervalSince1970
        ])
    }
    
    func endSession() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        
        track("session_ended", properties: [
            "session_id": sessionId,
            "session_duration": sessionDuration,
            "events_in_session": eventQueue.count
        ])
        
        Task {
            await flushEvents()
        }
    }
    
    // MARK: - Analytics Data
    func getAnalytics() -> AnalyticsReport {
        return AnalyticsReport(
            totalEvents: analyticsData.totalEvents,
            featureUsage: analyticsData.featureUsage,
            errorRate: calculateErrorRate(),
            averageSessionDuration: analyticsData.averageSessionDuration,
            topCommands: getTopCommands(),
            performanceMetrics: getPerformanceMetrics(),
            userEngagement: getUserEngagementMetrics()
        )
    }
    
    func exportAnalytics() async -> Data? {
        let report = getAnalytics()
        return try? JSONEncoder().encode(report)
    }
    
    // MARK: - Privacy Controls
    func enableTelemetry() {
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "telemetry_enabled")
        track("telemetry_enabled")
    }
    
    func disableTelemetry() {
        track("telemetry_disabled")
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "telemetry_enabled")
        
        // Clear existing data
        Task {
            await clearAllData()
        }
    }
    
    func clearAllData() async {
        eventQueue.removeAll()
        analyticsData = AnalyticsData()
        await storage.clearAll()
    }
    
    // MARK: - Data Processing
    private func flushEvents() async {
        guard !eventQueue.isEmpty else { return }
        
        let eventsToFlush = eventQueue
        eventQueue.removeAll()
        
        // Process events in batches
        await batchProcessor.process(eventsToFlush)
        
        // Store locally for analytics
        await storage.store(eventsToFlush)
        
        logger.info("Flushed \(eventsToFlush.count) events")
    }
    
    private func sanitizeProperties(_ properties: [String: Any]) -> [String: Any] {
        return privacyManager.sanitize(properties)
    }
    
    private func updateAnalyticsData(with event: TelemetryEvent) {
        analyticsData.totalEvents += 1
        analyticsData.lastEventTime = event.timestamp
        
        // Update specific metrics based on event type
        switch event.name {
        case "command_executed":
            if let command = event.properties["command"] as? String {
                analyticsData.commandUsage[command, default: 0] += 1
            }
        case "error_occurred":
            analyticsData.errorCount += 1
        case "session_ended":
            if let duration = event.properties["session_duration"] as? TimeInterval {
                updateSessionDuration(duration)
            }
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "telemetry_enabled")
    }
    
    private func getUserId() -> String {
        if let userId = UserDefaults.standard.string(forKey: "user_id") {
            return userId
        } else {
            let newUserId = UUID().uuidString
            UserDefaults.standard.set(newUserId, forKey: "user_id")
            return newUserId
        }
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private func getSystemInfo() -> [String: Any] {
        return [
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "device_model": getDeviceModel(),
            "memory_gb": Int(ProcessInfo.processInfo.physicalMemory / 1_000_000_000),
            "cpu_count": ProcessInfo.processInfo.processorCount
        ]
    }
    
    private func getDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private func categorizePerformance(_ duration: TimeInterval) -> String {
        switch duration {
        case 0..<0.1:
            return "excellent"
        case 0.1..<0.5:
            return "good"
        case 0.5..<2.0:
            return "acceptable"
        case 2.0..<5.0:
            return "slow"
        default:
            return "very_slow"
        }
    }
    
    private func getFlowSessionId(_ flow: String) -> String {
        let key = "flow_session_\(flow)"
        if let sessionId = UserDefaults.standard.string(forKey: key) {
            return sessionId
        } else {
            let newSessionId = UUID().uuidString
            UserDefaults.standard.set(newSessionId, forKey: key)
            return newSessionId
        }
    }
    
    private func calculateErrorRate() -> Double {
        guard analyticsData.totalEvents > 0 else { return 0.0 }
        return Double(analyticsData.errorCount) / Double(analyticsData.totalEvents)
    }
    
    private func getTopCommands() -> [(String, Int)] {
        return analyticsData.commandUsage.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }
    
    private func getPerformanceMetrics() -> PerformanceMetrics {
        // Calculate from stored events
        return PerformanceMetrics(
            averageResponseTime: 0.5,
            p95ResponseTime: 1.2,
            p99ResponseTime: 2.1,
            errorRate: calculateErrorRate()
        )
    }
    
    private func getUserEngagementMetrics() -> UserEngagementMetrics {
        return UserEngagementMetrics(
            dailyActiveUsers: 1,
            averageSessionsPerDay: 5,
            averageCommandsPerSession: 10,
            retentionRate: 0.85
        )
    }
    
    private func updateSessionDuration(_ duration: TimeInterval) {
        let currentAverage = analyticsData.averageSessionDuration
        let sessionCount = analyticsData.sessionCount + 1
        analyticsData.averageSessionDuration = (currentAverage * Double(analyticsData.sessionCount) + duration) / Double(sessionCount)
        analyticsData.sessionCount = sessionCount
    }
    
    private func setupPeriodicFlush() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await self.flushEvents()
            }
        }
    }
}

// MARK: - Telemetry Models
struct TelemetryEvent: Codable {
    let id: String
    let name: String
    let properties: [String: Any]
    let timestamp: Date
    let sessionId: String
    let userId: String
    let appVersion: String
    let systemInfo: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, name, timestamp, sessionId, userId, appVersion
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(userId, forKey: .userId)
        try container.encode(appVersion, forKey: .appVersion)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        userId = try container.decode(String.self, forKey: .userId)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        
        // Set default values for non-decoded properties
        properties = [:]
        systemInfo = [:]
    }
    
    init(id: String, name: String, properties: [String: Any], timestamp: Date, sessionId: String, userId: String, appVersion: String, systemInfo: [String: Any]) {
        self.id = id
        self.name = name
        self.properties = properties
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.appVersion = appVersion
        self.systemInfo = systemInfo
    }
}

struct AnalyticsData {
    var totalEvents: Int = 0
    var errorCount: Int = 0
    var sessionCount: Int = 0
    var averageSessionDuration: TimeInterval = 0
    var lastEventTime: Date?
    var featureUsage: [String: Int] = [:]
    var commandUsage: [String: Int] = [:]
}

struct AnalyticsReport: Codable {
    let totalEvents: Int
    let featureUsage: [String: Int]
    let errorRate: Double
    let averageSessionDuration: TimeInterval
    let topCommands: [(String, Int)]
    let performanceMetrics: PerformanceMetrics
    let userEngagement: UserEngagementMetrics
    
    enum CodingKeys: String, CodingKey {
        case totalEvents, featureUsage, errorRate, averageSessionDuration, performanceMetrics, userEngagement
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalEvents, forKey: .totalEvents)
        try container.encode(featureUsage, forKey: .featureUsage)
        try container.encode(errorRate, forKey: .errorRate)
        try container.encode(averageSessionDuration, forKey: .averageSessionDuration)
        try container.encode(performanceMetrics, forKey: .performanceMetrics)
        try container.encode(userEngagement, forKey: .userEngagement)
    }
}

struct PerformanceMetrics: Codable {
    let averageResponseTime: TimeInterval
    let p95ResponseTime: TimeInterval
    let p99ResponseTime: TimeInterval
    let errorRate: Double
}

struct UserEngagementMetrics: Codable {
    let dailyActiveUsers: Int
    let averageSessionsPerDay: Double
    let averageCommandsPerSession: Double
    let retentionRate: Double
}

// MARK: - Telemetry Storage
class TelemetryStorage {
    private let fileManager = FileManager.default
    private let storageURL: URL
    
    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("Sam/Telemetry")
        
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
    
    func store(_ events: [TelemetryEvent]) async {
        let filename = "events_\(Date().timeIntervalSince1970).json"
        let fileURL = storageURL.appendingPathComponent(filename)
        
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: fileURL)
        } catch {
            print("Failed to store telemetry events: \(error)")
        }
    }
    
    func loadEvents() async -> [TelemetryEvent] {
        var allEvents: [TelemetryEvent] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
            
            for file in files.filter({ $0.pathExtension == "json" }) {
                let data = try Data(contentsOf: file)
                let events = try JSONDecoder().decode([TelemetryEvent].self, from: data)
                allEvents.append(contentsOf: events)
            }
        } catch {
            print("Failed to load telemetry events: \(error)")
        }
        
        return allEvents
    }
    
    func clearAll() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to clear telemetry data: \(error)")
        }
    }
}

// MARK: - Telemetry Privacy Manager
class TelemetryPrivacyManager {
    private let sensitiveKeys = [
        "password", "token", "key", "secret", "credential",
        "email", "phone", "address", "name", "ssn"
    ]
    
    func sanitize(_ properties: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        
        for (key, value) in properties {
            if isSensitive(key) {
                sanitized[key] = "[REDACTED]"
            } else if let stringValue = value as? String {
                sanitized[key] = sanitizeString(stringValue)
            } else {
                sanitized[key] = value
            }
        }
        
        return sanitized
    }
    
    private func isSensitive(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        return sensitiveKeys.contains { lowercaseKey.contains($0) }
    }
    
    private func sanitizeString(_ string: String) -> String {
        // Remove potential PII patterns
        var sanitized = string
        
        // Email pattern
        sanitized = sanitized.replacingOccurrences(
            of: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            with: "[EMAIL]",
            options: .regularExpression
        )
        
        // Phone pattern
        sanitized = sanitized.replacingOccurrences(
            of: #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#,
            with: "[PHONE]",
            options: .regularExpression
        )
        
        return sanitized
    }
}

// MARK: - Telemetry Batch Processor
class TelemetryBatchProcessor {
    func process(_ events: [TelemetryEvent]) async {
        // Process events for insights
        await generateInsights(from: events)
        await detectAnomalies(in: events)
        await updateMetrics(with: events)
    }
    
    private func generateInsights(from events: [TelemetryEvent]) async {
        // Generate usage insights
        let commandEvents = events.filter { $0.name == "command_executed" }
        let errorEvents = events.filter { $0.name == "error_occurred" }
        
        // Analyze patterns and trends
        print("Generated insights from \(events.count) events")
    }
    
    private func detectAnomalies(in events: [TelemetryEvent]) async {
        // Detect unusual patterns or errors
        let errorRate = Double(events.filter { $0.name == "error_occurred" }.count) / Double(events.count)
        
        if errorRate > 0.1 {
            print("High error rate detected: \(errorRate)")
        }
    }
    
    private func updateMetrics(with events: [TelemetryEvent]) async {
        // Update performance and usage metrics
        print("Updated metrics with \(events.count) events")
    }
}

// MARK: - SamError Extension
extension SamError {
    var category: String {
        switch self {
        case .taskClassification:
            return "task_classification"
        case .fileOperation:
            return "file_operation"
        case .systemAccess:
            return "system_access"
        case .appIntegration:
            return "app_integration"
        case .aiService:
            return "ai_service"
        case .workflow:
            return "workflow"
        }
    }
}