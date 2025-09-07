import Foundation
import AppKit

/// Demo class to showcase Safari integration capabilities
class SafariIntegrationDemo {
    
    private let appDiscovery = AppDiscoveryService()
    private let urlSchemeHandler = URLSchemeHandler()
    private let appleScriptEngine = AppleScriptEngine()
    private lazy var safariIntegration = SafariIntegration(
        appDiscovery: appDiscovery,
        urlSchemeHandler: urlSchemeHandler,
        appleScriptEngine: appleScriptEngine
    )
    
    /// Run a comprehensive demo of Safari integration features
    func runDemo() async {
        print("🌐 Safari Integration Demo")
        print("=" * 50)
        
        // Check if Safari is installed
        guard safariIntegration.isInstalled else {
            print("❌ Safari is not installed on this system")
            return
        }
        
        print("✅ Safari is installed")
        print()
        
        // Show capabilities
        await showCapabilities()
        
        // Show supported commands
        await showSupportedCommands()
        
        // Demo URL opening
        await demoURLOpening()
        
        // Demo bookmark management
        await demoBookmarkManagement()
        
        // Demo tab management
        await demoTabManagement()
        
        // Demo history search
        await demoHistorySearch()
        
        // Demo page info
        await demoPageInfo()
        
        print("\n🎉 Safari Integration Demo Complete!")
    }
    
    private func showCapabilities() async {
        print("📋 Safari Integration Capabilities:")
        let capabilities = safariIntegration.getCapabilities()
        
        print("  • Can Launch: \(capabilities.canLaunch ? "✅" : "❌")")
        print("  • Can Quit: \(capabilities.canQuit ? "✅" : "❌")")
        print("  • Can Manage Windows: \(capabilities.canManageWindows ? "✅" : "❌")")
        
        print("  Custom Capabilities:")
        for (key, value) in capabilities.customCapabilities {
            print("    - \(key): \(value ? "✅" : "❌")")
        }
        print()
    }
    
    private func showSupportedCommands() async {
        print("🔧 Supported Commands:")
        let commands = safariIntegration.supportedCommands
        
        for command in commands {
            print("  • \(command.name): \(command.description)")
            if !command.examples.isEmpty {
                print("    Examples: \(command.examples.joined(separator: ", "))")
            }
        }
        print()
    }
    
    private func demoURLOpening() async {
        print("🌍 URL Opening Demo:")
        
        let urlCommands = [
            "open google.com",
            "go to apple.com",
            "visit https://github.com"
        ]
        
        for commandText in urlCommands {
            print("  Command: '\(commandText)'")
            
            let command = ParsedCommand(
                originalText: commandText,
                intent: .appControl,
                parameters: extractURLFromCommand(commandText),
                confidence: 0.9,
                requiresConfirmation: false,
                targetApplication: "com.apple.Safari"
            )
            
            if safariIntegration.canHandle(command) {
                print("    ✅ Can handle this command")
                // Note: Not actually executing to avoid opening browsers during demo
                print("    📝 Would open URL in Safari")
            } else {
                print("    ❌ Cannot handle this command")
            }
        }
        print()
    }
    
    private func demoBookmarkManagement() async {
        print("🔖 Bookmark Management Demo:")
        
        let bookmarkCommands = [
            "bookmark this page",
            "bookmark in Work folder",
            "create bookmark folder Development",
            "organize bookmarks in Projects"
        ]
        
        for commandText in bookmarkCommands {
            print("  Command: '\(commandText)'")
            
            let command = ParsedCommand(
                originalText: commandText,
                intent: .appControl,
                parameters: extractBookmarkParameters(commandText),
                confidence: 0.9,
                requiresConfirmation: false,
                targetApplication: "com.apple.Safari"
            )
            
            if safariIntegration.canHandle(command) {
                print("    ✅ Can handle this command")
                print("    📝 Would manage Safari bookmarks")
            } else {
                print("    ❌ Cannot handle this command")
            }
        }
        print()
    }
    
    private func demoTabManagement() async {
        print("📑 Tab Management Demo:")
        
        let tabCommands = [
            "new tab",
            "new tab with google.com",
            "close tab",
            "next tab",
            "previous tab",
            "go to tab 3",
            "find tab github",
            "switch to tab containing apple"
        ]
        
        for commandText in tabCommands {
            print("  Command: '\(commandText)'")
            
            let command = ParsedCommand(
                originalText: commandText,
                intent: .appControl,
                parameters: extractTabParameters(commandText),
                confidence: 0.9,
                requiresConfirmation: false,
                targetApplication: "com.apple.Safari"
            )
            
            if safariIntegration.canHandle(command) {
                print("    ✅ Can handle this command")
                print("    📝 Would manage Safari tabs")
            } else {
                print("    ❌ Cannot handle this command")
            }
        }
        print()
    }
    
