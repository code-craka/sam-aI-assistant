import XCTest
import Combine
@testable import Sam

@MainActor
final class ContextManagerTests: XCTestCase {
    var contextManager: ContextManager!
    var mockFileSystemService: MockFileSystemService!
    var mockSystemService: MockSystemService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockFileSystemService = MockFileSystemService()
        mockSystemService = MockSystemService()
        contextManager = ContextManager(
            fileSystemService: mockFileSystemService,
            systemService: mockSystemService
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        contextManager = nil
        mockFileSystemService = nil
        mockSystemService = nil
        super.tearDown()
    }
    
    // MARK: - Context Building Tests
    
    func testBuildSystemContext() async throws {
        // Given
        mockSystemService.mockSystemInfo = SystemInfo(
            batteryLevel: 0.85,
            batteryIsCharging: true,
            availableStorage: 500_000_000_000,
            memoryUsage: MemoryInfo(used: 8_000_000_000, total: 16_000_000_000),
            networkStatus: .connected,
            runningApps: [
                AppInfo(name: "Safari", bundleId: "com.apple.Safari", isActive: true),
                AppInfo(name: "TextEdit", bundleId: "com.apple.TextEdit", isActive: false)
            ]
        )
        
        // When
        let context = await contextManager.buildSystemContext()
        
        // Then
        XCTAssertNotNil(context.batteryLevel)
        XCTAssertEqual(context.batteryLevel, 0.85)
        XCTAssertTrue(context.batteryIsCharging)
        XCTAssertEqual(context.availableStorage, 500_000_000_000)
        XCTAssertEqual(context.runningApps.count, 2)
        XCTAssertTrue(mockSystemService.getSystemInfoCalled)
    }
    
    func testBuildFileContext() async throws {
        // Given
        let testDirectory = URL(fileURLWithPath: "/Users/test/Documents")
        mockFileSystemService.mockFiles = [
            FileInfo(url: testDirectory.appendingPathComponent("document.pdf"), size: 1024, modifiedDate: Date()),
            FileInfo(url: testDirectory.appendingPathComponent("image.jpg"), size: 2048, modifiedDate: Date()),
            FileInfo(url: testDirectory.appendingPathComponent("text.txt"), size: 512, modifiedDate: Date())
        ]
        
        // When
        let context = await contextManager.buildFileContext(for: testDirectory)
        
        // Then
        XCTAssertEqual(context.directory, testDirectory)
        XCTAssertEqual(context.files.count, 3)
        XCTAssertTrue(context.files.contains { $0.url.lastPathComponent == "document.pdf" })
        XCTAssertTrue(mockFileSystemService.listFilesCalled)
    }
    
    func testBuildApplicationContext() async throws {
        // Given
        mockSystemService.mockRunningApps = [
            AppInfo(name: "Safari", bundleId: "com.apple.Safari", isActive: true),
            AppInfo(name: "Mail", bundleId: "com.apple.mail", isActive: false),
            AppInfo(name: "Calendar", bundleId: "com.apple.iCal", isActive: false)
        ]
        
        // When
        let context = await contextManager.buildApplicationContext()
        
        // Then
        XCTAssertEqual(context.runningApps.count, 3)
        XCTAssertEqual(context.activeApp?.name, "Safari")
        XCTAssertTrue(mockSystemService.getRunningAppsCalled)
    }
    
    // MARK: - Context Updates Tests
    
    func testContextUpdateNotifications() async throws {
        // Given
        var receivedUpdates: [ContextUpdate] = []
        contextManager.contextUpdates
            .sink { update in
                receivedUpdates.append(update)
            }
            .store(in: &cancellables)
        
        // When
        await contextManager.updateSystemContext()
        await contextManager.updateApplicationContext()
        
        // Then
        XCTAssertEqual(receivedUpdates.count, 2)
        XCTAssertTrue(receivedUpdates.contains { $0.type == .system })
        XCTAssertTrue(receivedUpdates.contains { $0.type == .application })
    }
    
