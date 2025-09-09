import Foundation

/// Performance integration extensions for existing services
extension ChatManager {
    
    /// Setup performance monitoring for chat operations
    func setupPerformanceMonitoring() {
        let memoryManager = MemoryManager.shared
        
        // Register cleanup handler for chat history
        memoryManager.registerCleanupHandler("chat_manager") { [weak self] in
            await self?.performMemoryCleanup()
        }
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            forName: .memoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
    }
    
    /// Perform memory cleanup for chat manager
    private func performMemoryCleanup() async {
        // Keep only recent messages (last 50)
        if messages.count > 50 {
            let recentMessages = Array(messages.suffix(50))
            messages = recentMessages
        }
        
        // Clear old conversation contexts
        // This would depend on your specific implementation
    }
    
    /// Handle memory warning
    private func handleMemoryWarning() async {
        await performMemoryCleanup()
        
        // Cancel any pending operations if memory is critical
        if MemoryManager.shared.memoryPressure == .emergency {
            // Cancel non-essential operations
        }
    }
}

extension FileSystemService {
    
    /// Setup performance monitoring for file operations
    func setupPerformanceMonitoring() {
        let memoryManager = MemoryManager.shared
        
        // Register cleanup handler for file caches
        memoryManager.registerCleanupHandler("file_system_service") { [weak self] in
            await self?.performMemoryCleanup()
        }
    }
    
    /// Perform memory cleanup for file system service
    private func performMemoryCleanup() async {
        // Clear metadata caches
        await metadataService.clearCache()
        
        // Clear duplicate detection caches
        await duplicateService.clearCache()
        
        // Clear smart organization caches
        await smartOrganizationService.clearCache()
    }
}

extension AIService {
    
    /// Setup performance monitoring for AI operations
    func setupPerformanceMonitoring() {
        let memoryManager = MemoryManager.shared
        
        // Register cleanup handler for AI service
        memoryManager.registerCleanupHandler("ai_service") { [weak self] in
            await self?.performMemoryCleanup()
        }
        
        // Setup response optimization
        setupResponseOptimization()
    }
    
    /// Perform memory cleanup for AI service
    private func performMemoryCleanup() async {
        // Clear context manager caches
        await contextManager.clearCache()
        
        // Reset usage metrics if they're taking too much memory
        if currentUsage.totalRequests > 1000 {
            currentUsage = ChatModels.UsageMetrics()
        }
    }
    
    /// Setup response optimization with caching
    private func setupResponseOptimization() {
        // This would integrate with ResponseOptimizer for caching AI responses
        // based on similar queries and contexts
    }
}

extension WorkflowExecutor {
    
    /// Setup performance monitoring for workflow execution
    func setupPerformanceMonitoring() {
        let memoryManager = MemoryManager.shared
        
        // Register cleanup handler for workflow executor
        memoryManager.registerCleanupHandler("workflow_executor") { [weak self] in
            await self?.performMemoryCleanup()
        }
    }
    
    /// Perform memory cleanup for workflow executor
    private func performMemoryCleanup() async {
        // Clear execution history (keep only recent executions)
        // This would depend on your specific implementation
        
        // Cancel low-priority queued workflows if memory is critical
        if MemoryManager.shared.memoryPressure == .critical {
            // Implementation would depend on your workflow queue structure
        }
    }
}

/// Performance monitoring setup for the entire app
struct PerformanceSetup {
    
    /// Initialize performance monitoring for all services
    static func initializePerformanceMonitoring() {
        // Start the performance tracker
        _ = PerformanceTracker.shared
        
        // Start the memory manager
        _ = MemoryManager.shared
        
        // Start the response optimizer
        _ = ResponseOptimizer.shared
        
        // Start the background processor
        _ = BackgroundProcessor.shared
        
        // Setup integration with existing services
        setupServiceIntegrations()
    }
    
    /// Setup performance integrations with existing services
    private static func setupServiceIntegrations() {
        // This would be called during app initialization
        // to setup performance monitoring for all services
        
        // Note: The actual setup calls would be made when the services are initialized
        // This is just a placeholder for the integration pattern
    }
}

/// Performance metrics collection for analytics
struct PerformanceAnalytics {
    
    /// Collect performance metrics for analysis
    static func collectMetrics() -> PerformanceMetricsReport {
        let performanceTracker = PerformanceTracker.shared
        let memoryManager = MemoryManager.shared
        let responseOptimizer = ResponseOptimizer.shared
        let backgroundProcessor = BackgroundProcessor.shared
        
        return PerformanceMetricsReport(
            performanceReport: performanceTracker.getPerformanceReport(),
            memoryStatistics: memoryManager.getMemoryStatistics(),
            cacheStatistics: responseOptimizer.getCacheStatistics(),
            processingStatistics: backgroundProcessor.getProcessingStatistics(),
            timestamp: Date()
        )
    }
    
