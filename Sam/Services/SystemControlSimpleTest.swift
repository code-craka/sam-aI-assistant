import Foundation

/// Simple test runner for system control functionality
@MainActor
class SystemControlSimpleTest {
    
    private let systemService = SystemService()
    
    /// Run basic system control tests
    func runTests() async {
        print("🧪 System Control Simple Tests")
        print("==============================")
        
        await testVolumeControl()
        await testBrightnessControl()
        await testNetworkInfo()
        await testMaintenanceInfo()
        await testSystemControlOperations()
        
        print("\n✅ All simple tests completed!")
    }
    
    // MARK: - Volume Control Tests
    
    private func testVolumeControl() async {
        print("\n🔊 Testing Volume Control...")
        
        do {
            // Test getting current volume
            let currentVolume = try await systemService.getCurrentVolume()
            print("✅ Current volume retrieved: \(Int(currentVolume * 100))%")
            
            // Test setting volume
            let setResult = try await systemService.setVolume(0.5)
            print("✅ Set volume result: \(setResult.success ? "Success" : "Failed")")
            
            // Test volume up
            let upResult = try await systemService.volumeUp()
            print("✅ Volume up result: \(upResult.success ? "Success" : "Failed")")
            
            // Test volume down
            let downResult = try await systemService.volumeDown()
            print("✅ Volume down result: \(downResult.success ? "Success" : "Failed")")
            
        } catch {
            print("❌ Volume control test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Brightness Control Tests
    
    private func testBrightnessControl() async {
        print("\n💡 Testing Brightness Control...")
        
        do {
            // Test getting current brightness
            let currentBrightness = try await systemService.getCurrentBrightness()
            print("✅ Current brightness retrieved: \(Int(currentBrightness * 100))%")
            
            // Test setting brightness
            let setResult = try await systemService.setBrightness(0.6)
            print("✅ Set brightness result: \(setResult.success ? "Success" : "Failed")")
            
            // Test brightness up
            let upResult = try await systemService.brightnessUp()
            print("✅ Brightness up result: \(upResult.success ? "Success" : "Failed")")
            
            // Test brightness down
            let downResult = try await systemService.brightnessDown()
            print("✅ Brightness down result: \(downResult.success ? "Success" : "Failed")")
            
        } catch {
            print("❌ Brightness control test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Network Information Tests
    
    private func testNetworkInfo() async {
        print("\n🌐 Testing Network Information...")
        
        do {
            // Test getting network configuration
            let networkConfig = try await systemService.getNetworkConfiguration()
            print("✅ Network configuration retrieved")
            print("   Wi-Fi enabled: \(networkConfig.wifiEnabled)")
            print("   Bluetooth enabled: \(networkConfig.bluetoothEnabled)")
            print("   VPN connections: \(networkConfig.vpnConnections.count)")
            
        } catch {
            print("❌ Network info test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Maintenance Information Tests
    
    private func testMaintenanceInfo() async {
        print("\n🧹 Testing Maintenance Information...")
        
        do {
            // Test getting maintenance info
            let maintenanceInfo = try await systemService.getMaintenanceInfo()
            print("✅ Maintenance information retrieved")
            print("   Cache size: \(String(format: "%.1f", Double(maintenanceInfo.cacheSize) / 1_000_000)) MB")
            print("   Trash size: \(String(format: "%.1f", Double(maintenanceInfo.trashSize) / 1_000_000)) MB")
            print("   Total cleanable: \(String(format: "%.1f", maintenanceInfo.totalCleanableSizeGB)) GB")
            print("   Recommended actions: \(maintenanceInfo.recommendedActions.count)")
            
        } catch {
            print("❌ Maintenance info test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - System Control Operations Tests
    
    private func testSystemControlOperations() async {
        print("\n⚙️ Testing System Control Operations...")
        
        // Test operation enumeration
        print("✅ Available operations: \(SystemControlOperation.allCases.count)")
        
        // Test operations that require confirmation
        let dangerousOps = SystemControlOperation.allCases.filter { $0.requiresConfirmation }
        print("✅ Operations requiring confirmation: \(dangerousOps.count)")
        
        // Test display names
        for operation in SystemControlOperation.allCases {
            if operation.displayName.isEmpty {
                print("❌ Operation \(operation) has empty display name")
                return
            }
        }
        print("✅ All operations have display names")
        
        // Test executeSystemControl method with safe operations
        do {
            // Test volume up through executeSystemControl
            let result = try await systemService.executeSystemControl(.volumeUp)
            print("✅ Execute system control (volume up): \(result.success ? "Success" : "Failed")")
            
            // Test brightness up through executeSystemControl
            let brightnessResult = try await systemService.executeSystemControl(.brightnessUp)
            print("✅ Execute system control (brightness up): \(brightnessResult.success ? "Success" : "Failed")")
            
        } catch {
            print("❌ System control operations test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    private func testErrorHandling() async {
        print("\n🚨 Testing Error Handling...")
        
        do {
            // Test invalid parameter error
            _ = try await systemService.executeSystemControl(.volumeSet)
            print("❌ Should have thrown error for missing volume value")
        } catch SystemServiceError.invalidParameter(let message) {
            print("✅ Correctly caught invalid parameter error: \(message)")
        } catch {
            print("❌ Unexpected error type: \(error)")
        }
        
        do {
            // Test invalid parameter error for brightness
            _ = try await systemService.executeSystemControl(.brightnessSet)
            print("❌ Should have thrown error for missing brightness value")
        } catch SystemServiceError.invalidParameter(let message) {
            print("✅ Correctly caught invalid parameter error: \(message)")
        } catch {
            print("❌ Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Model Tests
    
    private func testModels() async {
        print("\n📊 Testing Data Models...")
        
        // Test SystemControlResult
        let result = SystemControlResult(
            operation: .volumeSet,
            success: true,
            message: "Test message",
            previousValue: 0.5,
            newValue: 0.7
        )
        
        if result.operation == .volumeSet &&
           result.success &&
           result.message == "Test message" &&
           result.previousValue == 0.5 &&
           result.newValue == 0.7 {
            print("✅ SystemControlResult model works correctly")
        } else {
            print("❌ SystemControlResult model has issues")
        }
        
        // Test MaintenanceInfo
        let maintenanceInfo = MaintenanceInfo(
            cacheSize: 100_000_000,
            trashSize: 50_000_000,
            logSize: 25_000_000,
            tempFilesSize: 75_000_000,
            downloadsSize: 200_000_000,
            lastCleanupDate: nil,
            recommendedActions: [.clearCache, .emptyTrash]
        )
        
        if maintenanceInfo.totalCleanableSize == 250_000_000 &&
           maintenanceInfo.totalCleanableSizeGB == 0.25 {
            print("✅ MaintenanceInfo model calculations work correctly")
        } else {
            print("❌ MaintenanceInfo model calculations are incorrect")
        }
        
        // Test MaintenanceAction display names
        for action in MaintenanceInfo.MaintenanceAction.allCases {
            if action.displayName.isEmpty || action.estimatedSpaceSaved.isEmpty {
                print("❌ MaintenanceAction \(action) has empty display properties")
                return
            }
        }
        print("✅ All MaintenanceAction cases have display properties")
    }
}

// MARK: - Test Runner

/// Run the simple system control tests
func runSystemControlSimpleTests() async {
    let tester = SystemControlSimpleTest()
    await tester.runTests()
}