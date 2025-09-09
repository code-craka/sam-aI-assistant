import Foundation

/// Demo class to test performance monitoring functionality
class PerformanceDemo {
    
    private let performanceTracker = PerformanceTracker.shared
    private let responseOptimizer = ResponseOptimizer.shared
    private let backgroundProcessor = BackgroundProcessor.shared
    private let memoryManager = MemoryManager.shared
    
    /// Run a comprehensive performance monitoring demo
    func runDemo() async {
        print("🚀 Starting Performance Monitoring Demo")
        print("=" * 50)
        
        // Initialize performance monitoring
        await initializePerformanceMonitoring()
        
        // Demo 1: Basic operation tracking
        await demoOperationTracking()
        
        // Demo 2: Response optimization with caching
        await demoResponseOptimization()
        
        // Demo 3: Background task processing
        await demoBackgroundProcessing()
        
        // Demo 4: Memory management
        await demoMemoryManagement()
        
        // Demo 5: Performance dashboard data
        await demoPerformanceDashboard()
        
        print("\n✅ Performance Monitoring Demo Complete")
    }
    
    // MARK: - Demo Functions
    
    private func initializePerformanceMonitoring() async {
        print("\n📊 Initializing Performance Monitoring...")
        
        // Setup performance monitoring for services
        PerformanceSetup.initializePerformanceMonitoring()
        
        print("✓ Performance monitoring initialized")
    }
    
    private func demoOperationTracking() async {
        print("\n🔍 Demo 1: Operation Tracking")
        
        // Track a simple operation
        let result1 = try! await performanceTracker.trackOperation("demo_file_copy", type: .fileOperation) {
            // Simulate file copy operation
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            return "File copied successfully"
        }
        print("✓ Tracked file operation: \(result1)")
        
        // Track an AI operation
        let result2 = try! await performanceTracker.trackOperation("demo_ai_query", type: .aiProcessing) {
            // Simulate AI processing
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return "AI response generated"
        }
        print("✓ Tracked AI operation: \(result2)")
        
        // Track a system query
        let result3 = try! await performanceTracker.trackOperation("demo_system_info", type: .systemQuery) {
            // Simulate system query
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            return "System info retrieved"
        }
        print("✓ Tracked system operation: \(result3)")
        
        // Show current metrics
        let metrics = performanceTracker.currentMetrics
        print("📈 Current metrics:")
        print("   - Total operations: \(metrics.operationHistory.count)")
        print("   - Average response time: \(String(format: "%.3f", metrics.averageResponseTime))s")
        print("   - Success rate: \(String(format: "%.1f", metrics.successRate * 100))%")
    }
    
    private func demoResponseOptimization() async {
        print("\n⚡ Demo 2: Response Optimization")
        
        let request1 = OptimizableRequest(
            cacheKey: "demo_weather_query",
            isCacheable: true,
            cacheTTL: 300
        )
        
        // First request (cache miss)
        let startTime1 = Date()
        let result1 = try! await responseOptimizer.optimizeResponse(for: request1) {
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms
            return "Weather: 72°F, Sunny"
        }
        let duration1 = Date().timeIntervalSince(startTime1)
        print("✓ First request (cache miss): \(result1)")
        print("   Duration: \(String(format: "%.3f", duration1))s")
        
        // Second request (cache hit)
        let startTime2 = Date()
        let result2 = try! await responseOptimizer.optimizeResponse(for: request1) {
            try await Task.sleep(nanoseconds: 800_000_000) // Should not execute
            return "This should not be returned"
        }
        let duration2 = Date().timeIntervalSince(startTime2)
        print("✓ Second request (cache hit): \(result2)")
        print("   Duration: \(String(format: "%.3f", duration2))s")
        
        // Show cache statistics
        let cacheStats = responseOptimizer.getCacheStatistics()
        print("📊 Cache statistics:")
        print("   - Hit rate: \(String(format: "%.1f", cacheStats.hitRate * 100))%")
        print("   - Total requests: \(cacheStats.totalRequests)")
        print("   - Cache hits: \(cacheStats.cacheHits)")
    }
    
