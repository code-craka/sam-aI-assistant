import Foundation
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import SystemConfiguration
import CoreWLAN
import AppKit

// Simple test to verify SystemService functionality
@MainActor
class SystemServiceSimpleTest {
    
    static func runTests() async {
        print("🧪 Running SystemService Simple Tests")
        print("=" * 40)
        
        let systemService = SystemService()
        
        // Test 1: System Info
        await testSystemInfo(systemService)
        
        // Test 2: Storage Info
        await testStorageInfo(systemService)
        
        // Test 3: Memory Info
        await testMemoryInfo(systemService)
        
        // Test 4: Network Info
        await testNetworkInfo(systemService)
        
        // Test 5: CPU Info
        await testCPUInfo(systemService)
        
        // Test 6: Running Apps
        await testRunningApps(systemService)
        
        // Test 7: Battery Info (if available)
        await testBatteryInfo(systemService)
        
        // Test 8: Query System
        await testQuerySystem(systemService)
        
        print("\n✅ All SystemService tests completed!")
    }
    
    private static func testSystemInfo(_ service: SystemService) async {
        print("\n🔍 Testing System Info...")
        do {
            let systemInfo = try await service.getSystemInfo()
            print("✅ System Info: macOS \(systemInfo.systemVersion) (\(systemInfo.systemBuild))")
            print("   Uptime: \(systemInfo.formattedUptime)")
            print("   Running Apps: \(systemInfo.runningApps.count)")
        } catch {
            print("❌ System Info failed: \(error)")
        }
    }
    
    private static func testStorageInfo(_ service: SystemService) async {
        print("\n💾 Testing Storage Info...")
        do {
            let storage = try await service.getStorageInfo()
            print("✅ Storage: \(String(format: "%.1f", storage.usagePercentage))% used")
            print("   Total: \(String(format: "%.1f", storage.totalSpaceGB)) GB")
            print("   Available: \(String(format: "%.1f", storage.availableSpaceGB)) GB")
            print("   Volumes: \(storage.volumes.count)")
        } catch {
            print("❌ Storage Info failed: \(error)")
        }
    }
    
    private static func testMemoryInfo(_ service: SystemService) async {
        print("\n🧠 Testing Memory Info...")
        do {
            let memory = try await service.getMemoryInfo()
            print("✅ Memory: \(String(format: "%.1f", memory.usagePercentage))% used")
            print("   Total: \(String(format: "%.1f", memory.totalMemoryGB)) GB")
            print("   Pressure: \(memory.memoryPressure.rawValue)")
        } catch {
            print("❌ Memory Info failed: \(error)")
        }
    }
    
    private static func testNetworkInfo(_ service: SystemService) async {
        print("\n🌐 Testing Network Info...")
        do {
            let network = try await service.getNetworkInfo()
            print("✅ Network: \(network.isConnected ? "Connected" : "Disconnected")")
            print("   Interfaces: \(network.interfaces.count)")
            if let primary = network.primaryInterface {
                print("   Primary: \(primary.displayName) (\(primary.type.rawValue))")
            }
        } catch {
            print("❌ Network Info failed: \(error)")
        }
    }
    
    private static func testCPUInfo(_ service: SystemService) async {
        print("\n⚡ Testing CPU Info...")
        do {
            let cpu = try await service.getCPUInfo()
            print("✅ CPU: \(String(format: "%.1f", cpu.usage))% usage")
            print("   Cores: \(cpu.coreCount) (\(cpu.threadCount) threads)")
            print("   Architecture: \(cpu.architecture)")
        } catch {
            print("❌ CPU Info failed: \(error)")
        }
    }
    
    private static func testRunningApps(_ service: SystemService) async {
        print("\n📱 Testing Running Apps...")
        do {
            let apps = try await service.getRunningApps()
            print("✅ Running Apps: \(apps.count) total")
            let activeApps = apps.filter { $0.isActive }
            print("   Active: \(activeApps.count)")
            print("   Background: \(apps.count - activeApps.count)")
        } catch {
            print("❌ Running Apps failed: \(error)")
        }
    }
    
    private static func testBatteryInfo(_ service: SystemService) async {
        print("\n🔋 Testing Battery Info...")
        do {
            let battery = try await service.getBatteryInfo()
            print("✅ Battery: \(battery.levelPercentage)%")
            print("   Charging: \(battery.isCharging ? "Yes" : "No")")
            print("   Power Source: \(battery.powerSource.rawValue)")
        } catch SystemServiceError.batteryNotFound {
            print("ℹ️  Battery not available (expected on some Mac models)")
        } catch {
            print("❌ Battery Info failed: \(error)")
        }
    }
    
    private static func testQuerySystem(_ service: SystemService) async {
        print("\n🔍 Testing System Queries...")
        
        let queries: [(String, SystemQueryType)] = [
            ("Storage", .storage),
            ("Memory", .memory),
            ("Network", .network),
            ("CPU", .cpu),
            ("Overview", .overview)
        ]
        
        for (name, queryType) in queries {
            do {
                let result = try await service.querySystem(queryType)
                let firstLine = result.components(separatedBy: "\n").first ?? ""
                print("✅ \(name): \(firstLine)")
            } catch {
                print("❌ \(name) query failed: \(error)")
            }
        }
    }
}

// String extension for test output
private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// Run the tests if this file is executed directly
if CommandLine.arguments.contains("--run-system-tests") {
    Task {
        await SystemServiceSimpleTest.runTests()
        exit(0)
    }
    RunLoop.main.run()
}