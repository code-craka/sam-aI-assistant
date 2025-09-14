import SwiftUI

struct CommandPaletteView: View {
    @StateObject private var commandSuggestionManager = CommandSuggestionManager()
    @State private var searchText = ""
    @State private var selectedCategory: CommandCategory = .all
    @Environment(\.dismiss) private var dismiss
    
    var filteredCommands: [SuggestedCommand] {
        commandSuggestionManager.getFilteredCommands(
            searchText: searchText,
            category: selectedCategory
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Command Examples")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Discover what Sam can do with these example commands")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search commands...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Category filter
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(CommandCategory.allCases, id: \.self) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                
                Divider()
                
                // Commands list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCommands) { command in
                            CommandSuggestionCard(
                                command: command,
                                onUse: { useCommand(command) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 700, height: 600)
        .navigationTitle("Command Palette")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
    
    private func useCommand(_ command: SuggestedCommand) {
        // Copy to clipboard and optionally execute
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command.text, forType: .string)
        
        // Track usage for learning
        commandSuggestionManager.trackCommandUsage(command)
        
        // Optionally close palette and execute command
        dismiss()
    }
}

struct CommandSuggestionCard: View {
    let command: SuggestedCommand
    let onUse: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category and difficulty
            HStack {
                Text(command.category.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                DifficultyIndicator(level: command.difficulty)
            }
            
            // Command text
            HStack {
                Text(command.text)
                    .font(.body)
                    .fontFamily(.monospaced)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command.text, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy to clipboard")
                    
                    Button("Use") {
                        onUse()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // Description
            Text(command.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Tags
            if !command.tags.isEmpty {
                HStack {
                    ForEach(command.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

struct DifficultyIndicator: View {
    let level: CommandDifficulty
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= level.rawValue ? level.color : Color(.quaternaryLabelColor))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

enum CommandCategory: String, CaseIterable {
    case all = "all"
    case fileOperations = "file_operations"
    case systemInfo = "system_info"
    case appControl = "app_control"
    case textProcessing = "text_processing"
    case workflows = "workflows"
    case productivity = "productivity"
    
    var title: String {
        switch self {
        case .all: return "All"
        case .fileOperations: return "Files"
        case .systemInfo: return "System"
        case .appControl: return "Apps"
        case .textProcessing: return "Text"
        case .workflows: return "Workflows"
        case .productivity: return "Productivity"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .fileOperations: return "folder"
        case .systemInfo: return "info.circle"
        case .appControl: return "app"
        case .textProcessing: return "textformat"
        case .workflows: return "flowchart"
        case .productivity: return "briefcase"
        }
    }
}

enum CommandDifficulty: Int, CaseIterable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    
    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct SuggestedCommand: Identifiable {
    let id = UUID()
    let text: String
    let description: String
    let category: CommandCategory
    let difficulty: CommandDifficulty
    let tags: [String]
    let usageCount: Int
    let isPopular: Bool
    
    init(text: String, description: String, category: CommandCategory, difficulty: CommandDifficulty = .beginner, tags: [String] = [], usageCount: Int = 0) {
        self.text = text
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.tags = tags
        self.usageCount = usageCount
        self.isPopular = usageCount > 10
    }
}

@MainActor
class CommandSuggestionManager: ObservableObject {
    @Published var suggestedCommands: [SuggestedCommand] = []
    @Published var recentCommands: [SuggestedCommand] = []
    @Published var popularCommands: [SuggestedCommand] = []
    
    private let userDefaults = UserDefaults.standard
    private let commandUsageKey = "CommandUsageStats"
    
    init() {
        loadPredefinedCommands()
        loadUsageStats()
    }
    
    func getFilteredCommands(searchText: String, category: CommandCategory) -> [SuggestedCommand] {
        var commands = suggestedCommands
        
        // Filter by category
        if category != .all {
            commands = commands.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            commands = commands.filter { command in
                command.text.localizedCaseInsensitiveContains(searchText) ||
                command.description.localizedCaseInsensitiveContains(searchText) ||
                command.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sort by relevance and popularity
        return commands.sorted { lhs, rhs in
            if lhs.isPopular != rhs.isPopular {
                return lhs.isPopular
            }
            return lhs.usageCount > rhs.usageCount
        }
    }
    
    func trackCommandUsage(_ command: SuggestedCommand) {
        // Update usage statistics
        var usageStats = loadUsageStatsFromDefaults()
        usageStats[command.text, default: 0] += 1
        saveUsageStats(usageStats)
        
        // Update command usage count
        if let index = suggestedCommands.firstIndex(where: { $0.id == command.id }) {
            let updatedCommand = SuggestedCommand(
                text: command.text,
                description: command.description,
                category: command.category,
                difficulty: command.difficulty,
                tags: command.tags,
                usageCount: command.usageCount + 1
            )
            suggestedCommands[index] = updatedCommand
        }
        
        // Add to recent commands
        recentCommands.removeAll { $0.text == command.text }
        recentCommands.insert(command, at: 0)
        if recentCommands.count > 10 {
            recentCommands.removeLast()
        }
    }
    
    func getSuggestionsForContext(_ context: String) -> [SuggestedCommand] {
        // Provide contextual suggestions based on current task or file type
        let contextKeywords = context.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        return suggestedCommands.filter { command in
            contextKeywords.contains { keyword in
                command.text.localizedCaseInsensitiveContains(keyword) ||
                command.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }
            }
        }.prefix(5).map { $0 }
    }
    
    private func loadPredefinedCommands() {
        suggestedCommands = [
            // File Operations - Beginner
            SuggestedCommand(
                text: "copy file.txt to Desktop",
                description: "Copy a specific file to the Desktop",
                category: .fileOperations,
                difficulty: .beginner,
                tags: ["copy", "file", "desktop"]
            ),
            SuggestedCommand(
                text: "move image.jpg to Pictures folder",
                description: "Move an image file to the Pictures folder",
                category: .fileOperations,
                difficulty: .beginner,
                tags: ["move", "image", "pictures"]
            ),
            SuggestedCommand(
                text: "delete old files from Downloads",
                description: "Remove old files from the Downloads folder",
                category: .fileOperations,
                difficulty: .beginner,
                tags: ["delete", "cleanup", "downloads"]
            ),
            
            // File Operations - Intermediate
            SuggestedCommand(
                text: "organize Desktop by file type",
                description: "Automatically organize Desktop files into folders by type",
                category: .fileOperations,
                difficulty: .intermediate,
                tags: ["organize", "desktop", "file type"]
            ),
            SuggestedCommand(
                text: "copy all PDFs from Downloads to Documents",
                description: "Batch copy all PDF files to Documents folder",
                category: .fileOperations,
                difficulty: .intermediate,
                tags: ["batch", "pdf", "copy"]
            ),
            SuggestedCommand(
                text: "find all images larger than 10MB",
                description: "Search for large image files across the system",
                category: .fileOperations,
                difficulty: .intermediate,
                tags: ["search", "images", "size"]
            ),
            
            // System Info - Beginner
            SuggestedCommand(
                text: "what's my battery percentage?",
                description: "Check current battery level",
                category: .systemInfo,
                difficulty: .beginner,
                tags: ["battery", "status"]
            ),
            SuggestedCommand(
                text: "how much storage do I have left?",
                description: "Check available disk space",
                category: .systemInfo,
                difficulty: .beginner,
                tags: ["storage", "disk", "space"]
            ),
            SuggestedCommand(
                text: "what's my RAM usage?",
                description: "View current memory consumption",
                category: .systemInfo,
                difficulty: .beginner,
                tags: ["memory", "ram", "usage"]
            ),
            
            // App Control - Beginner
            SuggestedCommand(
                text: "open Safari",
                description: "Launch the Safari web browser",
                category: .appControl,
                difficulty: .beginner,
                tags: ["open", "safari", "browser"]
            ),
            SuggestedCommand(
                text: "open Calculator",
                description: "Launch the Calculator app",
                category: .appControl,
                difficulty: .beginner,
                tags: ["open", "calculator"]
            ),
            
            // App Control - Intermediate
            SuggestedCommand(
                text: "open Safari and go to apple.com",
                description: "Launch Safari and navigate to a specific website",
                category: .appControl,
                difficulty: .intermediate,
                tags: ["safari", "navigate", "website"]
            ),
            SuggestedCommand(
                text: "send email to john@example.com about meeting",
                description: "Compose and send an email with specific recipient and subject",
                category: .appControl,
                difficulty: .intermediate,
                tags: ["email", "mail", "compose"]
            ),
            SuggestedCommand(
                text: "create calendar event for tomorrow at 2 PM",
                description: "Schedule a new calendar event",
                category: .appControl,
                difficulty: .intermediate,
                tags: ["calendar", "event", "schedule"]
            ),
            
            // Workflows - Advanced
            SuggestedCommand(
                text: "backup project files to external drive",
                description: "Create a workflow to backup important files",
                category: .workflows,
                difficulty: .advanced,
                tags: ["backup", "workflow", "automation"]
            ),
            SuggestedCommand(
                text: "organize downloads: move images to Pictures, documents to Documents",
                description: "Multi-step file organization workflow",
                category: .workflows,
                difficulty: .advanced,
                tags: ["organize", "multi-step", "automation"]
            ),
            
            // Productivity
            SuggestedCommand(
                text: "create new project folder with standard structure",
                description: "Set up a new project with organized folder structure",
                category: .productivity,
                difficulty: .intermediate,
                tags: ["project", "setup", "folders"]
            ),
            SuggestedCommand(
                text: "compress all files in folder for sharing",
                description: "Create a zip archive of folder contents",
                category: .productivity,
                difficulty: .intermediate,
                tags: ["compress", "zip", "sharing"]
            )
        ]
    }
    
    private func loadUsageStats() {
        let usageStats = loadUsageStatsFromDefaults()
        
        // Update command usage counts
        for i in 0..<suggestedCommands.count {
            let command = suggestedCommands[i]
            let usageCount = usageStats[command.text] ?? 0
            
            suggestedCommands[i] = SuggestedCommand(
                text: command.text,
                description: command.description,
                category: command.category,
                difficulty: command.difficulty,
                tags: command.tags,
                usageCount: usageCount
            )
        }
        
        // Update popular commands
        popularCommands = suggestedCommands.filter { $0.isPopular }.sorted { $0.usageCount > $1.usageCount }
    }
    
    private func loadUsageStatsFromDefaults() -> [String: Int] {
        return userDefaults.dictionary(forKey: commandUsageKey) as? [String: Int] ?? [:]
    }
    
    private func saveUsageStats(_ stats: [String: Int]) {
        userDefaults.set(stats, forKey: commandUsageKey)
    }
}

#Preview {
    CommandPaletteView()
}