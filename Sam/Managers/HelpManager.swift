import SwiftUI
import Combine

enum HelpCategory: String, CaseIterable {
    case gettingStarted = "getting_started"
    case commands = "commands"
    case fileOperations = "file_operations"
    case systemInfo = "system_info"
    case appIntegration = "app_integration"
    case workflows = "workflows"
    case settings = "settings"
    case troubleshooting = "troubleshooting"
    
    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .commands: return "Commands"
        case .fileOperations: return "File Operations"
        case .systemInfo: return "System Info"
        case .appIntegration: return "App Integration"
        case .workflows: return "Workflows"
        case .settings: return "Settings"
        case .troubleshooting: return "Troubleshooting"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "play.circle"
        case .commands: return "terminal"
        case .fileOperations: return "folder"
        case .systemInfo: return "info.circle"
        case .appIntegration: return "app.connected.to.app.below.fill"
        case .workflows: return "flowchart"
        case .settings: return "gear"
        case .troubleshooting: return "wrench.and.screwdriver"
        }
    }
    
    var description: String {
        switch self {
        case .gettingStarted: return "Learn the basics of using Sam"
        case .commands: return "Explore available commands and syntax"
        case .fileOperations: return "File management and organization"
        case .systemInfo: return "System queries and information"
        case .appIntegration: return "Control other macOS applications"
        case .workflows: return "Automate multi-step tasks"
        case .settings: return "Configure Sam's behavior"
        case .troubleshooting: return "Solve common problems"
        }
    }
}

enum CommandType: String, CaseIterable {
    case fileOperations = "file_operations"
    case systemQueries = "system_queries"
    case appControl = "app_control"
    case textProcessing = "text_processing"
    case workflows = "workflows"
    
    var title: String {
        switch self {
        case .fileOperations: return "File Operations"
        case .systemQueries: return "System Queries"
        case .appControl: return "App Control"
        case .textProcessing: return "Text Processing"
        case .workflows: return "Workflows"
        }
    }
    
    var examples: [CommandExample] {
        switch self {
        case .fileOperations:
            return [
                CommandExample(
                    command: "copy file.txt to Desktop",
                    description: "Copy a specific file to a destination",
                    category: "Basic Copy"
                ),
                CommandExample(
                    command: "move all PDFs from Downloads to Documents",
                    description: "Move files by type to a folder",
                    category: "Batch Move"
                ),
                CommandExample(
                    command: "organize Desktop by file type",
                    description: "Automatically organize files into folders",
                    category: "Organization"
                ),
                CommandExample(
                    command: "find all images larger than 10MB",
                    description: "Search files by type and size",
                    category: "Search"
                )
            ]
        case .systemQueries:
            return [
                CommandExample(
                    command: "what's my battery percentage?",
                    description: "Get current battery level",
                    category: "Battery"
                ),
                CommandExample(
                    command: "how much storage do I have left?",
                    description: "Check available disk space",
                    category: "Storage"
                ),
                CommandExample(
                    command: "what's my RAM usage?",
                    description: "View memory consumption",
                    category: "Memory"
                ),
                CommandExample(
                    command: "show running applications",
                    description: "List currently running apps",
                    category: "Processes"
                )
            ]
        case .appControl:
            return [
                CommandExample(
                    command: "open Safari and go to apple.com",
                    description: "Launch app and navigate to URL",
                    category: "Web Browsing"
                ),
                CommandExample(
                    command: "send email to john@example.com about meeting",
                    description: "Compose and send email",
                    category: "Email"
                ),
                CommandExample(
                    command: "create calendar event for tomorrow at 2 PM",
                    description: "Schedule new calendar event",
                    category: "Calendar"
                ),
                CommandExample(
                    command: "add reminder to call mom",
                    description: "Create new reminder",
                    category: "Reminders"
                )
            ]
        case .textProcessing:
            return [
                CommandExample(
                    command: "summarize this document",
                    description: "Create summary of text content",
                    category: "Summarization"
                ),
                CommandExample(
                    command: "translate this text to Spanish",
                    description: "Translate text to another language",
                    category: "Translation"
                ),
                CommandExample(
                    command: "format this code snippet",
                    description: "Format and beautify code",
                    category: "Code Formatting"
                ),
                CommandExample(
                    command: "extract key points from this article",
                    description: "Identify main points in text",
                    category: "Analysis"
                )
            ]
        case .workflows:
            return [
                CommandExample(
                    command: "create workflow to organize downloads daily",
                    description: "Set up recurring file organization",
                    category: "Automation"
                ),
                CommandExample(
                    command: "backup project files to external drive",
                    description: "Multi-step backup process",
                    category: "Backup"
                ),
                CommandExample(
                    command: "prepare presentation: create folder, open Keynote, set timer",
                    description: "Complex multi-app workflow",
                    category: "Productivity"
                )
            ]
        }
    }
}

