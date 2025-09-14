import XCTest
@testable import Sam

/// Tests for system control functionality
@MainActor
class SystemControlTests: XCTestCase {
    
    var systemService: SystemService!
    
    override func setUp() {
        super.setUp()
        systemService = SystemService()
    }
    
    override func tearDown() {
        systemService = nil
        super.tearDown()
    }
    
    // MARK: - Volume Control Tests
    
    func testVolumeUp() async throws {
        let result = try await systemService.volumeUp()
        
        XCTAssertEqual(result.operation, .volumeUp)
        XCTAssertNotNil(result.previousValue)
        XCTAssertNotNil(result.newValue)
        XCTAssertTrue(result.message.contains("Volume"))
    }
    
    func testVolumeDown() async throws {
        let result = try await systemService.volumeDown()
        
        XCTAssertEqual(result.operation, .volumeDown)
        XCTAssertNotNil(result.previousValue)
        XCTAssertNotNil(result.newValue)
        XCTAssertTrue(result.message.contains("Volume"))
    }
    
    func testSetVolume() async throws {
        let targetVolume = 0.5
        let result = try await systemService.setVolume(targetVolume)
        
        XCTAssertEqual(result.operation, .volumeSet)
        XCTAssertEqual(result.newValue, targetVolume)
        XCTAssertTrue(result.message.contains("50%"))
    }
    
    func testSetVolumeClampingLow() async throws {
        let result = try await systemService.setVolume(-0.5)
        
        XCTAssertEqual(result.newValue, 0.0)
    }
    
    func testSetVolumeClampingHigh() async throws {
        let result = try await systemService.setVolume(1.5)
        
        XCTAssertEqual(result.newValue, 1.0)
    }
    
    func testToggleMute() async throws {
        let result = try await systemService.toggleMute()
        
        XCTAssertEqual(result.operation, .volumeMute)
        XCTAssertTrue(result.message.contains("mute"))
    }
    
    // MARK: - Brightness Control Tests
    
    func testBrightnessUp() async throws {
        let result = try await systemService.brightnessUp()
        
        XCTAssertEqual(result.operation, .brightnessUp)
        XCTAssertNotNil(result.previousValue)
        XCTAssertNotNil(result.newValue)
        XCTAssertTrue(result.message.contains("Brightness"))
    }
    
    func testBrightnessDown() async throws {
        let result = try await systemService.brightnessDown()
        
        XCTAssertEqual(result.operation, .brightnessDown)
        XCTAssertNotNil(result.previousValue)
        XCTAssertNotNil(result.newValue)
        XCTAssertTrue(result.message.contains("Brightness"))
    }
    
    func testSetBrightness() async throws {
        let targetBrightness = 0.7
        let result = try await systemService.setBrightness(targetBrightness)
        
        XCTAssertEqual(result.operation, .brightnessSet)
        XCTAssertEqual(result.newValue, targetBrightness)
        XCTAssertTrue(result.message.contains("70%"))
    }
    
    func testSetBrightnessClampingLow() async throws {
        let result = try await systemService.setBrightness(-0.2)
        
        XCTAssertEqual(result.newValue, 0.0)
    }
    
    func testSetBrightnessClampingHigh() async throws {
        let result = try await systemService.setBrightness(1.2)
        
        XCTAssertEqual(result.newValue, 1.0)
    }
    
    // MARK: - Display Control Tests
    
    func testSleepDisplay() async throws {
        let result = try await systemService.sleepDisplay()
        
        XCTAssertEqual(result.operation, .displaySleep)
        XCTAssertTrue(result.message.contains("sleep"))
    }
    
    // MARK: - Network Control Tests
    
    func testToggleWiFi() async throws {
        let result = try await systemService.toggleWiFi()
        
        XCTAssertEqual(result.operation, .wifiToggle)
        XCTAssertTrue(result.message.contains("Wi-Fi"))
    }
    
