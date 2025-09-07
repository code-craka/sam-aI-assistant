import Foundation
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import SystemConfiguration
import CoreWLAN
import AppKit
import CoreAudio
import AudioToolbox

// MARK: - System Information Service
@MainActor
class SystemService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isGathering = false
    @Published var lastUpdate: Date?
    @Published var cachedSystemInfo: SystemInfo?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 5.0 // Update every 5 seconds
    private var updateTimer: Timer?
    private let workspace = NSWorkspace.shared
    
    // MARK: - Initialization
    init() {
        startPeriodicUpdates()
    }
    
    deinit {
        stopPeriodicUpdates()
    }
    
    // MARK: - Public Methods
    
    /// Get comprehensive system information
    func getSystemInfo() async throws -> SystemInfo {
        await MainActor.run { isGathering = true }
        defer { Task { @MainActor in isGathering = false } }
        
        async let batteryInfo = getBatteryInfo()
        async let storageInfo = getStorageInfo()
        async let memoryInfo = getMemoryInfo()
        async let networkInfo = getNetworkInfo()
        async let cpuInfo = getCPUInfo()
        async let runningApps = getRunningApps()
        
        let systemInfo = SystemInfo(
            battery: try? await batteryInfo,
            storage: try await storageInfo,
            memory: try await memoryInfo,
            network: try await networkInfo,
            cpu: try await cpuInfo,
            runningApps: try await runningApps,
            timestamp: Date(),
            systemVersion: getSystemVersion(),
            systemBuild: getSystemBuild(),
            uptime: getSystemUptime()
        )
        
        await MainActor.run {
            cachedSystemInfo = systemInfo
            lastUpdate = Date()
        }
        
        return systemInfo
    }
    
    /// Get battery information
    func getBatteryInfo() async throws -> BatteryInfo {       
 return try await withCheckedThrowingContinuation { continuation in
            let powerSources = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
            guard let powerSourcesList = IOPSCopyPowerSourcesList(powerSources)?.takeRetainedValue() as? [CFTypeRef] else {
                continuation.resume(throwing: SystemServiceError.batteryNotFound)
                return
            }
            
            for powerSource in powerSourcesList {
                guard let psInfo = IOPSGetPowerSourceDescription(powerSources, powerSource)?.takeUnretainedValue() as? [String: Any] else {
                    continue
                }
                
                // Check if this is a battery
                guard let type = psInfo[kIOPSTypeKey] as? String,
                      type == kIOPSInternalBatteryType else {
                    continue
                }
                
                let currentCapacity = psInfo[kIOPSCurrentCapacityKey] as? Int ?? 0
                let maxCapacity = psInfo[kIOPSMaxCapacityKey] as? Int ?? 100
                let isCharging = psInfo[kIOPSIsChargingKey] as? Bool ?? false
                let timeRemaining = psInfo[kIOPSTimeToEmptyKey] as? Int
                let cycleCount = psInfo["CycleCount"] as? Int
                
                let level = maxCapacity > 0 ? Double(currentCapacity) / Double(maxCapacity) : 0.0
                
                // Determine power source
                let powerSourceType: BatteryInfo.PowerSource
                if let powerSourceState = psInfo[kIOPSPowerSourceStateKey] as? String {
                    switch powerSourceState {
                    case kIOPSACPowerValue:
                        powerSourceType = .acPower
                    case kIOPSBatteryPowerValue:
                        powerSourceType = .battery
                    default:
                        powerSourceType = .unknown
                    }
                } else {
                    powerSourceType = .unknown
                }
                
                // Determine battery health
                let health: BatteryInfo.BatteryHealth
                if let healthInfo = psInfo["BatteryHealth"] as? String {
                    switch healthInfo.lowercased() {
                    case "good": health = .good
                    case "fair": health = .fair
                    case "poor": health = .poor
                    default: health = .unknown
                    }
                } else {
                    health = .unknown
                }
                
                let batteryInfo = BatteryInfo(
                    level: level,
                    isCharging: isCharging,
                    timeRemaining: timeRemaining != nil ? TimeInterval(timeRemaining!) * 60 : nil,
                    powerSource: powerSourceType,
                    cycleCount: cycleCount,
                    health: health
                )
                
                continuation.resume(returning: batteryInfo)
                return
            }
            
            continuation.resume(throwing: SystemServiceError.batteryNotFound)
        }
    }
    
    /// Get storage information
    func getStorageInfo() async throws -> StorageInfo {      
  return try await withCheckedThrowingContinuation { continuation in
            do {
                let fileManager = FileManager.default
                var volumes: [VolumeInfo] = []
                var totalSpace: Int64 = 0
                var availableSpace: Int64 = 0
                
                // Get mounted volumes
                let volumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsRemovableKey,
                    .volumeIsInternalKey,
                    .volumeLocalizedFormatDescriptionKey
                ], options: [.skipHiddenVolumes])
                
                for volumeURL in volumeURLs ?? [] {
                    let resourceValues = try volumeURL.resourceValues(forKeys: [
                        .volumeNameKey,
                        .volumeTotalCapacityKey,
                        .volumeAvailableCapacityKey,
                        .volumeIsRemovableKey,
                        .volumeIsInternalKey,
                        .volumeLocalizedFormatDescriptionKey
                    ])
                    
                    let volumeName = resourceValues.volumeName ?? "Unknown"
                    let volumeTotalSpace = Int64(resourceValues.volumeTotalCapacity ?? 0)
                    let volumeAvailableSpace = Int64(resourceValues.volumeAvailableCapacity ?? 0)
                    let isRemovable = resourceValues.volumeIsRemovable ?? false
                    let isInternal = resourceValues.volumeIsInternal ?? true
                    let fileSystem = resourceValues.volumeLocalizedFormatDescription ?? "Unknown"
                    
                    let volumeInfo = VolumeInfo(
                        name: volumeName,
                        path: volumeURL.path,
                        totalSpace: volumeTotalSpace,
                        availableSpace: volumeAvailableSpace,
                        fileSystem: fileSystem,
                        isRemovable: isRemovable,
                        isInternal: isInternal
                    )
                    
                    volumes.append(volumeInfo)
                    
                    // Add to totals (only internal volumes for main storage)
                    if isInternal {
                        totalSpace += volumeTotalSpace
                        availableSpace += volumeAvailableSpace
                    }
                }
                
                let usedSpace = totalSpace - availableSpace
                
                let storageInfo = StorageInfo(
                    totalSpace: totalSpace,
                    availableSpace: availableSpace,
                    usedSpace: usedSpace,
                    volumes: volumes
                )
                
                continuation.resume(returning: storageInfo)
            } catch {
                continuation.resume(throwing: SystemServiceError.systemCallFailed("storage query: \(error.localizedDescription)"))
            }
        }
    }
    
    /// Get memory information
    func getMemoryInfo() async throws -> MemoryInfo {       
 return try await withCheckedThrowingContinuation { continuation in
            var vmStats = vm_statistics64()
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            
            let result = withUnsafeMutablePointer(to: &vmStats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                }
            }
            
            guard result == KERN_SUCCESS else {
                continuation.resume(throwing: SystemServiceError.systemCallFailed("vm_statistics64"))
                return
            }
            
            let pageSize = Int64(vm_kernel_page_size)
            let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
            
            let freeMemory = Int64(vmStats.free_count) * pageSize
            let activeMemory = Int64(vmStats.active_count) * pageSize
            let inactiveMemory = Int64(vmStats.inactive_count) * pageSize
            let wiredMemory = Int64(vmStats.wire_count) * pageSize
            let compressedMemory = Int64(vmStats.compressor_page_count) * pageSize
            
            let usedMemory = totalMemory - freeMemory
            let availableMemory = freeMemory + inactiveMemory
            let appMemory = activeMemory + inactiveMemory
            
            // Get swap usage
            var swapUsage: Int64 = 0
            var swapStats = xsw_usage()
            var swapSize = MemoryLayout<xsw_usage>.size
            if sysctlbyname("vm.swapusage", &swapStats, &swapSize, nil, 0) == 0 {
                swapUsage = Int64(swapStats.xsu_used)
            }
            
            // Determine memory pressure
            let memoryPressure: MemoryInfo.MemoryPressure
            let usagePercentage = Double(usedMemory) / Double(totalMemory)
            switch usagePercentage {
            case 0..<0.6:
                memoryPressure = .normal
            case 0.6..<0.8:
                memoryPressure = .warning
            case 0.8..<0.95:
                memoryPressure = .urgent
            default:
                memoryPressure = .critical
            }
            
            let memoryInfo = MemoryInfo(
                totalMemory: totalMemory,
                usedMemory: usedMemory,
                availableMemory: availableMemory,
                appMemory: appMemory,
                wiredMemory: wiredMemory,
                compressedMemory: compressedMemory,
                swapUsed: swapUsage,
                memoryPressure: memoryPressure
            )
            
            continuation.resume(returning: memoryInfo)
        }
    }
    
    /// Get network information
    func getNetworkInfo() async throws -> NetworkInfo { 
       return try await withCheckedThrowingContinuation { continuation in
            var interfaces: [NetworkInterface] = []
            var primaryInterface: NetworkInterface?
            var wifiInfo: WiFiInfo?
            
            // Check network reachability
            var zeroAddress = sockaddr_in()
            zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            zeroAddress.sin_family = sa_family_t(AF_INET)
            
            guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    SCNetworkReachabilityCreateWithAddress(nil, $0)
                }
            }) else {
                continuation.resume(throwing: SystemServiceError.networkUnavailable)
                return
            }
            
            var flags: SCNetworkReachabilityFlags = []
            let isConnected = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) &&
                             flags.contains(.reachable) && !flags.contains(.connectionRequired)
            
            // Get network interfaces
            var ifaddrs: UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&ifaddrs) == 0 else {
                continuation.resume(throwing: SystemServiceError.systemCallFailed("getifaddrs"))
                return
            }
            
            defer { freeifaddrs(ifaddrs) }
            
            var current = ifaddrs
            while current != nil {
                defer { current = current?.pointee.ifa_next }
                
                guard let addr = current?.pointee.ifa_addr,
                      let name = current?.pointee.ifa_name else { continue }
                
                let interfaceName = String(cString: name)
                
                // Skip loopback and other non-physical interfaces
                guard !interfaceName.hasPrefix("lo") && 
                      !interfaceName.hasPrefix("utun") &&
                      !interfaceName.hasPrefix("awdl") else { continue }
                
                let isActive = (current?.pointee.ifa_flags & UInt32(IFF_UP)) != 0 &&
                              (current?.pointee.ifa_flags & UInt32(IFF_RUNNING)) != 0
                
                var ipAddress: String?
                if addr.pointee.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        ipAddress = String(cString: hostname)
                    }
                }
                
                // Determine interface type and display name
                let (type, displayName) = getInterfaceTypeAndName(interfaceName)
                
                let interface = NetworkInterface(
                    name: interfaceName,
                    displayName: displayName,
                    type: type,
                    isActive: isActive,
                    ipAddress: ipAddress,
                    macAddress: nil, // Could be implemented with additional system calls
                    speed: nil // Could be implemented with additional system calls
                )
                
                interfaces.append(interface)
                
                // Set primary interface (first active interface)
                if primaryInterface == nil && isActive && ipAddress != nil {
                    primaryInterface = interface
                }
            }
            
            // Get WiFi information if available
            if let wifiInterface = interfaces.first(where: { $0.type == .wifi && $0.isActive }) {
                wifiInfo = try? await getWiFiInfo()
            }
            
            let networkInfo = NetworkInfo(
                isConnected: isConnected,
                primaryInterface: primaryInterface,
                interfaces: interfaces,
                wifiInfo: wifiInfo
            )
            
            continuation.resume(returning: networkInfo)
        }
    }
    
    /// Get CPU information
    func getCPUInfo() async throws -> CPUInfo {    
    return try await withCheckedThrowingContinuation { continuation in
            // Get CPU usage
            var cpuInfo: processor_info_array_t!
            var numCpuInfo: mach_msg_type_number_t = 0
            var numCpus: natural_t = 0
            
            let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
            
            guard result == KERN_SUCCESS else {
                continuation.resume(throwing: SystemServiceError.systemCallFailed("host_processor_info"))
                return
            }
            
            defer {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo * MemoryLayout<integer_t>.size))
            }
            
            var totalUsage: Double = 0
            var perCoreUsage: [Double] = []
            
            for i in 0..<Int(numCpus) {
                let cpuLoadInfo = cpuInfo.advanced(by: i * Int(CPU_STATE_MAX)).withMemoryRebound(to: UInt32.self, capacity: Int(CPU_STATE_MAX)) { $0 }
                
                let user = Double(cpuLoadInfo[Int(CPU_STATE_USER)])
                let system = Double(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
                let nice = Double(cpuLoadInfo[Int(CPU_STATE_NICE)])
                let idle = Double(cpuLoadInfo[Int(CPU_STATE_IDLE)])
                
                let total = user + system + nice + idle
                let usage = total > 0 ? ((user + system + nice) / total) * 100 : 0
                
                perCoreUsage.append(usage)
                totalUsage += usage
            }
            
            totalUsage /= Double(numCpus)
            
            // Get system information
            var size = MemoryLayout<Int>.size
            var coreCount: Int = 0
            sysctlbyname("hw.ncpu", &coreCount, &size, nil, 0)
            
            var threadCount: Int = 0
            sysctlbyname("hw.logicalcpu", &threadCount, &size, nil, 0)
            
            // Get CPU brand
            var brandSize = 0
            sysctlbyname("machdep.cpu.brand_string", nil, &brandSize, nil, 0)
            var brand = [CChar](repeating: 0, count: brandSize)
            sysctlbyname("machdep.cpu.brand_string", &brand, &brandSize, nil, 0)
            let brandString = String(cString: brand)
            
            // Get architecture
            let architecture = getArchitecture()
            
            // Get frequency (if available)
            var frequency: Double?
            var freq: UInt64 = 0
            size = MemoryLayout<UInt64>.size
            if sysctlbyname("hw.cpufrequency_max", &freq, &size, nil, 0) == 0 {
                frequency = Double(freq) / 1_000_000_000 // Convert to GHz
            }
            
            let cpuInfo = CPUInfo(
                usage: totalUsage,
                coreCount: coreCount,
                threadCount: threadCount,
                architecture: architecture,
                brand: brandString,
                frequency: frequency,
                temperature: nil, // Temperature monitoring requires additional frameworks
                perCoreUsage: perCoreUsage
            )
            
            continuation.resume(returning: cpuInfo)
        }
    }
    
    /// Get running applications
    func getRunningApps() async throws -> [AppInfo] {      
  return try await withCheckedThrowingContinuation { continuation in
            let runningApps = workspace.runningApplications
            var appInfos: [AppInfo] = []
            
            for app in runningApps {
                guard let bundleId = app.bundleIdentifier,
                      !bundleId.isEmpty else { continue }
                
                let name = app.localizedName ?? bundleId
                let processID = app.processIdentifier
                let isActive = app.isActive
                let launchDate = app.launchDate
                
                // Get app icon
                var iconData: Data?
                if let icon = app.icon {
                    iconData = icon.tiffRepresentation
                }
                
                // Get memory usage (simplified - would need more complex implementation for accurate data)
                let memoryUsage: Int64 = 0 // Placeholder - requires process-specific memory queries
                let cpuUsage: Double = 0 // Placeholder - requires process-specific CPU monitoring
                
                let appInfo = AppInfo(
                    bundleIdentifier: bundleId,
                    name: name,
                    processID: processID,
                    memoryUsage: memoryUsage,
                    cpuUsage: cpuUsage,
                    isActive: isActive,
                    launchDate: launchDate,
                    icon: iconData
                )
                
                appInfos.append(appInfo)
            }
            
            // Sort by name
            appInfos.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            continuation.resume(returning: appInfos)
        }
    }
    
    // MARK: - Specific Query Methods
    
    /// Query specific system information type
    func querySystem(_ queryType: SystemQueryType) async throws -> String {
        switch queryType {
        case .battery:
            if let battery = try? await getBatteryInfo() {
                return formatBatteryInfo(battery)
            } else {
                return "Battery information not available on this device."
            }
            
        case .storage:
            let storage = try await getStorageInfo()
            return formatStorageInfo(storage)
            
        case .memory:
            let memory = try await getMemoryInfo()
            return formatMemoryInfo(memory)
            
        case .network:
            let network = try await getNetworkInfo()
            return formatNetworkInfo(network)
            
        case .cpu:
            let cpu = try await getCPUInfo()
            return formatCPUInfo(cpu)
            
        case .apps:
            let apps = try await getRunningApps()
            return formatRunningApps(apps)
            
        case .overview:
            let systemInfo = try await getSystemInfo()
            return formatSystemOverview(systemInfo)
            
        case .performance:
            let systemInfo = try await getSystemInfo()
            return formatPerformanceInfo(systemInfo)
        }
    }
    
    /// Execute system control operation
    func executeSystemControl(_ operation: SystemControlOperation, value: Double? = nil) async throws -> SystemControlResult {
        switch operation {
        case .volumeUp:
            return try await volumeUp()
        case .volumeDown:
            return try await volumeDown()
        case .volumeMute:
            return try await toggleMute()
        case .volumeSet:
            guard let value = value else {
                throw SystemServiceError.invalidParameter("Volume level required")
            }
            return try await setVolume(value)
        case .brightnessUp:
            return try await brightnessUp()
        case .brightnessDown:
            return try await brightnessDown()
        case .brightnessSet:
            guard let value = value else {
                throw SystemServiceError.invalidParameter("Brightness level required")
            }
            return try await setBrightness(value)
        case .displaySleep:
            return try await sleepDisplay()
        case .systemSleep:
            return try await sleepSystem()
        case .wifiToggle:
            return try await toggleWiFi()
        case .bluetoothToggle:
            return try await toggleBluetooth()
        case .doNotDisturbToggle:
            return try await toggleDoNotDisturb()
        case .nightShiftToggle:
            return try await toggleNightShift()
        case .cacheClear:
            return try await clearSystemCache()
        case .diskCleanup:
            return try await performDiskCleanup()
        case .emptyTrash:
            return try await emptyTrash()
        case .restartSystem:
            return try await restartSystem()
        case .shutdownSystem:
            return try await shutdownSystem()
        }
    }
    
    // MARK: - Periodic Updates
    
    private func startPeriodicUpdates() {    
    updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.getSystemInfo()
            }
        }
    }
    
    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Helper Methods
    
    private func getWiFiInfo() async throws -> WiFiInfo {
        return try await withCheckedThrowingContinuation { continuation in
            guard let wifiClient = CWWiFiClient.shared(),
                  let interface = wifiClient.interface() else {
                continuation.resume(throwing: SystemServiceError.serviceUnavailable("WiFi"))
                return
            }
            
            let ssid = interface.ssid()
            let bssid = interface.bssid()
            let rssi = interface.rssiValue()
            let channel = interface.wlanChannel()?.channelNumber
            let frequency = interface.wlanChannel()?.channelBand == .band2GHz ? 2.4 : 5.0
            
            // Determine security type
            let security: WiFiInfo.WiFiSecurity
            if let securityMode = interface.security() {
                switch securityMode {
                case .none: security = .none
                case .WEP: security = .wep
                case .WPA_Personal, .WPA_Personal_Mixed: security = .wpa
                case .WPA2_Personal, .WPA2_Personal_Mixed: security = .wpa2
                case .WPA3_Personal: security = .wpa3
                case .WPA_Enterprise, .WPA2_Enterprise, .WPA3_Enterprise: security = .enterprise
                default: security = .unknown
                }
            } else {
                security = .unknown
            }
            
            let wifiInfo = WiFiInfo(
                ssid: ssid,
                bssid: bssid,
                signalStrength: Int(rssi),
                channel: channel,
                security: security,
                frequency: frequency
            )
            
            continuation.resume(returning: wifiInfo)
        }
    }
    
    private func getInterfaceTypeAndName(_ interfaceName: String) -> (NetworkInterface.ConnectionType, String) {
        switch interfaceName {
        case let name where name.hasPrefix("en"):
            // Check if it's WiFi or Ethernet
            if name == "en0" {
                // Usually WiFi on modern Macs, but could be Ethernet on older ones
                return (.wifi, "Wi-Fi")
            } else {
                return (.ethernet, "Ethernet")
            }
        case let name where name.hasPrefix("bridge"):
            return (.other, "Bridge")
        case let name where name.hasPrefix("p2p"):
            return (.other, "Peer-to-Peer")
        default:
            return (.other, interfaceName.capitalized)
        }
    }
    
    private func getArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.targettype", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.targettype", &machine, &size, nil, 0)
        
        let targetType = String(cString: machine)
        
        // Get more specific architecture info
        size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        
        return String(cString: machine)
    }
    
    private func getSystemVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    private func getSystemBuild() -> String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var build = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &build, &size, nil, 0)
        return String(cString: build)
    }
    
    private func getSystemUptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 {
            let now = Date().timeIntervalSince1970
            let bootTime = Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000
            return now - bootTime
        }
        return 0
    }
}

