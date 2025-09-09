import XCTest
@testable import Sam

final class SystemServiceTests: XCTestCase {
    var systemService: SystemService!
    var mockSystemInfoProvider: MockSystemInfoProvider!
    
    override func setUp() {
        super.setUp()
        mockSystemInfoProvider = MockSystemInfoProvider()
        systemService = SystemService(systemInfoProvider: mockSystemInfoProvider)
    }
    
    override func tearDown() {
        systemService = nil
        mockSystemInfoProvider = nil
        super.tearDown()
    }
    
    // MARK: - Battery Information Tests
    
    func testGetBatteryInfo() async throws {
        // Given
        mockSystemInfoProvider.mockBatteryLevel = 0.75
        mockSystemInfoProvider.mockIsCharging = true
        
        // When
        let batteryInfo = try await systemService.getBatteryInfo()
        
        // Then
        XCTAssertEqual(batteryInfo.level, 0.75)
        XCTAssertTrue(batteryInfo.isCharging)
        XCTAssertEqual(batteryInfo.percentage, 75)
    }
    
    func testGetBatteryInfoWhenUnavailable() async throws {
        // Given
        mockSystemInfoProvider.mockBatteryLevel = nil
        
        // When & Then
        do {
            _ = try await systemService.getBatteryInfo()
            XCTFail("Expected error when battery info unavailable")
        } catch SystemAccessError.batteryInfoUnavailable {
            // Expected
        }
    }
    
    // MARK: - Storage Information Tests
    
    func testGetStorageInfo() async throws {
        // Given
        mockSystemInfoProvider.mockAvailableStorage = 500_000_000_000 // 500GB
        mockSystemInfoProvider.mockTotalStorage = 1_000_000_000_000 // 1TB
        
        // When
        let storageInfo = try await systemService.getStorageInfo()
        
        // Then
        XCTAssertEqual(storageInfo.availableBytes, 500_000_000_000)
        XCTAssertEqual(storageInfo.totalBytes, 1_000_000_000_000)
        XCTAssertEqual(storageInfo.usedBytes, 500_000_000_000)
        XCTAssertEqual(storageInfo.usagePercentage, 50.0, accuracy: 0.1)
    }
    
    func testGetStorageInfoFormatted() async throws {
        // Given
        mockSystemInfoProvider.mockAvailableStorage = 500_000_000_000
        mockSystemInfoProvider.mockTotalStorage = 1_000_000_000_000
        
        // When
        let storageInfo = try await systemService.getStorageInfo()
        
        // Then
        XCTAssertEqual(storageInfo.availableFormatted, "500.0 GB")
        XCTAssertEqual(storageInfo.totalFormatted, "1.0 TB")
        XCTAssertEqual(storageInfo.usedFormatted, "500.0 GB")
    }
    
    // MARK: - Memory Information Tests
    
    func testGetMemoryInfo() async throws {
        // Given
        mockSystemInfoProvider.mockTotalMemory = 16_000_000_000 // 16GB
        mockSystemInfoProvider.mockUsedMemory = 8_000_000_000 // 8GB
        
        // When
        let memoryInfo = try await systemService.getMemoryInfo()
        
        // Then
        XCTAssertEqual(memoryInfo.totalBytes, 16_000_000_000)
        XCTAssertEqual(memoryInfo.usedBytes, 8_000_000_000)
        XCTAssertEqual(memoryInfo.availableBytes, 8_000_000_000)
        XCTAssertEqual(memoryInfo.usagePercentage, 50.0, accuracy: 0.1)
    }
    
    func testGetMemoryPressure() async throws {
        // Given
        mockSystemInfoProvider.mockMemoryPressure = .normal
        
        // When
        let memoryInfo = try await systemService.getMemoryInfo()
        
        // Then
        XCTAssertEqual(memoryInfo.pressure, .normal)
    }
    
    // MARK: - Network Information Tests
    
    func testGetNetworkStatus() async throws {
        // Given
        mockSystemInfoProvider.mockNetworkStatus = NetworkStatus(
            isConnected: true,
            connectionType: .wifi,
            ssid: "TestNetwork",
            ipAddress: "192.168.1.100"
        )
        
        // When
        let networkStatus = try await systemService.getNetworkStatus()
        
        // Then
        XCTAssertTrue(networkStatus.isConnected)
        XCTAssertEqual(networkStatus.connectionType, .wifi)
        XCTAssertEqual(networkStatus.ssid, "TestNetwork")
        XCTAssertEqual(networkStatus.ipAddress, "192.168.1.100")
    }
    
