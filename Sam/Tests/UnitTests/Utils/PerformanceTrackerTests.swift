import XCTest
@testable import Sam

@MainActor
final class PerformanceTrackerTests: XCTestCase {
    
    var performanceTracker: PerformanceTracker!
    
    override func setUp() {
        super.setUp()
        performanceTracker = PerformanceTracker.shared
    }
    
    override func tearDown() {
        // Clear metrics for clean test state
        performanceTracker.currentMetrics = PerformanceMetrics()
        super.tearDown()
    }
    
    // MARK: - Operation Tracking Tests
    
    func testStartAndEndOperation() {
        let operationId = "test_operation"
        
        // Start operation
        performanceTracker.startOperation(operationId, type: .fileOperation)
        
        // Verify operation is tracked
        XCTAssertTrue(performanceTracker.activeOperations.keys.contains(operationId))
        
        // End operation
        performanceTracker.endOperation(operationId, success: true)
        
        // Verify operation is completed
        XCTAssertFalse(performanceTracker.activeOperations.keys.contains(operationId))
        XCTAssertEqual(performanceTracker.currentMetrics.operationHistory.count, 1)
        
        let completedOperation = performanceTracker.currentMetrics.operationHistory.first!
        XCTAssertEqual(completedOperation.id, operationId)
        XCTAssertEqual(completedOperation.type, .fileOperation)
        XCTAssertTrue(completedOperation.success)
    }
    
    func testTrackOperationWithClosure() async {
        let operationId = "test_async_operation"
        var operationExecuted = false
        
        let result = try! await performanceTracker.trackOperation(operationId, type: .aiProcessing) {
            operationExecuted = true
            return "test_result"
        }
        
        XCTAssertEqual(result, "test_result")
        XCTAssertTrue(operationExecuted)
        XCTAssertEqual(performanceTracker.currentMetrics.operationHistory.count, 1)
        
        let completedOperation = performanceTracker.currentMetrics.operationHistory.first!
        XCTAssertEqual(completedOperation.id, operationId)
        XCTAssertEqual(completedOperation.type, .aiProcessing)
        XCTAssertTrue(completedOperation.success)
    }
    
