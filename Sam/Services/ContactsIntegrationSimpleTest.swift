import Foundation

// MARK: - Simple Test for Contacts Integration
class ContactsIntegrationSimpleTest {
    
    static func runTests() {
        print("🧪 Running Contacts Integration Simple Tests...")
        
        testBasicProperties()
        testSupportedCommands()
        testCommandParsing()
        
        print("✅ Contacts Integration Simple Tests completed!")
    }
    
    private static func testBasicProperties() {
        print("Testing basic properties...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let contactsIntegration = ContactsIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        assert(contactsIntegration.bundleIdentifier == "com.apple.AddressBook", "Bundle identifier should be correct")
        assert(contactsIntegration.displayName == "Contacts", "Display name should be correct")
        assert(contactsIntegration.integrationMethods.contains(.appleScript), "Should support AppleScript")
        assert(contactsIntegration.integrationMethods.contains(.nativeSDK), "Should support native SDK")
        
        print("✓ Basic properties test passed")
    }
    
    private static func testSupportedCommands() {
        print("Testing supported commands...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let contactsIntegration = ContactsIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        let commands = contactsIntegration.supportedCommands
        assert(commands.count > 0, "Should have supported commands")
        
        let commandNames = commands.map { $0.name }
        assert(commandNames.contains("add_contact"), "Should support add_contact")
        assert(commandNames.contains("search_contact"), "Should support search_contact")
        assert(commandNames.contains("get_contact_info"), "Should support get_contact_info")
        assert(commandNames.contains("update_contact"), "Should support update_contact")
        
        print("✓ Supported commands test passed")
    }
    
    private static func testCommandParsing() {
        print("Testing command parsing...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let contactsIntegration = ContactsIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        // Test can handle correct commands
        let validCommand = ParsedCommand(
            originalText: "add contact John Smith",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.AddressBook",
            requiresConfirmation: false
        )
        
        assert(contactsIntegration.canHandle(validCommand), "Should handle valid contact commands")
        
        // Test cannot handle wrong app
        let wrongAppCommand = ParsedCommand(
            originalText: "add contact John Smith",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        assert(!contactsIntegration.canHandle(wrongAppCommand), "Should not handle commands for wrong app")
        
        // Test cannot handle wrong intent
        let wrongIntentCommand = ParsedCommand(
            originalText: "add contact John Smith",
            intent: .fileOperation,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.AddressBook",
            requiresConfirmation: false
        )
        
        assert(!contactsIntegration.canHandle(wrongIntentCommand), "Should not handle commands with wrong intent")
        
        print("✓ Command parsing test passed")
    }
    
    private static func testCapabilities() {
        print("Testing capabilities...")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let contactsIntegration = ContactsIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        let capabilities = contactsIntegration.getCapabilities()
        
        assert(capabilities.canLaunch, "Should be able to launch")
        assert(capabilities.canQuit, "Should be able to quit")
        assert(capabilities.canCreateDocuments, "Should be able to create documents")
        
        assert(capabilities.customCapabilities["canAddContact"] == true, "Should be able to add contacts")
        assert(capabilities.customCapabilities["canSearchContact"] == true, "Should be able to search contacts")
        assert(capabilities.customCapabilities["canUpdateContact"] == true, "Should be able to update contacts")
        assert(capabilities.customCapabilities["canDeleteContact"] == true, "Should be able to delete contacts")
        assert(capabilities.customCapabilities["canAccessAddressBook"] == true, "Should be able to access address book")
        
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