    func testGetNetworkStatusWhenDisconnected() async throws {
        // Given
        mockSystemInfoProvider.mockNetworkStatus = NetworkStatus(
            isConnected: false,
            connectionType: .none,
            ssid: nil,
            ipAddress: nil
        )
        
        // When
        let networkStatus = try await systemService.getNetworkStatus()
        
        // Then
        XCTAssertFalse(networkStatus.isConnected)
        XCTAssertEqual(networkStatus.connectionType, .none)
        XCTAssertNil(networkStatus.ssid)
        XCTAssertNil(networkStatus.ipAddress)
    }
    
    // MARK: - Running Applications Tests
    
    func testGetRunningApplications() async throws {
        // Given
        let mockApps = [
            AppInfo(bundleIdentifier: "com.apple.finder", name: "Finder", isActive: true),
            AppInfo(bundleIdentifier: "com.apple.safari", name: "Safari", isActive: false),
            AppInfo(bundleIdentifier: "com.microsoft.VSCode", name: "Visual Studio Code", isActive: true)
        ]
        mockSystemInfoProvider.mockRunningApps = mockApps
        
        // When
        let runningApps = try await systemService.getRunningApplications()
        
        // Then
        XCTAssertEqual(runningApps.count, 3)
        XCTAssertTrue(runningApps.contains { $0.name == "Finder" && $0.isActive })
        XCTAssertTrue(runningApps.contains { $0.name == "Safari" && !$0.isActive })
        XCTAssertTrue(runningApps.contains { $0.name == "Visual Studio Code" && $0.isActive })
    }
    
    func testGetActiveApplication() async throws {
        // Given
        let mockApps = [
            AppInfo(bundleIdentifier: "com.apple.finder", name: "Finder", isActive: false),
            AppInfo(bundleIdentifier: "com.apple.safari", name: "Safari", isActive: true)
        ]
        mockSystemInfoProvider.mockRunningApps = mockApps
        
        // When
        let activeApp = try await systemService.getActiveApplication()
        
        // Then
        XCTAssertEqual(activeApp?.name, "Safari")
        XCTAssertTrue(activeApp?.isActive ?? false)
    }
    
    // MARK: - System Control Tests
    
    func testSetVolume() async throws {
        // Given
        let targetVolume: Float = 0.5
        
        // When
        try await systemService.setVolume(targetVolume)
        
        // Then
        XCTAssertTrue(mockSystemInfoProvider.setVolumeCalled)
        XCTAssertEqual(mockSystemInfoProvider.lastVolumeSet, targetVolume)
    }
    
    func testSetVolumeWithInvalidValue() async throws {
        // Given
        let invalidVolume: Float = 1.5
        
        // When & Then
        do {
            try await systemService.setVolume(invalidVolume)
            XCTFail("Expected error for invalid volume")
        } catch SystemAccessError.invalidParameter {
            // Expected
        }
    }
    
    func testSetBrightness() async throws {
        // Given
        let targetBrightness: Float = 0.8
        
        // When
        try await systemService.setBrightness(targetBrightness)
        
        // Then
        XCTAssertTrue(mockSystemInfoProvider.setBrightnessCalled)
        XCTAssertEqual(mockSystemInfoProvider.lastBrightnessSet, targetBrightness)
    }
    
    // MARK: - System Maintenance Tests
    
