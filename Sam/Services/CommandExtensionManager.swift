import Foundation
import Combine

// MARK: - Command Extension Protocol
protocol CommandExtension {
    var identifier: String { get }
    var name: String { get }
    var description: String { get }
    var keywords: [String] { get }
    var parameters: [CommandParameter] { get }
    var category: CommandCategory { get }
    
    func execute(with parameters: [String: Any], context: CommandContext) async throws -> CommandResult
    func validate(parameters: [String: Any]) -> ValidationResult
    func getHelp() -> CommandHelp
}

// MARK: - Command Parameter
struct CommandParameter {
    let name: String
    let type: ParameterType
    let description: String
    let isRequired: Bool
    let defaultValue: Any?
    let validationRules: [ValidationRule]
    
    enum ParameterType {
        case string
        case integer
        case double
        case boolean
        case url
        case filePath
        case array(ParameterType)
        case custom(String)
    }
    
    enum ValidationRule {
        case minLength(Int)
        case maxLength(Int)
        case range(min: Double, max: Double)
        case regex(String)
        case oneOf([String])
        case fileExists
        case directoryExists
    }
}

// MARK: - Command Category
enum CommandCategory: String, CaseIterable {
    case fileSystem = "file_system"
    case system = "system"
    case productivity = "productivity"
    case development = "development"
    case media = "media"
    case network = "network"
    case automation = "automation"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .fileSystem: return "File System"
        case .system: return "System"
        case .productivity: return "Productivity"
        case .development: return "Development"
        case .media: return "Media"
        case .network: return "Network"
        case .automation: return "Automation"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Command Context
struct CommandContext {
    let userInput: String
    let parsedParameters: [String: Any]
    let workingDirectory: URL
    let selectedFiles: [URL]
    let environment: [String: String]
    let user: UserProfile?
    
    struct UserProfile {
        let preferences: [String: Any]
        let shortcuts: [String: String]
        let history: [String]
    }
}

// MARK: - Command Result
struct CommandResult {
    let success: Bool
    let output: String
    let data: [String: Any]?
    let affectedFiles: [URL]
    let executionTime: TimeInterval
    let suggestions: [String]
    
    static func success(_ output: String, data: [String: Any]? = nil) -> CommandResult {
        return CommandResult(
            success: true,
            output: output,
            data: data,
            affectedFiles: [],
            executionTime: 0,
            suggestions: []
        )
    }
    
    static func failure(_ error: String) -> CommandResult {
        return CommandResult(
            success: false,
            output: error,
            data: nil,
            affectedFiles: [],
            executionTime: 0,
            suggestions: []
        )
    }
}

// MARK: - Validation Result
struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    
    static let valid = ValidationResult(isValid: true, errors: [], warnings: [])
    
    static func invalid(_ errors: [String]) -> ValidationResult {
        return ValidationResult(isValid: false, errors: errors, warnings: [])
    }
}

// MARK: - Command Help
struct CommandHelp {
    let usage: String
    let examples: [String]
    let notes: String?
    let relatedCommands: [String]
}

// MARK: - Command Extension Manager
@MainActor
class CommandExtensionManager: ObservableObject {
    static let shared = CommandExtensionManager()
    
    @Published var extensions: [String: CommandExtension] = [:]
    @Published var categories: [CommandCategory: [String]] = [:]
    @Published var userCommands: [String: UserDefinedCommand] = [:]
    
    private let telemetryManager = TelemetryManager.shared
    private let storageManager = CommandStorageManager()
    
    private init() {
        loadBuiltInExtensions()
        loadUserCommands()
    }
    
    // MARK: - Extension Management
    func registerExtension(_ extension: CommandExtension) {
        extensions[extension.identifier] = `extension`
        
        // Update categories
        var categoryExtensions = categories[extension.category] ?? []
        categoryExtensions.append(extension.identifier)
        categories[extension.category] = categoryExtensions
        
        telemetryManager.track("command_extension_registered", properties: [
            "extension_id": extension.identifier,
            "category": extension.category.rawValue
        ])
    }
    
    func unregisterExtension(_ identifier: String) {
        if let extension = extensions[identifier] {
            extensions.removeValue(forKey: identifier)
            
            // Update categories
            if var categoryExtensions = categories[extension.category] {
                categoryExtensions.removeAll { $0 == identifier }
                categories[extension.category] = categoryExtensions
            }
            
            telemetryManager.track("command_extension_unregistered", properties: [
                "extension_id": identifier
            ])
        }
    }
    
