import Foundation

// MARK: - Task Types
enum TaskType: String, CaseIterable, Codable {
    case fileOperation = "file_operation"
    case systemQuery = "system_query"
    case appControl = "app_control"
    case textProcessing = "text_processing"
    case calculation = "calculation"
    case webQuery = "web_query"
    case automation = "automation"
    case settings = "settings"
    case help = "help"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .fileOperation: return "File Operation"
        case .systemQuery: return "System Query"
        case .appControl: return "App Control"
        case .textProcessing: return "Text Processing"
        case .calculation: return "Calculation"
        case .webQuery: return "Web Query"
        case .automation: return "Automation"
        case .settings: return "Settings"
        case .help: return "Help"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .fileOperation: return "folder"
        case .systemQuery: return "info.circle"
        case .appControl: return "app.badge"
        case .textProcessing: return "text.alignleft"
        case .calculation: return "function"
        case .webQuery: return "globe"
        case .automation: return "gearshape.2"
        case .settings: return "gear"
        case .help: return "questionmark.circle"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Task Complexity
enum TaskComplexity: String, Codable {
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
    case advanced = "advanced"
    
    var processingRoute: ProcessingRoute {
        switch self {
        case .simple: return .local
        case .moderate: return .hybrid
        case .complex, .advanced: return .cloud
        }
    }
}

// MARK: - Processing Route
enum ProcessingRoute: String, Codable {
    case local = "local"
    case cloud = "cloud"
    case hybrid = "hybrid"
}

// MARK: - Task Classification Result
struct TaskClassificationResult: Codable {
    let taskType: TaskType
    let confidence: Double
    let parameters: [String: String]
    let complexity: TaskComplexity
    let processingRoute: ProcessingRoute
    let requiresConfirmation: Bool
    let estimatedDuration: TimeInterval
    
    init(
        taskType: TaskType,
        confidence: Double,
        parameters: [String: String] = [:],
        complexity: TaskComplexity = .simple,
        processingRoute: ProcessingRoute = .local,
        requiresConfirmation: Bool = false,
        estimatedDuration: TimeInterval = 1.0
    ) {
        self.taskType = taskType
        self.confidence = confidence
        self.parameters = parameters
        self.complexity = complexity
        self.processingRoute = processingRoute
        self.requiresConfirmation = requiresConfirmation
        self.estimatedDuration = estimatedDuration
    }
}

// MARK: - Task Result
struct TaskResult: Codable {
    let success: Bool
    let output: String
    let executionTime: TimeInterval
    let affectedFiles: [URL]?
    let errorMessage: String?
    let followUpSuggestions: [String]
    let undoAction: String? // Serialized undo action
    
    init(
        success: Bool,
        output: String,
        executionTime: TimeInterval = 0,
        affectedFiles: [URL]? = nil,
        errorMessage: String? = nil,
        followUpSuggestions: [String] = [],
        undoAction: String? = nil
    ) {
        self.success = success
        self.output = output
        self.executionTime = executionTime
        self.affectedFiles = affectedFiles
        self.errorMessage = errorMessage
        self.followUpSuggestions = followUpSuggestions
        self.undoAction = undoAction
    }
}

// MARK: - Parsed Command
struct ParsedCommand: Codable {
    let originalText: String
    let intent: TaskType
    let parameters: [String: String]
    let confidence: Double
    let requiresConfirmation: Bool
    let targetApplication: String?
    
    init(
        originalText: String,
        intent: TaskType,
        parameters: [String: String] = [:],
        confidence: Double,
        requiresConfirmation: Bool = false,
        targetApplication: String? = nil
    ) {
        self.originalText = originalText
        self.intent = intent
        self.parameters = parameters
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.targetApplication = targetApplication
    }
}

// MARK: - System Information
struct TaskSystemInfo: Codable {
    let batteryLevel: Double?
    let batteryIsCharging: Bool
    let availableStorage: Int64
    let totalStorage: Int64
    let memoryUsage: MemoryInfo
    let networkStatus: NetworkStatus
    let runningApps: [AppInfo]
    let cpuUsage: Double
    let timestamp: Date
    
    init(
        batteryLevel: Double? = nil,
        batteryIsCharging: Bool = false,
        availableStorage: Int64 = 0,
        totalStorage: Int64 = 0,
        memoryUsage: MemoryInfo = MemoryInfo(),
        networkStatus: NetworkStatus = NetworkStatus(),
        runningApps: [AppInfo] = [],
        cpuUsage: Double = 0,
        timestamp: Date = Date()
    ) {
        self.batteryLevel = batteryLevel
        self.batteryIsCharging = batteryIsCharging
        self.availableStorage = availableStorage
        self.totalStorage = totalStorage
        self.memoryUsage = memoryUsage
        self.networkStatus = networkStatus
        self.runningApps = runningApps
        self.cpuUsage = cpuUsage
        self.timestamp = timestamp
    }
}

// MARK: - Memory Information
struct MemoryInfo: Codable {
    let totalMemory: Int64
    let usedMemory: Int64
    let availableMemory: Int64
    let memoryPressure: MemoryPressure
    
    init(
        totalMemory: Int64 = 0,
        usedMemory: Int64 = 0,
        availableMemory: Int64 = 0,
        memoryPressure: MemoryPressure = .normal
    ) {
        self.totalMemory = totalMemory
        self.usedMemory = usedMemory
        self.availableMemory = availableMemory
        self.memoryPressure = memoryPressure
    }
}

enum MemoryPressure: String, Codable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
}

// MARK: - Network Status
struct NetworkStatus: Codable {
    let isConnected: Bool
    let connectionType: ConnectionType
    let wifiName: String?
    let ipAddress: String?
    
    init(
        isConnected: Bool = false,
        connectionType: ConnectionType = .none,
        wifiName: String? = nil,
        ipAddress: String? = nil
    ) {
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.wifiName = wifiName
        self.ipAddress = ipAddress
    }
}

enum ConnectionType: String, Codable {
    case wifi = "wifi"
    case ethernet = "ethernet"
    case cellular = "cellular"
    case none = "none"
}

// MARK: - App Information
struct AppInfo: Codable, Identifiable {
    let id: String // Bundle identifier
    let name: String
    let isActive: Bool
    let memoryUsage: Int64
    let cpuUsage: Double
    
    init(
        id: String,
        name: String,
        isActive: Bool = false,
        memoryUsage: Int64 = 0,
        cpuUsage: Double = 0
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
    }
}