    private func demoBackgroundProcessing() async {
        print("\n🔄 Demo 3: Background Processing")
        
        // Submit individual tasks
        let task1 = backgroundProcessor.submitTask(
            name: "Process Large File",
            priority: .high
        ) {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            return "Large file processed"
        }
        
        let task2 = backgroundProcessor.submitTask(
            name: "Generate Report",
            priority: .normal
        ) {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return "Report generated"
        }
        
        let task3 = backgroundProcessor.submitTask(
            name: "Cleanup Temp Files",
            priority: .low
        ) {
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            return "Temp files cleaned"
        }
        
        print("✓ Submitted 3 background tasks")
        print("   - Active tasks: \(backgroundProcessor.activeTasks.count)")
        
        // Submit batch tasks
        let batchTasks = [
            ("Resize Image 1", { try await Task.sleep(nanoseconds: 300_000_000); return "Image 1 resized" }),
            ("Resize Image 2", { try await Task.sleep(nanoseconds: 300_000_000); return "Image 2 resized" }),
            ("Resize Image 3", { try await Task.sleep(nanoseconds: 300_000_000); return "Image 3 resized" })
        ]
        
        let batchSubmitted = backgroundProcessor.submitBatchTasks(
            name: "Image Batch Processing",
            tasks: batchTasks,
            priority: .normal
        )
        
        print("✓ Submitted batch of \(batchSubmitted.count) tasks")
        
        // Wait for some tasks to complete
        try! await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let stats = backgroundProcessor.getProcessingStatistics()
        print("📊 Processing statistics:")
        print("   - Total tasks: \(stats.totalTasks)")
        print("   - Active tasks: \(stats.activeTasks)")
        print("   - Completed tasks: \(stats.completedTasks)")
        print("   - Average execution time: \(String(format: "%.2f", stats.averageExecutionTime))s")
    }
    
    private func demoMemoryManagement() async {
        print("\n🧠 Demo 4: Memory Management")
        
        // Get initial memory statistics
        let initialStats = memoryManager.getMemoryStatistics()
        print("📊 Initial memory statistics:")
        print("   - Current usage: \(initialStats.formattedUsage)")
        print("   - Memory pressure: \(initialStats.pressure.rawValue)")
        print("   - Usage percentage: \(String(format: "%.1f", initialStats.usagePercentage))%")
        
        // Register a test cleanup handler
        var cleanupCalled = false
        memoryManager.registerCleanupHandler("demo_cleanup") {
            cleanupCalled = true
            print("   ✓ Demo cleanup handler executed")
        }
        
        // Perform manual cleanup
        print("🧹 Performing manual cleanup...")
        await memoryManager.performManualCleanup()
        
        if cleanupCalled {
            print("✓ Cleanup handlers executed successfully")
        }
        
        // Unregister cleanup handler
        memoryManager.unregisterCleanupHandler("demo_cleanup")
        
        let finalStats = memoryManager.getMemoryStatistics()
        print("📊 Final memory statistics:")
        print("   - Current usage: \(finalStats.formattedUsage)")
        print("   - Registered handlers: \(finalStats.registeredHandlers)")
    }
    
    private func demoPerformanceDashboard() async {
        print("\n📈 Demo 5: Performance Dashboard Data")
        
        // Collect comprehensive performance metrics
        let metricsReport = PerformanceAnalytics.collectMetrics()
        
        print("📊 Performance Report Summary:")
        print("   - Total operations: \(metricsReport.performanceReport.totalOperations)")
        print("   - Average response time: \(String(format: "%.3f", metricsReport.performanceReport.averageResponseTime))s")
        print("   - Success rate: \(String(format: "%.1f", metricsReport.performanceReport.successRate * 100))%")
        print("   - Current memory: \(metricsReport.memoryStatistics.formattedUsage)")
        print("   - Cache hit rate: \(String(format: "%.1f", metricsReport.cacheStatistics.hitRate * 100))%")
        print("   - Background tasks: \(metricsReport.processingStatistics.totalTasks)")
        
        // Export metrics to file
        do {
            let exportURL = try await PerformanceAnalytics.exportMetrics()
            print("✓ Metrics exported to: \(exportURL.path)")
        } catch {
            print("❌ Failed to export metrics: \(error.localizedDescription)")
        }
        
        // Show slowest operations
        let slowestOps = metricsReport.performanceReport.slowestOperations.prefix(3)
        if !slowestOps.isEmpty {
            print("🐌 Slowest operations:")
            for op in slowestOps {
                print("   - \(op.type.rawValue): \(String(format: "%.3f", op.duration))s")
            }
        }
        
        // Show operations by type
        print("📋 Operations by type:")
        for (type, count) in metricsReport.performanceReport.operationsByType {
            print("   - \(type.rawValue): \(count)")
        }
    }
}

// MARK: - Demo Runner

extension PerformanceDemo {
    
    /// Run a quick performance test
    static func runQuickTest() async {
        print("🏃‍♂️ Running Quick Performance Test...")
        
        let demo = PerformanceDemo()
        
        // Test basic operation tracking
        let tracker = PerformanceTracker.shared
        
        let result = try! await tracker.trackOperation("quick_test", type: .fileOperation) {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return "Quick test completed"
        }
        
        print("✓ \(result)")
        print("📊 Operations tracked: \(tracker.currentMetrics.operationHistory.count)")
        
        // Test response optimization
        let optimizer = ResponseOptimizer.shared
        let request = OptimizableRequest(cacheKey: "quick_test", isCacheable: true)
        
        let cachedResult = try! await optimizer.optimizeResponse(for: request) {
            return "Cached response"
        }
        
        print("✓ Response optimization: \(cachedResult)")
        print("📊 Cache requests: \(optimizer.totalRequests)")
        
        print("✅ Quick test complete!")
    }
}

// MARK: - String Extension for Demo

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}