struct CommandExample {
    let command: String
    let description: String
    let category: String
}

@MainActor
class HelpManager: ObservableObject {
    @Published var showingOnboarding = false
    @Published var showingCommandPalette = false
    @Published var showingKeyboardShortcuts = false
    @Published var searchResults: [HelpSearchResult] = []
    
    private let searchIndex = HelpSearchIndex()
    
    func showOnboarding() {
        showingOnboarding = true
    }
    
    func showCommandPalette() {
        showingCommandPalette = true
    }
    
    func showKeyboardShortcuts() {
        showingKeyboardShortcuts = true
    }
    
    func search(_ query: String) -> [HelpSearchResult] {
        guard !query.isEmpty else { return [] }
        return searchIndex.search(query)
    }
    
    func getContextualHelp(for taskType: TaskType) -> [CommandExample] {
        switch taskType {
        case .fileOperation:
            return CommandType.fileOperations.examples
        case .systemQuery:
            return CommandType.systemQueries.examples
        case .appControl:
            return CommandType.appControl.examples
        case .textProcessing:
            return CommandType.textProcessing.examples
        case .automation:
            return CommandType.workflows.examples
        default:
            return []
        }
    }
}

struct HelpSearchResult {
    let title: String
    let content: String
    let category: HelpCategory
    let relevanceScore: Double
}

class HelpSearchIndex {
    private let helpContent: [HelpCategory: [String]] = [
        .gettingStarted: [
            "welcome", "first steps", "basic commands", "setup", "permissions",
            "getting started", "introduction", "tutorial", "guide"
        ],
        .commands: [
            "commands", "syntax", "examples", "reference", "language",
            "natural language", "how to", "instructions"
        ],
        .fileOperations: [
            "files", "copy", "move", "delete", "organize", "search",
            "folders", "directories", "file management", "finder"
        ],
        .systemInfo: [
            "system", "battery", "storage", "memory", "network", "status",
            "information", "hardware", "performance", "monitoring"
        ],
        .appIntegration: [
            "apps", "applications", "safari", "mail", "calendar", "control",
            "automation", "integration", "third-party"
        ],
        .workflows: [
            "workflows", "automation", "multi-step", "tasks", "scheduling",
            "batch", "recurring", "complex", "sequences"
        ],
        .settings: [
            "settings", "configuration", "preferences", "api key", "setup",
            "customization", "options", "privacy", "security"
        ],
        .troubleshooting: [
            "problems", "issues", "errors", "troubleshooting", "help",
            "fix", "solve", "debug", "support", "faq"
        ]
    ]
    
    func search(_ query: String) -> [HelpSearchResult] {
        let lowercaseQuery = query.lowercased()
        var results: [HelpSearchResult] = []
        
        for (category, keywords) in helpContent {
            let relevanceScore = calculateRelevance(query: lowercaseQuery, keywords: keywords)
            
            if relevanceScore > 0 {
                results.append(HelpSearchResult(
                    title: category.title,
                    content: category.description,
                    category: category,
                    relevanceScore: relevanceScore
                ))
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func calculateRelevance(query: String, keywords: [String]) -> Double {
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
        var totalScore = 0.0
        
        for queryWord in queryWords {
            for keyword in keywords {
                if keyword.contains(queryWord) {
                    totalScore += keyword == queryWord ? 1.0 : 0.5
                }
            }
        }
        
        return totalScore / Double(queryWords.count)
    }
}

// MARK: - Supporting Models

struct FileOperationCard: View {
    let icon: String
    let title: String
    let examples: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(examples, id: \.self) { example in
                    Text("• \(example)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SystemInfoCard: View {
    let icon: String
    let title: String
    let examples: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(examples, id: \.self) { example in
                    Text("• \(example)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct CommandExampleCard: View {
    let example: CommandExample
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(example.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(example.command, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy command")
            }
            
            Text(example.command)
                .font(.body)
                .fontFamily(.monospaced)
            
            Text(example.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct AppIntegrationSection: View {
    let appName: String
    let icon: String
    let examples: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                
                Text(appName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(examples, id: \.self) { example in
                    Text("• \(example)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WorkflowExampleCard: View {
    let title: String
    let description: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Steps:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingSection: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct TroubleshootingItem: View {
    let problem: String
    let solution: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                
                Text(problem)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(solution)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}