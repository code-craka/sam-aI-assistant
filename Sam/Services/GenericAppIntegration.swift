import Foundation
import AppKit

// MARK: - Generic App Integration
class GenericAppIntegration: AppIntegration {
    
    // MARK: - AppIntegration Protocol
    let bundleIdentifier: String
    let displayName: String
    
    var supportedCommands: [CommandDefinition] {
        var commands = [
            CommandDefinition(
                name: "launch",
                description: "Launch the application",
                parameters: [],
                examples: ["open \(displayName)", "launch \(displayName)", "start \(displayName)"],
                integrationMethod: .accessibility
            ),
            CommandDefinition(
                name: "quit",
                description: "Quit the application",
                parameters: [],
                examples: ["quit \(displayName)", "close \(displayName)", "exit \(displayName)"],
                integrationMethod: .accessibility,
                requiresConfirmation: true
            )
        ]
        
        // Add additional commands based on app capabilities
        let capabilities = getCapabilities()
        
        if capabilities.canOpenFiles {
            commands.append(CommandDefinition(
                name: "open_file",
                description: "Open a file with the application",
                parameters: [
                    CommandParameter(name: "file", type: .file, description: "File path to open")
                ],
                examples: ["open document.pdf with \(displayName)"],
                integrationMethod: .accessibility
            ))
        }
        
        if capabilities.canCreateDocuments {
            commands.append(CommandDefinition(
                name: "new_document",
                description: "Create a new document",
                parameters: [],
                examples: ["create new document in \(displayName)"],
                integrationMethod: .appleScript
            ))
        }
        
        if capabilities.canManageWindows {
            commands.append(CommandDefinition(
                name: "minimize_window",
                description: "Minimize the application window",
                parameters: [],
                examples: ["minimize \(displayName)"],
                integrationMethod: .appleScript
            ))
        }
        
        return commands
    }
    
    let integrationMethods: [IntegrationMethod]
    
    var isInstalled: Bool {
        return appDiscovery.isAppInstalled(bundleIdentifier: bundleIdentifier)
    }
    
    // MARK: - Properties
    private let appInfo: AppDiscoveryResult
    private let appDiscovery: AppDiscoveryService
    private let appleScriptEngine: AppleScriptEngine
    private let accessibilityController: AccessibilityController
    
    // MARK: - Initialization
    init(
        appInfo: AppDiscoveryResult,
        appDiscovery: AppDiscoveryService,
        appleScriptEngine: AppleScriptEngine,
        accessibilityController: AccessibilityController
    ) {
        self.appInfo = appInfo
        self.bundleIdentifier = appInfo.bundleIdentifier
        self.displayName = appInfo.displayName
        self.integrationMethods = appInfo.supportedIntegrationMethods
        self.appDiscovery = appDiscovery
        self.appleScriptEngine = appleScriptEngine
        self.accessibilityController = accessibilityController
    }
    
    // MARK: - AppIntegration Methods
    
    func canHandle(_ command: ParsedCommand) -> Bool {
        guard command.targetApplication == bundleIdentifier else { return false }
        
        // Generic integration can handle basic app control commands
        switch command.intent {
        case .appControl:
            return true
        default:
            return false
        }
    }
    
    func execute(_ command: ParsedCommand) async throws -> CommandResult {
        let startTime = Date()
        
        let result: CommandResult
        
        // Determine the action based on command content
        let lowercaseCommand = command.originalText.lowercased()
        
        if lowercaseCommand.contains("open") || lowercaseCommand.contains("launch") || lowercaseCommand.contains("start") {
            result = try await launchApp()
        } else if lowercaseCommand.contains("quit") || lowercaseCommand.contains("close") || lowercaseCommand.contains("exit") {
            result = try await quitApp()
        } else if lowercaseCommand.contains("minimize") {
            result = try await minimizeWindow()
        } else if lowercaseCommand.contains("new") && (lowercaseCommand.contains("document") || lowercaseCommand.contains("file")) {
            result = try await createNewDocument()
        } else if let filePath = command.parameters["file"] {
            result = try await openFile(filePath)
        } else {
            // Try to execute as a generic command
            result = try await executeGenericCommand(command.originalText)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        return CommandResult(
            success: result.success,
            output: result.output,
            executionTime: executionTime,
            integrationMethod: result.integrationMethod,
            errorMessage: result.errorMessage,
            followUpActions: result.followUpActions
        )
    }
    
    func getCapabilities() -> AppCapabilities {
        return appInfo.capabilities
    }
    
    // MARK: - Private Methods
    
    private func launchApp() async throws -> CommandResult {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppIntegrationError.appNotInstalled(displayName)
        }
        
        do {
            try NSWorkspace.shared.launchApplication(at: appURL, options: [], configuration: [:])
            
            return CommandResult(
                success: true,
                output: "Successfully launched \(displayName)",
                integrationMethod: .accessibility,
                followUpActions: ["\(displayName) is now running"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.accessibility, error.localizedDescription)
        }
    }
    
    private func quitApp() async throws -> CommandResult {
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AppIntegrationError.appNotRunning(displayName)
        }
        
        let success = runningApp.terminate()
        
        if success {
            return CommandResult(
                success: true,
                output: "Successfully quit \(displayName)",
                integrationMethod: .accessibility
            )
        } else {
            // Try force quit as fallback
            let forceSuccess = runningApp.forceTerminate()
            if forceSuccess {
                return CommandResult(
                    success: true,
                    output: "Force quit \(displayName)",
                    integrationMethod: .accessibility
                )
            } else {
                throw AppIntegrationError.integrationMethodFailed(.accessibility, "Failed to quit application")
            }
        }
    }
    
    private func minimizeWindow() async throws -> CommandResult {
        let script = """
        tell application "\(displayName)"
            set miniaturized of front window to true
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Minimized \(displayName) window",
                integrationMethod: .appleScript
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func createNewDocument() async throws -> CommandResult {
        let script = """
        tell application "\(displayName)"
            activate
            make new document
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Created new document in \(displayName)",
                integrationMethod: .appleScript,
                followUpActions: ["You can now start working on your new document"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func openFile(_ filePath: String) async throws -> CommandResult {
        let expandedPath = NSString(string: filePath).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)
        
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw AppIntegrationError.invalidParameters(["File not found: \(filePath)"])
        }
        
        do {
            try NSWorkspace.shared.open([fileURL], withApplicationAt: URL(fileURLWithPath: appInfo.path), options: [], configuration: [:])
            
            return CommandResult(
                success: true,
                output: "Opened \(fileURL.lastPathComponent) with \(displayName)",
                integrationMethod: .accessibility,
                followUpActions: ["The file is now open in \(displayName)"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.accessibility, error.localizedDescription)
        }
    }
    
    private func executeGenericCommand(_ command: String) async throws -> CommandResult {
        // Try to execute a generic AppleScript command
        let script = """
        tell application "\(displayName)"
            activate
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Activated \(displayName)",
                integrationMethod: .appleScript,
                followUpActions: [
                    "\(displayName) is now active",
                    "You may need to perform the specific action manually"
                ]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
}