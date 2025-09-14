import SwiftUI

struct HelpView: View {
    @StateObject private var helpManager = HelpManager()
    @State private var searchText = ""
    @State private var selectedCategory: HelpCategory = .gettingStarted
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with categories
            List(selection: $selectedCategory) {
                Section("Help Topics") {
                    ForEach(HelpCategory.allCases, id: \.self) { category in
                        NavigationLink(value: category) {
                            Label(category.title, systemImage: category.icon)
                        }
                    }
                }
                
                Section("Quick Actions") {
                    Button(action: { helpManager.showOnboarding() }) {
                        Label("Show Onboarding", systemImage: "play.circle")
                    }
                    
                    Button(action: { helpManager.showCommandPalette() }) {
                        Label("Command Examples", systemImage: "command")
                    }
                    
                    Button(action: { helpManager.showKeyboardShortcuts() }) {
                        Label("Keyboard Shortcuts", systemImage: "keyboard")
                    }
                }
            }
            .navigationTitle("Help")
            .searchable(text: $searchText, prompt: "Search help topics...")
        } detail: {
            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category header
                    HStack {
                        Image(systemName: selectedCategory.icon)
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text(selectedCategory.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(selectedCategory.description)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom)
                    
                    // Content based on selected category
                    helpContentView(for: selectedCategory)
                }
                .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $helpManager.showingOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $helpManager.showingCommandPalette) {
            CommandPaletteView()
        }
        .sheet(isPresented: $helpManager.showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
    }
    
    @ViewBuilder
    private func helpContentView(for category: HelpCategory) -> some View {
        switch category {
        case .gettingStarted:
            GettingStartedHelpView()
        case .commands:
            CommandsHelpView()
        case .fileOperations:
            FileOperationsHelpView()
        case .systemInfo:
            SystemInfoHelpView()
        case .appIntegration:
            AppIntegrationHelpView()
        case .workflows:
            WorkflowsHelpView()
        case .settings:
            SettingsHelpView()
        case .troubleshooting:
            TroubleshootingHelpView()
        }
    }
}

// MARK: - Help Category Views

struct GettingStartedHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Welcome to Sam") {
                Text("Sam is your intelligent macOS assistant that performs actual tasks through natural language commands. Unlike traditional chatbots, Sam can execute file operations, control applications, and automate workflows on your Mac.")
            }
            
            HelpSection(title: "First Steps") {
                VStack(alignment: .leading, spacing: 8) {
                    HelpStep(number: 1, title: "Grant Permissions", description: "Allow Sam to access files and control applications")
                    HelpStep(number: 2, title: "Configure AI Settings", description: "Set up your OpenAI API key for advanced features (optional)")
                    HelpStep(number: 3, title: "Try Basic Commands", description: "Start with simple file operations or system queries")
                    HelpStep(number: 4, title: "Explore Workflows", description: "Create multi-step automations for complex tasks")
                }
            }
            
            HelpSection(title: "Quick Examples") {
                VStack(alignment: .leading, spacing: 8) {
                    ExampleCommand(command: "What's my battery level?", description: "Get system information")
                    ExampleCommand(command: "Copy all images from Downloads to Pictures", description: "File operations")
                    ExampleCommand(command: "Open Safari and go to apple.com", description: "App control")
                    ExampleCommand(command: "Create a calendar event for tomorrow at 2 PM", description: "Productivity tasks")
                }
            }
        }
    }
}

struct CommandsHelpView: View {
    @State private var selectedCommandType: CommandType = .fileOperations
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Command Types") {
                Picker("Command Type", selection: $selectedCommandType) {
                    ForEach(CommandType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            commandExamplesView(for: selectedCommandType)
        }
    }
    
    @ViewBuilder
    private func commandExamplesView(for type: CommandType) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(type.examples, id: \.command) { example in
                CommandExampleCard(example: example)
            }
        }
    }
}

struct FileOperationsHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "File Operations") {
                Text("Sam can perform various file operations using natural language. Here are the supported operations:")
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                FileOperationCard(
                    icon: "doc.on.doc",
                    title: "Copy Files",
                    examples: [
                        "Copy file.txt to Desktop",
                        "Copy all PDFs from Downloads to Documents"
                    ]
                )
                
                FileOperationCard(
                    icon: "arrow.right.circle",
                    title: "Move Files",
                    examples: [
                        "Move image.jpg to Pictures folder",
                        "Move all videos to Movies"
                    ]
                )
                
                FileOperationCard(
                    icon: "folder.badge.plus",
                    title: "Organize Files",
                    examples: [
                        "Organize Desktop by file type",
                        "Sort Downloads by date"
                    ]
                )
                
                FileOperationCard(
                    icon: "magnifyingglass",
                    title: "Search Files",
                    examples: [
                        "Find all Excel files",
                        "Search for files containing 'project'"
                    ]
                )
            }
        }
    }
}

