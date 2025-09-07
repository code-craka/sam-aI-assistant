import Foundation
import SwiftUI

// MARK: - App Integration Demo
@MainActor
class AppIntegrationDemo: ObservableObject {
    
    @Published var demoResults: [DemoResult] = []
    @Published var isRunning = false
    
    private let appIntegrationManager = AppIntegrationManager()
    
    struct DemoResult: Identifiable {
        let id = UUID()
        let command: String
        let result: CommandResult?
        let error: String?
        let timestamp: Date
        
        init(command: String, result: CommandResult? = nil, error: String? = nil) {
            self.command = command
            self.result = result
            self.error = error
            self.timestamp = Date()
        }
    }
    
    // MARK: - Demo Commands
    
    private let demoCommands = [
        // Safari commands
        "open google.com in Safari",
        "search for Swift programming in Safari",
        "bookmark this page in Safari",
        
        // Mail commands
        "send email to test@example.com about demo",
        "check new mail",
        "search emails for project",
        
        // Calendar commands
        "create event Demo Meeting at 2pm",
        "show today's events",
        "remind me to call John",
        
        // Finder commands
        "open Desktop folder",
        "create folder called Demo Projects",
        "search for PDF files",
        
        // Generic app commands
        "launch TextEdit",
        "open Calculator",
        "quit Preview"
    ]
    
    // MARK: - Demo Methods
    
