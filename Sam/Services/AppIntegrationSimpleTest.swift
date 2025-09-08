import Foundation

// MARK: - Simple App Integration Test
class AppIntegrationSimpleTest {
    
    static func runTests() async {
        print("🧪 Running App Integration Simple Tests")
        print("=" * 40)
        
        await testCommandParser()
        await testAppDiscovery()
        await testAppIntegrationModels()
        
        print("✅ All App Integration tests completed!")
        print("=" * 40)
    }
    
    // MARK: - Command Parser Tests
    
    static func testCommandParser() async {
        print("\n🧠 Testing Command Parser")
        print("-" * 25)
        
        let parser = CommandParser()
        
        // Test Safari command
        let safariCommand = parser.parseCommand("open google.com in Safari")
        print("Safari Command:")
        print("  Input: 'open google.com in Safari'")
        print("  Intent: \(safariCommand.intent)")
        print("  Target App: \(safariCommand.targetApplication ?? "none")")
        print("  Confidence: \(String(format: "%.1f%%", safariCommand.confidence * 100))")
        print("  Parameters: \(safariCommand.parameters)")
        
        // Test Mail command
        let mailCommand = parser.parseCommand("send email to john@example.com about meeting")
        print("\nMail Command:")
        print("  Input: 'send email to john@example.com about meeting'")
        print("  Intent: \(mailCommand.intent)")
        print("  Target App: \(mailCommand.targetApplication ?? "none")")
        print("  Confidence: \(String(format: "%.1f%%", mailCommand.confidence * 100))")
        print("  Parameters: \(mailCommand.parameters)")
        
        // Test Calendar command
        let calendarCommand = parser.parseCommand("create event Team Meeting at 2pm")
        print("\nCalendar Command:")
        print("  Input: 'create event Team Meeting at 2pm'")
        print("  Intent: \(calendarCommand.intent)")
        print("  Target App: \(calendarCommand.targetApplication ?? "none")")
        print("  Confidence: \(String(format: "%.1f%%", calendarCommand.confidence * 100))")
        print("  Parameters: \(calendarCommand.parameters)")
    }
    
    // MARK: - App Discovery Tests
    
    static func testAppDiscovery() async {
        print("\n📱 Testing App Discovery")
        print("-" * 25)
        
        let appDiscovery = AppDiscoveryService()
        await appDiscovery.discoverInstalledApps()
        
        print("Discovered \(appDiscovery.discoveredApps.count) applications")
        
        // Test finding specific apps
        let finder = appDiscovery.findApp(bundleIdentifier: "com.apple.finder")
        if let finder = finder {
            print("✅ Found Finder: \(finder.displayName)")
            print("   Path: \(finder.path)")
            print("   Integration Methods: \(finder.supportedIntegrationMethods.map { $0.displayName }.joined(separator: ", "))")
        } else {
            print("❌ Finder not found")
        }
        
        // Test finding apps by name
        let safariApps = appDiscovery.findApps(byName: "Safari")
        if !safariApps.isEmpty {
            print("✅ Found Safari apps: \(safariApps.count)")
            for app in safariApps {
                print("   - \(app.displayName) (\(app.bundleIdentifier))")
            }
        } else {
            print("ℹ️  No Safari apps found")
        }
        
        // Test app installation check
        print("Finder installed: \(appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.finder"))")
        print("Non-existent app installed: \(appDiscovery.isAppInstalled(bundleIdentifier: "com.nonexistent.app"))")
    }
    
    // MARK: - App Integration Models Tests
    
    static func testAppIntegrationModels() async {
        print("\n🔧 Testing App Integration Models")
        print("-" * 30)
        
        // Test CommandDefinition
        let commandDef = CommandDefinition(vvcccbdendhhfhnlctrunhbdrgkkjtbfjkcedtrduidc
        
            name: "test_command",
            description: "A test command",
            parameters: [
                CommandParameter(name: "param1", type: .string, description: "Test parameter")
            ],
            examples: ["test example"],
            integrationMethod: .appleScript
        )
        
        print("Command Definition:")
        print("  Name: \(commandDef.name)")
        print("  Description: \(commandDef.description)")
        print("  Parameters: \(commandDef.parameters.count)")
        print("  Integration Method: \(commandDef.integrationMethod.displayName)")
        
        // Test AppCapabilities
        let capabilities = AppCapabilities(
            canLaunch: true,
            canQuit: true,
            canCreateDocuments: true,
            customCapabilities: ["canTest": true]
        )
        
        print("\nApp Capabilities:")
        print("  Can Launch: \(capabilities.canLaunch)")
        print("  Can Quit: \(capabilities.canQuit)")
        print("  Can Create Documents: \(capabilities.canCreateDocuments)")
        print("  Custom Capabilities: \(capabilities.customCapabilities)")
        
        // Test CommandResult
        let result = CommandResult(
            success: true,
            output: "Test command executed successfully",
            executionTime: 0.123,
            integrationMethod: .appleScript,
            followUpActions: ["Next step", "Another action"]
        )
        
        print("\nCommand Result:")
        print("  Success: \(result.success)")
        print("  Output: \(result.output)")
        print("  Execution Time: \(String(format: "%.3f", result.executionTime))s")
        print("  Integration Method: \(result.integrationMethod.displayName)")
        print("  Follow-up Actions: \(result.followUpActions.count)")
        
        // Test Integration Methods
        print("\nIntegration Methods (by priority):")
        let methods = IntegrationMethod.allCases.sorted { $0.priority < $1.priority }
        for method in methods {
            print("  \(method.priority). \(method.displayName)")
        }
    }
}

// MARK: - String Extension for Repeat
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// MARK: - Main Execution
// Uncomment the following lines to run the test when this file is executed directly
/*
if CommandLine.arguments.contains("--run-app-integration-tests") {
    Task {
        await AppIntegrationSimpleTest.runTests()
    }
}
*/