struct SystemInfoHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "System Information") {
                Text("Ask Sam about your Mac's current status and system information.")
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                SystemInfoCard(
                    icon: "battery.100",
                    title: "Battery Status",
                    examples: [
                        "What's my battery percentage?",
                        "Is my Mac charging?"
                    ]
                )
                
                SystemInfoCard(
                    icon: "internaldrive",
                    title: "Storage Info",
                    examples: [
                        "How much storage do I have left?",
                        "Show disk usage"
                    ]
                )
                
                SystemInfoCard(
                    icon: "memorychip",
                    title: "Memory Usage",
                    examples: [
                        "What's my RAM usage?",
                        "Show memory statistics"
                    ]
                )
                
                SystemInfoCard(
                    icon: "wifi",
                    title: "Network Status",
                    examples: [
                        "Am I connected to WiFi?",
                        "What's my IP address?"
                    ]
                )
            }
        }
    }
}

struct AppIntegrationHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Application Integration") {
                Text("Sam can control and interact with various macOS applications.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                AppIntegrationSection(
                    appName: "Safari",
                    icon: "safari",
                    examples: [
                        "Open Safari and go to apple.com",
                        "Bookmark this page",
                        "Search for 'SwiftUI tutorial' in Safari"
                    ]
                )
                
                AppIntegrationSection(
                    appName: "Mail",
                    icon: "mail",
                    examples: [
                        "Send email to john@example.com about meeting",
                        "Compose email with subject 'Project Update'",
                        "Show unread emails"
                    ]
                )
                
                AppIntegrationSection(
                    appName: "Calendar",
                    icon: "calendar",
                    examples: [
                        "Create event for tomorrow at 2 PM",
                        "Schedule meeting with team next Friday",
                        "Show today's events"
                    ]
                )
                
                AppIntegrationSection(
                    appName: "Finder",
                    icon: "folder",
                    examples: [
                        "Open Downloads folder",
                        "Show Desktop in Finder",
                        "Navigate to Applications"
                    ]
                )
            }
        }
    }
}

struct WorkflowsHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Workflow Automation") {
                Text("Create and execute multi-step workflows to automate complex tasks.")
            }
            
            HelpSection(title: "Creating Workflows") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Describe your multi-step process in natural language")
                    Text("2. Sam will break it down into individual steps")
                    Text("3. Review and modify the workflow as needed")
                    Text("4. Save and execute whenever you need it")
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            HelpSection(title: "Example Workflows") {
                VStack(alignment: .leading, spacing: 12) {
                    WorkflowExampleCard(
                        title: "Daily Cleanup",
                        description: "Organize Desktop, empty Trash, and clear Downloads",
                        steps: [
                            "Organize Desktop by file type",
                            "Move old files to Archive folder",
                            "Empty Trash",
                            "Clear Downloads folder of files older than 30 days"
                        ]
                    )
                    
                    WorkflowExampleCard(
                        title: "Project Setup",
                        description: "Create project structure and open development tools",
                        steps: [
                            "Create new project folder",
                            "Set up standard directory structure",
                            "Open project in Xcode",
                            "Create initial README file"
                        ]
                    )
                }
            }
        }
    }
}

struct SettingsHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Settings & Configuration") {
                Text("Customize Sam's behavior and configure integrations.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                SettingSection(
                    title: "AI Configuration",
                    description: "Set up OpenAI API key and model preferences",
                    icon: "brain.head.profile"
                )
                
                SettingSection(
                    title: "Task Execution",
                    description: "Configure confirmation settings for dangerous operations",
                    icon: "gear"
                )
                
                SettingSection(
                    title: "Privacy Settings",
                    description: "Control data handling and cloud processing preferences",
                    icon: "lock.shield"
                )
                
                SettingSection(
                    title: "Keyboard Shortcuts",
                    description: "Customize shortcuts for quick access to Sam",
                    icon: "keyboard"
                )
            }
        }
    }
}

struct TroubleshootingHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSection(title: "Common Issues") {
                Text("Solutions to frequently encountered problems.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                TroubleshootingItem(
                    problem: "Sam can't access files",
                    solution: "Grant Full Disk Access in System Preferences > Security & Privacy > Privacy"
                )
                
                TroubleshootingItem(
                    problem: "App automation not working",
                    solution: "Enable Accessibility access and Automation permissions for Sam"
                )
                
                TroubleshootingItem(
                    problem: "AI responses are slow",
                    solution: "Check your internet connection or switch to local processing mode"
                )
                
                TroubleshootingItem(
                    problem: "Commands not recognized",
                    solution: "Try rephrasing your request or check the command examples"
                )
            }
        }
    }
}

// MARK: - Supporting Views and Components

struct HelpSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content
        }
    }
}

struct HelpStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ExampleCommand: View {
    let command: String
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(command)
                    .font(.body)
                    .fontFamily(.monospaced)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy command")
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    HelpView()
}