import SwiftUI
import Combine

@MainActor
class CommandDiscoveryManager: ObservableObject {
    @Published var suggestions: [CommandSuggestion] = []
    @Published var contextualTips: [ContextualTip] = []
    @Published var showingSuggestions = false
    
    private let chatManager: ChatManager
    private let contextManager: ContextManager
    private let userDefaults = UserDefaults.standard
    
    private let suggestionDisplayedKey = "SuggestionDisplayed"
    private let tipDisplayedKey = "TipDisplayed"
    
    init(chatManager: ChatManager, contextManager: ContextManager) {
        self.chatManager = chatManager
        self.contextManager = contextManager
    }
    
    func generateSuggestions(for context: DiscoveryContext) {
        let newSuggestions = getSuggestionsForContext(context)
        
        // Filter out already shown suggestions
        let filteredSuggestions = newSuggestions.filter { suggestion in
            !hasShownSuggestion(suggestion.id)
        }
        
        suggestions = filteredSuggestions
        showingSuggestions = !suggestions.isEmpty
        
        // Generate contextual tips
        contextualTips = getTipsForContext(context)
    }
    
    func dismissSuggestion(_ suggestion: CommandSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
        markSuggestionAsShown(suggestion.id)
        
        if suggestions.isEmpty {
            showingSuggestions = false
        }
    }
    
    func useSuggestion(_ suggestion: CommandSuggestion) {
        // Track usage for learning
        trackSuggestionUsage(suggestion)
        
        // Execute or copy the suggestion
        switch suggestion.action {
        case .execute(let command):
            chatManager.sendMessage(command)
        case .copy(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .showHelp(let topic):
            // Show help for specific topic
            break
        }
        
        dismissSuggestion(suggestion)
    }
    
    private func getSuggestionsForContext(_ context: DiscoveryContext) -> [CommandSuggestion] {
        switch context {
        case .firstLaunch:
            return getFirstLaunchSuggestions()
        case .emptyChat:
            return getEmptyChatSuggestions()
        case .afterFileOperation:
            return getFileOperationSuggestions()
        case .afterSystemQuery:
            return getSystemQuerySuggestions()
        case .errorOccurred(let error):
            return getErrorRecoverySuggestions(for: error)
        case .fileSelected(let fileURL):
            return getFileContextSuggestions(for: fileURL)
        case .appFocused(let appName):
            return getAppContextSuggestions(for: appName)
        case .timeOfDay(let hour):
            return getTimeBasedSuggestions(for: hour)
        }
    }
    
    private func getFirstLaunchSuggestions() -> [CommandSuggestion] {
        return [
            CommandSuggestion(
                id: "first_launch_battery",
                title: "Check Your Battery",
                description: "Try asking about your Mac's current status",
                command: "What's my battery percentage?",
                action: .execute("What's my battery percentage?"),
                priority: .high,
                category: .systemInfo
            ),
            CommandSuggestion(
                id: "first_launch_files",
                title: "Organize Your Files",
                description: "Let Sam help organize your Desktop",
                command: "Organize my Desktop by file type",
                action: .execute("Organize my Desktop by file type"),
                priority: .medium,
                category: .fileOperations
            ),
            CommandSuggestion(
                id: "first_launch_help",
                title: "Learn More",
                description: "Explore what Sam can do for you",
                command: "Show me help",
                action: .showHelp(.gettingStarted),
                priority: .low,
                category: .help
            )
        ]
    }
    
    private func getEmptyChatSuggestions() -> [CommandSuggestion] {
        let recentFiles = contextManager.getRecentFiles()
        var suggestions: [CommandSuggestion] = []
        
        // File-based suggestions
        if !recentFiles.isEmpty {
            suggestions.append(CommandSuggestion(
                id: "recent_files_organize",
                title: "Organize Recent Files",
                description: "Clean up files you've been working with",
                command: "Organize my recent files",
                action: .execute("Organize my recent files"),
                priority: .medium,
                category: .fileOperations
            ))
        }
        
        // Time-based suggestions
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            suggestions.append(CommandSuggestion(
                id: "morning_system_check",
                title: "Morning System Check",
                description: "Check your Mac's status to start the day",
                command: "Show me system status",
                action: .execute("Show me system status"),
                priority: .medium,
                category: .systemInfo
            ))
        }
        
        // General suggestions
        suggestions.append(contentsOf: [
            CommandSuggestion(
                id: "empty_chat_storage",
                title: "Check Storage",
                description: "See how much space you have available",
                command: "How much storage do I have left?",
                action: .execute("How much storage do I have left?"),
                priority: .low,
                category: .systemInfo
            ),
            CommandSuggestion(
                id: "empty_chat_apps",
                title: "Control Apps",
                description: "Try opening an application",
                command: "Open Safari",
                action: .execute("Open Safari"),
                priority: .low,
                category: .appControl
            )
        ])
        
        return suggestions
    }
    
