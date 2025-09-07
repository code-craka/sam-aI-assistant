import Foundation

// MARK: - System Service Demo
/// Demonstrates the capabilities of the SystemService
class SystemServiceDemo {
    
    private let systemService = SystemService()
    
    // MARK: - Demo Methods
    
    /// Run all system information demos
    func runAllDemos() async {
        print("🖥️  System Service Demo")
        print("=" * 50)
        
        await demoSystemOverview()
        await demoBatteryInfo()
        await demoStorageInfo()
        await demoMemoryInfo()
        await demoNetworkInfo()
        await demoCPUInfo()
        await demoRunningApps()
        await demoPerformanceMetrics()
        await demoSpecificQueries()
        
        print("\n✅ Demo completed!")
    }
    
    /// Demo system overview
    private func demoSystemOverview() async {
        print("\n📊 System Overview Demo")
        print("-" * 30)
        
        do {
            let overview = try await systemService.querySystem(.overview)
            print(overview)
        } catch {
            print("❌ Error getting system overview: \(error)")
        }
    }
    
    /// Demo battery information
    private func demoBatteryInfo() async {
        print("\n🔋 Battery Information Demo")
        print("-" * 30)
        
        do {
            let batteryResult = try await systemService.querySystem(.battery)
            print(batteryResult)
            
            // Also demonstrate direct battery info access
            if let battery = try? await systemService.getBatteryInfo() {
                print("\n📋 Detailed Battery Info:")
                print("• Level: \(battery.levelPercentage)%")
                print("• Charging: \(battery.isCharging ? "Yes" : "No")")
                print("• Power Source: \(battery.powerSource.rawValue)")
                if let health = battery.health {
                    print("• Health: \(health.rawValue)")
                }
                if let cycles = battery.cycleCount {
                    print("• Cycle Count: \(cycles)")
                }
            }
        } catch {
            print("❌ Error getting battery info: \(error)")
        }
    }
    
    /// Demo storage information
    private func demoStorageInfo() async {
        print("\n💾 Storage Information Demo")
        print("-" * 30)
        
        do {
            let storageResult = try await systemService.querySystem(.storage)
            print(storageResult)
            
            // Demonstrate direct storage access
            let storage = try await systemService.getStorageInfo()
            print("\n📋 Storage Analysis:")
            print("• Total: \(String(format: "%.1f", storage.totalSpaceGB)) GB")
            print("• Used: \(String(format: "%.1f", storage.usedSpaceGB)) GB (\(String(format: "%.1f", storage.usagePercentage))%)")
            print("• Available: \(String(format: "%.1f", storage.availableSpaceGB)) GB")
            
            if storage.usagePercentage > 90 {
                print("⚠️  Warning: Storage is nearly full!")
            } else if storage.usagePercentage > 80 {
                print("⚠️  Caution: Storage is getting full")
            }
            
        } catch {
            print("❌ Error getting storage info: \(error)")
        }
    }
    
    /// Demo memory information
    private func demoMemoryInfo() async {
        print("\n🧠 Memory Information Demo")
        print("-" * 30)
        
        do {
            let memoryResult = try await systemService.querySystem(.memory)
            print(memoryResult)
            
            // Demonstrate memory pressure analysis
            let memory = try await systemService.getMemoryInfo()
            print("\n📋 Memory Analysis:")
            print("• Total: \(String(format: "%.1f", memory.totalMemoryGB)) GB")
            print("• Used: \(String(format: "%.1f", memory.usedMemoryGB)) GB (\(String(format: "%.1f", memory.usagePercentage))%)")
            print("• Pressure: \(memory.memoryPressure.rawValue)")
            
            switch memory.memoryPressure {
            case .normal:
                print("✅ Memory usage is normal")
            case .warning:
                print("⚠️  Memory usage is elevated")
            case .urgent:
                print("🚨 Memory pressure is high")
            case .critical:
                print("🔴 Critical memory pressure!")
            }
            
        } catch {
            print("❌ Error getting memory info: \(error)")
        }
    }
    
    /// Demo network information
    private func demoNetworkInfo() async {
        print("\n🌐 Network Information Demo")
        print("-" * 30)
        
        do {
            let networkResult = try await systemService.querySystem(.network)
            print(networkResult)
            
            // Demonstrate network analysis
            let network = try await systemService.getNetworkInfo()
            print("\n📋 Network Analysis:")
            print("• Connected: \(network.isConnected ? "Yes" : "No")")
            print("• Interfaces: \(network.interfaces.count)")
            
            if let primary = network.primaryInterface {
                print("• Primary: \(primary.displayName) (\(primary.type.rawValue))")
            }
            
            if let wifi = network.wifiInfo {
                print("• WiFi Quality: \(wifi.signalQuality.rawValue)")
                if let ssid = wifi.ssid {
                    print("• Network: \(ssid)")
                }
            }
            
        } catch {
            print("❌ Error getting network info: \(error)")
        }
    }
    
    /// Demo CPU information
    private func demoCPUInfo() async {
        print("\n⚡ CPU Information Demo")
        print("-" * 30)
        
        do {
            let cpuResult = try await systemService.querySystem(.cpu)
            print(cpuResult)
            
            // Demonstrate CPU analysis
            let cpu = try await systemService.getCPUInfo()
            print("\n📋 CPU Analysis:")
            print("• Usage: \(String(format: "%.1f", cpu.usage))%")
            print("• Architecture: \(cpu.architecture)")
            print("• Cores: \(cpu.coreCount) (\(cpu.threadCount) threads)")
            
            if cpu.usage > 80 {
                print("🚨 High CPU usage detected!")
            } else if cpu.usage > 60 {
                print("⚠️  Elevated CPU usage")
            } else {
                print("✅ CPU usage is normal")
            }
            
        } catch {
            print("❌ Error getting CPU info: \(error)")
        }
    }
    