    func testTrackOperationWithError() async {
        let operationId = "test_error_operation"
        
        do {
            _ = try await performanceTracker.trackOperation(operationId, type: .systemQuery) {
                throw TestError.testError
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
        
        XCTAssertEqual(performanceTracker.currentMetrics.operationHistory.count, 1)
        
        let completedOperation = performanceTracker.currentMetrics.operationHistory.first!
        XCTAssertEqual(completedOperation.id, operationId)
        XCTAssertEqual(completedOperation.type, .systemQuery)
        XCTAssertFalse(completedOperation.success)
    }
    
    // MARK: - Metrics Tests
    
    func testAverageMetricsCalculation() {
        // Add multiple operations with known durations
        let operations = [
            ("op1", 1.0),
            ("op2", 2.0),
            ("op3", 3.0)
        ]
        
        for (id, duration) in operations {
            let startTime = CFAbsoluteTimeGetCurrent() - duration
            let metrics = OperationMetrics(
                id: id,
                type: .fileOperation,
                startTime: startTime,
                memoryAtStart: 1000
            )
            performanceTracker.activeOperations[id] = metrics
            
            let completedMetrics = CompletedOperationMetrics(
                id: id,
                type: .fileOperation,
                duration: duration,
                memoryUsed: 100,
                success: true,
                timestamp: Date(),
                additionalData: [:]
            )
            performanceTracker.currentMetrics.operationHistory.append(completedMetrics)
        }
        
        performanceTracker.updateAverageMetrics()
        
        XCTAssertEqual(performanceTracker.currentMetrics.averageResponseTime, 2.0, accuracy: 0.01)
        XCTAssertEqual(performanceTracker.currentMetrics.successRate, 1.0)
    }
    
    func testPerformanceReport() {
        // Add test data
        let completedMetrics = CompletedOperationMetrics(
            id: "test_op",
            type: .aiProcessing,
            duration: 1.5,
            memoryUsed: 1000,
            success: true,
            timestamp: Date(),
            additionalData: [:]
        )
        performanceTracker.currentMetrics.operationHistory.append(completedMetrics)
        
        let report = performanceTracker.getPerformanceReport()
        
        XCTAssertEqual(report.totalOperations, 1)
        XCTAssertEqual(report.slowestOperations.count, 1)
        XCTAssertEqual(report.operationsByType[.aiProcessing], 1)
    }
    
    // MARK: - Memory Monitoring Tests
    
    func testMemoryMonitoring() {
        // Test that memory monitoring updates current usage
        XCTAssertGreaterThanOrEqual(performanceTracker.currentMetrics.currentMemoryUsage, 0)
    }
}

// MARK: - Response Optimizer Tests

@MainActor
final class ResponseOptimizerTests: XCTestCase {
    
    var responseOptimizer: ResponseOptimizer!
    
    override func setUp() {
        super.setUp()
        responseOptimizer = ResponseOptimizer.shared
    }
    
    override func tearDown() async {
        await responseOptimizer.clearCache()
        super.tearDown()
    }
    
    func testCacheHitAndMiss() async {
        let request = OptimizableRequest(
            cacheKey: "test_key",
            isCacheable: true,
            cacheTTL: 300
        )
        
        // First call should be a cache miss
        let result1 = try! await responseOptimizer.optimizeResponse(for: request) {
            return "test_response"
        }
        
        XCTAssertEqual(result1, "test_response")
        XCTAssertEqual(responseOptimizer.totalRequests, 1)
        XCTAssertEqual(responseOptimizer.cacheHits, 0)
        
        // Second call should be a cache hit
        let result2 = try! await responseOptimizer.optimizeResponse(for: request) {
            return "different_response"
        }
        
        XCTAssertEqual(result2, "test_response") // Should return cached value
        XCTAssertEqual(responseOptimizer.totalRequests, 2)
        XCTAssertEqual(responseOptimizer.cacheHits, 1)
        XCTAssertEqual(responseOptimizer.cacheHitRate, 0.5)
    }
    
    func testNonCacheableRequest() async {
        let request = OptimizableRequest(
            cacheKey: "test_key",
            isCacheable: false,
            cacheTTL: 300
        )
        
        // Both calls should execute the operation
        let result1 = try! await responseOptimizer.optimizeResponse(for: request) {
            return "response1"
        }
        
        let result2 = try! await responseOptimizer.optimizeResponse(for: request) {
            return "response2"
        }
        
        XCTAssertEqual(result1, "response1")
        XCTAssertEqual(result2, "response2")
        XCTAssertEqual(responseOptimizer.cacheHits, 0)
    }
}

// MARK: - Background Processor Tests

@MainActor
final class BackgroundProcessorTests: XCTestCase {
    
    var backgroundProcessor: BackgroundProcessor!
    
    override func setUp() {
        super.setUp()
        backgroundProcessor = BackgroundProcessor.shared
    }
    
    override func tearDown() {
        // Cancel all active tasks
        for task in backgroundProcessor.activeTasks {
            Task {
                await backgroundProcessor.cancelTask(task.id)
            }
        }
        super.tearDown()
    }
    
    func testTaskSubmissionAndCompletion() async {
        let expectation = XCTestExpectation(description: "Task completion")
        
        let task = backgroundProcessor.submitTask(
            name: "Test Task",
            priority: .normal
        ) {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return "completed"
        }
        
        XCTAssertEqual(task.status, .queued)
        XCTAssertEqual(backgroundProcessor.activeTasks.count, 1)
        
        // Wait for completion
        var attempts = 0
        while task.status != .completed && attempts < 50 {
            try! await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }
        
        XCTAssertEqual(task.status, .completed)
        XCTAssertEqual(backgroundProcessor.activeTasks.count, 0)
        XCTAssertEqual(backgroundProcessor.completedTasks.count, 1)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testTaskCancellation() async {
        let task = backgroundProcessor.submitTask(
            name: "Cancellable Task",
            priority: .low
        ) {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return "should not complete"
        }
        
        XCTAssertEqual(task.status, .queued)
        
        await backgroundProcessor.cancelTask(task.id)
        
        XCTAssertEqual(task.status, .cancelled)
        XCTAssertEqual(backgroundProcessor.activeTasks.count, 0)
        XCTAssertEqual(backgroundProcessor.completedTasks.count, 1)
    }
    
    func testBatchTaskSubmission() {
        let tasks = [
            ("Task 1", { return "Result 1" }),
            ("Task 2", { return "Result 2" }),
            ("Task 3", { return "Result 3" })
        ]
        
        let submittedTasks = backgroundProcessor.submitBatchTasks(
            name: "Batch Test",
            tasks: tasks,
            priority: .normal
        )
        
        XCTAssertEqual(submittedTasks.count, 3)
        XCTAssertEqual(backgroundProcessor.activeTasks.count, 3)
        
        for task in submittedTasks {
            XCTAssertTrue(task.name.contains("Batch Test"))
        }
    }
}

// MARK: - Memory Manager Tests

@MainActor
final class MemoryManagerTests: XCTestCase {
    
    var memoryManager: MemoryManager!
    
    override func setUp() {
        super.setUp()
        memoryManager = MemoryManager.shared
    }
    
    func testMemoryPressureDetection() {
        let stats = memoryManager.getMemoryStatistics()
        
        XCTAssertGreaterThan(stats.currentUsage, 0)
        XCTAssertNotNil(stats.pressure)
        XCTAssertGreaterThan(stats.warningThreshold, 0)
        XCTAssertGreaterThan(stats.criticalThreshold, stats.warningThreshold)
        XCTAssertGreaterThan(stats.emergencyThreshold, stats.criticalThreshold)
    }
    
    func testCleanupHandlerRegistration() {
        var handlerCalled = false
        
        memoryManager.registerCleanupHandler("test_handler") {
            handlerCalled = true
        }
        
        let initialCount = memoryManager.getMemoryStatistics().registeredHandlers
        
        memoryManager.unregisterCleanupHandler("test_handler")
        
        let finalCount = memoryManager.getMemoryStatistics().registeredHandlers
        XCTAssertEqual(finalCount, initialCount - 1)
    }
    
    func testManualCleanup() async {
        await memoryManager.performManualCleanup()
        
        // Test should complete without errors
        XCTAssertFalse(memoryManager.isCleanupInProgress)
    }
}

// MARK: - Test Helpers

enum TestError: Error {
    case testError
}

extension PerformanceTracker {
    var activeOperations: [String: OperationMetrics] {
        return self.activeOperations
    }
    
    func updateAverageMetrics() {
        self.updateAverageMetrics()
    }
}