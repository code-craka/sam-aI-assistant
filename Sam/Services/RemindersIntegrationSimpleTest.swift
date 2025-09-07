import Foundation

// MARK: - Simple Test for Reminders Integration
class RemindersIntegrationSimpleTest {
    
    static func runTests() {
        print("🧪 Running Reminders Integration Simple Tests...")
        
        testBasicProperties()
        testSupportedCommands()
        testCommandParsing()
        testCapabilities()
        
        print("✅ Reminders Integration Simple Tests completed!")
    }
    
    private static func testBasicProperties() {
        print("Testing basic properties...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let remindersIntegration = RemindersIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        assert(remindersIntegration.bundleIdentifier == "com.apple.reminders", "Bundle identifier should be correct")
        assert(remindersIntegration.displayName == "Reminders", "Display name should be correct")
        assert(remindersIntegration.integrationMethods.contains(.appleScript), "Should support AppleScript")
        assert(remindersIntegration.integrationMethods.contains(.accessibility), "Should support accessibility")
        
        print("✓ Basic properties test passed")
    }
    
    private static func testSupportedCommands() {
        print("Testing supported commands...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let remindersIntegration = RemindersIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        let commands = remindersIntegration.supportedCommands
        assert(commands.count > 0, "Should have supported commands")
        
        let commandNames = commands.map { $0.name }
        assert(commandNames.contains("create_reminder"), "Should support create_reminder")
        assert(commandNames.contains("create_task"), "Should support create_task")
        assert(commandNames.contains("complete_reminder"), "Should support complete_reminder")
        assert(commandNames.contains("show_reminders"), "Should support show_reminders")
        assert(commandNames.contains("create_list"), "Should support create_list")
        assert(commandNames.contains("delete_reminder"), "Should support delete_reminder")
        
        print("✓ Supported commands test passed")
    }
    
    private static func testCommandParsing() {
        print("Testing command parsing...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let remindersIntegration = RemindersIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        // Test can handle correct commands
        let validCommand = ParsedCommand(
            originalText: "remind me to call John",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.reminders",
            requiresConfirmation: false
        )
        
        assert(remindersIntegration.canHandle(validCommand), "Should handle valid reminder commands")
        
        // Test cannot handle wrong app
        let wrongAppCommand = ParsedCommand(
            originalText: "remind me to call John",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        assert(!remindersIntegration.canHandle(wrongAppCommand), "Should not handle commands for wrong app")
        
        // Test cannot handle wrong intent
        let wrongIntentCommand = ParsedCommand(
            originalText: "remind me to call John",
            intent: .fileOperation,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.reminders",
            requiresConfirmation: false
        )
        
        assert(!remindersIntegration.canHandle(wrongIntentCommand), "Should not handle commands with wrong intent")
        
        print("✓ Command parsing test passed")
    }
    
    private static func testCapabilities() {
        print("Testing capabilities...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let remindersIntegration = RemindersIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        let capabilities = remindersIntegration.getCapabilities()
        
        assert(capabilities.canLaunch, "Should be able to launch")
        assert(capabilities.canQuit, "Should be able to quit")
        assert(capabilities.canCreateDocuments, "Should be able to create documents")
        
        assert(capabilities.customCapabilities["canCreateReminder"] == true, "Should be able to create reminders")
        assert(capabilities.customCapabilities["canCompleteReminder"] == true, "Should be able to complete reminders")
        assert(capabilities.customCapabilities["canDeleteReminder"] == true, "Should be able to delete reminders")
        assert(capabilities.customCapabilities["canCreateList"] == true, "Should be able to create lists")
        assert(capabilities.customCapabilities["canShowReminders"] == true, "Should be able to show reminders")
        assert(capabilities.customCapabilities["canSetDueDate"] == true, "Should be able to set due dates")
        assert(capabilities.customCapabilities["canSetPriority"] == true, "Should be able to set priority")
        
        print("✓ Capabilities test passed")
    }
}

// MARK: - Mock Classes for Testing

private class MockAppDiscoveryService {
    func isAppInstalled(bundleIdentifier: String) -> Bool {
        return ["com.apple.AddressBook", "com.apple.mail", "com.apple.iCal", "com.apple.reminders"].contains(bundleIdentifier)
    }
}

private class MockAppleScriptEngine {
    func executeScript(_ script: String) async throws -> String {
        return "Mock script result"
    }
}