    private func demoHistorySearch() async {
        print("🔍 History Search Demo:")
        
        let historyCommands = [
            "search history for apple",
            "find in history swift documentation"
        ]
        
        for commandText in historyCommands {
            print("  Command: '\(commandText)'")
            
            let command = ParsedCommand(
                originalText: commandText,
                intent: .appControl,
                parameters: extractHistoryParameters(commandText),
                confidence: 0.9,
                requiresConfirmation: false,
                targetApplication: "com.apple.Safari"
            )
            
            if safariIntegration.canHandle(command) {
                print("    ✅ Can handle this command")
                print("    📝 Would search Safari history")
            } else {
                print("    ❌ Cannot handle this command")
            }
        }
        print()
    }
    
    private func demoPageInfo() async {
        print("📄 Page Info Demo:")
        
        let pageCommands = [
            "what page am I on",
            "current page info",
            "get page title"
        ]
        
        for commandText in pageCommands {
            print("  Command: '\(commandText)'")
            
            let command = ParsedCommand(
                originalText: commandText,
                intent: .appControl,
                parameters: [:],
                confidence: 0.9,
                requiresConfirmation: false,
                targetApplication: "com.apple.Safari"
            )
            
            if safariIntegration.canHandle(command) {
                print("    ✅ Can handle this command")
                print("    📝 Would get current page information")
            } else {
                print("    ❌ Cannot handle this command")
            }
        }
        print()
    }
    
    // MARK: - Helper Methods
    
    private func extractURLFromCommand(_ command: String) -> [String: Any] {
        let patterns = [
            "open (.+)",
            "go to (.+)",
            "visit (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(command.startIndex..<command.endIndex, in: command)
                if let match = regex.firstMatch(in: command, options: [], range: range) {
                    if let urlRange = Range(match.range(at: 1), in: command) {
                        let url = String(command[urlRange]).trimmingCharacters(in: .whitespaces)
                        return ["url": url]
                    }
                }
            }
        }
        
        return [:]
    }
    
    private func extractBookmarkParameters(_ command: String) -> [String: Any] {
        if command.contains("bookmark in") {
            let pattern = "bookmark in (.+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(command.startIndex..<command.endIndex, in: command)
                if let match = regex.firstMatch(in: command, options: [], range: range) {
                    if let folderRange = Range(match.range(at: 1), in: command) {
                        let folder = String(command[folderRange]).trimmingCharacters(in: .whitespaces)
                        return ["folder": folder]
                    }
                }
            }
        } else if command.contains("create bookmark folder") || command.contains("organize bookmarks in") {
            let patterns = [
                "create bookmark folder (.+)",
                "organize bookmarks in (.+)"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(command.startIndex..<command.endIndex, in: command)
                    if let match = regex.firstMatch(in: command, options: [], range: range) {
                        if let folderRange = Range(match.range(at: 1), in: command) {
                            let folder = String(command[folderRange]).trimmingCharacters(in: .whitespaces)
                            return ["folder_name": folder]
                        }
                    }
                }
            }
        }
        
        return [:]
    }
    
    private func extractTabParameters(_ command: String) -> [String: Any] {
        if command.contains("new tab with") {
            let pattern = "new tab with (.+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(command.startIndex..<command.endIndex, in: command)
                if let match = regex.firstMatch(in: command, options: [], range: range) {
                    if let urlRange = Range(match.range(at: 1), in: command) {
                        let url = String(command[urlRange]).trimmingCharacters(in: .whitespaces)
                        return ["url": url]
                    }
                }
            }
        } else if command.contains("go to tab") {
            let pattern = "go to tab (\\d+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(command.startIndex..<command.endIndex, in: command)
                if let match = regex.firstMatch(in: command, options: [], range: range) {
                    if let numberRange = Range(match.range(at: 1), in: command) {
                        let direction = String(command[numberRange])
                        return ["direction": direction]
                    }
                }
            }
        } else if command.contains("find tab") || command.contains("switch to tab") {
            let patterns = [
                "find tab (.+)",
                "switch to tab containing (.+)"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(command.startIndex..<command.endIndex, in: command)
                    if let match = regex.firstMatch(in: command, options: [], range: range) {
                        if let queryRange = Range(match.range(at: 1), in: command) {
                            let query = String(command[queryRange]).trimmingCharacters(in: .whitespaces)
                            return ["query": query]
                        }
                    }
                }
            }
        } else if command.contains("next tab") {
            return ["direction": "next"]
        } else if command.contains("previous tab") {
            return ["direction": "previous"]
        }
        
        return [:]
    }
    
    private func extractHistoryParameters(_ command: String) -> [String: Any] {
        let patterns = [
            "search history for (.+)",
            "find in history (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(command.startIndex..<command.endIndex, in: command)
                if let match = regex.firstMatch(in: command, options: [], range: range) {
                    if let queryRange = Range(match.range(at: 1), in: command) {
                        let query = String(command[queryRange]).trimmingCharacters(in: .whitespaces)
                        return ["query": query]
                    }
                }
            }
        }
        
        return [:]
    }
}

// MARK: - String Extension for Demo

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Demo Runner

/// Run the Safari integration demo
func runSafariIntegrationDemo() async {
    let demo = SafariIntegrationDemo()
    await demo.runDemo()
}