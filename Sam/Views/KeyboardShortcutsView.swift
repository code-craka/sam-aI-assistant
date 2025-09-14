import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shortcutManager = KeyboardShortcutManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Keyboard Shortcuts")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Speed up your workflow with these keyboard shortcuts")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Divider()
                
                // Shortcuts list
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(ShortcutCategory.allCases, id: \.self) { category in
                            ShortcutCategorySection(
                                category: category,
                                shortcuts: shortcutManager.shortcuts(for: category)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 600, height: 500)
        .navigationTitle("Keyboard Shortcuts")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
}

struct ShortcutCategorySection: View {
    let category: ShortcutCategory
    let shortcuts: [KeyboardShortcut]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(category.title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 8) {
                ForEach(shortcuts) { shortcut in
                    ShortcutRow(shortcut: shortcut)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ShortcutRow: View {
    let shortcut: KeyboardShortcut
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.action)
                    .font(.body)
                
                if let description = shortcut.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            KeyCombinationView(combination: shortcut.keyCombination)
        }
        .padding(.vertical, 4)
    }
}

struct KeyCombinationView: View {
    let combination: String
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(keyComponents, id: \.self) { key in
                KeyView(key: key)
            }
        }
    }
    
    private var keyComponents: [String] {
        combination.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct KeyView: View {
    let key: String
    
    var body: some View {
        Text(displayKey)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.quaternarySystemFill))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(.tertiaryLabelColor), lineWidth: 0.5)
            )
    }
    
    private var displayKey: String {
        switch key.lowercased() {
        case "cmd", "command": return "⌘"
        case "opt", "option", "alt": return "⌥"
        case "ctrl", "control": return "⌃"
        case "shift": return "⇧"
        case "tab": return "⇥"
        case "enter", "return": return "↩"
        case "space": return "Space"
        case "esc", "escape": return "⎋"
        case "delete": return "⌫"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        default: return key.uppercased()
        }
    }
}

enum ShortcutCategory: String, CaseIterable {
    case general = "general"
    case chat = "chat"
    case navigation = "navigation"
    case fileOperations = "file_operations"
    case workflows = "workflows"
    
    var title: String {
        switch self {
        case .general: return "General"
        case .chat: return "Chat Interface"
        case .navigation: return "Navigation"
        case .fileOperations: return "File Operations"
        case .workflows: return "Workflows"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "keyboard"
        case .chat: return "message"
        case .navigation: return "arrow.up.arrow.down"
        case .fileOperations: return "folder"
        case .workflows: return "flowchart"
        }
    }
}

struct KeyboardShortcut: Identifiable {
    let id = UUID()
    let action: String
    let keyCombination: String
    let description: String?
    let category: ShortcutCategory
    
    init(action: String, keys: String, description: String? = nil, category: ShortcutCategory) {
        self.action = action
        self.keyCombination = keys
        self.description = description
        self.category = category
    }
}

@MainActor
class KeyboardShortcutManager: ObservableObject {
    @Published var customShortcuts: [KeyboardShortcut] = []
    