// MARK: - Formatting Methods
extension SystemService {
    
    private func formatBatteryInfo(_ battery: BatteryInfo) -> String {
        var result = "🔋 Battery: \(battery.levelPercentage)%"
        
        if battery.isCharging {
            result += " (Charging)"
        } else if let timeRemaining = battery.formattedTimeRemaining {
            result += " (\(timeRemaining) remaining)"
        }
        
        result += "\nPower Source: \(battery.powerSource.rawValue.capitalized)"
        
        if let health = battery.health {
            result += "\nHealth: \(health.rawValue.capitalized)"
        }
        
        if let cycles = battery.cycleCount {
            result += "\nCycle Count: \(cycles)"
        }
        
        return result
    }
    
    private func formatStorageInfo(_ storage: StorageInfo) -> String {
        let usedGB = storage.usedSpaceGB
        let totalGB = storage.totalSpaceGB
        let availableGB = storage.availableSpaceGB
        let usagePercent = storage.usagePercentage
        
        var result = "💾 Storage: \(String(format: "%.1f", usedGB)) GB used of \(String(format: "%.1f", totalGB)) GB (\(String(format: "%.1f", usagePercent))%)"
        result += "\nAvailable: \(String(format: "%.1f", availableGB)) GB"
        
        if storage.volumes.count > 1 {
            result += "\n\nVolumes:"
            for volume in storage.volumes {
                let volumeUsedGB = Double(volume.totalSpace - volume.availableSpace) / 1_000_000_000
                result += "\n• \(volume.name): \(String(format: "%.1f", volumeUsedGB)) GB / \(String(format: "%.1f", volume.totalSpaceGB)) GB"
            }
        }
        
        return result
    }
    
