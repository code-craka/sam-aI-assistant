import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain.head.profile")
                }
            
            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
            
            AccessibilitySettingsView()
                .tabItem {
                    Label("Accessibility", systemImage: "accessibility")
                }
        }
        .frame(width: 600, height: 500)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings")
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var launchAtLogin = false
    @State private var showMenuBarIcon = true
    @State private var enableNotifications = true
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Sam at login", isOn: $launchAtLogin)
                    .accessibilityHint("Automatically start Sam when you log in to macOS")
                
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    .accessibilityHint("Display Sam icon in the menu bar for quick access")
            }
            
            Section("Notifications") {
                Toggle("Enable notifications", isOn: $enableNotifications)
                    .accessibilityHint("Allow Sam to send system notifications")
            }
            
            Section("Window") {
                Picker("Sidebar visibility", selection: $appState.sidebarVisibility) {
                    Text("Automatic").tag(NavigationSplitViewVisibility.automatic)
                    Text("Always show").tag(NavigationSplitViewVisibility.doubleColumn)
                    Text("Hide").tag(NavigationSplitViewVisibility.detailOnly)
                }
                .accessibilityLabel("Sidebar visibility preference")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appState.themeMode) {
                    ForEach(AppState.ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Choose app appearance theme")
            }
            
            Section("Interface") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size")
                        .font(.headline)
                    
                    Text("Use system font size preferences in System Settings > Accessibility > Display")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AISettingsView: View {
    @State private var apiKey = ""
    @State private var selectedModel = "gpt-4-turbo"
    @State private var maxTokens = 4000
    @State private var temperature = 0.7
    
    var body: some View {
        Form {
            Section("OpenAI Configuration") {
                SecureField("API Key", text: $apiKey)
                    .accessibilityLabel("OpenAI API Key")
                    .accessibilityHint("Enter your OpenAI API key for cloud processing")
                
                Picker("Model", selection: $selectedModel) {
                    Text("GPT-4 Turbo").tag("gpt-4-turbo")
                    Text("GPT-4").tag("gpt-4")
                    Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
                }
                .accessibilityLabel("AI model selection")
            }
            
            Section("Response Settings") {
                VStack(alignment: .leading) {
                    Text("Max Tokens: \(maxTokens)")
                    Slider(value: Binding(
                        get: { Double(maxTokens) },
                        set: { maxTokens = Int($0) }
                    ), in: 100...8000, step: 100)
                    .accessibilityLabel("Maximum tokens per response")
                    .accessibilityValue("\(maxTokens) tokens")
                }
                
                VStack(alignment: .leading) {
                    Text("Temperature: \(String(format: "%.1f", temperature))")
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                    .accessibilityLabel("Response creativity level")
                    .accessibilityValue("\(String(format: "%.1f", temperature)) out of 2")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PrivacySettingsView: View {
    @State private var localProcessingPreferred = true
    @State private var shareUsageData = false
    @State private var encryptChatHistory = true
    @State private var autoDeleteOldChats = false
    
    var body: some View {
        Form {
            Section("Data Processing") {
                Toggle("Prefer local processing", isOn: $localProcessingPreferred)
                    .accessibilityHint("Process simple tasks locally when possible for better privacy")
                
                Toggle("Encrypt chat history", isOn: $encryptChatHistory)
                    .accessibilityHint("Encrypt stored conversations for additional security")
            }
            
            Section("Data Sharing") {
                Toggle("Share anonymous usage data", isOn: $shareUsageData)
                    .accessibilityHint("Help improve Sam by sharing anonymous usage statistics")
            }
            
            Section("Data Retention") {
                Toggle("Auto-delete old chats", isOn: $autoDeleteOldChats)
                    .accessibilityHint("Automatically remove chat history older than 30 days")
                
                Button("Clear All Chat History") {
                    // TODO: Implement clear history
                }
                .foregroundColor(.red)
                .accessibilityLabel("Clear all chat history")
                .accessibilityHint("Permanently delete all stored conversations")
            }
            
            Section("Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.headline)
                    
                    Text("Sam processes most tasks locally on your Mac. Only complex queries that require advanced AI capabilities are sent to external services. Your data is never used for training AI models.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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