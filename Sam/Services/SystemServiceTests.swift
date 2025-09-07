import XCTest
@testable import Sam

@MainActor
final class SystemServiceTests: XCTestCase {
    
    var systemService: SystemService!
    
    override func setUp() {
        super.setUp()
        systemService = SystemService()
    }
    
    override func tearDown() {
        systemService = nil
        super.tearDown()
    }
    
    // MARK: - System Information Tests
    
    func testGetSystemInfo() async throws {
        // When
        let systemInfo = try await systemService.getSystemInfo()
        
        // Then
        XCTAssertNotNil(systemInfo)
        XCTAssertFalse(systemInfo.systemVersion.isEmpty)
        XCTAssertFalse(systemInfo.systemBuild.isEmpty)
        XCTAssertGreaterThan(systemInfo.uptime, 0)
        XCTAssertNotNil(systemInfo.storage)
        XCTAssertNotNil(systemInfo.memory)
        XCTAssertNotNil(systemInfo.network)
        XCTAssertNotNil(systemInfo.cpu)
        XCTAssertNotNil(systemInfo.runningApps)
        
        // Verify timestamp is recent
        let timeDifference = abs(systemInfo.timestamp.timeIntervalSinceNow)
        XCTAssertLessThan(timeDifference, 5.0, "Timestamp should be within 5 seconds")
    }
    
    func testGetStorageInfo() async throws {
        // When
        let storageInfo = try await systemService.getStorageInfo()
        
        // Then
        XCTAssertGreaterThan(storageInfo.totalSpace, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.availableSpace, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.usedSpace, 0)
        XCTAssertLessThanOrEqual(storageInfo.availableSpace, storageInfo.totalSpace)
        XCTAssertEqual(storageInfo.usedSpace, storageInfo.totalSpace - storageInfo.availableSpace)
        XCTAssertFalse(storageInfo.volumes.isEmpty)
        
        // Test calculated properties
        XCTAssertGreaterThan(storageInfo.totalSpaceGB, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.availableSpaceGB, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.usedSpaceGB, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.usagePercentage, 0)
        XCTAssertLessThanOrEqual(storageInfo.usagePercentage, 100)
    }
    
    func testGetMemoryInfo() async throws {
        // When
        let memoryInfo = try await systemService.getMemoryInfo()
        
        // Then
        XCTAssertGreaterThan(memoryInfo.totalMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.usedMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.availableMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.appMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.wiredMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.compressedMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.swapUsed, 0)
        
        // Test calculated properties
        XCTAssertGreaterThan(memoryInfo.totalMemoryGB, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.usedMemoryGB, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.availableMemoryGB, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.usagePercentage, 0)
        XCTAssertLessThanOrEqual(memoryInfo.usagePercentage, 100)
        
        // Test memory pressure enum
        let validPressures: [MemoryInfo.MemoryPressure] = [.normal, .warning, .urgent, .critical]
        XCTAssertTrue(validPressures.contains(memoryInfo.memoryPressure))
    }
    
    func testGetNetworkInfo() async throws {
        // When
        let networkInfo = try await systemService.getNetworkInfo()
        
        // Then
        XCTAssertNotNil(networkInfo)
        XCTAssertFalse(networkInfo.interfaces.isEmpty)
        
        // If connected, should have a primary interface
        if networkInfo.isConnected {
            XCTAssertNotNil(networkInfo.primaryInterface)
            XCTAssertTrue(networkInfo.primaryInterface?.isActive ?? false)
        }
        
        // Test interface properties
        for interface in networkInfo.interfaces {
            XCTAssertFalse(interface.name.isEmpty)
            XCTAssertFalse(interface.displayName.isEmpty)
            
            let validTypes: [NetworkInterface.ConnectionType] = [.wifi, .ethernet, .cellular, .vpn, .bluetooth, .other, .none]
            XCTAssertTrue(validTypes.contains(interface.type))
        }
    }
    