    private func formatMemoryInfo(_ memory: MemoryInfo) -> String {
        let usedGB = memory.usedMemoryGB
        let totalGB = memory.totalMemoryGB
        let availableGB = memory.availableMemoryGB
        let usagePercent = memory.usagePercentage
        
        var result = "🧠 Memory: \(String(format: "%.1f", usedGB)) GB used of \(String(format: "%.1f", totalGB)) GB (\(String(format: "%.1f", usagePercent))%)"
        result += "\nAvailable: \(String(format: "%.1f", availableGB)) GB"
        result += "\nPressure: \(memory.memoryPressure.rawValue.capitalized)"
        
        let appMemoryGB = Double(memory.appMemory) / 1_000_000_000
        let wiredMemoryGB = Double(memory.wiredMemory) / 1_000_000_000
        let compressedMemoryGB = Double(memory.compressedMemory) / 1_000_000_000
        
        result += "\n\nBreakdown:"
        result += "\n• App Memory: \(String(format: "%.1f", appMemoryGB)) GB"
        result += "\n• Wired Memory: \(String(format: "%.1f", wiredMemoryGB)) GB"
        result += "\n• Compressed: \(String(format: "%.1f", compressedMemoryGB)) GB"
        
        if memory.swapUsed > 0 {
            let swapGB = Double(memory.swapUsed) / 1_000_000_000
            result += "\n• Swap Used: \(String(format: "%.1f", swapGB)) GB"
        }
        
        return result
    }
    