    private func getFileOperationSuggestions() -> [CommandSuggestion] {
        return [
            CommandSuggestion(
                id: "after_file_op_cleanup",
                title: "Clean Up More",
                description: "Continue organizing other folders",
                command: "Organize Downloads folder",
                action: .execute("Organize Downloads folder"),
                priority: .medium,
                category: .fileOperations
            ),
            CommandSuggestion(
                id: "after_file_op_backup",
                title: "Backup Important Files",
                description: "Create a backup of your organized files",
                command: "Backup Documents to external drive",
                action: .execute("Backup Documents to external drive"),
                priority: .low,
                category: .fileOperations
            )
        ]
    }
    
    private func getSystemQuerySuggestions() -> [CommandSuggestion] {
        return [
            CommandSuggestion(
                id: "after_system_memory",
                title: "Check Memory Usage",
                description: "See how your Mac is performing",
                command: "What's my RAM usage?",
                action: .execute("What's my RAM usage?"),
                priority: .medium,
                category: .systemInfo
            ),
            CommandSuggestion(
                id: "after_system_network",
                title: "Network Status",
                description: "Check your internet connection",
                command: "Am I connected to WiFi?",
                action: .execute("Am I connected to WiFi?"),
                priority: .low,
                category: .systemInfo
            )
        ]
    }
    
    private func getErrorRecoverySuggestions(for error: SamError) -> [CommandSuggestion] {
        switch error {
        case .fileOperation(.insufficientPermissions):
            return [
                CommandSuggestion(
                    id: "error_permissions_help",
                    title: "Fix Permissions",
                    description: "Learn how to grant file access permissions",
                    command: "How do I grant file permissions?",
                    action: .showHelp(.troubleshooting),
                    priority: .high,
                    category: .help
                )
            ]
        case .systemAccess:
            return [
                CommandSuggestion(
                    id: "error_system_access_help",
                    title: "System Access Help",
                    description: "Learn about system permissions",
                    command: "Help with system permissions",
                    action: .showHelp(.troubleshooting),
                    priority: .high,
                    category: .help
                )
            ]
        default:
            return [
                CommandSuggestion(
                    id: "error_general_help",
                    title: "Get Help",
                    description: "Find solutions to common problems",
                    command: "Show troubleshooting guide",
                    action: .showHelp(.troubleshooting),
                    priority: .medium,
                    category: .help
                )
            ]
        }
    }
    
    private func getFileContextSuggestions(for fileURL: URL) -> [CommandSuggestion] {
        let fileExtension = fileURL.pathExtension.lowercased()
        var suggestions: [CommandSuggestion] = []
        
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic":
            suggestions.append(CommandSuggestion(
                id: "file_image_organize",
                title: "Organize Images",
                description: "Move this image to Pictures folder",
                command: "Move \(fileURL.lastPathComponent) to Pictures",
                action: .execute("Move \(fileURL.lastPathComponent) to Pictures"),
                priority: .high,
                category: .fileOperations
            ))
        case "pdf":
            suggestions.append(CommandSuggestion(
                id: "file_pdf_organize",
                title: "Organize Document",
                description: "Move this PDF to Documents folder",
                command: "Move \(fileURL.lastPathComponent) to Documents",
                action: .execute("Move \(fileURL.lastPathComponent) to Documents"),
                priority: .high,
                category: .fileOperations
            ))
        case "mp4", "mov", "avi":
            suggestions.append(CommandSuggestion(
                id: "file_video_organize",
                title: "Organize Video",
                description: "Move this video to Movies folder",
                command: "Move \(fileURL.lastPathComponent) to Movies",
                action: .execute("Move \(fileURL.lastPathComponent) to Movies"),
                priority: .high,
                category: .fileOperations
            ))
        default:
            break
        }
        
        // General file suggestions
        suggestions.append(contentsOf: [
            CommandSuggestion(
                id: "file_copy_desktop",
                title: "Copy to Desktop",
                description: "Make a copy on your Desktop",
                command: "Copy \(fileURL.lastPathComponent) to Desktop",
                action: .execute("Copy \(fileURL.lastPathComponent) to Desktop"),
                priority: .medium,
                category: .fileOperations
            ),
            CommandSuggestion(
                id: "file_get_info",
                title: "File Information",
                description: "Get details about this file",
                command: "Show info for \(fileURL.lastPathComponent)",
                action: .execute("Show info for \(fileURL.lastPathComponent)"),
                priority: .low,
                category: .fileOperations
            )
        ])
        
