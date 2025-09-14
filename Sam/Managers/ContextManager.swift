import Foundation
import AppKit

@MainActor
class ContextManager: ObservableObject {
    @Published var currentFiles: [URL] = []
    @Published var recentFiles: [URL] = []
    @Published var activeApplication: String?
    @Published var systemContext: SystemContext = SystemContext()
    
    private let fileManager = FileManager.default
    private let workspace = NSWorkspace.shared
    private let maxRecentFiles = 20
    
    init() {
        loadRecentFiles()
        startMonitoring()
    }
    
    func getRecentFiles() -> [URL] {
        return recentFiles
    }
    
    func addRecentFile(_ url: URL) {
        // Remove if already exists
        recentFiles.removeAll { $0 == url }
        
        // Add to beginning
        recentFiles.insert(url, at: 0)
        
        // Limit to max count
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        
        saveRecentFiles()
    }
    
    func getCurrentContext() -> [String: Any] {
        var context: [String: Any] = [:]
        
        context["recent_files"] = recentFiles.map { $0.path }
        context["active_app"] = activeApplication
        context["system_info"] = systemContext.toDictionary()
        context["current_directory"] = fileManager.currentDirectoryPath
        
        return context
    }
    
    func updateSystemContext() {
        systemContext.update()
    }
    
    private func startMonitoring() {
        // Monitor active application changes
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.activeApplication = app.localizedName
            }
        }
        
        // Update system context periodically
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateSystemContext()
        }
    }
    
    private func loadRecentFiles() {
        if let data = UserDefaults.standard.data(forKey: "RecentFiles"),
           let urls = try? JSONDecoder().decode([URL].self, from: data) {
            recentFiles = urls.filter { fileManager.fileExists(atPath: $0.path) }
        }
    }
    
    private func saveRecentFiles() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(data, forKey: "RecentFiles")
        }
    }
}

struct SystemContext {
    var batteryLevel: Double?
    var isCharging: Bool = false
    var availableStorage: Int64 = 0
    var memoryUsage: Double = 0
    var networkConnected: Bool = false
    var lastUpdated: Date = Date()
    
    mutating func update() {
        lastUpdated = Date()
        
        // Update battery info
        updateBatteryInfo()
        
        // Update storage info
        updateStorageInfo()
        
        // Update memory info
        updateMemoryInfo()
        
        // Update network info
        updateNetworkInfo()
    }
    
    private mutating func updateBatteryInfo() {
        // Get battery information using IOKit
        let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef]
        
        if let powerSources = powerSources {
            for powerSource in powerSources {
                let info = IOPSGetPowerSourceDescription(powerSourceInfo, powerSource)?.takeUnretainedValue() as? [String: Any]
                
                if let capacity = info?[kIOPSCurrentCapacityKey] as? Int,
                   let maxCapacity = info?[kIOPSMaxCapacityKey] as? Int {
                    batteryLevel = Double(capacity) / Double(maxCapacity)
                }
                
                if let powerSourceState = info?[kIOPSPowerSourceStateKey] as? String {
                    isCharging = powerSourceState == kIOPSACPowerValue
                }
            }
        }
    }
    
    private mutating func updateStorageInfo() {
        do {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            availableStorage = resourceValues.volumeAvailableCapacity ?? 0
        } catch {
            availableStorage = 0
        }
    }
    
    private mutating func updateMemoryInfo() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / (1024 * 1024 * 1024) // Convert to GB
        }
    }
    
    private mutating func updateNetworkInfo() {
        // Simple network connectivity check
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            networkConnected = false
            return
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            networkConnected = false
            return
        }
        
        networkConnected = flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "battery_level": batteryLevel ?? 0,
            "is_charging": isCharging,
            "available_storage": availableStorage,
            "memory_usage": memoryUsage,
            "network_connected": networkConnected,
            "last_updated": lastUpdated.timeIntervalSince1970
        ]
    }
}