    private func formatNetworkInfo(_ network: NetworkInfo) -> String {
        var result = network.isConnected ? "🌐 Network: Connected" : "🌐 Network: Disconnected"
        
        if let primary = network.primaryInterface {
            result += "\nPrimary: \(primary.displayName) (\(primary.name))"
            if let ip = primary.ipAddress {
                result += "\nIP Address: \(ip)"
            }
        }
        
        if let wifi = network.wifiInfo {
            result += "\n\nWi-Fi Details:"
            if let ssid = wifi.ssid {
                result += "\n• Network: \(ssid)"
            }
            if let signal = wifi.signalStrength {
                result += "\n• Signal: \(signal) dBm (\(wifi.signalQuality.rawValue))"
            }
            if let channel = wifi.channel {
                result += "\n• Channel: \(channel)"
            }
            result += "\n• Security: \(wifi.security.rawValue.uppercased())"
        }
        
        if network.interfaces.count > 1 {
            result += "\n\nAll Interfaces:"
            for interface in network.interfaces {
                let status = interface.isActive ? "Active" : "Inactive"
                result += "\n• \(interface.displayName): \(status)"
            }
        }
        
        return result
    }
    
    private func formatCPUInfo(_ cpu: CPUInfo) -> String {
        var result = "⚡ CPU: \(String(format: "%.1f", cpu.usage))% usage"
        result += "\nProcessor: \(cpu.brand)"
        result += "\nArchitecture: \(cpu.architecture)"
        result += "\nCores: \(cpu.coreCount) (\(cpu.threadCount) threads)"
        
        if let frequency = cpu.frequency {
            result += "\nFrequency: \(String(format: "%.2f", frequency)) GHz"
        }
        
        if cpu.perCoreUsage.count > 1 {
            result += "\n\nPer-Core Usage:"
            for (index, usage) in cpu.perCoreUsage.enumerated() {
                result += "\n• Core \(index + 1): \(String(format: "%.1f", usage))%"
            }
        }
        
        if let temp = cpu.temperature {
            result += "\nTemperature: \(String(format: "%.1f", temp))°C (\(cpu.thermalState.rawValue))"
        }
        
        return result
    }
    