    // MARK: - Command Execution
    func executeCommand(_ input: String, context: CommandContext) async -> CommandResult {
        let startTime = Date()
        
        // Parse command and find matching extension
        guard let (extensionId, parameters) = parseCommand(input) else {
            return CommandResult.failure("Command not recognized")
        }
        
        guard let extension = extensions[extensionId] else {
            return CommandResult.failure("Command extension not found")
        }
        
        // Validate parameters
        let validation = extension.validate(parameters: parameters)
        guard validation.isValid else {
            return CommandResult.failure("Invalid parameters: \(validation.errors.joined(separator: ", "))")
        }
        
        do {
            var result = try await extension.execute(with: parameters, context: context)
            result = CommandResult(
                success: result.success,
                output: result.output,
                data: result.data,
                affectedFiles: result.affectedFiles,
                executionTime: Date().timeIntervalSince(startTime),
                suggestions: result.suggestions
            )
            
            telemetryManager.track("command_executed", properties: [
                "extension_id": extensionId,
                "success": result.success,
                "execution_time": result.executionTime
            ])
            
            return result
        } catch {
            telemetryManager.track("command_execution_failed", properties: [
                "extension_id": extensionId,
                "error": error.localizedDescription
            ])
            
            return CommandResult.failure("Execution failed: \(error.localizedDescription)")
        }
    }
    
    private func parseCommand(_ input: String) -> (String, [String: Any])? {
        // Simple command parsing - in real implementation would be more sophisticated
        let components = input.components(separatedBy: " ")
        guard let command = components.first else { return nil }
        
        // Find matching extension by keywords
        for (id, extension) in extensions {
            if extension.keywords.contains(command.lowercased()) {
                let parameters = parseParameters(Array(components.dropFirst()), for: extension)
                return (id, parameters)
            }
        }
        
        return nil
    }
    
    private func parseParameters(_ args: [String], for extension: CommandExtension) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // Simple parameter parsing
        for (index, param) in extension.parameters.enumerated() {
            if index < args.count {
                parameters[param.name] = convertParameter(args[index], to: param.type)
            } else if let defaultValue = param.defaultValue {
                parameters[param.name] = defaultValue
            }
        }
        