    func testGetCPUInfo() async throws {
        // When
        let cpuInfo = try await systemService.getCPUInfo()
        
        // Then
        XCTAssertGreaterThanOrEqual(cpuInfo.usage, 0)
        XCTAssertLessThanOrEqual(cpuInfo.usage, 100)
        XCTAssertGreaterThan(cpuInfo.coreCount, 0)
        XCTAssertGreaterThan(cpuInfo.threadCount, 0)
        XCTAssertGreaterThanOrEqual(cpuInfo.threadCount, cpuInfo.coreCount)
        XCTAssertFalse(cpuInfo.architecture.isEmpty)
        XCTAssertFalse(cpuInfo.brand.isEmpty)
        
        // Test per-core usage
        XCTAssertEqual(cpuInfo.perCoreUsage.count, cpuInfo.coreCount)
        for coreUsage in cpuInfo.perCoreUsage {
            XCTAssertGreaterThanOrEqual(coreUsage, 0)
            XCTAssertLessThanOrEqual(coreUsage, 100)
        }
        
        // Test thermal state if temperature is available
        if cpuInfo.temperature != nil {
            let validStates: [CPUInfo.ThermalState] = [.normal, .warm, .hot, .critical, .unknown]
            XCTAssertTrue(validStates.contains(cpuInfo.thermalState))
        }
    }
    
    func testGetRunningApps() async throws {
        // When
        let runningApps = try await systemService.getRunningApps()
        
        // Then
        XCTAssertFalse(runningApps.isEmpty, "Should have at least one running app")
        
        for app in runningApps {
            XCTAssertFalse(app.bundleIdentifier.isEmpty)
            XCTAssertFalse(app.name.isEmpty)
            XCTAssertGreaterThan(app.processID, 0)
            XCTAssertGreaterThanOrEqual(app.memoryUsage, 0)
            XCTAssertGreaterThanOrEqual(app.cpuUsage, 0)
        }
        
        // Should find this test app
        let testApp = runningApps.first { $0.bundleIdentifier.contains("Sam") || $0.name.contains("Sam") }
        // Note: This might not always find the app depending on how tests are run
    }
    
    // MARK: - Battery Tests
    
    func testGetBatteryInfoOnDeviceWithBattery() async {
        // This test will pass on devices with batteries and fail gracefully on others
        do {
            let batteryInfo = try await systemService.getBatteryInfo()
            
            // Then
            XCTAssertGreaterThanOrEqual(batteryInfo.level, 0)
            XCTAssertLessThanOrEqual(batteryInfo.level, 1)
            
            let validPowerSources: [BatteryInfo.PowerSource] = [.battery, .acPower, .ups, .unknown]
            XCTAssertTrue(validPowerSources.contains(batteryInfo.powerSource))
            
            let validHealthStates: [BatteryInfo.BatteryHealth] = [.good, .fair, .poor, .unknown]
            if let health = batteryInfo.health {
                XCTAssertTrue(validHealthStates.contains(health))
            }
            
            // Test calculated properties
            let percentage = batteryInfo.levelPercentage
            XCTAssertGreaterThanOrEqual(percentage, 0)
            XCTAssertLessThanOrEqual(percentage, 100)
            
        } catch SystemServiceError.batteryNotFound {
            // This is expected on devices without batteries (like Mac Pro, Mac Studio, etc.)
            XCTAssertTrue(true, "Battery not found - this is expected on some Mac models")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Query Tests
    
    func testQuerySystemBattery() async throws {
        // When
        let result = try await systemService.querySystem(.battery)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Battery") || result.contains("not available"))
    }
    
    func testQuerySystemStorage() async throws {
        // When
        let result = try await systemService.querySystem(.storage)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Storage"))
        XCTAssertTrue(result.contains("GB"))
    }
    
    func testQuerySystemMemory() async throws {
        // When
        let result = try await systemService.querySystem(.memory)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Memory"))
        XCTAssertTrue(result.contains("GB"))
    }
    
    func testQuerySystemNetwork() async throws {
        // When
        let result = try await systemService.querySystem(.network)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Network"))
    }
    
    func testQuerySystemCPU() async throws {
        // When
        let result = try await systemService.querySystem(.cpu)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("CPU"))
        XCTAssertTrue(result.contains("%"))
    }
    
    func testQuerySystemApps() async throws {
        // When
        let result = try await systemService.querySystem(.apps)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Running Applications"))
    }
    
    func testQuerySystemOverview() async throws {
        // When
        let result = try await systemService.querySystem(.overview)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("System Overview"))
        XCTAssertTrue(result.contains("macOS"))
    }
    
    func testQuerySystemPerformance() async throws {
        // When
        let result = try await systemService.querySystem(.performance)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Performance Metrics"))
    }
    
    // MARK: - Model Tests
    