    func testToggleBluetooth() async throws {
        let result = try await systemService.toggleBluetooth()
        
        XCTAssertEqual(result.operation, .bluetoothToggle)
        XCTAssertTrue(result.message.contains("Bluetooth"))
    }
    
    func testToggleDoNotDisturb() async throws {
        let result = try await systemService.toggleDoNotDisturb()
        
        XCTAssertEqual(result.operation, .doNotDisturbToggle)
        XCTAssertTrue(result.message.contains("Do Not Disturb"))
    }
    
    func testToggleNightShift() async throws {
        let result = try await systemService.toggleNightShift()
        
        XCTAssertEqual(result.operation, .nightShiftToggle)
        XCTAssertTrue(result.message.contains("Night Shift"))
    }
    
    // MARK: - System Maintenance Tests
    
    func testGetMaintenanceInfo() async throws {
        let maintenanceInfo = try await systemService.getMaintenanceInfo()
        
        XCTAssertGreaterThanOrEqual(maintenanceInfo.cacheSize, 0)
        XCTAssertGreaterThanOrEqual(maintenanceInfo.trashSize, 0)
        XCTAssertGreaterThanOrEqual(maintenanceInfo.logSize, 0)
        XCTAssertGreaterThanOrEqual(maintenanceInfo.tempFilesSize, 0)
        XCTAssertGreaterThanOrEqual(maintenanceInfo.totalCleanableSize, 0)
    }
    
    func testClearSystemCache() async throws {
        let result = try await systemService.clearSystemCache()
        
        XCTAssertEqual(result.operation, .cacheClear)
        XCTAssertTrue(result.message.contains("cache"))
    }
    
    func testEmptyTrash() async throws {
        let result = try await systemService.emptyTrash()
        
        XCTAssertEqual(result.operation, .emptyTrash)
        XCTAssertTrue(result.message.contains("Trash"))
    }
    
    func testPerformDiskCleanup() async throws {
        let result = try await systemService.performDiskCleanup()
        
        XCTAssertEqual(result.operation, .diskCleanup)
        XCTAssertTrue(result.message.contains("cleanup"))
    }
    
    // MARK: - System Power Control Tests
    
    func testSleepSystem() async throws {
        // Note: This test should be run carefully as it will actually put the system to sleep
        // In a real test environment, you might want to mock this
        let result = try await systemService.sleepSystem()
        
        XCTAssertEqual(result.operation, .systemSleep)
        XCTAssertTrue(result.message.contains("sleep"))
    }
    
    // MARK: - System Control Operation Execution Tests
    
    func testExecuteSystemControlVolumeUp() async throws {
        let result = try await systemService.executeSystemControl(.volumeUp)
        
        XCTAssertEqual(result.operation, .volumeUp)
    }
    
    func testExecuteSystemControlVolumeSet() async throws {
        let result = try await systemService.executeSystemControl(.volumeSet, value: 0.6)
        
        XCTAssertEqual(result.operation, .volumeSet)
        XCTAssertEqual(result.newValue, 0.6)
    }
    
    func testExecuteSystemControlVolumeSetWithoutValue() async throws {
        do {
            _ = try await systemService.executeSystemControl(.volumeSet)
            XCTFail("Should have thrown an error for missing value")
        } catch SystemServiceError.invalidParameter(let message) {
            XCTAssertTrue(message.contains("Volume level required"))
        }
    }
    
    func testExecuteSystemControlBrightnessSet() async throws {
        let result = try await systemService.executeSystemControl(.brightnessSet, value: 0.8)
        
        XCTAssertEqual(result.operation, .brightnessSet)
        XCTAssertEqual(result.newValue, 0.8)
    }
    
    func testExecuteSystemControlBrightnessSetWithoutValue() async throws {
        do {
            _ = try await systemService.executeSystemControl(.brightnessSet)
            XCTFail("Should have thrown an error for missing value")
        } catch SystemServiceError.invalidParameter(let message) {
            XCTAssertTrue(message.contains("Brightness level required"))
        }
    }
    
