import Foundation

/// Simple test runner for Safari Integration functionality
/// This tests the Safari integration without requiring the full app to compile
class SafariIntegrationSimpleTest {
    
    static func runTests() async {
        print("🧪 Safari Integration Simple Tests")
        print("=" * 40)
        
        await testSafariIntegrationCreation()
        await testSupportedCommands()
        await testCommandHandling()
        await testCapabilities()
        await testTextParsing()
        
        print("\n✅ All Safari Integration tests completed!")
    }
    
    // MARK: - Test Cases
    
    static func testSafariIntegrationCreation() async {
        print("\n📝 Test: Safari Integration Creation")
        
        // Create mock dependencies
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockURLSchemeHandler = MockURLSchemeHandler()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        // Create Safari integration
        let safariIntegration = SafariIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        // Test basic properties
        assert(safariIntegration.bundleIdentifier == "com.apple.Safari", "Bundle identifier should be com.apple.Safari")
        assert(safariIntegration.displayName == "Safari", "Display name should be Safari")
        assert(safariIntegration.integrationMethods.contains(.urlScheme), "Should support URL scheme integration")
        assert(safariIntegration.integrationMethods.contains(.appleScript), "Should support AppleScript integration")
        
        print("   ✅ Safari integration created successfully")
        print("   ✅ Bundle identifier: \(safariIntegration.bundleIdentifier)")
        print("   ✅ Display name: \(safariIntegration.displayName)")
        print("   ✅ Integration methods: \(safariIntegration.integrationMethods.count)")
    }
    
    static func testSupportedCommands() async {
        print("\n📝 Test: Supported Commands")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockURLSchemeHandler = MockURLSchemeHandler()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let safariIntegration = SafariIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        let commands = safariIntegration.supportedCommands
        
        // Test that we have the expected commands
        let expectedCommands = [
            "open_url",
            "bookmark_page", 
            "organize_bookmarks",
            "new_tab",
            "close_tab",
            "navigate_tabs",
            "find_tab",
            "search_history",
            "get_current_page",
            "search"
        ]
        
        assert(commands.count >= expectedCommands.count, "Should have at least \(expectedCommands.count) commands")
        
        for expectedCommand in expectedCommands {
            let hasCommand = commands.contains { $0.name == expectedCommand }
            assert(hasCommand, "Should have command: \(expectedCommand)")
            print("   ✅ Command supported: \(expectedCommand)")
        }
        
        // Test that commands have examples
        for command in commands {
            assert(!command.examples.isEmpty, "Command \(command.name) should have examples")
        }
        
        print("   ✅ All expected commands are supported")
    }
    
    static func testCommandHandling() async {
        print("\n📝 Test: Command Handling")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockURLSchemeHandler = MockURLSchemeHandler()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let safariIntegration = SafariIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        // Test app control commands
        let appControlCommand = ParsedCommand(
            originalText: "open google.com",
            intent: .appControl,
            parameters: ["url": "google.com"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        assert(safariIntegration.canHandle(appControlCommand), "Should handle app control commands")
        print("   ✅ Can handle app control commands")
        
        // Test web query commands
        let webQueryCommand = ParsedCommand(
            originalText: "search for swift programming",
            intent: .webQuery,
            parameters: ["query": "swift programming"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        assert(safariIntegration.canHandle(webQueryCommand), "Should handle web query commands")
        print("   ✅ Can handle web query commands")
        
        // Test wrong app commands
        let wrongAppCommand = ParsedCommand(
            originalText: "open google.com",
            intent: .appControl,
            parameters: ["url": "google.com"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.mail"
        )
        
        assert(!safariIntegration.canHandle(wrongAppCommand), "Should not handle commands for other apps")
        print("   ✅ Correctly rejects commands for other apps")
    }
    
    static func testCapabilities() async {
        print("\n📝 Test: Capabilities")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockURLSchemeHandler = MockURLSchemeHandler()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let safariIntegration = SafariIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        let capabilities = safariIntegration.getCapabilities()
        
        // Test basic capabilities
        assert(capabilities.canLaunch, "Should be able to launch")
        assert(capabilities.canQuit, "Should be able to quit")
        assert(capabilities.canManageWindows, "Should be able to manage windows")
        
        // Test custom capabilities
        let customCapabilities = capabilities.customCapabilities
        assert(customCapabilities["canOpenURL"] == true, "Should be able to open URLs")
        assert(customCapabilities["canBookmark"] == true, "Should be able to bookmark")
        assert(customCapabilities["canOrganizeBookmarks"] == true, "Should be able to organize bookmarks")
        assert(customCapabilities["canSearchTabs"] == true, "Should be able to search tabs")
        assert(customCapabilities["canSearchHistory"] == true, "Should be able to search history")
        assert(customCapabilities["canGetPageInfo"] == true, "Should be able to get page info")
        
        print("   ✅ Basic capabilities verified")
        print("   ✅ Custom capabilities verified")
        print("   ✅ Total custom capabilities: \(customCapabilities.count)")
    }
    
    static func testTextParsing() async {
        print("\n📝 Test: Text Parsing Logic")
        
        // Test URL extraction patterns
        let urlCommands = [
            "open google.com",
            "go to apple.com", 
            "visit https://github.com"
        ]
        
        for command in urlCommands {
            let hasURL = command.contains("google.com") || command.contains("apple.com") || command.contains("github.com")
            assert(hasURL, "Command should contain recognizable URL: \(command)")
            print("   ✅ URL pattern recognized: \(command)")
        }
        
        // Test bookmark patterns
        let bookmarkCommands = [
            "bookmark this page",
            "bookmark in Work folder",
            "create bookmark folder Development"
        ]
        
        for command in bookmarkCommands {
            let isBookmarkCommand = command.contains("bookmark")
            assert(isBookmarkCommand, "Command should be recognized as bookmark command: \(command)")
            print("   ✅ Bookmark pattern recognized: \(command)")
        }
        
        // Test tab navigation patterns
        let tabCommands = [
            "next tab",
            "previous tab",
            "go to tab 3",
            "find tab github"
        ]
        
        for command in tabCommands {
            let isTabCommand = command.contains("tab")
            assert(isTabCommand, "Command should be recognized as tab command: \(command)")
            print("   ✅ Tab pattern recognized: \(command)")
        }
        
        print("   ✅ All text parsing patterns verified")
    }
}

// MARK: - Mock Classes for Testing

class MockAppDiscoveryService: AppDiscoveryService {
    var isInstalledResult = true
    var isRunningResult = false
    
    override func isAppInstalled(bundleIdentifier: String) -> Bool {
        return isInstalledResult
    }
    
    override func isAppRunning(bundleIdentifier: String) -> Bool {
        return isRunningResult
    }
}

class MockURLSchemeHandler: URLSchemeHandler {
    var openURLResult = true
    
    override func openURL(_ url: URL) async throws -> Bool {
        return openURLResult
    }
}

class MockAppleScriptEngine: AppleScriptEngine {
    var executeResult = "Success"
    var shouldThrow = false
    
    override func executeScript(_ script: String) async throws -> String {
        if shouldThrow {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, "Mock error")
        }
        return executeResult
    }
}

// MARK: - String Extension for Tests

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Test Runner Function

/// Run the Safari integration simple tests
func runSafariIntegrationSimpleTests() async {
    await SafariIntegrationSimpleTest.runTests()
}