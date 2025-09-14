import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: onboardingManager.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
                
                // Content area
                TabView(selection: $onboardingManager.currentStep) {
                    ForEach(OnboardingStep.allCases, id: \.self) { step in
                        onboardingStepView(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: onboardingManager.currentStep)
                
                // Navigation buttons
                HStack {
                    if onboardingManager.canGoBack {
                        Button("Back") {
                            onboardingManager.goBack()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if onboardingManager.isLastStep {
                        Button("Get Started") {
                            onboardingManager.completeOnboarding()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Continue") {
                            onboardingManager.goNext()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .navigationTitle("Welcome to Sam")
    }
    
    @ViewBuilder
    private func onboardingStepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .features:
            FeaturesStepView()
        case .permissions:
            PermissionsStepView()
        case .apiSetup:
            APISetupStepView()
        case .examples:
            ExamplesStepView()
        }
    }
}

// MARK: - Onboarding Steps

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Sam")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your intelligent macOS assistant that actually performs tasks")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "gear", title: "Task Execution", description: "Performs actual file operations and system tasks")
                FeatureRow(icon: "lock.shield", title: "Privacy First", description: "Local processing with optional cloud features")
                FeatureRow(icon: "app.connected.to.app.below.fill", title: "Deep Integration", description: "Works seamlessly with your favorite Mac apps")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding()
    }
}

struct FeaturesStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("What Sam Can Do")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                FeatureCard(
                    icon: "folder",
                    title: "File Management",
                    description: "Copy, move, organize, and search files with natural language"
                )
                
                FeatureCard(
                    icon: "info.circle",
                    title: "System Info",
                    description: "Check battery, storage, memory, and network status"
                )
                
                FeatureCard(
                    icon: "app.badge",
                    title: "App Control",
                    description: "Open apps, send emails, create calendar events"
                )
                
                FeatureCard(
                    icon: "flowchart",
                    title: "Workflows",
                    description: "Automate multi-step tasks and repetitive operations"
                )
            }
        }
        .padding()
    }
}

struct PermissionsStepView: View {
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Permissions Setup")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Sam needs certain permissions to help you effectively")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "folder",
                    title: "File System Access",
                    description: "Required for file operations and organization",
                    isGranted: permissionManager.fileSystemAccess,
                    action: { await permissionManager.requestFileSystemAccess() }
                )
                
                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility Access",
                    description: "Enables app automation and control",
                    isGranted: permissionManager.accessibilityAccess,
                    action: { await permissionManager.requestAccessibilityAccess() }
                )
                
                PermissionRow(
                    icon: "applescript",
                    title: "Automation Access",
                    description: "Allows Sam to control other applications",
                    isGranted: permissionManager.automationAccess,
                    action: { await permissionManager.requestAutomationAccess() }
                )
            }
            
            Text("You can grant these permissions later in System Preferences")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct APISetupStepView: View {
    @State private var apiKey = ""
    @State private var selectedModel = AIModel.gpt4Turbo
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Text("AI Configuration")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Configure your AI preferences for enhanced capabilities")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key (Optional)")
                        .font(.headline)
                    
                    SecureField("Enter your OpenAI API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Required for advanced AI features. Sam works locally without this.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred AI Model")
                        .font(.headline)
                    
                    Picker("Model", selection: $selectedModel) {
                        ForEach(AIModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            
            Button("Save Configuration") {
                if !apiKey.isEmpty {
                    settingsManager.setAPIKey(apiKey)
                }
                settingsManager.setPreferredModel(selectedModel)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct ExamplesStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Try These Commands")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Here are some examples to get you started")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ExampleCommandRow(
                    category: "File Operations",
                    command: "Copy all PDFs from Downloads to Desktop"
                )
                
                ExampleCommandRow(
                    category: "System Info",
                    command: "What's my battery percentage?"
                )
                
                ExampleCommandRow(
                    category: "App Control",
                    command: "Open Safari and go to apple.com"
                )
                
                ExampleCommandRow(
                    category: "Organization",
                    command: "Organize my Desktop by file type"
                )
                
                ExampleCommandRow(
                    category: "Email",
                    command: "Send email to john@example.com about meeting"
                )
            }
            
            Text("Just type naturally - Sam understands conversational language!")
                .font(.callout)
                .foregroundColor(.accentColor)
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
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
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(height: 120)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () async -> Void
    
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
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    Task {
                        await action()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ExampleCommandRow: View {
    let category: String
    let command: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(command)
                    .font(.body)
                    .fontFamily(.monospaced)
            }
            
            Spacer()
            
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy to clipboard")
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    OnboardingView()
}