    func testClearSystemCaches() async throws {
        // When
        let result = try await systemService.clearSystemCaches()
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockSystemInfoProvider.clearCachesCalled)
        XCTAssertTrue(result.summary.contains("cache"))
    }
    
    func testEmptyTrash() async throws {
        // When
        let result = try await systemService.emptyTrash()
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockSystemInfoProvider.emptyTrashCalled)
        XCTAssertTrue(result.summary.contains("trash"))
    }
    
    // MARK: - System Information Aggregation Tests
    
    func testGetSystemOverview() async throws {
        // Given
        mockSystemInfoProvider.mockBatteryLevel = 0.85
        mockSystemInfoProvider.mockIsCharging = false
        mockSystemInfoProvider.mockAvailableStorage = 250_000_000_000
        mockSystemInfoProvider.mockTotalStorage = 500_000_000_000
        mockSystemInfoProvider.mockTotalMemory = 16_000_000_000
        mockSystemInfoProvider.mockUsedMemory = 12_000_000_000
        
        // When
        let overview = try await systemService.getSystemOverview()
        
        // Then
        XCTAssertEqual(overview.batteryPercentage, 85)
        XCTAssertFalse(overview.isCharging)
        XCTAssertEqual(overview.storageUsagePercentage, 50.0, accuracy: 0.1)
        XCTAssertEqual(overview.memoryUsagePercentage, 75.0, accuracy: 0.1)
        XCTAssertNotNil(overview.networkStatus)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleSystemAccessDenied() async throws {
        // Given
        mockSystemInfoProvider.shouldThrowAccessDenied = true
        
        // When & Then
        do {
            _ = try await systemService.getBatteryInfo()
            XCTFail("Expected access denied error")
        } catch SystemAccessError.accessDenied {
            // Expected
        }
    }
    
    func testHandleSystemInfoUnavailable() async throws {
        // Given
        mockSystemInfoProvider.shouldThrowInfoUnavailable = true
        
        // When & Then
        do {
            _ = try await systemService.getMemoryInfo()
            XCTFail("Expected info unavailable error")
        } catch SystemAccessError.informationUnavailable {
            // Expected
        }
    }
    
    // MARK: - Performance Tests
    
    func testSystemInfoPerformance() {
        measure {
            Task {
                _ = try? await systemService.getSystemOverview()
            }
        }
    }
    
    func testConcurrentSystemQueries() async throws {
        // When
        let startTime = Date()
        
        async let batteryInfo = systemService.getBatteryInfo()
        async let storageInfo = systemService.getStorageInfo()
        async let memoryInfo = systemService.getMemoryInfo()
        async let networkStatus = systemService.getNetworkStatus()
        
        let results = try await [
            batteryInfo,
            storageInfo,
            memoryInfo,
            networkStatus
        ]
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, 4)
        XCTAssertLessThan(executionTime, 2.0, "Concurrent queries took too long")
    }
}

// MARK: - Mock Classes

class MockSystemInfoProvider: SystemInfoProviderProtocol {
    var mockBatteryLevel: Double?
    var mockIsCharging = false
    var mockAvailableStorage: Int64 = 0
    var mockTotalStorage: Int64 = 0
    var mockTotalMemory: Int64 = 0
    var mockUsedMemory: Int64 = 0
    var mockMemoryPressure: MemoryPressure = .normal
    var mockNetworkStatus: NetworkStatus?
    var mockRunningApps: [AppInfo] = []
    
    var shouldThrowAccessDenied = false
    var shouldThrowInfoUnavailable = false
    
    var setVolumeCalled = false
    var setBrightnessCalled = false
    var clearCachesCalled = false
    var emptyTrashCalled = false
    
    var lastVolumeSet: Float?
    var lastBrightnessSet: Float?
    
    func getBatteryLevel() throws -> Double? {
        if shouldThrowAccessDenied {
            throw SystemAccessError.accessDenied("Battery access denied")
        }
        return mockBatteryLevel
    }
    
    func isBatteryCharging() throws -> Bool {
        if shouldThrowAccessDenied {
            throw SystemAccessError.accessDenied("Battery access denied")
        }
        return mockIsCharging
    }
    
    func getStorageInfo() throws -> (available: Int64, total: Int64) {
        if shouldThrowInfoUnavailable {
            throw SystemAccessError.informationUnavailable("Storage info unavailable")
        }
        return (available: mockAvailableStorage, total: mockTotalStorage)
    }
    
    func getMemoryInfo() throws -> (total: Int64, used: Int64, pressure: MemoryPressure) {
        if shouldThrowInfoUnavailable {
            throw SystemAccessError.informationUnavailable("Memory info unavailable")
        }
        return (total: mockTotalMemory, used: mockUsedMemory, pressure: mockMemoryPressure)
    }
    
    func getNetworkStatus() throws -> NetworkStatus {
        if shouldThrowInfoUnavailable {
            throw SystemAccessError.informationUnavailable("Network info unavailable")
        }
        return mockNetworkStatus ?? NetworkStatus(isConnected: false, connectionType: .none, ssid: nil, ipAddress: nil)
    }
    
    func getRunningApplications() throws -> [AppInfo] {
        if shouldThrowAccessDenied {
            throw SystemAccessError.accessDenied("App list access denied")
        }
        return mockRunningApps
    }
    
    func setVolume(_ volume: Float) throws {
        if volume < 0 || volume > 1 {
            throw SystemAccessError.invalidParameter("Volume must be between 0 and 1")
        }
        setVolumeCalled = true
        lastVolumeSet = volume
    }
    
    func setBrightness(_ brightness: Float) throws {
        if brightness < 0 || brightness > 1 {
            throw SystemAccessError.invalidParameter("Brightness must be between 0 and 1")
        }
        setBrightnessCalled = true
        lastBrightnessSet = brightness
    }
    
    func clearSystemCaches() throws {
        clearCachesCalled = true
    }
    
    func emptyTrash() throws {
        emptyTrashCalled = true
    }
}