    /// Export performance metrics to file
    static func exportMetrics() async throws -> URL {
        let metrics = collectMetrics()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(metrics)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent("sam_performance_metrics_\(Date().timeIntervalSince1970).json")
        
        try data.write(to: fileURL)
        return fileURL
    }
}

/// Comprehensive performance metrics report
struct PerformanceMetricsReport: Codable {
    let performanceReport: PerformanceReport
    let memoryStatistics: MemoryStatistics
    let cacheStatistics: CacheStatistics
    let processingStatistics: ProcessingStatistics
    let timestamp: Date
}

// MARK: - Codable Extensions

extension PerformanceReport: Codable {
    enum CodingKeys: String, CodingKey {
        case totalOperations, averageResponseTime, successRate
        case currentMemoryUsage, peakMemoryUsage
        case slowestOperations, operationsByType, memoryTrend
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalOperations, forKey: .totalOperations)
        try container.encode(averageResponseTime, forKey: .averageResponseTime)
        try container.encode(successRate, forKey: .successRate)
        try container.encode(currentMemoryUsage, forKey: .currentMemoryUsage)
        try container.encode(peakMemoryUsage, forKey: .peakMemoryUsage)
        try container.encode(slowestOperations, forKey: .slowestOperations)
        try container.encode(memoryTrend, forKey: .memoryTrend)
        
        // Convert operationsByType to encodable format
        let operationsDict = operationsByType.mapKeys { $0.rawValue }
        try container.encode(operationsDict, forKey: .operationsByType)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalOperations = try container.decode(Int.self, forKey: .totalOperations)
        averageResponseTime = try container.decode(Double.self, forKey: .averageResponseTime)
        successRate = try container.decode(Double.self, forKey: .successRate)
        currentMemoryUsage = try container.decode(UInt64.self, forKey: .currentMemoryUsage)
        peakMemoryUsage = try container.decode(UInt64.self, forKey: .peakMemoryUsage)
        slowestOperations = try container.decode([CompletedOperationMetrics].self, forKey: .slowestOperations)
        memoryTrend = try container.decode([MemoryDataPoint].self, forKey: .memoryTrend)
        
        // Convert back from encodable format
        let operationsDict = try container.decode([String: Int].self, forKey: .operationsByType)
        operationsByType = operationsDict.compactMapKeys { OperationType(rawValue: $0) }
    }
}

extension CompletedOperationMetrics: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, duration, memoryUsed, success, timestamp
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(duration, forKey: .duration)
        try container.encode(memoryUsed, forKey: .memoryUsed)
        try container.encode(success, forKey: .success)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let typeString = try container.decode(String.self, forKey: .type)
        type = OperationType(rawValue: typeString) ?? .backgroundTask
        duration = try container.decode(Double.self, forKey: .duration)
        memoryUsed = try container.decode(UInt64.self, forKey: .memoryUsed)
        success = try container.decode(Bool.self, forKey: .success)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        additionalData = [:] // Not encoded for simplicity
    }
}

extension MemoryDataPoint: Codable {}
extension MemoryStatistics: Codable {}
extension CacheStatistics: Codable {}
extension ProcessingStatistics: Codable {
    enum CodingKeys: String, CodingKey {
        case totalTasks, activeTasks, completedTasks, failedTasks, cancelledTasks
        case averageExecutionTime, tasksByPriority
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalTasks, forKey: .totalTasks)
        try container.encode(activeTasks, forKey: .activeTasks)
        try container.encode(completedTasks, forKey: .completedTasks)
        try container.encode(failedTasks, forKey: .failedTasks)
        try container.encode(cancelledTasks, forKey: .cancelledTasks)
        try container.encode(averageExecutionTime, forKey: .averageExecutionTime)
        
        let priorityDict = tasksByPriority.mapKeys { $0.rawValue }
        try container.encode(priorityDict, forKey: .tasksByPriority)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalTasks = try container.decode(Int.self, forKey: .totalTasks)
        activeTasks = try container.decode(Int.self, forKey: .activeTasks)
        completedTasks = try container.decode(Int.self, forKey: .completedTasks)
        failedTasks = try container.decode(Int.self, forKey: .failedTasks)
        cancelledTasks = try container.decode(Int.self, forKey: .cancelledTasks)
        averageExecutionTime = try container.decode(TimeInterval.self, forKey: .averageExecutionTime)
        
        let priorityDict = try container.decode([String: Int].self, forKey: .tasksByPriority)
        tasksByPriority = priorityDict.compactMapKeys { TaskPriority(rawValue: $0) }
    }
}

// MARK: - Helper Extensions

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: self.map { (transform($0.key), $0.value) })
    }
    
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: self.compactMap { 
            guard let newKey = transform($0.key) else { return nil }
            return (newKey, $0.value)
        })
    }
}