    // MARK: - Network Configuration Tests
    
    func testGetNetworkConfiguration() async throws {
        let config = try await systemService.getNetworkConfiguration()
        
        // Basic validation - in a real implementation these would have actual values
        XCTAssertNotNil(config.wifiEnabled)
        XCTAssertNotNil(config.bluetoothEnabled)
        XCTAssertNotNil(config.vpnConnections)
        XCTAssertNotNil(config.dnsServers)
    }
    
    // MARK: - Display Information Tests
    
    func testGetDisplayInfo() async throws {
        let displays = try await systemService.getDisplayInfo()
        
        // This is a placeholder implementation, so we just verify it doesn't crash
        XCTAssertNotNil(displays)
    }
    
    // MARK: - Error Handling Tests
    
    func testSystemServiceErrorDescriptions() {
        let errors: [SystemServiceError] = [
            .operationFailed("test operation"),
            .unsupportedOperation("test operation"),
            .invalidParameter("test parameter")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
        }
    }
    
    // MARK: - Model Tests
    
    func testSystemControlOperationDisplayNames() {
        for operation in SystemControlOperation.allCases {
            XCTAssertFalse(operation.displayName.isEmpty)
        }
    }
    
    func testSystemControlOperationConfirmationRequirements() {
        let dangerousOperations: [SystemControlOperation] = [
            .cacheClear, .diskCleanup, .emptyTrash, .restartSystem, .shutdownSystem
        ]
        
        for operation in dangerousOperations {
            XCTAssertTrue(operation.requiresConfirmation, "\(operation) should require confirmation")
        }
        
        let safeOperations: [SystemControlOperation] = [
            .volumeUp, .volumeDown, .brightnessUp, .brightnessDown
        ]
        
        for operation in safeOperations {
            XCTAssertFalse(operation.requiresConfirmation, "\(operation) should not require confirmation")
        }
    }
    
    func testMaintenanceActionDisplayNames() {
        for action in MaintenanceInfo.MaintenanceAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty)
            XCTAssertFalse(action.estimatedSpaceSaved.isEmpty)
        }
    }
    
    func testMaintenanceInfoCalculations() {
        let maintenanceInfo = MaintenanceInfo(
            cacheSize: 100_000_000, // 100MB
            trashSize: 50_000_000,  // 50MB
            logSize: 25_000_000,    // 25MB
            tempFilesSize: 75_000_000, // 75MB
            downloadsSize: 200_000_000, // 200MB
            lastCleanupDate: nil,
            recommendedActions: []
        )
        
        XCTAssertEqual(maintenanceInfo.totalCleanableSize, 250_000_000) // 250MB
        XCTAssertEqual(maintenanceInfo.totalCleanableSizeGB, 0.25) // 0.25GB
    }
    
    func testSystemControlResultInitialization() {
        let result = SystemControlResult(
            operation: .volumeSet,
            success: true,
            message: "Test message",
            previousValue: 0.5,
            newValue: 0.7
        )
        
        XCTAssertEqual(result.operation, .volumeSet)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Test message")
        XCTAssertEqual(result.previousValue, 0.5)
        XCTAssertEqual(result.newValue, 0.7)
        XCTAssertNotNil(result.timestamp)
    }
}

// MARK: - Performance Tests

extension SystemControlTests {
    
    func testVolumeControlPerformance() {
        measure {
            Task {
                _ = try? await systemService.getCurrentVolume()
            }
        }
    }
    
    func testBrightnessControlPerformance() {
        measure {
            Task {
                _ = try? await systemService.getCurrentBrightness()
            }
        }
    }
    
    func testMaintenanceInfoPerformance() {
        measure {
            Task {
                _ = try? await systemService.getMaintenanceInfo()
            }
        }
    }
}