        return suggestions
    }
    
    private func getAppContextSuggestions(for appName: String) -> [CommandSuggestion] {
        switch appName.lowercased() {
        case "safari":
            return [
                CommandSuggestion(
                    id: "app_safari_bookmark",
                    title: "Bookmark Page",
                    description: "Save the current page to bookmarks",
                    command: "Bookmark this page",
                    action: .execute("Bookmark this page"),
                    priority: .high,
                    category: .appControl
                )
            ]
        case "finder":
            return [
                CommandSuggestion(
                    id: "app_finder_organize",
                    title: "Organize Current Folder",
                    description: "Clean up the folder you're viewing",
                    command: "Organize this folder",
                    action: .execute("Organize this folder"),
                    priority: .high,
                    category: .fileOperations
                )
            ]
        case "mail":
            return [
                CommandSuggestion(
                    id: "app_mail_compose",
                    title: "Compose Email",
                    description: "Create a new email message",
                    command: "Compose new email",
                    action: .execute("Compose new email"),
                    priority: .high,
                    category: .appControl
                )
            ]
        default:
            return []
        }
    }
    
    private func getTimeBasedSuggestions(for hour: Int) -> [CommandSuggestion] {
        switch hour {
        case 6...11: // Morning
            return [
                CommandSuggestion(
                    id: "morning_cleanup",
                    title: "Morning Cleanup",
                    description: "Start your day with a clean workspace",
                    command: "Organize Desktop and Downloads",
                    action: .execute("Organize Desktop and Downloads"),
                    priority: .medium,
                    category: .fileOperations
                )
            ]
        case 17...22: // Evening
            return [
                CommandSuggestion(
                    id: "evening_backup",
                    title: "Evening Backup",
                    description: "Back up your work from today",
                    command: "Backup today's work",
                    action: .execute("Backup today's work"),
                    priority: .medium,
                    category: .fileOperations
                )
            ]
        default:
            return []
        }
    }
    
    private func getTipsForContext(_ context: DiscoveryContext) -> [ContextualTip] {
        switch context {
        case .firstLaunch:
            return [
                ContextualTip(
                    title: "Natural Language Commands",
                    content: "You can talk to Sam naturally. No need to learn special syntax or commands.",
                    example: "Copy all my photos to the Pictures folder",
                    context: .firstLaunch
                ),
                ContextualTip(
                    title: "Privacy First",
                    content: "Sam processes simple tasks locally to protect your privacy. Complex requests may use cloud AI with your permission.",
                    context: .firstLaunch
                )
            ]
        case .emptyChat:
            return [
                ContextualTip(
                    title: "Start Simple",
                    content: "Try asking about your system status or organizing files to get started.",
                    example: "What's my battery level?",
                    context: .emptyChat
                )
            ]
        case .afterFileOperation:
            return [
                ContextualTip(
                    title: "Undo Operations",
                    content: "Most file operations can be undone. Just ask Sam to undo the last action.",
                    example: "Undo the last file operation",
                    context: .afterFileOperation
                )
            ]
        default:
            return []
        }
    }
    
    private func hasShownSuggestion(_ id: String) -> Bool {
        let key = "\(suggestionDisplayedKey)_\(id)"
        return userDefaults.bool(forKey: key)
    }
    
    private func markSuggestionAsShown(_ id: String) {
        let key = "\(suggestionDisplayedKey)_\(id)"
        userDefaults.set(true, forKey: key)
    }
    
    private func trackSuggestionUsage(_ suggestion: CommandSuggestion) {
        // Track suggestion usage for learning and improvement
        let usageKey = "SuggestionUsage_\(suggestion.id)"
        let currentCount = userDefaults.integer(forKey: usageKey)
        userDefaults.set(currentCount + 1, forKey: usageKey)
    }
}

enum DiscoveryContext {
    case firstLaunch
    case emptyChat
    case afterFileOperation
    case afterSystemQuery
    case errorOccurred(SamError)
    case fileSelected(URL)
    case appFocused(String)
    case timeOfDay(Int)
}

struct CommandSuggestion: Identifiable {
    let id: String
    let title: String
    let description: String
    let command: String
    let action: SuggestionAction
    let priority: SuggestionPriority
    let category: SuggestionCategory
}

enum SuggestionAction {
    case execute(String)
    case copy(String)
    case showHelp(HelpCategory)
}

enum SuggestionPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum SuggestionCategory {
    case fileOperations
    case systemInfo
    case appControl
    case workflows
    case help
}