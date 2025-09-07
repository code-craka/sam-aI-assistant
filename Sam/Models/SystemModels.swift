import Foundation
import IOKit.ps
import SystemConfiguration

// MARK: - System Information Models

/// Battery information structure
struct BatteryInfo: Codable, Equatable {
    let level: Double // 0.0 to 1.0
    let isCharging: Bool
    let timeRemaining: TimeInterval? // in seconds, nil if unknown
    let powerSource: PowerSource
    let cycleCount: Int?
    let health: BatteryHealth?
    
    enum PowerSource: String, Codable {
        case battery = "battery"
        case acPower = "ac_power"
        case ups = "ups"
        case unknown = "unknown"
    }
    
    enum BatteryHealth: String, Codable {
        case good = "good"
        case fair = "fair"
        case poor = "poor"
        case unknown = "unknown"
    }
    
    var levelPercentage: Int {
        Int(level * 100)
    }
    
    var formattedTimeRemaining: String? {
        guard let timeRemaining = timeRemaining else { return nil }
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

/// Storage information structure
struct StorageInfo: Codable, Equatable {
    let totalSpace: Int64 // in bytes
    let availableSpace: Int64 // in bytes
    let usedSpace: Int64 // in bytes
    let volumes: [VolumeInfo]
    
    var totalSpaceGB: Double {
        Double(totalSpace) / 1_000_000_000
    }
    
    var availableSpaceGB: Double {
        Double(availableSpace) / 1_000_000_000
    }
    
    var usedSpaceGB: Double {
        Double(usedSpace) / 1_000_000_000
    }
    
    var usagePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

/// Volume information structure
struct VolumeInfo: Codable, Equatable, Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let totalSpace: Int64
    let availableSpace: Int64
    let fileSystem: String
    let isRemovable: Bool
    let isInternal: Bool
    
    var totalSpaceGB: Double {
        Double(totalSpace) / 1_000_000_000
    }
    
    var availableSpaceGB: Double {
        Double(availableSpace) / 1_000_000_000
    }
    
    var usagePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        let usedSpace = totalSpace - availableSpace
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

/// Memory information structure
struct MemoryInfo: Codable, Equatable {
    let totalMemory: Int64 // in bytes
    let usedMemory: Int64 // in bytes
    let availableMemory: Int64 // in bytes
    let appMemory: Int64 // memory used by applications
    let wiredMemory: Int64 // memory wired down
    let compressedMemory: Int64 // compressed memory
    let swapUsed: Int64 // swap space used
    let memoryPressure: MemoryPressure
    
    enum MemoryPressure: String, Codable {
        case normal = "normal"
        case warning = "warning"
        case urgent = "urgent"
        case critical = "critical"
    }
    
    var totalMemoryGB: Double {
        Double(totalMemory) / 1_000_000_000
    }
    
    var usedMemoryGB: Double {
        Double(usedMemory) / 1_000_000_000
    }
    
    var availableMemoryGB: Double {
        Double(availableMemory) / 1_000_000_000
    }
    
    var usagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100
    }
}

/// Network information structure
struct NetworkInfo: Codable, Equatable {
    let isConnected: Bool
    let primaryInterface: NetworkInterface?
    let interfaces: [NetworkInterface]
    let wifiInfo: WiFiInfo?
    
    var connectionType: NetworkInterface.ConnectionType {
        guard let primary = primaryInterface else { return .none }
        return primary.type
    }
}

/// Network interface information
struct NetworkInterface: Codable, Equatable, Identifiable {
    let id = UUID()
    let name: String // e.g., "en0", "en1"
    let displayName: String // e.g., "Wi-Fi", "Ethernet"
    let type: ConnectionType
    let isActive: Bool
    let ipAddress: String?
    let macAddress: String?
    let speed: Int64? // in bits per second
    
    enum ConnectionType: String, Codable {
        case wifi = "wifi"
        case ethernet = "ethernet"
        case cellular = "cellular"
        case vpn = "vpn"
        case bluetooth = "bluetooth"
        case other = "other"
        case none = "none"
    }
}

/// WiFi specific information
struct WiFiInfo: Codable, Equatable {
    let ssid: String?
    let bssid: String?
    let signalStrength: Int? // RSSI in dBm
    let channel: Int?
    let security: WiFiSecurity
    let frequency: Double? // in GHz
    
    enum WiFiSecurity: String, Codable {
        case none = "none"
        case wep = "wep"
        case wpa = "wpa"
        case wpa2 = "wpa2"
        case wpa3 = "wpa3"
        case enterprise = "enterprise"
        case unknown = "unknown"
    }
    
    var signalQuality: SignalQuality {
        guard let rssi = signalStrength else { return .unknown }
        switch rssi {
        case -30...0: return .excellent
        case -50..<(-30): return .good
        case -70..<(-50): return .fair
        case -90..<(-70): return .poor
        default: return .poor
        }
    }
    
    enum SignalQuality: String, Codable {
        case excellent = "excellent"
        case good = "good"
        case fair = "fair"
        case poor = "poor"
        case unknown = "unknown"
    }
}

/// Running application information
struct AppInfo: Codable, Equatable, Identifiable {
    let id = UUID()
    let bundleIdentifier: String
    let name: String
    let processID: Int32
    let memoryUsage: Int64 // in bytes
    let cpuUsage: Double // percentage
    let isActive: Bool
    let launchDate: Date?
    let icon: Data? // app icon as data
    
    var memoryUsageMB: Double {
        Double(memoryUsage) / 1_000_000
    }
}

/// CPU information structure
struct CPUInfo: Codable, Equatable {
    let usage: Double // overall CPU usage percentage
    let coreCount: Int
    let threadCount: Int
    let architecture: String // e.g., "arm64", "x86_64"
    let brand: String // e.g., "Apple M1", "Intel Core i7"
    let frequency: Double? // in GHz
    let temperature: Double? // in Celsius
    let perCoreUsage: [Double] // usage per core
    
    var thermalState: ThermalState {
        guard let temp = temperature else { return .unknown }
        switch temp {
        case 0..<60: return .normal
        case 60..<80: return .warm
        case 80..<95: return .hot
        default: return .critical
        }
    }
    
    enum ThermalState: String, Codable {
        case normal = "normal"
        case warm = "warm"
        case hot = "hot"
        case critical = "critical"
        case unknown = "unknown"
    }
}

/// Comprehensive system information
struct SystemInfo: Codable, Equatable {
    let battery: BatteryInfo?
    let storage: StorageInfo
    let memory: MemoryInfo
    let network: NetworkInfo
    let cpu: CPUInfo
    let runningApps: [AppInfo]
    let timestamp: Date
    let systemVersion: String
    let systemBuild: String
    let uptime: TimeInterval
    
    var formattedUptime: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - System Query Types

enum SystemQueryType: String, CaseIterable, Codable {
    case battery = "battery"
    case storage = "storage"
    case memory = "memory"
    case network = "network"
    case cpu = "cpu"
    case apps = "apps"
    case overview = "overview"
    case performance = "performance"
    
    var displayName: String {
        switch self {
        case .battery: return "Battery"
        case .storage: return "Storage"
        case .memory: return "Memory"
        case .network: return "Network"
        case .cpu: return "CPU"
        case .apps: return "Running Apps"
        case .overview: return "System Overview"
        case .performance: return "Performance"
        }
    }
}

// MARK: - System Control Models

/// System control operation types
enum SystemControlOperation: String, CaseIterable, Codable {
    case volumeUp = "volume_up"
    case volumeDown = "volume_down"
    case volumeMute = "volume_mute"
    case volumeSet = "volume_set"
    case brightnessUp = "brightness_up"
    case brightnessDown = "brightness_down"
    case brightnessSet = "brightness_set"
    case displaySleep = "display_sleep"
    case systemSleep = "system_sleep"
    case wifiToggle = "wifi_toggle"
    case bluetoothToggle = "bluetooth_toggle"
    case doNotDisturbToggle = "do_not_disturb_toggle"
    case nightShiftToggle = "night_shift_toggle"
    case cacheClear = "cache_clear"
    case diskCleanup = "disk_cleanup"
    case emptyTrash = "empty_trash"
    case restartSystem = "restart_system"
    case shutdownSystem = "shutdown_system"
    
    var displayName: String {
        switch self {
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .volumeMute: return "Mute/Unmute Volume"
        case .volumeSet: return "Set Volume"
        case .brightnessUp: return "Brightness Up"
        case .brightnessDown: return "Brightness Down"
        case .brightnessSet: return "Set Brightness"
        case .displaySleep: return "Sleep Display"
        case .systemSleep: return "Sleep System"
        case .wifiToggle: return "Toggle Wi-Fi"
        case .bluetoothToggle: return "Toggle Bluetooth"
        case .doNotDisturbToggle: return "Toggle Do Not Disturb"
        case .nightShiftToggle: return "Toggle Night Shift"
        case .cacheClear: return "Clear System Cache"
        case .diskCleanup: return "Disk Cleanup"
        case .emptyTrash: return "Empty Trash"
        case .restartSystem: return "Restart System"
        case .shutdownSystem: return "Shutdown System"
        }
    }
    
    var requiresConfirmation: Bool {
        switch self {
        case .cacheClear, .diskCleanup, .emptyTrash, .restartSystem, .shutdownSystem:
            return true
        default:
            return false
        }
    }
}

/// System control result
struct SystemControlResult: Codable, Equatable {
    let operation: SystemControlOperation
    let success: Bool
    let message: String
    let previousValue: Double? // For operations that change values
    let newValue: Double? // For operations that change values
    let timestamp: Date
    
    init(operation: SystemControlOperation, success: Bool, message: String, previousValue: Double? = nil, newValue: Double? = nil) {
        self.operation = operation
        self.success = success
        self.message = message
        self.previousValue = previousValue
        self.newValue = newValue
        self.timestamp = Date()
    }
}

/// Display information
struct DisplayInfo: Codable, Equatable, Identifiable {
    let id = UUID()
    let displayID: UInt32
    let name: String
    let brightness: Double // 0.0 to 1.0
    let resolution: DisplayResolution
    let colorSpace: String
    let refreshRate: Double
    let isPrimary: Bool
    let isBuiltIn: Bool
    
    struct DisplayResolution: Codable, Equatable {
        let width: Int
        let height: Int
        let scale: Double
        
        var description: String {
            return "\(width) × \(height) @ \(scale)x"
        }
    }
}

/// Audio device information
struct AudioDevice: Codable, Equatable, Identifiable {
    let id = UUID()
    let deviceID: UInt32
    let name: String
    let type: AudioDeviceType
    let volume: Double // 0.0 to 1.0
    let isMuted: Bool
    let isDefault: Bool
    let sampleRate: Double
    let channels: Int
    
    enum AudioDeviceType: String, Codable {
        case input = "input"
        case output = "output"
        case system = "system"
    }
}

/// Network configuration information
struct NetworkConfiguration: Codable, Equatable {
    let wifiEnabled: Bool
    let bluetoothEnabled: Bool
    let airDropEnabled: Bool
    let hotspotEnabled: Bool
    let vpnConnections: [VPNConnection]
    let dnsServers: [String]
    let proxySettings: ProxySettings?
    
    struct VPNConnection: Codable, Equatable, Identifiable {
        let id = UUID()
        let name: String
        let type: VPNType
        let isConnected: Bool
        let serverAddress: String?
        
        enum VPNType: String, Codable {
            case ipsec = "ipsec"
            case l2tp = "l2tp"
            case pptp = "pptp"
            case cisco = "cisco"
            case juniper = "juniper"
            case other = "other"
        }
    }
    
    struct ProxySettings: Codable, Equatable {
        let httpEnabled: Bool
        let httpsEnabled: Bool
        let socksEnabled: Bool
        let httpProxy: String?
        let httpsProxy: String?
        let socksProxy: String?
        let bypassList: [String]
    }
}

/// System maintenance information
struct MaintenanceInfo: Codable, Equatable {
    let cacheSize: Int64 // in bytes
    let trashSize: Int64 // in bytes
    let logSize: Int64 // in bytes
    let tempFilesSize: Int64 // in bytes
    let downloadsSize: Int64 // in bytes
    let lastCleanupDate: Date?
    let recommendedActions: [MaintenanceAction]
    
    enum MaintenanceAction: String, Codable {
        case clearCache = "clear_cache"
        case emptyTrash = "empty_trash"
        case clearLogs = "clear_logs"
        case clearTempFiles = "clear_temp_files"
        case clearDownloads = "clear_downloads"
        case repairPermissions = "repair_permissions"
        case rebuildSpotlight = "rebuild_spotlight"
        
        var displayName: String {
            switch self {
            case .clearCache: return "Clear System Cache"
            case .emptyTrash: return "Empty Trash"
            case .clearLogs: return "Clear Log Files"
            case .clearTempFiles: return "Clear Temporary Files"
            case .clearDownloads: return "Clear Downloads Folder"
            case .repairPermissions: return "Repair Disk Permissions"
            case .rebuildSpotlight: return "Rebuild Spotlight Index"
            }
        }
        
        var estimatedSpaceSaved: String {
            switch self {
            case .clearCache: return "100-500 MB"
            case .emptyTrash: return "Varies"
            case .clearLogs: return "50-200 MB"
            case .clearTempFiles: return "50-300 MB"
            case .clearDownloads: return "Varies"
            case .repairPermissions: return "0 MB"
            case .rebuildSpotlight: return "0 MB"
            }
        }
    }
    
    var totalCleanableSize: Int64 {
        return cacheSize + trashSize + logSize + tempFilesSize
    }
    
    var totalCleanableSizeGB: Double {
        return Double(totalCleanableSize) / 1_000_000_000
    }
}

// MARK: - System Service Errors

enum SystemServiceError: LocalizedError, Equatable {
    case permissionDenied(String)
    case serviceUnavailable(String)
    case dataCorrupted(String)
    case networkUnavailable
    case batteryNotFound
    case insufficientPrivileges
    case systemCallFailed(String)
    case operationFailed(String)
    case unsupportedOperation(String)
    case invalidParameter(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let detail):
            return "Permission denied: \(detail)"
        case .serviceUnavailable(let service):
            return "Service unavailable: \(service)"
        case .dataCorrupted(let detail):
            return "Data corrupted: \(detail)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .batteryNotFound:
            return "Battery information not available"
        case .insufficientPrivileges:
            return "Insufficient privileges to access system information"
        case .systemCallFailed(let call):
            return "System call failed: \(call)"
        case .operationFailed(let operation):
            return "Operation failed: \(operation)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .invalidParameter(let parameter):
            return "Invalid parameter: \(parameter)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant necessary permissions in System Preferences > Security & Privacy"
        case .serviceUnavailable:
            return "Please try again later or restart the application"
        case .dataCorrupted:
            return "Please restart the application or contact support"
        case .networkUnavailable:
            return "Please check your network connection"
        case .batteryNotFound:
            return "This device may not have a battery or battery information is unavailable"
        case .insufficientPrivileges:
            return "Please run the application with appropriate permissions"
        case .systemCallFailed:
            return "Please try again or restart the application"
        case .operationFailed:
            return "Please try the operation again or use an alternative method"
        case .unsupportedOperation:
            return "This operation is not supported on your system"
        case .invalidParameter:
            return "Please check the parameter values and try again"
        }
    }
}