    func testPeriodicContextUpdates() async throws {
        // Given
        contextManager.startPeriodicUpdates(interval: 0.1) // 100ms for testing
        
        var updateCount = 0
        contextManager.contextUpdates
            .sink { _ in
                updateCount += 1
            }
            .store(in: &cancellables)
        
        // When
        try await Task.sleep(nanoseconds: 250_000_000) // 250ms
        
        // Then
        XCTAssertGreaterThan(updateCount, 1)
        
        // Cleanup
        contextManager.stopPeriodicUpdates()
    }
    
    // MARK: - Context Querying Tests
    
    func testQueryCurrentContext() async throws {
        // Given
        await contextManager.updateSystemContext()
        await contextManager.updateApplicationContext()
        
        // When
        let currentContext = contextManager.getCurrentContext()
        
        // Then
        XCTAssertNotNil(currentContext.systemInfo)
        XCTAssertNotNil(currentContext.applicationInfo)
        XCTAssertNotNil(currentContext.timestamp)
    }
    
    func testContextRelevanceScoring() async throws {
        // Given
        let query = "copy file.pdf to Desktop"
        await contextManager.updateFileContext(for: URL(fileURLWithPath: "/Users/test/Documents"))
        
        // When
        let relevantContext = await contextManager.getRelevantContext(for: query)
        
        // Then
        XCTAssertNotNil(relevantContext.fileContext)
        XCTAssertGreaterThan(relevantContext.relevanceScore, 0.5)
    }
    
    // MARK: - Error Handling Tests
    
    func testContextBuildingWithErrors() async throws {
        // Given
        mockSystemService.shouldThrowError = true
        
        // When
        let context = await contextManager.buildSystemContext()
        
        // Then
        XCTAssertNil(context.batteryLevel) // Should handle error gracefully
        XCTAssertNotNil(contextManager.lastError)
    }
    
    // MARK: - Performance Tests
    
    func testContextBuildingPerformance() async throws {
        measure {
            Task {
                _ = await self.contextManager.buildSystemContext()
            }
        }
    }
    
    func testConcurrentContextUpdates() async throws {
        // Given
        let updateTasks = (1...10).map { _ in
            Task {
                await self.contextManager.updateSystemContext()
            }
        }
        
        // When
        let startTime = Date()
        for task in updateTasks {
            await task.value
        }
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(executionTime, 5.0, "Concurrent context updates took too long")
    }
}

// MARK: - Mock Classes

class MockFileSystemService: FileSystemServiceProtocol {
    var mockFiles: [FileInfo] = []
    var listFilesCalled = false
    
    func listFiles(in directory: URL) async throws -> [FileInfo] {
        listFilesCalled = true
        return mockFiles
    }
    
    func executeFileOperation(_ operation: FileOperation) async throws -> TaskResult {
        return TaskResult(success: true, output: "Mock operation", executionTime: 0.1, affectedFiles: [], undoAction: nil, followUpSuggestions: [])
    }
}

class MockSystemService: SystemServiceProtocol {
    var mockSystemInfo: SystemInfo?
    var mockRunningApps: [AppInfo] = []
    var shouldThrowError = false
    var getSystemInfoCalled = false
    var getRunningAppsCalled = false
    
    func getSystemInfo() async throws -> SystemInfo {
        getSystemInfoCalled = true
        if shouldThrowError {
            throw SystemAccessError.permissionDenied
        }
        return mockSystemInfo ?? SystemInfo(
            batteryLevel: nil,
            batteryIsCharging: false,
            availableStorage: 0,
            memoryUsage: MemoryInfo(used: 0, total: 0),
            networkStatus: .disconnected,
            runningApps: []
        )
    }
    
    func getRunningApps() async throws -> [AppInfo] {
        getRunningAppsCalled = true
        return mockRunningApps
    }
}