    func runFullDemo() async {
        await MainActor.run {
            isRunning = true
            demoResults.removeAll()
        }
        
        print("🚀 Starting App Integration Demo")
        print("=" * 50)
        
        // Wait for app integration manager to initialize
        while !appIntegrationManager.isInitialized {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        print("✅ App Integration Manager initialized")
        
        // Discover available integrations
        await demonstrateAppDiscovery()
        
        // Test command parsing
        await demonstrateCommandParsing()
        
        // Test app integrations
        await demonstrateAppIntegrations()
        
        await MainActor.run {
            isRunning = false
        }
        
        print("🎉 App Integration Demo completed!")
        print("=" * 50)
    }
    
    private func demonstrateAppDiscovery() async {
        print("\n📱 App Discovery Demo")
        print("-" * 30)
        
        let integrations = appIntegrationManager.getAvailableIntegrations()
        print("Found \(integrations.count) available app integrations:")
        
        for integration in integrations.prefix(10) { // Show first 10
            print("  • \(integration.displayName) (\(integration.bundleIdentifier))")
            print("    Methods: \(integration.integrationMethods.map { $0.displayName }.joined(separator: ", "))")
            print("    Commands: \(integration.supportedCommands.count)")
        }
        
        if integrations.count > 10 {
            print("  ... and \(integrations.count - 10) more")
        }
    }
    
    private func demonstrateCommandParsing() async {
        print("\n🧠 Command Parsing Demo")
        print("-" * 30)
        
        let parser = CommandParser()
        let testCommands = [
            "open google.com in Safari",
            "send email to john@example.com about meeting",
            "create event lunch at noon tomorrow",
            "search for documents in Finder"
        ]
        
        for command in testCommands {
            let parsed = parser.parseCommand(command)
            print("Command: '\(command)'")
            print("  → Intent: \(parsed.intent)")
            print("  → Target App: \(parsed.targetApplication ?? "none")")
            print("  → Confidence: \(String(format: "%.1f%%", parsed.confidence * 100))")
            print("  → Parameters: \(parsed.parameters)")
            print()
        }
    }
    
    private func demonstrateAppIntegrations() async {
        print("\n🔧 App Integration Demo")
        print("-" * 30)
        
        for command in demoCommands {
            await executeAndLogCommand(command)
            
            // Small delay between commands
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
    
    private func executeAndLogCommand(_ command: String) async {
        print("Executing: '\(command)'")
        
        do {
            let result = try await appIntegrationManager.executeCommand(command)
            
            await MainActor.run {
                demoResults.append(DemoResult(command: command, result: result))
            }
            
            print("  ✅ Success: \(result.output)")
            print("  ⏱️  Execution time: \(String(format: "%.3f", result.executionTime))s")
            print("  🔧 Method: \(result.integrationMethod.displayName)")
            
            if !result.followUpActions.isEmpty {
                print("  💡 Follow-up actions:")
                for action in result.followUpActions {
                    print("     • \(action)")
                }
            }
            
        } catch {
            await MainActor.run {
                demoResults.append(DemoResult(command: command, error: error.localizedDescription))
            }
            
            print("  ❌ Error: \(error.localizedDescription)")
            
            if let appError = error as? AppIntegrationError,
               let suggestion = appError.recoverySuggestion {
                print("  💡 Suggestion: \(suggestion)")
            }
        }
        
        print()
    }
    
    // MARK: - Individual Demo Methods
    
    func demonstrateSafariIntegration() async {
        print("\n🌐 Safari Integration Demo")
        print("-" * 30)
        
        let safariCommands = [
            "open apple.com in Safari",
            "search for SwiftUI tutorials in Safari",
            "open new tab in Safari",
            "bookmark this page in Safari"
        ]
        
        for command in safariCommands {
            await executeAndLogCommand(command)
        }
    }
    
    func demonstrateMailIntegration() async {
        print("\n📧 Mail Integration Demo")
        print("-" * 30)
        
        let mailCommands = [
            "send email to demo@example.com about test",
            "check new mail",
            "search emails for important",
            "create mailbox called Demo"
        ]
        
        for command in mailCommands {
            await executeAndLogCommand(command)
        }
    }
    
    func demonstrateCalendarIntegration() async {
        print("\n📅 Calendar Integration Demo")
        print("-" * 30)
        
        let calendarCommands = [
            "create event Team Meeting at 3pm",
            "show today's events",
            "remind me to review code",
            "schedule lunch tomorrow at noon"
        ]
        
        for command in calendarCommands {
            await executeAndLogCommand(command)
        }
    }
    
    func demonstrateFinderIntegration() async {
        print("\n📁 Finder Integration Demo")
        print("-" * 30)
        
        let finderCommands = [
            "open Downloads folder",
            "create folder called Test Projects",
            "search for Swift files",
            "show Desktop in Finder"
        ]
        
        for command in finderCommands {
            await executeAndLogCommand(command)
        }
    }
    
    // MARK: - Utility Methods
    
    func clearResults() {
        demoResults.removeAll()
    }
    
    func exportResults() -> String {
        var output = "App Integration Demo Results\n"
        output += "Generated: \(Date())\n"
        output += "=" * 50 + "\n\n"
        
        for result in demoResults {
            output += "Command: \(result.command)\n"
            output += "Time: \(result.timestamp)\n"
            
            if let commandResult = result.result {
                output += "Status: ✅ Success\n"
                output += "Output: \(commandResult.output)\n"
                output += "Method: \(commandResult.integrationMethod.displayName)\n"
                output += "Duration: \(String(format: "%.3f", commandResult.executionTime))s\n"
            } else if let error = result.error {
                output += "Status: ❌ Error\n"
                output += "Error: \(error)\n"
            }
            
            output += "\n" + "-" * 30 + "\n\n"
        }
        
        return output
    }
}

// MARK: - Demo SwiftUI View

struct AppIntegrationDemoView: View {
    @StateObject private var demo = AppIntegrationDemo()
    @State private var selectedDemo = "Full Demo"
    
    private let demoOptions = [
        "Full Demo",
        "Safari Integration",
        "Mail Integration",
        "Calendar Integration",
        "Finder Integration"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Demo Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Demo")
                        .font(.headline)
                    
                    Picker("Demo Type", selection: $selectedDemo) {
                        ForEach(demoOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Control Buttons
                HStack(spacing: 15) {
                    Button("Run Demo") {
                        Task {
                            await runSelectedDemo()
                        }
                    }
                    .disabled(demo.isRunning)
                    
                    Button("Clear Results") {
                        demo.clearResults()
                    }
                    .disabled(demo.isRunning)
                    
                    Button("Export Results") {
                        let results = demo.exportResults()
                        // In a real app, you'd save this to a file or copy to clipboard
                        print(results)
                    }
                    .disabled(demo.demoResults.isEmpty)
                }
                
                // Results List
                List(demo.demoResults) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.command)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let commandResult = result.result {
                            Label(commandResult.output, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            HStack {
                                Text("Method: \(commandResult.integrationMethod.displayName)")
                                Spacer()
                                Text("\(String(format: "%.3f", commandResult.executionTime))s")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                        } else if let error = result.error {
                            Label(error, systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        
                        Text(result.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                if demo.isRunning {
                    ProgressView("Running demo...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .padding()
            .navigationTitle("App Integration Demo")
        }
    }
    
    private func runSelectedDemo() async {
        switch selectedDemo {
        case "Full Demo":
            await demo.runFullDemo()
        case "Safari Integration":
            await demo.demonstrateSafariIntegration()
        case "Mail Integration":
            await demo.demonstrateMailIntegration()
        case "Calendar Integration":
            await demo.demonstrateCalendarIntegration()
        case "Finder Integration":
            await demo.demonstrateFinderIntegration()
        default:
            await demo.runFullDemo()
        }
    }
}

// MARK: - String Extension for Repeat

extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// MARK: - Preview

struct AppIntegrationDemoView_Previews: PreviewProvider {
    static var previews: some View {
        AppIntegrationDemoView()
    }
}