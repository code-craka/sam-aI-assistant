import Foundation

/// Demo class showcasing system control functionality
@MainActor
class SystemControlDemo {
    
    private let systemService = SystemService()
    
    /// Run comprehensive system control demo
    func runDemo() async {
        print("🎛️ System Control Demo")
        print("====================")
        
        await demoVolumeControl()
        await demoBrightnessControl()
        await demoNetworkControl()
        await demoSystemMaintenance()
        await demoSystemPower()
        
        print("\n✅ System Control Demo completed!")
    }
    
    // MARK: - Volume Control Demo
    
    private func demoVolumeControl() async {
        print("\n🔊 Volume Control Demo")
        print("---------------------")
        
        do {
            // Get current volume
            print("Getting current volume...")
            let currentVolume = try await systemService.getCurrentVolume()
            print("Current volume: \(Int(currentVolume * 100))%")
            
            // Volume up
            print("\nIncreasing volume...")
            let volumeUpResult = try await systemService.volumeUp()
            print("Result: \(volumeUpResult.message)")
            if let newVolume = volumeUpResult.newValue {
                print("New volume: \(Int(newVolume * 100))%")
            }
            
            // Set specific volume
            print("\nSetting volume to 50%...")
            let setVolumeResult = try await systemService.setVolume(0.5)
            print("Result: \(setVolumeResult.message)")
            
            // Volume down
            print("\nDecreasing volume...")
            let volumeDownResult = try await systemService.volumeDown()
            print("Result: \(volumeDownResult.message)")
            
            // Toggle mute
            print("\nToggling mute...")
            let muteResult = try await systemService.toggleMute()
            print("Result: \(muteResult.message)")
            
        } catch {
            print("❌ Volume control error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Brightness Control Demo
    
    private func demoBrightnessControl() async {
        print("\n💡 Brightness Control Demo")
        print("-------------------------")
        
        do {
            // Get current brightness
            print("Getting current brightness...")
            let currentBrightness = try await systemService.getCurrentBrightness()
            print("Current brightness: \(Int(currentBrightness * 100))%")
            
            // Brightness up
            print("\nIncreasing brightness...")
            let brightnessUpResult = try await systemService.brightnessUp()
            print("Result: \(brightnessUpResult.message)")
            
            // Set specific brightness
            print("\nSetting brightness to 70%...")
            let setBrightnessResult = try await systemService.setBrightness(0.7)
            print("Result: \(setBrightnessResult.message)")
            
            // Brightness down
            print("\nDecreasing brightness...")
            let brightnessDownResult = try await systemService.brightnessDown()
            print("Result: \(brightnessDownResult.message)")
            
        } catch {
            print("❌ Brightness control error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Network Control Demo
    
    private func demoNetworkControl() async {
        print("\n🌐 Network Control Demo")
        print("----------------------")
        
        do {
            // Get network configuration
            print("Getting network configuration...")
            let networkConfig = try await systemService.getNetworkConfiguration()
            print("Wi-Fi enabled: \(networkConfig.wifiEnabled)")
            print("Bluetooth enabled: \(networkConfig.bluetoothEnabled)")
            print("VPN connections: \(networkConfig.vpnConnections.count)")
            
            // Note: Actual toggling is commented out to avoid disrupting connectivity during demo
            print("\nNetwork toggle operations available:")
            print("- Toggle Wi-Fi: systemService.toggleWiFi()")
            print("- Toggle Bluetooth: systemService.toggleBluetooth()")
            print("- Toggle Do Not Disturb: systemService.toggleDoNotDisturb()")
            print("- Toggle Night Shift: systemService.toggleNightShift()")
            
        } catch {
            print("❌ Network control error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - System Maintenance Demo
    
    private func demoSystemMaintenance() async {
        print("\n🧹 System Maintenance Demo")
        print("--------------------------")
        
        do {
            // Get maintenance info
            print("Analyzing system for maintenance opportunities...")
            let maintenanceInfo = try await systemService.getMaintenanceInfo()
            
            print("Cache size: \(String(format: "%.1f", Double(maintenanceInfo.cacheSize) / 1_000_000)) MB")
            print("Trash size: \(String(format: "%.1f", Double(maintenanceInfo.trashSize) / 1_000_000)) MB")
            print("Log size: \(String(format: "%.1f", Double(maintenanceInfo.logSize) / 1_000_000)) MB")
            print("Temp files size: \(String(format: "%.1f", Double(maintenanceInfo.tempFilesSize) / 1_000_000)) MB")
            print("Total cleanable: \(String(format: "%.1f", maintenanceInfo.totalCleanableSizeGB)) GB")
            
            if !maintenanceInfo.recommendedActions.isEmpty {
                print("\nRecommended actions:")
                for action in maintenanceInfo.recommendedActions {
                    print("- \(action.displayName) (saves ~\(action.estimatedSpaceSaved))")
                }
            }
            
            // Note: Actual cleanup operations are commented out to avoid modifying system during demo
            print("\nMaintenance operations available:")
            print("- Clear system cache: systemService.clearSystemCache()")
            print("- Empty trash: systemService.emptyTrash()")
            print("- Perform disk cleanup: systemService.performDiskCleanup()")
            
        } catch {
            print("❌ System maintenance error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - System Power Demo
    
    private func demoSystemPower() async {
        print("\n⚡ System Power Control Demo")
        print("---------------------------")
        
        do {
            // Display sleep
            print("Display sleep operation available:")
            print("- Sleep display: systemService.sleepDisplay()")
            
            // Note: System power operations are commented out to avoid disrupting the demo
            print("\nSystem power operations available:")
            print("- Sleep system: systemService.sleepSystem()")
            print("- Restart system: systemService.restartSystem() [REQUIRES CONFIRMATION]")
            print("- Shutdown system: systemService.shutdownSystem() [REQUIRES CONFIRMATION]")
            
            // Show which operations require confirmation
            print("\nOperations requiring user confirmation:")
            for operation in SystemControlOperation.allCases where operation.requiresConfirmation {
                print("- \(operation.displayName)")
            }
            
        } catch {
            print("❌ System power control error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Interactive Demo
    
    /// Run interactive demo with user input
    func runInteractiveDemo() async {
        print("🎛️ Interactive System Control Demo")
        print("==================================")
        
        while true {
            print("\nAvailable operations:")
            print("1. Volume Up")
            print("2. Volume Down")
            print("3. Set Volume")
            print("4. Brightness Up")
            print("5. Brightness Down")
            print("6. Set Brightness")
            print("7. Get Maintenance Info")
            print("8. Toggle Wi-Fi")
            print("9. Toggle Bluetooth")
            print("0. Exit")
            
            print("\nEnter your choice (0-9): ", terminator: "")
            
            guard let input = readLine(),
                  let choice = Int(input) else {
                print("Invalid input. Please enter a number.")
                continue
            }
            
            switch choice {
            case 0:
                print("Exiting interactive demo...")
                return
                
            case 1:
                await executeOperation { try await systemService.volumeUp() }
                
            case 2:
                await executeOperation { try await systemService.volumeDown() }
                
            case 3:
                print("Enter volume level (0-100): ", terminator: "")
                if let volumeInput = readLine(),
                   let volume = Double(volumeInput),
                   volume >= 0 && volume <= 100 {
                    await executeOperation { try await systemService.setVolume(volume / 100.0) }
                } else {
                    print("Invalid volume level. Please enter a number between 0 and 100.")
                }
                
            case 4:
                await executeOperation { try await systemService.brightnessUp() }
                
            case 5:
                await executeOperation { try await systemService.brightnessDown() }
                
            case 6:
                print("Enter brightness level (0-100): ", terminator: "")
                if let brightnessInput = readLine(),
                   let brightness = Double(brightnessInput),
                   brightness >= 0 && brightness <= 100 {
                    await executeOperation { try await systemService.setBrightness(brightness / 100.0) }
                } else {
                    print("Invalid brightness level. Please enter a number between 0 and 100.")
                }
                
            case 7:
                do {
                    let maintenanceInfo = try await systemService.getMaintenanceInfo()
                    print("Total cleanable space: \(String(format: "%.1f", maintenanceInfo.totalCleanableSizeGB)) GB")
                    if !maintenanceInfo.recommendedActions.isEmpty {
                        print("Recommended actions: \(maintenanceInfo.recommendedActions.map { $0.displayName }.joined(separator: ", "))")
                    }
                } catch {
                    print("❌ Error getting maintenance info: \(error.localizedDescription)")
                }
                
            case 8:
                print("⚠️  This will toggle your Wi-Fi connection. Continue? (y/n): ", terminator: "")
                if let confirm = readLine(), confirm.lowercased() == "y" {
                    await executeOperation { try await systemService.toggleWiFi() }
                } else {
                    print("Wi-Fi toggle cancelled.")
                }
                
            case 9:
                print("⚠️  This will toggle your Bluetooth connection. Continue? (y/n): ", terminator: "")
                if let confirm = readLine(), confirm.lowercased() == "y" {
                    await executeOperation { try await systemService.toggleBluetooth() }
                } else {
                    print("Bluetooth toggle cancelled.")
                }
                
            default:
                print("Invalid choice. Please enter a number between 0 and 9.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func executeOperation(_ operation: () async throws -> SystemControlResult) async {
        do {
            let result = try await operation()
            print("✅ \(result.message)")
            if let previousValue = result.previousValue,
               let newValue = result.newValue {
                print("   Changed from \(Int(previousValue * 100))% to \(Int(newValue * 100))%")
            }
        } catch {
            print("❌ Operation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Demo Runner

/// Run the system control demo
func runSystemControlDemo() async {
    let demo = SystemControlDemo()
    await demo.runDemo()
}

/// Run the interactive system control demo
func runInteractiveSystemControlDemo() async {
    let demo = SystemControlDemo()
    await demo.runInteractiveDemo()
}