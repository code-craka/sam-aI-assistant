import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .environmentObject(settingsManager)
            
            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain.head.profile")
                }
                .environmentObject(settingsManager)
            
            TaskExecutionSettingsView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle")
                }
                .environmentObject(settingsManager)
            
            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
                .environmentObject(settingsManager)
            
            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .environmentObject(settingsManager)
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .environmentObject(settingsManager)
            
            AccessibilitySettingsView()
                .tabItem {
                    Label("Accessibility", systemImage: "accessibility")
                }
                .environmentObject(settingsManager)
            
            PerformanceDashboardView()
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }
                .environmentObject(settingsManager)
        }
        .frame(width: 700, height: 600)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings")
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var launchAtLogin = false
    @State private var showMenuBarIcon = true
    @State private var showingResetAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    
    var body: some View {
        Form {
            Section("Application") {
                Toggle("Launch Sam at login", isOn: $launchAtLogin)
                    .accessibilityHint("Automatically start Sam when you log in to macOS")
                
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    .accessibilityHint("Display Sam icon in the menu bar for quick access")
                
                Text("Launch at login requires permission to add Sam to your login items.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Settings Management") {
                HStack {
                    Button("Export Settings") {
                        showingExportSheet = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import Settings") {
                        showingImportSheet = true
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Text("Export your settings to share across devices or create backups. Import settings from a previously exported file.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Application Info") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Version:")
                        Spacer()
                        Text(AppConstants.version)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build:")
                        Spacer()
                        Text(AppConstants.buildNumber)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Bundle ID:")
                        Spacer()
                        Text(AppConstants.bundleIdentifier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Support") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Privacy Policy") {
                        NSWorkspace.shared.open(AppConstants.privacyPolicyURL)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    
                    Button("Terms of Service") {
                        NSWorkspace.shared.open(AppConstants.termsOfServiceURL)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    
                    Button("Support & Feedback") {
                        NSWorkspace.shared.open(AppConstants.supportURL)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsManager.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. Your API keys and shortcuts will be removed. This action cannot be undone.")
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: SettingsDocument(data: settingsManager.exportSettings() ?? Data()),
            contentType: .json,
            defaultFilename: "sam-settings"
        ) { result in
            // Handle export result if needed
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importSettings(from: url)
                }
            case .failure:
                break
            }
        }
    }
    
    private func importSettings(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let success = settingsManager.importSettings(from: data)
            
            if success {
                // Show success message
            } else {
                // Show error message
            }
        } catch {
            // Handle error
        }
    }
}

// Helper document type for settings export
struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: Binding(
                    get: { 
                        // Convert UserModels.ThemeMode to AppState.ThemeMode
                        switch settingsManager.userPreferences.themeMode {
                        case .light: return AppState.ThemeMode.light
                        case .dark: return AppState.ThemeMode.dark
                        case .system: return AppState.ThemeMode.system
                        }
                    },
                    set: { (appStateTheme: AppState.ThemeMode) in
                        // Convert AppState.ThemeMode to UserModels.ThemeMode and update both
                        let userTheme: UserModels.ThemeMode
                        switch appStateTheme {
                        case .light: userTheme = .light
                        case .dark: userTheme = .dark
                        case .system: userTheme = .system
                        }
                        
                        settingsManager.updateThemeMode(userTheme)
                        appState.themeMode = appStateTheme
                    }
                )) {
                    ForEach(AppState.ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Choose app appearance theme")
                
                Text("Theme changes apply immediately and are synchronized across all app windows.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Window Behavior") {
                Picker("Sidebar visibility", selection: $appState.sidebarVisibility) {
                    Text("Automatic").tag(NavigationSplitViewVisibility.automatic)
                    Text("Always show").tag(NavigationSplitViewVisibility.doubleColumn)
                    Text("Hide").tag(NavigationSplitViewVisibility.detailOnly)
                }
                .accessibilityLabel("Sidebar visibility preference")
                
                Text("Controls how the sidebar is displayed in the main window.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Chat Interface") {
                Toggle("Compact mode", isOn: settingsManager.binding(for: \.interfacePreferences.compactMode))
                    .accessibilityHint("Use a more compact layout with less spacing")
                
                Toggle("Show timestamps", isOn: settingsManager.binding(for: \.interfacePreferences.showTimestamps))
                    .accessibilityHint("Display timestamps for each message")
                
                Toggle("Group messages", isOn: settingsManager.binding(for: \.interfacePreferences.groupMessages))
                    .accessibilityHint("Group consecutive messages from the same sender")
                
                Picker("Message spacing", selection: settingsManager.binding(for: \.interfacePreferences.messageSpacing)) {
                    ForEach(MessageSpacing.allCases, id: \.self) { spacing in
                        Text(spacing.displayName).tag(spacing)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Font scale", selection: settingsManager.binding(for: \.interfacePreferences.fontScale)) {
                    ForEach(FontScale.allCases, id: \.self) { scale in
                        Text(scale.displayName).tag(scale)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Animations & Effects") {
                Toggle("Enable animations", isOn: settingsManager.binding(for: \.interfacePreferences.animationsEnabled))
                    .accessibilityHint("Enable smooth animations and transitions")
                
                Toggle("Sound effects", isOn: settingsManager.binding(for: \.interfacePreferences.soundEffectsEnabled))
                    .accessibilityHint("Play sound effects for interactions")
                
                Toggle("Show typing indicators", isOn: settingsManager.binding(for: \.interfacePreferences.showTypingIndicators))
                    .accessibilityHint("Show when Sam is typing a response")
                
                Text("Animation settings respect your system's Reduce Motion preference.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("System Integration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size")
                        .font(.headline)
                    
                    Text("Sam respects your system font size preferences. Adjust text size in System Settings > Accessibility > Display.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if appState.largerText {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Larger text is enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Motion")
                        .font(.headline)
                    
                    if appState.reduceMotion {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Reduce Motion is enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Animations and transitions are enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Motion settings are controlled in System Settings > Accessibility > Display.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contrast")
                        .font(.headline)
                    
                    if appState.increaseContrast {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Increase Contrast is enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Standard contrast is being used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Contrast settings are controlled in System Settings > Accessibility > Display.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Notifications") {
                Toggle("Enable notifications", isOn: settingsManager.binding(for: \.notificationSettings.enableNotifications))
                    .accessibilityHint("Allow Sam to send system notifications")
                
                if settingsManager.userPreferences.notificationSettings.enableNotifications {
                    Toggle("Task completion notifications", isOn: settingsManager.binding(for: \.notificationSettings.taskCompletionNotifications))
                    
                    Toggle("Error notifications", isOn: settingsManager.binding(for: \.notificationSettings.errorNotifications))
                    
                    Toggle("Sound enabled", isOn: settingsManager.binding(for: \.notificationSettings.soundEnabled))
                    
                    if settingsManager.userPreferences.notificationSettings.soundEnabled {
                        Picker("Notification Sound", selection: settingsManager.binding(for: \.notificationSettings.notificationSound)) {
                            ForEach(NotificationSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AISettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var apiKeyInput = ""
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyAlertMessage = ""
    @State private var isStoringAPIKey = false
    
    var body: some View {
        Form {
            Section("OpenAI Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SecureField("Enter OpenAI API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("OpenAI API Key")
                            .accessibilityHint("Enter your OpenAI API key for cloud processing")
                        
                        Button(action: storeAPIKey) {
                            if isStoringAPIKey {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(settingsManager.hasAPIKey ? "Update" : "Save")
                            }
                        }
                        .disabled(apiKeyInput.isEmpty || isStoringAPIKey)
                        .buttonStyle(.borderedProminent)
                    }
                    
                    HStack {
                        Text("Status:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(settingsManager.apiKeyValidationStatus.color)
                                .frame(width: 8, height: 8)
                            
                            Text(settingsManager.apiKeyValidationStatus.displayText)
                                .font(.caption)
                                .foregroundColor(settingsManager.apiKeyValidationStatus.color)
                        }
                        
                        if settingsManager.isValidatingAPIKey {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        
                        Spacer()
                        
                        if settingsManager.hasAPIKey {
                            Button("Remove", action: removeAPIKey)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Text("Your API key is stored securely in the macOS Keychain and never shared with third parties.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Model Selection") {
                Picker("AI Model", selection: settingsManager.binding(for: \.preferredModel)) {
                    ForEach(UserModels.AIModel.allCases, id: \.self) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                            Text("Max tokens: \(model.maxTokens) • Cost: $\(String(format: "%.6f", model.costPerToken))/token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(model)
                    }
                }
                .accessibilityLabel("AI model selection")
                
                Text("Local models provide better privacy but may have limited capabilities compared to cloud models.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Response Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Max Tokens")
                                .font(.headline)
                            Spacer()
                            Text("\(settingsManager.userPreferences.maxTokens)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(settingsManager.userPreferences.maxTokens) },
                                set: { settingsManager.updateMaxTokens(Int($0)) }
                            ),
                            in: 100...Double(settingsManager.userPreferences.preferredModel.maxTokens),
                            step: 100
                        )
                        .accessibilityLabel("Maximum tokens per response")
                        .accessibilityValue("\(settingsManager.userPreferences.maxTokens) tokens")
                        
                        Text("Controls the maximum length of AI responses. Higher values allow longer responses but cost more.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Temperature")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.1f", settingsManager.userPreferences.temperature))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: settingsManager.binding(for: \.temperature),
                            in: 0...2,
                            step: 0.1
                        )
                        .accessibilityLabel("Response creativity level")
                        .accessibilityValue("\(String(format: "%.1f", settingsManager.userPreferences.temperature)) out of 2")
                        
                        Text("Controls response creativity. Lower values (0.0-0.3) for focused tasks, higher values (0.7-1.0) for creative tasks.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Usage & Costs") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Estimated cost per 1K tokens:")
                        Spacer()
                        Text("$\(String(format: "%.4f", settingsManager.userPreferences.preferredModel.costPerToken * 1000))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current response cost estimate:")
                        Spacer()
                        Text("$\(String(format: "%.4f", Double(settingsManager.userPreferences.maxTokens) * settingsManager.userPreferences.preferredModel.costPerToken))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Costs are estimates based on OpenAI pricing. Actual usage may vary.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI Configuration")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("API Key", isPresented: $showingAPIKeyAlert) {
            Button("OK") { }
        } message: {
            Text(apiKeyAlertMessage)
        }
    }
    
    private func storeAPIKey() {
        guard !apiKeyInput.isEmpty else { return }
        
        isStoringAPIKey = true
        
        Task {
            let success = await settingsManager.storeAPIKey(apiKeyInput)
            
            await MainActor.run {
                isStoringAPIKey = false
                
                if success {
                    apiKeyInput = ""
                    apiKeyAlertMessage = "API key stored successfully and validated."
                } else {
                    apiKeyAlertMessage = "Failed to store API key. Please check the format and try again."
                }
                
                showingAPIKeyAlert = true
            }
        }
    }
    
    private func removeAPIKey() {
        let success = settingsManager.deleteAPIKey()
        
        apiKeyAlertMessage = success ? 
            "API key removed successfully." : 
            "Failed to remove API key."
        showingAPIKeyAlert = true
    }
}

struct TaskExecutionSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section("Task Execution Behavior") {
                Toggle("Auto-execute safe tasks", isOn: settingsManager.binding(for: \.autoExecuteTasks))
                    .accessibilityHint("Automatically execute tasks that are considered safe without confirmation")
                
                Toggle("Confirm dangerous operations", isOn: settingsManager.binding(for: \.confirmDangerousOperations))
                    .accessibilityHint("Always ask for confirmation before performing potentially destructive operations")
                
                Text("Safe tasks include file searches, system information queries, and read-only operations. Dangerous operations include file deletion, system changes, and app automation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Task Classification") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Processing Preference")
                        .font(.headline)
                    
                    Picker("Processing Mode", selection: settingsManager.binding(for: \.privacySettings.dataSensitivityLevel)) {
                        ForEach(DataSensitivityLevel.allCases, id: \.self) { level in
                            VStack(alignment: .leading) {
                                Text(level.displayName)
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Section("Confirmation Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Always confirm before:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 20)
                            Text("Deleting files or folders")
                        }
                        
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            Text("Moving files to different locations")
                        }
                        
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("Changing system settings")
                        }
                        
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundColor(.purple)
                                .frame(width: 20)
                            Text("Controlling other applications")
                        }
                        
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            Text("Sending data to external services")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Section("Execution Limits") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These limits help prevent runaway operations and protect your system.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Max execution time:")
                        Spacer()
                        Text("5 minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max retry attempts:")
                        Spacer()
                        Text("3 attempts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max batch operations:")
                        Spacer()
                        Text("100 files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Task Execution")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}


struct ShortcutsSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var showingAddShortcut = false
    @State private var newShortcutName = ""
    @State private var newShortcutCommand = ""
    @State private var newShortcutKeyboard = ""
    @State private var selectedCategory: TaskType = .fileOperation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Add button
            HStack {
                Text("Custom Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Shortcut") {
                    showingAddShortcut = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Shortcuts list
            if settingsManager.userPreferences.shortcuts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Custom Shortcuts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Create shortcuts for frequently used commands to save time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settingsManager.userPreferences.shortcuts) { shortcut in
                        ShortcutRowView(shortcut: shortcut) {
                            settingsManager.removeTaskShortcut(shortcut)
                        }
                    }
                }
            }
        }
        .navigationTitle("Shortcuts")
        .sheet(isPresented: $showingAddShortcut) {
            AddShortcutView(
                name: $newShortcutName,
                command: $newShortcutCommand,
                keyboardShortcut: $newShortcutKeyboard,
                category: $selectedCategory,
                onSave: { shortcut in
                    settingsManager.addTaskShortcut(shortcut)
                    clearNewShortcutFields()
                },
                onCancel: {
                    clearNewShortcutFields()
                }
            )
        }
    }
    
    private func clearNewShortcutFields() {
        newShortcutName = ""
        newShortcutCommand = ""
        newShortcutKeyboard = ""
        selectedCategory = .fileOperation
    }
}

struct ShortcutRowView: View {
    let shortcut: TaskShortcut
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.name)
                    .font(.headline)
                
                Text(shortcut.command)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(shortcut.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if let keyboard = shortcut.keyboardShortcut {
                        Text(keyboard)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text("Used \(shortcut.usageCount) times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct AddShortcutView: View {
    @Binding var name: String
    @Binding var command: String
    @Binding var keyboardShortcut: String
    @Binding var category: TaskType
    let onSave: (TaskShortcut) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Shortcut Details") {
                    TextField("Name", text: $name)
                        .accessibilityLabel("Shortcut name")
                    
                    TextField("Command", text: $command, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Command text")
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section("Keyboard Shortcut (Optional)") {
                    TextField("e.g., ⌘⇧F", text: $keyboardShortcut)
                        .accessibilityLabel("Keyboard shortcut")
                    
                    Text("Use standard macOS keyboard symbols: ⌘ (Command), ⌥ (Option), ⌃ (Control), ⇧ (Shift)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Examples") {
                    VStack(alignment: .leading, spacing: 8) {
                        ExampleShortcutView(
                            name: "Quick Screenshot",
                            command: "take a screenshot of the current window",
                            keyboard: "⌘⇧4"
                        )
                        
                        ExampleShortcutView(
                            name: "Organize Downloads",
                            command: "organize my Downloads folder by file type",
                            keyboard: "⌘⇧O"
                        )
                        
                        ExampleShortcutView(
                            name: "System Status",
                            command: "show me battery level, memory usage, and disk space",
                            keyboard: "⌘⇧S"
                        )
                    }
                }
            }
            .navigationTitle("Add Shortcut")

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let shortcut = TaskShortcut(
                            name: name,
                            command: command,
                            keyboardShortcut: keyboardShortcut.isEmpty ? nil : keyboardShortcut,
                            category: category
                        )
                        onSave(shortcut)
                        dismiss()
                    }
                    .disabled(name.isEmpty || command.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct ExampleShortcutView: View {
    let name: String
    let command: String
    let keyboard: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(command)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(keyboard)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(3)
        }
    }
}

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            Section("Motion") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reduce Motion")
                        .font(.headline)
                    
                    if appState.reduceMotion {
                        Text("✓ Reduce Motion is enabled in System Settings")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Reduce Motion is disabled in System Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Display") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Increase Contrast")
                        .font(.headline)
                    
                    if appState.increaseContrast {
                        Text("✓ Increase Contrast is enabled in System Settings")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Increase Contrast is disabled in System Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Size")
                        .font(.headline)
                    
                    Text("Sam respects your system text size preferences. Adjust text size in System Settings > Accessibility > Display.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Keyboard Navigation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⌘N - New Chat")
                        Text("⌘/ - Focus Input")
                        Text("⌘⇧K - Clear History")
                        Text("⌃⌘S - Toggle Sidebar")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Accessibility")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
// MARK: - Shortcuts Settings View
struct ShortcutsSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var showingAddShortcut = false
    @State private var editingShortcut: TaskShortcut?
    @State private var searchText = ""
    
    var filteredShortcuts: [TaskShortcut] {
        if searchText.isEmpty {
            return settingsManager.userPreferences.shortcuts
        } else {
            return settingsManager.userPreferences.shortcuts.filter { shortcut in
                shortcut.name.localizedCaseInsensitiveContains(searchText) ||
                shortcut.command.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Add Header
            HStack {
                TextField("Search shortcuts and aliases...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search shortcuts and aliases")
                
                Menu {
                    Button("Add Shortcut") {
                        showingAddShortcut = true
                    }
                    
                    Button("Add Command Alias") {
                        // TODO: Show alias creation sheet
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add new shortcut or alias")
            }
            .padding()
            
            // Shortcuts List
            if filteredShortcuts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No shortcuts created yet" : "No shortcuts match your search")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if searchText.isEmpty {
                        Text("Create shortcuts to quickly execute common tasks with keyboard combinations or custom commands.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(TaskType.allCases, id: \.self) { category in
                        let categoryShortcuts = filteredShortcuts.filter { $0.category == category }
                        if !categoryShortcuts.isEmpty {
                            Section(category.displayName) {
                                ForEach(categoryShortcuts) { shortcut in
                                    ShortcutRowView(
                                        shortcut: shortcut,
                                        onEdit: { editingShortcut = shortcut },
                                        onDelete: { settingsManager.removeTaskShortcut(shortcut) }
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Shortcuts")
        .sheet(isPresented: $showingAddShortcut) {
            ShortcutEditorView(shortcut: nil) { shortcut in
                settingsManager.addTaskShortcut(shortcut)
            }
        }
        .sheet(item: $editingShortcut) { shortcut in
            ShortcutEditorView(shortcut: shortcut) { updatedShortcut in
                settingsManager.updateTaskShortcut(updatedShortcut)
            }
        }
    }
}

struct ShortcutRowView: View {
    let shortcut: TaskShortcut
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: shortcut.category.icon)
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    
                    Text(shortcut.name)
                        .font(.headline)
                    
                    if !shortcut.isEnabled {
                        Text("Disabled")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(shortcut.command)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if let keyboardShortcut = shortcut.keyboardShortcut {
                        HStack(spacing: 2) {
                            Text("⌘")
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text(keyboardShortcut.uppercased())
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Used \(shortcut.usageCount) times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button("Edit") {
                    onEdit()
                }
                
                Button("Duplicate") {
                    // TODO: Implement duplicate functionality
                }
                
                Divider()
                
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortcut.name) shortcut")
        .accessibilityHint("Double tap to edit, or use the menu for more options")
    }
}

struct ShortcutEditorView: View {
    let shortcut: TaskShortcut?
    let onSave: (TaskShortcut) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var keyboardShortcut = ""
    @State private var category: TaskType = .fileOperation
    @State private var isEnabled = true
    @State private var showingKeyboardShortcutRecorder = false
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Shortcut Name", text: $name)
                        .accessibilityLabel("Shortcut name")
                    
                    TextField("Command", text: $command, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Command to execute")
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .accessibilityLabel("Shortcut category")
                }
                
                Section("Keyboard Shortcut") {
                    HStack {
                        TextField("Keyboard Shortcut", text: $keyboardShortcut)
                            .disabled(true)
                            .accessibilityLabel("Keyboard shortcut combination")
                        
                        Button("Record") {
                            showingKeyboardShortcutRecorder = true
                        }
                        .buttonStyle(.bordered)
                        
                        if !keyboardShortcut.isEmpty {
                            Button("Clear") {
                                keyboardShortcut = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Text("Press Record and then the key combination you want to use. Common shortcuts like ⌘N are reserved by the system.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Options") {
                    Toggle("Enabled", isOn: $isEnabled)
                        .accessibilityHint("Enable or disable this shortcut")
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This shortcut will:")
                            .font(.headline)
                        
                        Text("• Execute the command: \"\(command.isEmpty ? "No command specified" : command)\"")
                            .font(.caption)
                        
                        if !keyboardShortcut.isEmpty {
                            Text("• Respond to keyboard shortcut: ⌘\(keyboardShortcut.uppercased())")
                                .font(.caption)
                        }
                        
                        Text("• Be categorized under: \(category.displayName)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(shortcut == nil ? "New Shortcut" : "Edit Shortcut")

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveShortcut()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let shortcut = shortcut {
                name = shortcut.name
                command = shortcut.command
                keyboardShortcut = shortcut.keyboardShortcut ?? ""
                category = shortcut.category
                isEnabled = shortcut.isEnabled
            }
        }
        .sheet(isPresented: $showingKeyboardShortcutRecorder) {
            KeyboardShortcutRecorderView { recordedShortcut in
                keyboardShortcut = recordedShortcut
            }
        }
    }
    
    private func saveShortcut() {
        let newShortcut = TaskShortcut(
            id: shortcut?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            command: command.trimmingCharacters(in: .whitespacesAndNewlines),
            keyboardShortcut: keyboardShortcut.isEmpty ? nil : keyboardShortcut,
            category: category,
            createdAt: shortcut?.createdAt ?? Date(),
            usageCount: shortcut?.usageCount ?? 0,
            isEnabled: isEnabled
        )
        
        onSave(newShortcut)
        dismiss()
    }
}

struct KeyboardShortcutRecorderView: View {
    let onRecord: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var recordedKey = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Record Keyboard Shortcut")
                .font(.headline)
            
            Text("Press the key you want to use with ⌘ (Command)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 200, height: 100)
                
                if isRecording {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Press a key...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if recordedKey.isEmpty {
                    Text("Click to start recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack {
                        Text("⌘\(recordedKey.uppercased())")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Recorded")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .onTapGesture {
                if !isRecording {
                    startRecording()
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Use This Shortcut") {
                    onRecord(recordedKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordedKey.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 250)
    }
    
    private func startRecording() {
        isRecording = true
        recordedKey = ""
        
        // Simulate key recording (in a real implementation, this would use NSEvent monitoring)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // For demo purposes, simulate recording a key
            recordedKey = "K" // This would be the actual key pressed
            isRecording = false
        }
    }
}


// MARK: - Accessibility Settings View
struct AccessibilitySettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section("System Accessibility Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sam respects your macOS accessibility preferences. These settings are managed in System Settings > Accessibility.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    AccessibilityStatusRow(
                        title: "Reduce Motion",
                        isEnabled: appState.reduceMotion,
                        description: "Minimizes animations and transitions"
                    )
                    
                    AccessibilityStatusRow(
                        title: "Increase Contrast",
                        isEnabled: appState.increaseContrast,
                        description: "Enhances text and UI element contrast"
                    )
                    
                    AccessibilityStatusRow(
                        title: "Larger Text",
                        isEnabled: appState.largerText,
                        description: "Uses larger system font sizes"
                    )
                }
            }
            
            Section("Voice Control") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Control Integration")
                        .font(.headline)
                    
                    Text("Sam works with macOS Voice Control. You can use voice commands to:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• \"Click Send\" to send messages")
                            .font(.caption)
                        Text("• \"Show numbers\" to see clickable elements")
                            .font(.caption)
                        Text("• \"Open Settings\" to access preferences")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    
                    Button("Open Voice Control Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?VoiceOver")!)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            
            Section("Keyboard Navigation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Keyboard Access")
                        .font(.headline)
                    
                    Text("Sam supports full keyboard navigation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Tab to navigate between elements")
                            .font(.caption)
                        Text("• Space to activate buttons")
                            .font(.caption)
                        Text("• Arrow keys to navigate lists")
                            .font(.caption)
                        Text("• Escape to close dialogs")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    
                    Button("Open Keyboard Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.keyboard")!)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            
            Section("Screen Reader Support") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("VoiceOver Compatibility")
                        .font(.headline)
                    
                    Text("Sam is optimized for VoiceOver with:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Descriptive labels for all interface elements")
                            .font(.caption)
                        Text("• Logical reading order for conversations")
                            .font(.caption)
                        Text("• Helpful hints for complex interactions")
                            .font(.caption)
                        Text("• Announcements for task completion")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    
                    Button("Open VoiceOver Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?VoiceOver")!)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            
            Section("Custom Accessibility") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sam-Specific Options")
                        .font(.headline)
                    
                    Toggle("Announce task completion", isOn: Binding(
                        get: { settingsManager.userPreferences.notificationSettings.taskCompletionNotifications },
                        set: { 
                            var prefs = settingsManager.userPreferences
                            prefs.notificationSettings.taskCompletionNotifications = $0
                            settingsManager.updatePreferences(prefs)
                        }
                    ))
                    .accessibilityHint("Announce when tasks are completed for screen reader users")
                    
                    Toggle("Verbose error descriptions", isOn: .constant(true))
                        .accessibilityHint("Provide detailed error descriptions for better understanding")
                        .disabled(true) // Always enabled for accessibility
                    
                    Text("These options enhance the experience for users with visual impairments.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Accessibility Resources") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Sam Accessibility Guide") {
                        NSWorkspace.shared.open(URL(string: "https://samassistant.com/accessibility")!)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    
                    Button("Report Accessibility Issue") {
                        NSWorkspace.shared.open(URL(string: "https://samassistant.com/accessibility-feedback")!)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    
                    Button("macOS Accessibility Features") {
                        NSWorkspace.shared.open(URL(string: "https://support.apple.com/accessibility/mac")!)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Accessibility")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AccessibilityStatusRow: View {
    let title: String
    let isEnabled: Bool
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(isEnabled ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                
                Text(isEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundColor(isEnabled ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}