    private func formatRunningApps(_ apps: [AppInfo]) -> String {
        var result = "📱 Running Applications (\(apps.count)):"
        
        let activeApps = apps.filter { $0.isActive }
        if !activeApps.isEmpty {
            result += "\n\nActive:"
            for app in activeApps.prefix(10) {
                result += "\n• \(app.name)"
                if app.memoryUsage > 0 {
                    result += " (\(String(format: "%.1f", app.memoryUsageMB)) MB)"
                }
            }
        }
        
        let backgroundApps = apps.filter { !$0.isActive }
        if !backgroundApps.isEmpty {
            result += "\n\nBackground (\(backgroundApps.count)):"
            for app in backgroundApps.prefix(5) {
                result += "\n• \(app.name)"
            }
            if backgroundApps.count > 5 {
                result += "\n• ... and \(backgroundApps.count - 5) more"
            }
        }
        
        return result
    }
    
    private func formatSystemOverview(_ system: SystemInfo) -> String {
        var result = "🖥️ System Overview"
        result += "\nmacOS \(system.systemVersion) (Build \(system.systemBuild))"
        result += "\nUptime: \(system.formattedUptime)"
        
        // CPU summary
        result += "\n\n⚡ CPU: \(String(format: "%.1f", system.cpu.usage))% usage"
        result += "\n🧠 Memory: \(String(format: "%.1f", system.memory.usagePercentage))% used (\(system.memory.memoryPressure.rawValue))"
        result += "\n💾 Storage: \(String(format: "%.1f", system.storage.usagePercentage))% used"
        
        // Battery (if available)
        if let battery = system.battery {
            result += "\n🔋 Battery: \(battery.levelPercentage)%"
            if battery.isCharging {
                result += " (Charging)"
            }
        }
        
        // Network
        result += "\n🌐 Network: \(system.network.isConnected ? "Connected" : "Disconnected")"
        if let primary = system.network.primaryInterface {
            result += " via \(primary.displayName)"
        }
        
        result += "\n📱 Running Apps: \(system.runningApps.count)"
        
        return result
    }
    