        return parameters
    }
    
    private func convertParameter(_ value: String, to type: CommandParameter.ParameterType) -> Any {
        switch type {
        case .string:
            return value
        case .integer:
            return Int(value) ?? 0
        case .double:
            return Double(value) ?? 0.0
        case .boolean:
            return Bool(value) ?? false
        case .url:
            return URL(string: value) ?? URL(fileURLWithPath: value)
        case .filePath:
            return URL(fileURLWithPath: value)
        case .array(let elementType):
            return value.components(separatedBy: ",").map { convertParameter($0.trimmingCharacters(in: .whitespaces), to: elementType) }
        case .custom:
            return value
        }
    }
    
    // MARK: - User-Defined Commands
    func createUserCommand(_ command: UserDefinedCommand) {
        userCommands[command.name] = command
        storageManager.saveUserCommand(command)
        
        telemetryManager.track("user_command_created", properties: [
            "command_name": command.name,
            "category": command.category.rawValue
        ])
    }
    
    func deleteUserCommand(_ name: String) {
        userCommands.removeValue(forKey: name)
        storageManager.deleteUserCommand(name)
        
        telemetryManager.track("user_command_deleted", properties: [
            "command_name": name
        ])
    }
    
    // MARK: - Command Discovery
    func searchCommands(_ query: String) -> [CommandExtension] {
        let lowercaseQuery = query.lowercased()
        return extensions.values.filter { extension in
            extension.name.lowercased().contains(lowercaseQuery) ||
            extension.description.lowercased().contains(lowercaseQuery) ||
            extension.keywords.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    func getCommandsByCategory(_ category: CommandCategory) -> [CommandExtension] {
        guard let extensionIds = categories[category] else { return [] }
        return extensionIds.compactMap { extensions[$0] }
    }
    
    func getCommandHelp(_ identifier: String) -> CommandHelp? {
        return extensions[identifier]?.getHelp()
    }
    
    // MARK: - Built-in Extensions
    private func loadBuiltInExtensions() {
        // Register built-in command extensions
        registerExtension(FileOperationExtension())
        registerExtension(SystemInfoExtension())
        registerExtension(TextProcessingExtension())
        registerExtension(CalculatorExtension())
    }
    
    private func loadUserCommands() {
        userCommands = storageManager.loadUserCommands()
    }
}

// MARK: - User-Defined Command
struct UserDefinedCommand: Codable {
    let name: String
    let description: String
    let category: CommandCategory
    let script: String
    let parameters: [String]
    let createdAt: Date
    let lastUsed: Date?
    let usageCount: Int
}

// MARK: - Command Storage Manager
class CommandStorageManager {
    private let userDefaults = UserDefaults.standard
    private let userCommandsKey = "user_defined_commands"
    
    func saveUserCommand(_ command: UserDefinedCommand) {
        var commands = loadUserCommands()
        commands[command.name] = command
        
        if let data = try? JSONEncoder().encode(commands) {
            userDefaults.set(data, forKey: userCommandsKey)
        }
    }
    
    func loadUserCommands() -> [String: UserDefinedCommand] {
        guard let data = userDefaults.data(forKey: userCommandsKey),
              let commands = try? JSONDecoder().decode([String: UserDefinedCommand].self, from: data) else {
            return [:]
        }
        return commands
    }
    
    func deleteUserCommand(_ name: String) {
        var commands = loadUserCommands()
        commands.removeValue(forKey: name)
        
        if let data = try? JSONEncoder().encode(commands) {
            userDefaults.set(data, forKey: userCommandsKey)
        }
    }
}

// MARK: - Built-in Extensions (Examples)
struct FileOperationExtension: CommandExtension {
    let identifier = "file_operations"
    let name = "File Operations"
    let description = "Basic file system operations"
    let keywords = ["copy", "move", "delete", "rename"]
    let category = CommandCategory.fileSystem
    
    let parameters = [
        CommandParameter(
            name: "operation",
            type: .string,
            description: "Operation to perform",
            isRequired: true,
            defaultValue: nil,
            validationRules: [.oneOf(["copy", "move", "delete", "rename"])]
        ),
        CommandParameter(
            name: "source",
            type: .filePath,
            description: "Source file path",
            isRequired: true,
            defaultValue: nil,
            validationRules: [.fileExists]
        ),
        CommandParameter(
            name: "destination",
            type: .filePath,
            description: "Destination path",
            isRequired: false,
            defaultValue: nil,
            validationRules: []
        )
    ]
    
    func execute(with parameters: [String: Any], context: CommandContext) async throws -> CommandResult {
        // Implementation would perform actual file operations
        return CommandResult.success("File operation completed")
    }
    
    func validate(parameters: [String: Any]) -> ValidationResult {
        // Validate parameters
        return ValidationResult.valid
    }
    
    func getHelp() -> CommandHelp {
        return CommandHelp(
            usage: "file_operation <operation> <source> [destination]",
            examples: [
                "copy ~/Documents/file.txt ~/Desktop/",
                "move ~/Downloads/image.jpg ~/Pictures/",
                "delete ~/Desktop/old_file.txt"
            ],
            notes: "Use quotes for paths with spaces",
            relatedCommands: ["organize", "search"]
        )
    }
}

struct SystemInfoExtension: CommandExtension {
    let identifier = "system_info"
    let name = "System Information"
    let description = "Get system information and status"
    let keywords = ["battery", "memory", "disk", "cpu", "network"]
    let category = CommandCategory.system
    let parameters: [CommandParameter] = []
    
    func execute(with parameters: [String: Any], context: CommandContext) async throws -> CommandResult {
        return CommandResult.success("System info retrieved")
    }
    
    func validate(parameters: [String: Any]) -> ValidationResult {
        return ValidationResult.valid
    }
    
    func getHelp() -> CommandHelp {
        return CommandHelp(
            usage: "system_info [type]",
            examples: ["battery", "memory usage", "disk space"],
            notes: nil,
            relatedCommands: ["performance"]
        )
    }
}

struct TextProcessingExtension: CommandExtension {
    let identifier = "text_processing"
    let name = "Text Processing"
    let description = "Text manipulation and processing"
    let keywords = ["summarize", "translate", "format", "count"]
    let category = CommandCategory.productivity
    let parameters: [CommandParameter] = []
    
    func execute(with parameters: [String: Any], context: CommandContext) async throws -> CommandResult {
        return CommandResult.success("Text processed")
    }
    
    func validate(parameters: [String: Any]) -> ValidationResult {
        return ValidationResult.valid
    }
    
    func getHelp() -> CommandHelp {
        return CommandHelp(
            usage: "text_processing <operation> <text>",
            examples: ["summarize document.txt", "translate 'hello' to spanish"],
            notes: nil,
            relatedCommands: ["ai"]
        )
    }
}

struct CalculatorExtension: CommandExtension {
    let identifier = "calculator"
    let name = "Calculator"
    let description = "Mathematical calculations"
    let keywords = ["calculate", "math", "convert"]
    let category = CommandCategory.productivity
    let parameters: [CommandParameter] = []
    
    func execute(with parameters: [String: Any], context: CommandContext) async throws -> CommandResult {
        return CommandResult.success("Calculation completed")
    }
    
    func validate(parameters: [String: Any]) -> ValidationResult {
        return ValidationResult.valid
    }
    
    func getHelp() -> CommandHelp {
        return CommandHelp(
            usage: "calculate <expression>",
            examples: ["calculate 2 + 2", "convert 100 USD to EUR"],
            notes: nil,
            relatedCommands: ["unit_converter"]
        )
    }
}