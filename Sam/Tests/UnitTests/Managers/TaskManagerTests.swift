import XCTest
@testable import Sam

final class TaskManagerTests: XCTestCase {
    var taskManager: TaskManager!
    var mockTaskClassifier: MockTaskClassifier!
    var mockFileSystemService: MockFileSystemService!
    var mockSystemService: MockSystemService!
    
    override func setUp() {
        super.setUp()
        mockTaskClassifier = MockTaskClassifier()
        mockFileSystemService = MockFileSystemService()
        mockSystemService = MockSystemService()
        taskManager = TaskManager(
            taskClassifier: mockTaskClassifier,
            fileSystemService: mockFileSystemService,
            systemService: mockSystemService
        )
    }
    
    override func tearDown() {
        taskManager = nil
        mockTaskClassifier = nil
        mockFileSystemService = nil
        mockSystemService = nil
        super.tearDown()
    }
    
    func testFileOperationTask() async throws {
        // Given
        let input = "copy file.txt to Desktop"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .fileOperation,
            confidence: 0.95,
            parameters: [
                "operation": "copy",
                "source": "file.txt",
                "destination": "Desktop"
            ],
            requiresCloudProcessing: false
        )
        mockFileSystemService.mockResult = TaskResult(
            success: true,
            output: "File copied successfully",
            executionTime: 0.5,
            affectedFiles: [URL(fileURLWithPath: "/Users/test/Desktop/file.txt")]
        )
        
        // When
        let result = try await taskManager.executeTask(input)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "File copied successfully")
        XCTAssertTrue(mockTaskClassifier.classifyCalled)
        XCTAssertTrue(mockFileSystemService.executeCalled)
    }
    
    func testSystemQueryTask() async throws {
        // Given
        let input = "what's my battery level?"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .systemQuery,
            confidence: 0.90,
            parameters: ["queryType": "battery"],
            requiresCloudProcessing: false
        )
        mockSystemService.mockBatteryLevel = 85.0
        
        // When
        let result = try await taskManager.executeTask(input)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("85%"))
        XCTAssertTrue(mockSystemService.getBatteryLevelCalled)
    }
    
    func testLowConfidenceClassification() async throws {
        // Given
        let input = "complex ambiguous request"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .textProcessing,
            confidence: 0.60, // Below threshold
            parameters: [:],
            requiresCloudProcessing: true
        )
        
        // When
        let result = try await taskManager.executeTask(input)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("cloud processing"))
    }
    
    func testTaskExecutionError() async throws {
        // Given
        let input = "invalid file operation"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .fileOperation,
            confidence: 0.85,
            parameters: ["operation": "invalid"],
            requiresCloudProcessing: false
        )
        mockFileSystemService.shouldThrowError = true
        
        // When
        let result = try await taskManager.executeTask(input)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.output.contains("error"))
    }
    
    func testTaskTimeout() async throws {
        // Given
        let input = "long running task"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .fileOperation,
            confidence: 0.85,
            parameters: [:],
            requiresCloudProcessing: false
        )
        mockFileSystemService.simulateDelay = 10.0 // 10 seconds
        
        // When
        let startTime = Date()
        let result = try await taskManager.executeTask(input, timeout: 2.0)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertLessThan(executionTime, 3.0) // Should timeout before 3 seconds
        XCTAssertTrue(result.output.contains("timeout"))
    }
}

// MARK: - Mock Classes

class MockTaskClassifier: TaskClassifierProtocol {
    var mockResult: TaskClassificationResult!
    var classifyCalled = false
    
    func classify(_ input: String) async throws -> TaskClassificationResult {
        classifyCalled = true
        return mockResult
    }
}

class MockFileSystemService: FileSystemServiceProtocol {
    var mockResult: TaskResult!
    var executeCalled = false
    var shouldThrowError = false
    var simulateDelay: TimeInterval = 0
    
    func executeFileOperation(_ operation: FileOperation) async throws -> TaskResult {
        executeCalled = true
        
        if simulateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw FileSystemError.operationFailed("Mock error")
        }
        
        return mockResult
    }
}

class MockSystemService: SystemServiceProtocol {
    var mockBatteryLevel: Double = 100.0
    var getBatteryLevelCalled = false
    
    func getBatteryLevel() async throws -> Double {
        getBatteryLevelCalled = true
        return mockBatteryLevel
    }
    
    func getSystemInfo() async throws -> SystemInfo {
        return SystemInfo(
            batteryLevel: mockBatteryLevel,
            batteryIsCharging: false,
            availableStorage: 1000000000,
            memoryUsage: MemoryInfo(used: 8000000000, total: 16000000000),
            networkStatus: .connected,
            runningApps: []
        )
    }
}