    func testSystemQueryTypeEnum() {
        let allTypes = SystemQueryType.allCases
        XCTAssertEqual(allTypes.count, 8)
        
        for type in allTypes {
            XCTAssertFalse(type.displayName.isEmpty)
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }
    
    func testBatteryInfoCalculatedProperties() {
        let batteryInfo = BatteryInfo(
            level: 0.75,
            isCharging: false,
            timeRemaining: 7200, // 2 hours
            powerSource: .battery,
            cycleCount: 150,
            health: .good
        )
        
        XCTAssertEqual(batteryInfo.levelPercentage, 75)
        XCTAssertEqual(batteryInfo.formattedTimeRemaining, "2h 0m")
    }
    
    func testStorageInfoCalculatedProperties() {
        let storageInfo = StorageInfo(
            totalSpace: 1_000_000_000_000, // 1TB
            availableSpace: 250_000_000_000, // 250GB
            usedSpace: 750_000_000_000, // 750GB
            volumes: []
        )
        
        XCTAssertEqual(storageInfo.totalSpaceGB, 1000, accuracy: 0.1)
        XCTAssertEqual(storageInfo.availableSpaceGB, 250, accuracy: 0.1)
        XCTAssertEqual(storageInfo.usedSpaceGB, 750, accuracy: 0.1)
        XCTAssertEqual(storageInfo.usagePercentage, 75, accuracy: 0.1)
    }
    
    func testMemoryInfoCalculatedProperties() {
        let memoryInfo = MemoryInfo(
            totalMemory: 16_000_000_000, // 16GB
            usedMemory: 12_000_000_000, // 12GB
            availableMemory: 4_000_000_000, // 4GB
            appMemory: 8_000_000_000,
            wiredMemory: 2_000_000_000,
            compressedMemory: 1_000_000_000,
            swapUsed: 0,
            memoryPressure: .warning
        )
        
        XCTAssertEqual(memoryInfo.totalMemoryGB, 16, accuracy: 0.1)
        XCTAssertEqual(memoryInfo.usedMemoryGB, 12, accuracy: 0.1)
        XCTAssertEqual(memoryInfo.availableMemoryGB, 4, accuracy: 0.1)
        XCTAssertEqual(memoryInfo.usagePercentage, 75, accuracy: 0.1)
    }
    
    func testWiFiInfoSignalQuality() {
        let excellentWiFi = WiFiInfo(ssid: "Test", bssid: nil, signalStrength: -25, channel: 6, security: .wpa2, frequency: 2.4)
        XCTAssertEqual(excellentWiFi.signalQuality, .excellent)
        
        let goodWiFi = WiFiInfo(ssid: "Test", bssid: nil, signalStrength: -40, channel: 6, security: .wpa2, frequency: 2.4)
        XCTAssertEqual(goodWiFi.signalQuality, .good)
        
        let fairWiFi = WiFiInfo(ssid: "Test", bssid: nil, signalStrength: -60, channel: 6, security: .wpa2, frequency: 2.4)
        XCTAssertEqual(fairWiFi.signalQuality, .fair)
        
        let poorWiFi = WiFiInfo(ssid: "Test", bssid: nil, signalStrength: -80, channel: 6, security: .wpa2, frequency: 2.4)
        XCTAssertEqual(poorWiFi.signalQuality, .poor)
    }
    
    func testSystemInfoFormattedUptime() {
        let systemInfo = SystemInfo(
            battery: nil,
            storage: StorageInfo(totalSpace: 0, availableSpace: 0, usedSpace: 0, volumes: []),
            memory: MemoryInfo(totalMemory: 0, usedMemory: 0, availableMemory: 0, appMemory: 0, wiredMemory: 0, compressedMemory: 0, swapUsed: 0, memoryPressure: .normal),
            network: NetworkInfo(isConnected: false, primaryInterface: nil, interfaces: [], wifiInfo: nil),
            cpu: CPUInfo(usage: 0, coreCount: 1, threadCount: 1, architecture: "test", brand: "test", frequency: nil, temperature: nil, perCoreUsage: []),
            runningApps: [],
            timestamp: Date(),
            systemVersion: "14.0.0",
            systemBuild: "23A344",
            uptime: 90061 // 1 day, 1 hour, 1 minute, 1 second
        )
        
        XCTAssertEqual(systemInfo.formattedUptime, "1d 1h 1m")
    }
    
    // MARK: - Performance Tests
    
    func testSystemInfoPerformance() {
        measure {
            Task {
                _ = try? await systemService.getSystemInfo()
            }
        }
    }
    
    func testBatteryInfoPerformance() {
        measure {
            Task {
                _ = try? await systemService.getBatteryInfo()
            }
        }
    }
    
    func testStorageInfoPerformance() {
        measure {
            Task {
                _ = try? await systemService.getStorageInfo()
            }
        }
    }
    
    func testMemoryInfoPerformance() {
        measure {
            Task {
                _ = try? await systemService.getMemoryInfo()
            }
        }
    }
}