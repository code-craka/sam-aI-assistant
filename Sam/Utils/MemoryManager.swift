import Foundation
import os.log

/// Memory management and automatic cleanup system
@MainActor
class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    // MARK: - Published Properties
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var isCleanupInProgress = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.sam.performance", category: "memory")
    private var cleanupHandlers: [String: () async -> Void] = [:]
    private var memoryTimer: Timer?
    private let cleanupQueue = DispatchQueue(label: "com.sam.memory.cleanup", qos: .utility)
    
    // Memory thresholds (in bytes)
    private let warningThreshold: UInt64 = 150 * 1024 * 1024  // 150MB
    private let criticalThreshold: UInt64 = 200 * 1024 * 1024 // 200MB
    private let emergencyThreshold: UInt64 = 250 * 1024 * 1024 // 250MB
    
    private init() {
        startMemoryMonitoring()
        setupMemoryPressureSource()
        registerDefaultCleanupHandlers()
    }
    
    deinit {
        stopMemoryMonitoring()
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkMemoryUsage()
            }
        }
    }
    
    private func stopMemoryMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
    }
    
    private func checkMemoryUsage() async {
        let usage = getCurrentMemoryUsage()
        currentMemoryUsage = usage
        
        let newPressure = determineMemoryPressure(usage)
        
        if newPressure != memoryPressure {
            memoryPressure = newPressure
            await handleMemoryPressureChange(newPressure)
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
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func determineMemoryPressure(_ usage: UInt64) -> MemoryPressure {
        switch usage {
        case 0..<warningThreshold:
            return .normal
        case warningThreshold..<criticalThreshold:
            return .warning
        case criticalThreshold..<emergencyThreshold:
            return .critical
        default:
            return .emergency
        }
    }
    
    private func handleMemoryPressureChange(_ pressure: MemoryPressure) async {
        logger.info("Memory pressure changed to: \(pressure.rawValue)")
        
        switch pressure {
        case .normal:
            break // No action needed
        case .warning:
            await performLightCleanup()
        case .critical:
            await performMediumCleanup()
        case .emergency:
            await performAggressiveCleanup()
        }
        
        // Post notification for other components
        NotificationCenter.default.post(
            name: .memoryPressureChanged,
            object: pressure
        )
    }
    
    // MARK: - System Memory Pressure
    
    private func setupMemoryPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.handleSystemMemoryPressure()
            }
        }
        
        source.resume()
    }
    
    private func handleSystemMemoryPressure() async {
        logger.warning("System memory pressure detected")
        await performAggressiveCleanup()
    }
    
    // MARK: - Cleanup Operations
    
    /// Register a cleanup handler for a specific component
    func registerCleanupHandler(_ id: String, handler: @escaping () async -> Void) {
        cleanupHandlers[id] = handler
        logger.debug("Registered cleanup handler: \(id)")
    }
    
    /// Unregister a cleanup handler
    func unregisterCleanupHandler(_ id: String) {
        cleanupHandlers.removeValue(forKey: id)
        logger.debug("Unregistered cleanup handler: \(id)")
    }
    
    /// Perform light cleanup (warning level)
    private func performLightCleanup() async {
        guard !isCleanupInProgress else { return }
        isCleanupInProgress = true
        
        logger.info("Performing light memory cleanup")
        
        // Clear caches
        await executeCleanupHandler("response_cache")
        await executeCleanupHandler("image_cache")
        
        isCleanupInProgress = false
    }
    
    /// Perform medium cleanup (critical level)
    private func performMediumCleanup() async {
        guard !isCleanupInProgress else { return }
        isCleanupInProgress = true
        
        logger.info("Performing medium memory cleanup")
        
        // Execute all light cleanup
        await performLightCleanup()
        
        // Additional cleanup
        await executeCleanupHandler("chat_history")
        await executeCleanupHandler("file_metadata_cache")
        await executeCleanupHandler("background_tasks")
        
        // Force garbage collection
        await forceGarbageCollection()
        
        isCleanupInProgress = false
    }
    
    /// Perform aggressive cleanup (emergency level)
    private func performAggressiveCleanup() async {
        guard !isCleanupInProgress else { return }
        isCleanupInProgress = true
        
        logger.warning("Performing aggressive memory cleanup")
        
        // Execute all medium cleanup
        await performMediumCleanup()
        
        // Execute all remaining cleanup handlers
        for (id, handler) in cleanupHandlers {
            await executeCleanupHandler(id)
        }
        
        // Multiple garbage collection cycles
        for _ in 0..<3 {
            await forceGarbageCollection()
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        isCleanupInProgress = false
    }
    
    private func executeCleanupHandler(_ id: String) async {
        guard let handler = cleanupHandlers[id] else { return }
        
        do {
            await handler()
            logger.debug("Executed cleanup handler: \(id)")
        } catch {
            logger.error("Cleanup handler failed: \(id) - \(error.localizedDescription)")
        }
    }
    
    private func forceGarbageCollection() async {
        // Swift doesn't have explicit GC, but we can trigger autoreleasepool drainage
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    // Force autorelease pool drainage
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Default Cleanup Handlers
    
    private func registerDefaultCleanupHandlers() {
        // Response cache cleanup
        registerCleanupHandler("response_cache") {
            await ResponseOptimizer.shared.clearCache()
        }
        
        // Performance tracker cleanup
        registerCleanupHandler("performance_tracker") {
            let tracker = PerformanceTracker.shared
            // Clear old metrics
            if tracker.currentMetrics.operationHistory.count > 50 {
                tracker.currentMetrics.operationHistory = Array(
                    tracker.currentMetrics.operationHistory.suffix(50)
                )
            }
        }
        
        // Background processor cleanup
        registerCleanupHandler("background_tasks") {
            let processor = BackgroundProcessor.shared
            // Cancel low priority queued tasks
            let lowPriorityTasks = processor.activeTasks.filter { 
                $0.priority == .low && $0.status == .queued 
            }
            for task in lowPriorityTasks {
                await processor.cancelTask(task.id)
            }
        }
        
        // Chat history cleanup
        registerCleanupHandler("chat_history") {
            // This would integrate with ChatManager to clear old messages
            NotificationCenter.default.post(name: .cleanupChatHistory, object: nil)
        }
        
        // File metadata cache cleanup
        registerCleanupHandler("file_metadata_cache") {
            // This would integrate with FileSystemService to clear cached metadata
            NotificationCenter.default.post(name: .cleanupFileCache, object: nil)
        }
    }
    
    // MARK: - Manual Operations
    
    /// Manually trigger cleanup
    func performManualCleanup() async {
        logger.info("Manual cleanup requested")
        await performMediumCleanup()
    }
    
    /// Get memory statistics
    func getMemoryStatistics() -> MemoryStatistics {
        return MemoryStatistics(
            currentUsage: currentMemoryUsage,
            pressure: memoryPressure,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold,
            emergencyThreshold: emergencyThreshold,
            usagePercentage: Double(currentMemoryUsage) / Double(emergencyThreshold) * 100,
            registeredHandlers: cleanupHandlers.count
        )
    }
}

// MARK: - Supporting Types

enum MemoryPressure: String, CaseIterable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
    case emergency = "emergency"
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "yellow"
        case .critical: return "orange"
        case .emergency: return "red"
        }
    }
}

struct MemoryStatistics {
    let currentUsage: UInt64
    let pressure: MemoryPressure
    let warningThreshold: UInt64
    let criticalThreshold: UInt64
    let emergencyThreshold: UInt64
    let usagePercentage: Double
    let registeredHandlers: Int
    
    var formattedUsage: String {
        return ByteCountFormatter.string(fromByteCount: Int64(currentUsage), countStyle: .memory)
    }
    
    var formattedWarningThreshold: String {
        return ByteCountFormatter.string(fromByteCount: Int64(warningThreshold), countStyle: .memory)
    }
    
    var formattedCriticalThreshold: String {
        return ByteCountFormatter.string(fromByteCount: Int64(criticalThreshold), countStyle: .memory)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryPressureChanged = Notification.Name("com.sam.memoryPressureChanged")
    static let cleanupChatHistory = Notification.Name("com.sam.cleanupChatHistory")
    static let cleanupFileCache = Notification.Name("com.sam.cleanupFileCache")
}