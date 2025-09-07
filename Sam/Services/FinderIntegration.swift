import Foundation
import AppKit

// MARK: - Finder Integration
class FinderIntegration: AppIntegration {
    
    // MARK: - AppIntegration Protocol
    let bundleIdentifier = "com.apple.finder"
    let displayName = "Finder"
    
    var supportedCommands: [CommandDefinition] {
        return [
            CommandDefinition(
                name: "open_folder",
                description: "Open a folder in Finder",
                parameters: [
                    CommandParameter(name: "path", type: .folder, description: "Folder path to open")
                ],
                examples: ["open Downloads folder", "show Desktop in Finder", "navigate to Documents"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "reveal_file",
                description: "Reveal a file in Finder",
                parameters: [
                    CommandParameter(name: "file", type: .file, description: "File path to reveal")
                ],
                examples: ["show file.txt in Finder", "reveal document.pdf"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "create_folder",
                description: "Create a new folder",
                parameters: [
                    CommandParameter(name: "name", type: .string, description: "Folder name"),
                    CommandParameter(name: "location", type: .folder, isRequired: false, description: "Parent folder location")
                ],
                examples: ["create folder Projects", "make new folder called Archive"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "search_files",
                description: "Search for files",
                parameters: [
                    CommandParameter(name: "query", type: .string, description: "Search query"),
                    CommandParameter(name: "location", type: .folder, isRequired: false, description: "Search location")
                ],
                examples: ["search for PDF files", "find documents containing project"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "empty_trash",
                description: "Empty the Trash",
                parameters: [],
                examples: ["empty trash", "clear trash"],
                integrationMethod: .appleScript,
                requiresConfirmation: true
            )
        ]
    }
    
    let integrationMethods: [IntegrationMethod] = [.appleScript, .accessibility]
    
    var isInstalled: Bool {
        return true // Finder is always available on macOS
    }
    
    // MARK: - Properties
    private let appDiscovery: AppDiscoveryService
    private let appleScriptEngine: AppleScriptEngine
    
    // MARK: - Initialization
    init(appDiscovery: AppDiscoveryService, appleScriptEngine: AppleScriptEngine) {
        self.appDiscovery = appDiscovery
        self.appleScriptEngine = appleScriptEngine
    }
    
    // MARK: - AppIntegration Methods
    
    func canHandle(_ command: ParsedCommand) -> Bool {
        guard command.targetApplication == bundleIdentifier else { return false }
        
        switch command.intent {
        case .appControl, .fileOperation:
            return true
        default:
            return false
        }
    }
    
    func execute(_ command: ParsedCommand) async throws -> CommandResult {
        let startTime = Date()
        
        let result: CommandResult
        let lowercaseCommand = command.originalText.lowercased()
        
        if lowercaseCommand.contains("open") || lowercaseCommand.contains("show") || lowercaseCommand.contains("navigate") {
            if let path = command.parameters["path"] {
                result = try await openFolder(path)
            } else {
                let folderPath = extractFolderPath(from: command.originalText)
                result = try await openFolder(folderPath)
            }
        } else if lowercaseCommand.contains("reveal") {
            if let filePath = command.parameters["file"] {
                result = try await revealFile(filePath)
            } else {
                let filePath = extractFilePath(from: command.originalText)
                result = try await revealFile(filePath)
            }
        } else if lowercaseCommand.contains("create") && lowercaseCommand.contains("folder") {
            let folderName = extractFolderName(from: command.originalText)
            let location = command.parameters["location"]
            result = try await createFolder(name: folderName, location: location)
        } else if lowercaseCommand.contains("search") || lowercaseCommand.contains("find") {
            let query = extractSearchQuery(from: command.originalText)
            result = try await searchFiles(query: query)
        } else if lowercaseCommand.contains("empty") && lowercaseCommand.contains("trash") {
            result = try await emptyTrash()
        } else {
            throw AppIntegrationError.commandNotSupported(command.originalText)
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
        return AppCapabilities(
            canLaunch: true,
            canOpenFiles: true,
            canManageWindows: true,
            canAccessMenus: true,
            customCapabilities: [
                "canNavigate": true,
                "canSearch": true,
                "canCreateFolder": true,
                "canRevealFile": true,
                "canEmptyTrash": true
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func openFolder(_ path: String) async throws -> CommandResult {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let folderURL = URL(fileURLWithPath: expandedPath)
        
        // Check if folder exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AppIntegrationError.invalidParameters(["Folder not found: \(path)"])
        }
        
        let script = """
        tell application "Finder"
            activate
            open folder POSIX file "\(expandedPath)"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Opened \(folderURL.lastPathComponent) in Finder",
                integrationMethod: .appleScript,
                followUpActions: ["You can now browse the folder contents"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func revealFile(_ filePath: String) async throws -> CommandResult {
        let expandedPath = NSString(string: filePath).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)
        
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw AppIntegrationError.invalidParameters(["File not found: \(filePath)"])
        }
        
        let script = """
        tell application "Finder"
            activate
            reveal POSIX file "\(expandedPath)"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Revealed \(fileURL.lastPathComponent) in Finder",
                integrationMethod: .appleScript,
                followUpActions: ["The file is now selected in Finder"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func createFolder(name: String, location: String?) async throws -> CommandResult {
        let parentPath = location ?? NSHomeDirectory()
        let expandedParentPath = NSString(string: parentPath).expandingTildeInPath
        
        let script = """
        tell application "Finder"
            activate
            set parentFolder to folder POSIX file "\(expandedParentPath)"
            make new folder at parentFolder with properties {name:"\(name)"}
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Created folder '\(name)' in \(URL(fileURLWithPath: expandedParentPath).lastPathComponent)",
                integrationMethod: .appleScript,
                followUpActions: ["The new folder is ready for use"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func searchFiles(query: String) async throws -> CommandResult {
        let script = """
        tell application "Finder"
            activate
            set searchResults to (search for "\(query)")
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Searching for '\(query)' in Finder",
                integrationMethod: .appleScript,
                followUpActions: ["Search results will appear in a new Finder window"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func emptyTrash() async throws -> CommandResult {
        let script = """
        tell application "Finder"
            empty trash
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Emptied Trash",
                integrationMethod: .appleScript,
                followUpActions: ["All items in Trash have been permanently deleted"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    // MARK: - Text Extraction Helpers
    
    private func extractFolderPath(from input: String) -> String {
        let commonFolders = [
            "desktop": "~/Desktop",
            "downloads": "~/Downloads",
            "documents": "~/Documents",
            "pictures": "~/Pictures",
            "music": "~/Music",
            "movies": "~/Movies",
            "applications": "/Applications",
            "home": "~"
        ]
        
        let lowercaseInput = input.lowercased()
        for (keyword, path) in commonFolders {
            if lowercaseInput.contains(keyword) {
                return path
            }
        }
        
        // Try to extract path from input
        let pathRegex = try! NSRegularExpression(pattern: #"[~/][^\s]+"#)
        let matches = pathRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if let match = matches.first {
            return String(input[Range(match.range, in: input)!])
        }
        
        return "~/Desktop" // Default fallback
    }
    
    private func extractFilePath(from input: String) -> String {
        let fileRegex = try! NSRegularExpression(pattern: #"[~/][^\s]+"#)
        let matches = fileRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if let match = matches.first {
            return String(input[Range(match.range, in: input)!])
        }
        
        // Try to extract filename
        let filenameRegex = try! NSRegularExpression(pattern: #"([^\s]+\.[a-zA-Z]{2,4})"#)
        let filenameMatches = filenameRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if let match = filenameMatches.first {
            let filename = String(input[Range(match.range, in: input)!])
            return "~/Desktop/\(filename)" // Assume Desktop as default location
        }
        
        return "~/Desktop" // Default fallback
    }
    
    private func extractFolderName(from input: String) -> String {
        let patterns = [
            "create folder (?:called )?(.+)",
            "make (?:new )?folder (?:called )?(.+)",
            "new folder (?:called )?(.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let nameRange = Range(match.range(at: 1), in: input) {
                        return String(input[nameRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        return "New Folder"
    }
    
    private func extractSearchQuery(from input: String) -> String {
        let patterns = [
            "search for (.+)",
            "find (.+)",
            "look for (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let queryRange = Range(match.range(at: 1), in: input) {
                        return String(input[queryRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        return input
    }
}