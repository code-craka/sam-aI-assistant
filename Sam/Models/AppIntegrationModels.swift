import Foundation

// MARK: - App Integration Protocol
protocol AppIntegration {
    var bundleIdentifier: String { get }
    var displayName: String { get }
    var supportedCommands: [CommandDefinition] { get }
    var integrationMethods: [IntegrationMethod] { get }
    var isInstalled: Bool { get }
    
    func canHandle(_ command: ParsedCommand) -> Bool
    func execute(_ command: ParsedCommand) async throws -> CommandResult
    func getCapabilities() -> AppCapabilities
}

// MARK: - Integration Methods
enum IntegrationMethod: String, CaseIterable, Codable {
    case urlScheme = "url_scheme"
    case appleScript = "apple_script"
    case accessibility = "accessibility"
    case nativeSDK = "native_sdk"
    case guiAutomation = "gui_automation"
    
    var priority: Int {
        switch self {
        case .nativeSDK: return 1
        case .urlScheme: return 2
        case .appleScript: return 3
        case .accessibility: return 4
        case .guiAutomation: return 5
        }
    }
    
    var displayName: String {
        switch self {
        case .urlScheme: return "URL Scheme"
        case .appleScript: return "AppleScript"
        case .accessibility: return "Accessibility API"
        case .nativeSDK: return "Native SDK"
        case .guiAutomation: return "GUI Automation"
        }
    }
}

// MARK: - Command Definition
struct CommandDefinition: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let parameters: [CommandParameter]
    let examples: [String]
    let integrationMethod: IntegrationMethod
    let requiresConfirmation: Bool
    
    init(
        name: String,
        description: String,
        parameters: [CommandParameter] = [],
        examples: [String] = [],
        integrationMethod: IntegrationMethod,
        requiresConfirmation: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.parameters = parameters
        self.examples = examples
        self.integrationMethod = integrationMethod
        self.requiresConfirmation = requiresConfirmation
    }
}

// MARK: - Command Parameter
struct CommandParameter: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: ParameterType
    let isRequired: Bool
    let description: String
    let defaultValue: String?
    
    init(
        name: String,
        type: ParameterType,
        isRequired: Bool = true,
        description: String,
        defaultValue: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.isRequired = isRequired
        self.description = description
        self.defaultValue = defaultValue
    }
}

enum ParameterType: String, Codable {
    case string = "string"
    case number = "number"
    case boolean = "boolean"
    case url = "url"
    case email = "email"
    case date = "date"
    case file = "file"
    case folder = "folder"
}

// MARK: - Command Result
struct CommandResult: Codable {
    let success: Bool
    let output: String
    let executionTime: TimeInterval
    let integrationMethod: IntegrationMethod
    let errorMessage: String?
    let followUpActions: [String]
    let undoAction: UndoAction?
    
    init(
        success: Bool,
        output: String,
        executionTime: TimeInterval = 0,
        integrationMethod: IntegrationMethod,
        errorMessage: String? = nil,
        followUpActions: [String] = [],
        undoAction: UndoAction? = nil
    ) {
        self.success = success
        self.output = output
        self.executionTime = executionTime
        self.integrationMethod = integrationMethod
        self.errorMessage = errorMessage
        self.followUpActions = followUpActions
        self.undoAction = undoAction
    }
}

// MARK: - Undo Action
struct UndoAction: Codable {
    let description: String
    let command: String
    let parameters: [String: String]
    
    init(description: String, command: String, parameters: [String: String] = [:]) {
        self.description = description
        self.command = command
        self.parameters = parameters
    }
}

// MARK: - App Capabilities
struct AppCapabilities: Codable {
    let canLaunch: Bool
    let canQuit: Bool
    let canCreateDocuments: Bool
    let canOpenFiles: Bool
    let canSaveFiles: Bool
    let canManageWindows: Bool
    let canAccessMenus: Bool
    let customCapabilities: [String: Bool]
    
    init(
        canLaunch: Bool = true,
        canQuit: Bool = true,
        canCreateDocuments: Bool = false,
        canOpenFiles: Bool = false,
        canSaveFiles: Bool = false,
        canManageWindows: Bool = false,
        canAccessMenus: Bool = false,
        customCapabilities: [String: Bool] = [:]
    ) {
        self.canLaunch = canLaunch
        self.canQuit = canQuit
        self.canCreateDocuments = canCreateDocuments
        self.canOpenFiles = canOpenFiles
        self.canSaveFiles = canSaveFiles
        self.canManageWindows = canManageWindows
        self.canAccessMenus = canAccessMenus
        self.customCapabilities = customCapabilities
    }
}

// MARK: - App Discovery Result
struct AppDiscoveryResult: Codable {
    let bundleIdentifier: String
    let displayName: String
    let version: String
    let path: String
    let isRunning: Bool
    let supportedIntegrationMethods: [IntegrationMethod]
    let capabilities: AppCapabilities
    
    init(
        bundleIdentifier: String,
        displayName: String,
        version: String,
        path: String,
        isRunning: Bool = false,
        supportedIntegrationMethods: [IntegrationMethod] = [],
        capabilities: AppCapabilities = AppCapabilities()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.version = version
        self.path = path
        self.isRunning = isRunning
        self.supportedIntegrationMethods = supportedIntegrationMethods
        self.capabilities = capabilities
    }
}

// MARK: - Integration Error
enum AppIntegrationError: LocalizedError {
    case appNotInstalled(String)
    case appNotRunning(String)
    case commandNotSupported(String)
    case integrationMethodFailed(IntegrationMethod, String)
    case permissionDenied(String)
    case invalidParameters([String])
    case executionTimeout
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .appNotInstalled(let app):
            return "Application '\(app)' is not installed"
        case .appNotRunning(let app):
            return "Application '\(app)' is not running"
        case .commandNotSupported(let command):
            return "Command '\(command)' is not supported by this application"
        case .integrationMethodFailed(let method, let reason):
            return "\(method.displayName) integration failed: \(reason)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .invalidParameters(let params):
            return "Invalid parameters: \(params.joined(separator: ", "))"
        case .executionTimeout:
            return "Command execution timed out"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .appNotInstalled:
            return "Please install the application from the App Store or the developer's website"
        case .appNotRunning:
            return "Please launch the application first"
        case .permissionDenied:
            return "Please grant necessary permissions in System Preferences > Security & Privacy"
        case .integrationMethodFailed:
            return "Try using a different integration method or check app permissions"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
}