    private func formatPerformanceInfo(_ system: SystemInfo) -> String {
        var result = "📊 Performance Metrics"
        
        // CPU Performance
        result += "\n\n⚡ CPU Performance:"
        result += "\n• Usage: \(String(format: "%.1f", system.cpu.usage))%"
        result += "\n• Cores: \(system.cpu.coreCount) (\(system.cpu.threadCount) threads)"
        if let freq = system.cpu.frequency {
            result += "\n• Frequency: \(String(format: "%.2f", freq)) GHz"
        }
        
        // Memory Performance
        result += "\n\n🧠 Memory Performance:"
        result += "\n• Usage: \(String(format: "%.1f", system.memory.usagePercentage))%"
        result += "\n• Pressure: \(system.memory.memoryPressure.rawValue.capitalized)"
        result += "\n• Available: \(String(format: "%.1f", system.memory.availableMemoryGB)) GB"
        
        // Storage Performance
        result += "\n\n💾 Storage Performance:"
        result += "\n• Usage: \(String(format: "%.1f", system.storage.usagePercentage))%"
        result += "\n• Available: \(String(format: "%.1f", system.storage.availableSpaceGB)) GB"
        
        // Network Performance
        result += "\n\n🌐 Network Status:"
        result += "\n• Connection: \(system.network.isConnected ? "Active" : "Inactive")"
        if let primary = system.network.primaryInterface {
            result += "\n• Interface: \(primary.displayName) (\(primary.type.rawValue))"
        }
        
        // System Health Summary
        result += "\n\n🏥 System Health:"
        var healthIssues: [String] = []
        
        if system.cpu.usage > 80 {
            healthIssues.append("High CPU usage")
        }
        if system.memory.memoryPressure == .urgent || system.memory.memoryPressure == .critical {
            healthIssues.append("Memory pressure")
        }
        if system.storage.usagePercentage > 90 {
            healthIssues.append("Low storage space")
        }
        if let battery = system.battery, battery.level < 0.2 && !battery.isCharging {
            healthIssues.append("Low battery")
        }
        
        if healthIssues.isEmpty {
            result += "\n• Status: All systems normal ✅"
        } else {
            result += "\n• Issues: \(healthIssues.joined(separator: ", ")) ⚠️"
        }
        
        return result
    }
}

// MARK: - System Control Methods
extension SystemService {
    
    // MARK: - Volume Control
    
    /// Set system volume level
    func setVolume(_ level: Double) async throws -> SystemControlResult {
        let clampedLevel = max(0.0, min(1.0, level))
        let previousVolume = try await getCurrentVolume()
        
        let script = """
        set volume output volume \(Int(clampedLevel * 100))
        """
        
        let success = await executeAppleScript(script)
        let message = success ? 
            "Volume set to \(Int(clampedLevel * 100))%" : 
            "Failed to set volume"
        
        return SystemControlResult(
            operation: .volumeSet,
            success: success,
            message: message,
            previousValue: previousVolume,
            newValue: clampedLevel
        )
    }
    
    /// Increase system volume
    func volumeUp() async throws -> SystemControlResult {
        let currentVolume = try await getCurrentVolume()
        let newVolume = min(1.0, currentVolume + 0.1)
        return try await setVolume(newVolume)
    }
    
    /// Decrease system volume
    func volumeDown() async throws -> SystemControlResult {
        let currentVolume = try await getCurrentVolume()
        let newVolume = max(0.0, currentVolume - 0.1)
        return try await setVolume(newVolume)
    }
    
    /// Toggle system volume mute
    func toggleMute() async throws -> SystemControlResult {
        let script = "set volume with output muted"
        let success = await executeAppleScript(script)
        let message = success ? "Volume muted/unmuted" : "Failed to toggle mute"
        
        return SystemControlResult(
            operation: .volumeMute,
            success: success,
            message: message
        )
    }
    