    /// Demo running applications
    private func demoRunningApps() async {
        print("\n📱 Running Applications Demo")
        print("-" * 30)
        
        do {
            let appsResult = try await systemService.querySystem(.apps)
            print(appsResult)
            
            // Demonstrate app analysis
            let apps = try await systemService.getRunningApps()
            let activeApps = apps.filter { $0.isActive }
            let backgroundApps = apps.filter { !$0.isActive }
            
            print("\n📋 Application Analysis:")
            print("• Total Apps: \(apps.count)")
            print("• Active Apps: \(activeApps.count)")
            print("• Background Apps: \(backgroundApps.count)")
            
            if apps.count > 50 {
                print("⚠️  Many applications running - consider closing unused apps")
            }
            
        } catch {
            print("❌ Error getting running apps: \(error)")
        }
    }
    
    /// Demo performance metrics
    private func demoPerformanceMetrics() async {
        print("\n📊 Performance Metrics Demo")
        print("-" * 30)
        
        do {
            let performanceResult = try await systemService.querySystem(.performance)
            print(performanceResult)
            
            // Demonstrate performance analysis
            let systemInfo = try await systemService.getSystemInfo()
            print("\n📋 Performance Summary:")
            
            var performanceScore = 100.0
            var issues: [String] = []
            
            // CPU performance impact
            if systemInfo.cpu.usage > 80 {
                performanceScore -= 20
                issues.append("High CPU usage")
            } else if systemInfo.cpu.usage > 60 {
                performanceScore -= 10
                issues.append("Elevated CPU usage")
            }
            
            // Memory performance impact
            switch systemInfo.memory.memoryPressure {
            case .critical:
                performanceScore -= 30
                issues.append("Critical memory pressure")
            case .urgent:
                performanceScore -= 20
                issues.append("High memory pressure")
            case .warning:
                performanceScore -= 10
                issues.append("Elevated memory usage")
            case .normal:
                break
            }
            
            // Storage performance impact
            if systemInfo.storage.usagePercentage > 95 {
                performanceScore -= 15
                issues.append("Very low storage space")
            } else if systemInfo.storage.usagePercentage > 90 {
                performanceScore -= 10
                issues.append("Low storage space")
            }
            
            print("• Performance Score: \(String(format: "%.0f", performanceScore))/100")
            
            if issues.isEmpty {
                print("✅ System performance is optimal")
            } else {
                print("⚠️  Performance Issues: \(issues.joined(separator: ", "))")
            }
            
        } catch {
            print("❌ Error getting performance metrics: \(error)")
        }
    }
    
    /// Demo specific system queries
    private func demoSpecificQueries() async {
        print("\n🔍 Specific Query Demo")
        print("-" * 30)
        
        let queries = [
            ("Battery Status", SystemQueryType.battery),
            ("Storage Usage", SystemQueryType.storage),
            ("Memory Usage", SystemQueryType.memory),
            ("Network Status", SystemQueryType.network),
            ("CPU Usage", SystemQueryType.cpu)
        ]
        
        for (description, queryType) in queries {
            do {
                print("\n🔸 \(description):")
                let result = try await systemService.querySystem(queryType)
                // Print first line only for brevity
                if let firstLine = result.components(separatedBy: "\n").first {
                    print("  \(firstLine)")
                }
            } catch {
                print("  ❌ Error: \(error)")
            }
        }
    }
    
    /// Demo continuous monitoring
    func demoContinuousMonitoring(duration: TimeInterval = 30) async {
        print("\n📡 Continuous Monitoring Demo (\(Int(duration))s)")
        print("-" * 40)
        
        let startTime = Date()
        var iteration = 0
        
        while Date().timeIntervalSince(startTime) < duration {
            iteration += 1
            print("\n📊 Update #\(iteration) - \(Date().formatted(date: .omitted, time: .standard))")
            
            do {
                let systemInfo = try await systemService.getSystemInfo()
                
                print("CPU: \(String(format: "%.1f", systemInfo.cpu.usage))% | " +
                      "Memory: \(String(format: "%.1f", systemInfo.memory.usagePercentage))% | " +
                      "Storage: \(String(format: "%.1f", systemInfo.storage.usagePercentage))%")
                
                if let battery = systemInfo.battery {
                    let chargingStatus = battery.isCharging ? "⚡" : "🔋"
                    print("Battery: \(chargingStatus) \(battery.levelPercentage)%")
                }
                
            } catch {
                print("❌ Error: \(error)")
            }
            
            // Wait 5 seconds between updates
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        
        print("\n✅ Monitoring completed after \(iteration) updates")
    }
}

// MARK: - String Extension for Demo
private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Demo Runner
/// Run the system service demo
func runSystemServiceDemo() async {
    let demo = SystemServiceDemo()
    await demo.runAllDemos()
}

/// Run continuous monitoring demo
func runSystemMonitoringDemo() async {
    let demo = SystemServiceDemo()
    await demo.demoContinuousMonitoring(duration: 30)
}