    private let predefinedShortcuts: [KeyboardShortcut] = [
        // General shortcuts
        KeyboardShortcut(
            action: "Show Sam",
            keys: "Cmd+Shift+S",
            description: "Open Sam from anywhere",
            category: .general
        ),
        KeyboardShortcut(
            action: "Hide Sam",
            keys: "Cmd+H",
            description: "Hide the Sam window",
            category: .general
        ),
        KeyboardShortcut(
            action: "Quit Sam",
            keys: "Cmd+Q",
            description: "Quit the application",
            category: .general
        ),
        KeyboardShortcut(
            action: "Open Settings",
            keys: "Cmd+,",
            description: "Open preferences window",
            category: .general
        ),
        KeyboardShortcut(
            action: "Show Help",
            keys: "Cmd+?",
            description: "Open help documentation",
            category: .general
        ),
        
        // Chat interface shortcuts
        KeyboardShortcut(
            action: "Send Message",
            keys: "Enter",
            description: "Send the current message",
            category: .chat
        ),
        KeyboardShortcut(
            action: "New Line",
            keys: "Shift+Enter",
            description: "Add a new line without sending",
            category: .chat
        ),
        KeyboardShortcut(
            action: "Clear Chat",
            keys: "Cmd+K",
            description: "Clear the current conversation",
            category: .chat
        ),
        KeyboardShortcut(
            action: "Previous Message",
            keys: "Up",
            description: "Navigate to previous message in history",
            category: .chat
        ),
        KeyboardShortcut(
            action: "Next Message",
            keys: "Down",
            description: "Navigate to next message in history",
            category: .chat
        ),
        KeyboardShortcut(
            action: "Copy Last Response",
            keys: "Cmd+Shift+C",
            description: "Copy Sam's last response to clipboard",
            category: .chat
        ),
        
        // Navigation shortcuts
        KeyboardShortcut(
            action: "Focus Chat Input",
            keys: "Cmd+L",
            description: "Focus the chat input field",
            category: .navigation
        ),
        KeyboardShortcut(
            action: "Toggle Sidebar",
            keys: "Cmd+Shift+D",
            description: "Show or hide the sidebar",
            category: .navigation
        ),
        KeyboardShortcut(
            action: "Switch to Chat",
            keys: "Cmd+1",
            description: "Switch to chat view",
            category: .navigation
        ),
        KeyboardShortcut(
            action: "Switch to Workflows",
            keys: "Cmd+2",
            description: "Switch to workflows view",
            category: .navigation
        ),
        KeyboardShortcut(
            action: "Switch to Settings",
            keys: "Cmd+3",
            description: "Switch to settings view",
            category: .navigation
        ),
        
        // File operations shortcuts
        KeyboardShortcut(
            action: "Quick File Search",
            keys: "Cmd+F",
            description: "Open quick file search dialog",
            category: .fileOperations
        ),
        KeyboardShortcut(
            action: "Open File Browser",
            keys: "Cmd+O",
            description: "Open file browser for selection",
            category: .fileOperations
        ),
        KeyboardShortcut(
            action: "Show Recent Files",
            keys: "Cmd+R",
            description: "Show recently accessed files",
            category: .fileOperations
        ),
        
        // Workflow shortcuts
        KeyboardShortcut(
            action: "Create New Workflow",
            keys: "Cmd+N",
            description: "Start creating a new workflow",
            category: .workflows
        ),
        KeyboardShortcut(
            action: "Execute Last Workflow",
            keys: "Cmd+Shift+R",
            description: "Run the most recently used workflow",
            category: .workflows
        ),
        KeyboardShortcut(
            action: "Show Workflow Library",
            keys: "Cmd+Shift+W",
            description: "Open the workflow library",
            category: .workflows
        )
    ]
    
    func shortcuts(for category: ShortcutCategory) -> [KeyboardShortcut] {
        let predefined = predefinedShortcuts.filter { $0.category == category }
        let custom = customShortcuts.filter { $0.category == category }
        return predefined + custom
    }
    
    func allShortcuts() -> [KeyboardShortcut] {
        return predefinedShortcuts + customShortcuts
    }
    
    func addCustomShortcut(_ shortcut: KeyboardShortcut) {
        customShortcuts.append(shortcut)
        saveCustomShortcuts()
    }
    
    func removeCustomShortcut(_ shortcut: KeyboardShortcut) {
        customShortcuts.removeAll { $0.id == shortcut.id }
        saveCustomShortcuts()
    }
    
    private func saveCustomShortcuts() {
        // Save to UserDefaults or Core Data
        // Implementation would depend on persistence strategy
    }
    
    private func loadCustomShortcuts() {
        // Load from UserDefaults or Core Data
        // Implementation would depend on persistence strategy
    }
}

// MARK: - Contextual Tips View

struct ContextualTipsView: View {
    let tips: [ContextualTip]
    @State private var currentTipIndex = 0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                
                Text("Tip")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if tips.count > 1 {
                    HStack(spacing: 8) {
                        Button(action: previousTip) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentTipIndex == 0)
                        
                        Text("\(currentTipIndex + 1) of \(tips.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: nextTip) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentTipIndex == tips.count - 1)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if !tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tips[currentTipIndex].title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(tips[currentTipIndex].content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let example = tips[currentTipIndex].example {
                        HStack {
                            Text("Try: ")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(example)
                                .font(.caption2)
                                .fontFamily(.monospaced)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func nextTip() {
        if currentTipIndex < tips.count - 1 {
            currentTipIndex += 1
        }
    }
    
    private func previousTip() {
        if currentTipIndex > 0 {
            currentTipIndex -= 1
        }
    }
}

struct ContextualTip {
    let title: String
    let content: String
    let example: String?
    let context: TipContext
    
    init(title: String, content: String, example: String? = nil, context: TipContext) {
        self.title = title
        self.content = content
        self.example = example
        self.context = context
    }
}

enum TipContext {
    case firstLaunch
    case emptyChat
    case afterFileOperation
    case afterSystemQuery
    case workflowCreation
    case errorRecovery
}

#Preview {
    KeyboardShortcutsView()
}