    /// Get current system volume
    func getCurrentVolume() async throws -> Double {
        return try await withCheckedThrowingContinuation { continuation in
            let script = "get volume settings"
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // Parse output to extract volume level
                if let range = output.range(of: "output volume:(\\d+)", options: .regularExpression) {
                    let volumeString = String(output[range]).replacingOccurrences(of: "output volume:", with: "")
                    if let volume = Int(volumeString) {
                        continuation.resume(returning: Double(volume) / 100.0)
                        return
                    }
                }
                
                continuation.resume(returning: 0.5) // Default fallback
            } catch {
                continuation.resume(throwing: SystemServiceError.systemCallFailed("volume query"))
            }
        }
    }
    
    // MARK: - Display Control
    
    /// Set display brightness
    func setBrightness(_ level: Double) async throws -> SystemControlResult {
        let clampedLevel = max(0.0, min(1.0, level))
        let previousBrightness = try await getCurrentBrightness()
        
        let script = """
        tell application "System Events"
            tell appearance preferences
                set brightness to \(clampedLevel)
            end tell
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? 
            "Brightness set to \(Int(clampedLevel * 100))%" : 
            "Failed to set brightness"
        
        return SystemControlResult(
            operation: .brightnessSet,
            success: success,
            message: message,
            previousValue: previousBrightness,
            newValue: clampedLevel
        )
    }
    
    /// Increase display brightness
    func brightnessUp() async throws -> SystemControlResult {
        let currentBrightness = try await getCurrentBrightness()
        let newBrightness = min(1.0, currentBrightness + 0.1)
        return try await setBrightness(newBrightness)
    }
    
    /// Decrease display brightness
    func brightnessDown() async throws -> SystemControlResult {
        let currentBrightness = try await getCurrentBrightness()
        let newBrightness = max(0.0, currentBrightness - 0.1)
        return try await setBrightness(newBrightness)
    }
    
    /// Get current display brightness
    func getCurrentBrightness() async throws -> Double {
        return try await withCheckedThrowingContinuation { continuation in
            let script = """
            tell application "System Events"
                tell appearance preferences
                    get brightness
                end tell
            end tell
            """
            
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if let brightness = Double(output) {
                    continuation.resume(returning: brightness)
                } else {
                    continuation.resume(returning: 0.5) // Default fallback
                }
            } catch {
                continuation.resume(throwing: SystemServiceError.systemCallFailed("brightness query"))
            }
        }
    }
    
    /// Put display to sleep
    func sleepDisplay() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            sleep
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "Display put to sleep" : "Failed to sleep display"
        
        return SystemControlResult(
            operation: .displaySleep,
            success: success,
            message: message
        )
    }
    
    /// Get display information
    func getDisplayInfo() async throws -> [DisplayInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            // This would require Core Graphics framework for full implementation
            // For now, return basic info
            let displays: [DisplayInfo] = []
            continuation.resume(returning: displays)
        }
    }
    
    // MARK: - Network Control
    
    /// Toggle Wi-Fi on/off
    func toggleWiFi() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            tell network preferences
                set wifi to not (wifi enabled)
            end tell
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "Wi-Fi toggled" : "Failed to toggle Wi-Fi"
        
        return SystemControlResult(
            operation: .wifiToggle,
            success: success,
            message: message
        )
    }
    
    /// Toggle Bluetooth on/off
    func toggleBluetooth() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            tell bluetooth preferences
                set bluetooth enabled to not (bluetooth enabled)
            end tell
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "Bluetooth toggled" : "Failed to toggle Bluetooth"
        
        return SystemControlResult(
            operation: .bluetoothToggle,
            success: success,
            message: message
        )
    }
    
    /// Toggle Do Not Disturb mode
    func toggleDoNotDisturb() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            tell notification center preferences
                set do not disturb enabled to not (do not disturb enabled)
            end tell
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "Do Not Disturb toggled" : "Failed to toggle Do Not Disturb"
        
        return SystemControlResult(
            operation: .doNotDisturbToggle,
            success: success,
            message: message
        )
    }
    
    /// Toggle Night Shift mode
    func toggleNightShift() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            tell displays preferences
                set night shift enabled to not (night shift enabled)
            end tell
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "Night Shift toggled" : "Failed to toggle Night Shift"
        
        return SystemControlResult(
            operation: .nightShiftToggle,
            success: success,
            message: message
        )
    }
    
    /// Get network configuration
    func getNetworkConfiguration() async throws -> NetworkConfiguration {
        return try await withCheckedThrowingContinuation { continuation in
            // Basic implementation - would need more detailed system calls for full functionality
            let config = NetworkConfiguration(
                wifiEnabled: true, // Placeholder
                bluetoothEnabled: true, // Placeholder
                airDropEnabled: false, // Placeholder
                hotspotEnabled: false, // Placeholder
                vpnConnections: [], // Placeholder
                dnsServers: [], // Placeholder
                proxySettings: nil // Placeholder
            )
            continuation.resume(returning: config)
        }
    }
    
    // MARK: - System Maintenance
    
    /// Get system maintenance information
    func getMaintenanceInfo() async throws -> MaintenanceInfo {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let fileManager = FileManager.default
                    var cacheSize: Int64 = 0
                    var trashSize: Int64 = 0
                    var logSize: Int64 = 0
                    var tempFilesSize: Int64 = 0
                    var downloadsSize: Int64 = 0
                    
                    // Calculate cache size
                    let cachePaths = [
                        "~/Library/Caches",
                        "/Library/Caches",
                        "/System/Library/Caches"
                    ]
                    
                    for cachePath in cachePaths {
                        let expandedPath = NSString(string: cachePath).expandingTildeInPath
                        if let size = try? getDirectorySize(at: URL(fileURLWithPath: expandedPath)) {
                            cacheSize += size
                        }
                    }
                    
                    // Calculate trash size
                    let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
                    if let trashURL = trashURL,
                       let size = try? getDirectorySize(at: trashURL) {
                        trashSize = size
                    }
                    
                    // Calculate log size
                    let logPaths = [
                        "~/Library/Logs",
                        "/Library/Logs",
                        "/var/log"
                    ]
                    
                    for logPath in logPaths {
                        let expandedPath = NSString(string: logPath).expandingTildeInPath
                        if let size = try? getDirectorySize(at: URL(fileURLWithPath: expandedPath)) {
                            logSize += size
                        }
                    }
                    
                    // Calculate temp files size
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    if let size = try? getDirectorySize(at: tempURL) {
                        tempFilesSize = size
                    }
                    
                    // Calculate downloads size
                    let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    if let downloadsURL = downloadsURL,
                       let size = try? getDirectorySize(at: downloadsURL) {
                        downloadsSize = size
                    }
                    
                    // Determine recommended actions
                    var recommendedActions: [MaintenanceInfo.MaintenanceAction] = []
                    
                    if cacheSize > 100_000_000 { // > 100MB
                        recommendedActions.append(.clearCache)
                    }
                    if trashSize > 0 {
                        recommendedActions.append(.emptyTrash)
                    }
                    if logSize > 50_000_000 { // > 50MB
                        recommendedActions.append(.clearLogs)
                    }
                    if tempFilesSize > 50_000_000 { // > 50MB
                        recommendedActions.append(.clearTempFiles)
                    }
                    
                    let maintenanceInfo = MaintenanceInfo(
                        cacheSize: cacheSize,
                        trashSize: trashSize,
                        logSize: logSize,
                        tempFilesSize: tempFilesSize,
                        downloadsSize: downloadsSize,
                        lastCleanupDate: nil, // Would need to track this
                        recommendedActions: recommendedActions
                    )
                    
                    continuation.resume(returning: maintenanceInfo)
                } catch {
                    continuation.resume(throwing: SystemServiceError.systemCallFailed("maintenance info"))
                }
            }
        }
    }
    
    /// Clear system cache
    func clearSystemCache() async throws -> SystemControlResult {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let fileManager = FileManager.default
                    var clearedSize: Int64 = 0
                    var errors: [String] = []
                    
                    // Clear user cache
                    let userCachePath = NSString(string: "~/Library/Caches").expandingTildeInPath
                    let userCacheURL = URL(fileURLWithPath: userCachePath)
                    
                    if fileManager.fileExists(atPath: userCachePath) {
                        do {
                            let contents = try fileManager.contentsOfDirectory(at: userCacheURL, includingPropertiesForKeys: nil)
                            for item in contents {
                                do {
                                    let size = try getDirectorySize(at: item)
                                    try fileManager.removeItem(at: item)
                                    clearedSize += size
                                } catch {
                                    errors.append("Failed to clear \(item.lastPathComponent): \(error.localizedDescription)")
                                }
                            }
                        } catch {
                            errors.append("Failed to access user cache: \(error.localizedDescription)")
                        }
                    }
                    
                    let success = errors.isEmpty
                    let message = success ? 
                        "Cleared \(String(format: "%.1f", Double(clearedSize) / 1_000_000)) MB of cache" :
                        "Partially cleared cache with \(errors.count) errors"
                    
                    let result = SystemControlResult(
                        operation: .cacheClear,
                        success: success,
                        message: message
                    )
                    
                    continuation.resume(returning: result)
                } catch {
                    let result = SystemControlResult(
                        operation: .cacheClear,
                        success: false,
                        message: "Failed to clear cache: \(error.localizedDescription)"
                    )
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    /// Empty trash
    func emptyTrash() async throws -> SystemControlResult {
        let script = """
        tell application "Finder"
            empty trash
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "Trash emptied successfully" : "Failed to empty trash"
        
        return SystemControlResult(
            operation: .emptyTrash,
            success: success,
            message: message
        )
    }
    
    /// Perform disk cleanup
    func performDiskCleanup() async throws -> SystemControlResult {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                var totalCleaned: Int64 = 0
                var operations: [String] = []
                
                // Clear cache
                if let cacheResult = try? await clearSystemCache(), cacheResult.success {
                    operations.append("System cache cleared")
                }
                
                // Empty trash
                if let trashResult = try? await emptyTrash(), trashResult.success {
                    operations.append("Trash emptied")
                }
                
                let success = !operations.isEmpty
                let message = success ? 
                    "Disk cleanup completed: \(operations.joined(separator: ", "))" :
                    "Disk cleanup failed"
                
                let result = SystemControlResult(
                    operation: .diskCleanup,
                    success: success,
                    message: message
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - System Power Control
    
    /// Put system to sleep
    func sleepSystem() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            sleep
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "System put to sleep" : "Failed to sleep system"
        
        return SystemControlResult(
            operation: .systemSleep,
            success: success,
            message: message
        )
    }
    
    /// Restart system
    func restartSystem() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            restart
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "System restart initiated" : "Failed to restart system"
        
        return SystemControlResult(
            operation: .restartSystem,
            success: success,
            message: message
        )
    }
    
    /// Shutdown system
    func shutdownSystem() async throws -> SystemControlResult {
        let script = """
        tell application "System Events"
            shut down
        end tell
        """
        
        let success = await executeAppleScript(script)
        let message = success ? "System shutdown initiated" : "Failed to shutdown system"
        
        return SystemControlResult(
            operation: .shutdownSystem,
            success: success,
            message: message
        )
    }
    
    // MARK: - Helper Methods
    
    /// Execute AppleScript command
    private func executeAppleScript(_ script: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            
            do {
                try task.run()
                task.waitUntilExit()
                continuation.resume(returning: task.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Get directory size recursively
    private func getDirectorySize(at url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: resourceKeys)
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isRegularFile == true {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
}