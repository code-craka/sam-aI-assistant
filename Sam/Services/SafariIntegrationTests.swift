import XCTest
@testable import Sam

class SafariIntegrationTests: XCTestCase {
    
    var safariIntegration: SafariIntegration!
    var mockAppDiscovery: MockAppDiscoveryService!
    var mockURLSchemeHandler: MockURLSchemeHandler!
    var mockAppleScriptEngine: MockAppleScriptEngine!
    
    override func setUp() {
        super.setUp()
        mockAppDiscovery = MockAppDiscoveryService()
        mockURLSchemeHandler = MockURLSchemeHandler()
        mockAppleScriptEngine = MockAppleScriptEngine()
        
        safariIntegration = SafariIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
    }
    
    override func tearDown() {
        safariIntegration = nil
        mockAppDiscovery = nil
        mockURLSchemeHandler = nil
        mockAppleScriptEngine = nil
        super.tearDown()
    }
    
    // MARK: - Basic Integration Tests
    
    func testSafariIntegrationProperties() {
        XCTAssertEqual(safariIntegration.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(safariIntegration.displayName, "Safari")
        XCTAssertTrue(safariIntegration.integrationMethods.contains(.urlScheme))
        XCTAssertTrue(safariIntegration.integrationMethods.contains(.appleScript))
    }
    
    func testSupportedCommands() {
        let commands = safariIntegration.supportedCommands
        XCTAssertTrue(commands.count >= 8) // Should have at least 8 commands
        
        let commandNames = commands.map { $0.name }
        XCTAssertTrue(commandNames.contains("open_url"))
        XCTAssertTrue(commandNames.contains("bookmark_page"))
        XCTAssertTrue(commandNames.contains("organize_bookmarks"))
        XCTAssertTrue(commandNames.contains("find_tab"))
        XCTAssertTrue(commandNames.contains("search_history"))
        XCTAssertTrue(commandNames.contains("get_current_page"))
    }
    
    func testCapabilities() {
        let capabilities = safariIntegration.getCapabilities()
        XCTAssertTrue(capabilities.canLaunch)
        XCTAssertTrue(capabilities.canManageWindows)
        XCTAssertTrue(capabilities.customCapabilities["canOpenURL"] == true)
        XCTAssertTrue(capabilities.customCapabilities["canBookmark"] == true)
        XCTAssertTrue(capabilities.customCapabilities["canOrganizeBookmarks"] == true)
        XCTAssertTrue(capabilities.customCapabilities["canSearchTabs"] == true)
        XCTAssertTrue(capabilities.customCapabilities["canSearchHistory"] == true)
    }
    
    // MARK: - Command Handling Tests
    
    func testCanHandleAppControlCommands() {
        let command = ParsedCommand(
            originalText: "open google.com",
            intent: .appControl,
            parameters: ["url": "google.com"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        XCTAssertTrue(safariIntegration.canHandle(command))
    }
    
    func testCanHandleWebQueryCommands() {
        let command = ParsedCommand(
            originalText: "search for swift programming",
            intent: .webQuery,
            parameters: ["query": "swift programming"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        XCTAssertTrue(safariIntegration.canHandle(command))
    }
    
    func testCannotHandleWrongApp() {
        let command = ParsedCommand(
            originalText: "open google.com",
            intent: .appControl,
            parameters: ["url": "google.com"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.mail"
        )
        
        XCTAssertFalse(safariIntegration.canHandle(command))
    }
    
    // MARK: - URL Opening Tests
    
    func testOpenURL() async throws {
        mockAppDiscovery.isRunningResult = true
        mockURLSchemeHandler.openURLResult = true
        
        let command = ParsedCommand(
            originalText: "open google.com",
            intent: .appControl,
            parameters: ["url": "google.com"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        let result = try await safariIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Opened https://google.com"))
        XCTAssertEqual(result.integrationMethod, .urlScheme)
    }
    
    // MARK: - Bookmark Tests
    
    func testBookmarkCurrentPage() async throws {
        mockAppDiscovery.isRunningResult = true
        mockAppleScriptEngine.executeResult = "Success"
        
        let command = ParsedCommand(
            originalText: "bookmark this page",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        let result = try await safariIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Added current page to Safari bookmarks"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testBookmarkInFolder() async throws {
        mockAppDiscovery.isRunningResult = true
        mockAppleScriptEngine.executeResult = "Success"
        
        let command = ParsedCommand(
            originalText: "bookmark in Work folder",
            intent: .appControl,
            parameters: ["folder": "Work"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        let result = try await safariIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Added current page to 'Work' bookmark folder"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Tab Management Tests
    
    func testNavigateToNextTab() async throws {
        mockAppDiscovery.isRunningResult = true
        mockAppleScriptEngine.executeResult = "Switched to next tab: Example Page"
        
        let command = ParsedCommand(
            originalText: "next tab",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        let result = try await safariIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Switched to next tab"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testFindTab() async throws {
        mockAppDiscovery.isRunningResult = true
        mockAppleScriptEngine.executeResult = "Found and switched to tab 2: GitHub"
        
        let command = ParsedCommand(
            originalText: "find tab github",
            intent: .appControl,
            parameters: ["query": "github"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        let result = try await safariIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Found and switched to tab"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - History Search Tests
    
    func testSearchHistory() async throws {
        mockAppDiscovery.isRunningResult = true
        mockAppleScriptEngine.executeResult = "Opened Safari history"
        
        let command = ParsedCommand(
            originalText: "search history for apple",
            intent: .appControl,
            parameters: ["query": "apple"],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        let result = try await safariIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Opened Safari history page"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Current Page Info Tests
    
    func testGetCurrentPageInfo() async throws {
        mockAppDiscovery.isRunningResult = true
        mockAppleScriptEngine.executeResult = "Current page: Example\\nURL: https://example.com\\nTab 1 of 3"
        
        let command = ParsedCommand(
            originalText: "what page am I on",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            requiresConfirmation: false,
            targetApplication: "com.apple.Safari"
        )
        
        let result = try await safariIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Current page: Example"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Text Parsing Tests
    
    func testExtractFolderName() {
        // This would test the private method if it were made internal for testing
        // For now, we test through the public interface
    }
    
    func testExtractTabNumber() {
        // This would test the private method if it were made internal for testing
        // For now, we test through the public interface
    }
}

// MARK: - Mock Classes

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