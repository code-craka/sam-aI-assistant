import Foundation
import os.log

/// Performance tracking and monitoring system for Sam
@MainActor
class PerformanceTracker: ObservableObject {
    static let shared = PerformanceTracker()
    
    // MARK: - Published Properties
    @Published var currentMetrics = PerformanceMetrics()
    @Published var isMonitoring = false
    
    // MARK: - Private Properties
    private var activeOperations: [String: OperationMetrics] = [:]
    private let logger = Logger(subsystem: "com.sam.performance", category: "tracker")
    private var memoryTimer: Timer?
    private let metricsQueue = DispatchQueue(label: "com.sam.performance.metrics", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        startMemoryMonitoring()
    }
    
    deinit {
        stopMemoryMonitoring()
    }
    
    // MARK: - Operation Tracking
    
    /// Start tracking a new operation
    func startOperation(_ operationId: String, type: OperationType) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let metrics = OperationMetrics(
            id: operationId,
            type: type,
            startTime: startTime,
            memoryAtStart: getCurrentMemoryUsage()
        )
        
        activeOperations[operationId] = metrics
        logger.info("Started operation: \(operationId) of type: \(type.rawValue)")
    }
    
    /// End tracking an operation and record metrics
    func endOperation(_ operationId: String, success: Bool = true, additionalData: [String: Any] = [:]) {
        guard let operation = activeOperations.removeValue(forKey: operationId) else {
            logger.warning("Attempted to end unknown operation: \(operationId)")
            return
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - operation.startTime
        let memoryAtEnd = getCurrentMemoryUsage()
        
        let completedMetrics = CompletedOperationMetrics(
            id: operationId,
            type: operation.type,
            duration: duration,
            memoryUsed: memoryAtEnd - operation.memoryAtStart,
            success: success,
            timestamp: Date(),
            additionalData: additionalData
        )
        
        recordMetrics(completedMetrics)
        logger.info("Completed operation: \(operationId) in \(String(format: "%.3f", duration))s")
    }
    
    /// Track a simple operation with automatic timing
    func trackOperation<T>(_ operationId: String, type: OperationType, operation: () async throws -> T) async rethrows -> T {
        startOperation(operationId, type: type)
        
        do {
            let result = try await operation()
            endOperation(operationId, success: true)
            return result
        } catch {
            endOperation(operationId, success: false, additionalData: ["error": error.localizedDescription])
            throw error
        }
    }
    
    // MARK: - Memory Management
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryMetrics()
            }
        }
    }
    
    private func stopMemoryMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
    }
    
    private func updateMemoryMetrics() {
        let currentMemory = getCurrentMemoryUsage()
        currentMetrics.currentMemoryUsage = currentMemory
        
        if currentMemory > currentMetrics.peakMemoryUsage {
            currentMetrics.peakMemoryUsage = currentMemory
        }
        
        // Trigger cleanup if memory usage is high
        if currentMemory > PerformanceConstants.memoryWarningThreshold {
            triggerMemoryCleanup()
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func triggerMemoryCleanup() {
        logger.warning("Memory usage high, triggering cleanup")
        
        // Post notification for other components to clean up
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
        
        // Perform our own cleanup
        performInternalCleanup()
    }
    
    private func performInternalCleanup() {
        // Clear old metrics (keep only last 100)
        if currentMetrics.operationHistory.count > 100 {
            currentMetrics.operationHistory = Array(currentMetrics.operationHistory.suffix(100))
        }
        
        // Clear completed operations older than 1 hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        currentMetrics.operationHistory.removeAll { $0.timestamp < oneHourAgo }
    }
    
    // MARK: - Metrics Recording
    
    private func recordMetrics(_ metrics: CompletedOperationMetrics) {
        metricsQueue.async { [weak self] in
            Task { @MainActor in
                self?.currentMetrics.operationHistory.append(metrics)
                self?.updateAverageMetrics()
            }
        }
    }
    
    private func updateAverageMetrics() {
        let recentOperations = currentMetrics.operationHistory.suffix(50)
        
        if !recentOperations.isEmpty {
            currentMetrics.averageResponseTime = recentOperations.map { $0.duration }.reduce(0, +) / Double(recentOperations.count)
            currentMetrics.successRate = Double(recentOperations.filter { $0.success }.count) / Double(recentOperations.count)
        }
    }
    
    // MARK: - Performance Analysis
    
    func getPerformanceReport() -> PerformanceReport {
        let report = PerformanceReport(
            totalOperations: currentMetrics.operationHistory.count,
            averageResponseTime: currentMetrics.averageResponseTime,
            successRate: currentMetrics.successRate,
            currentMemoryUsage: currentMetrics.currentMemoryUsage,
            peakMemoryUsage: currentMetrics.peakMemoryUsage,
            slowestOperations: getSlowestOperations(),
            operationsByType: getOperationsByType(),
            memoryTrend: getMemoryTrend()
        )
        
        return report
    }
    
    private func getSlowestOperations() -> [CompletedOperationMetrics] {
        return currentMetrics.operationHistory
            .sorted { $0.duration > $1.duration }
            .prefix(10)
            .map { $0 }
    }
    
    private func getOperationsByType() -> [OperationType: Int] {
        var counts: [OperationType: Int] = [:]
        for operation in currentMetrics.operationHistory {
            counts[operation.type, default: 0] += 1
        }
        return counts
    }
    
    private func getMemoryTrend() -> [MemoryDataPoint] {
        // Return memory usage over time (simplified)
        return [MemoryDataPoint(timestamp: Date(), usage: currentMetrics.currentMemoryUsage)]
    }
}

// MARK: - Supporting Types

struct PerformanceMetrics {
    var currentMemoryUsage: UInt64 = 0
    var peakMemoryUsage: UInt64 = 0
    var averageResponseTime: Double = 0
    var successRate: Double = 1.0
    var operationHistory: [CompletedOperationMetrics] = []
}

struct OperationMetrics {
    let id: String
    let type: OperationType
    let startTime: CFAbsoluteTime
    let memoryAtStart: UInt64
}

struct CompletedOperationMetrics {
    let id: String
    let type: OperationType
    let duration: Double
    let memoryUsed: UInt64
    let success: Bool
    let timestamp: Date
    let additionalData: [String: Any]
}

enum OperationType: String, CaseIterable {
    case fileOperation = "file_operation"
    case systemQuery = "system_query"
    case appIntegration = "app_integration"
    case aiProcessing = "ai_processing"
    case taskClassification = "task_classification"
    case workflowExecution = "workflow_execution"
    case cacheOperation = "cache_operation"
    case backgroundTask = "background_task"
}

struct PerformanceReport {
    let totalOperations: Int
    let averageResponseTime: Double
    let successRate: Double
    let currentMemoryUsage: UInt64
    let peakMemoryUsage: UInt64
    let slowestOperations: [CompletedOperationMetrics]
    let operationsByType: [OperationType: Int]
    let memoryTrend: [MemoryDataPoint]
}

struct MemoryDataPoint {
    let timestamp: Date
    let usage: UInt64
}

struct PerformanceConstants {
    static let memoryWarningThreshold: UInt64 = 200 * 1024 * 1024 // 200MB
    static let maxOperationHistory = 1000
    static let cleanupInterval: TimeInterval = 300 // 5 minutes
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryWarning = Notification.Name("com.sam.memoryWarning")
    static let performanceAlert = Notification.Name("com.sam.performanceAlert")
}