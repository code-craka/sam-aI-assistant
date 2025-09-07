import XCTest
@testable import Sam

class AppIntegrationManagerTests: XCTestCase {
    
    var appIntegrationManager: AppIntegrationManager!
    var mockAppDiscovery: MockAppDiscoveryService!
    
    override func setUp() {
        super.setUp()
        mockAppDiscovery = MockAppDiscoveryService()
        appIntegrationManager = AppIntegrationManager()
        
        // Wait for initialization
        let expectation = XCTestExpectation(description: "Manager initialization")
        Task {
            while !appIntegrationManager.isInitialized {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    override func tearDown() {
        appIntegrationManager = nil
        mockAppDiscovery = nil
        super.tearDown()
    }
    
    // MARK: - Command Parsing Tests
    
    func testCommandParsingForSafari() async throws {
        let command = "open google.com in Safari"
        
        do {
            let result = try await appIntegrationManager.executeCommand(command)
            XCTAssertTrue(result.success)
            XCTAssertTrue(result.output.contains("google.com"))
        } catch AppIntegrationError.appNotInstalled {
            // Safari might not be available in test environment
            XCTSkip("Safari not available in test environment")
        }
    }
    
    func testCommandParsingForMail() async throws {
        let command = "send email to test@example.com about project update"
        
        do {
            let result = try await appIntegrationManager.executeCommand(command)
            XCTAssertTrue(result.success)
            XCTAssertTrue(result.output.contains("test@example.com"))
        } catch AppIntegrationError.appNotInstalled {
            // Mail might not be available in test environment
            XCTSkip("Mail not available in test environment")
        }
    }
    
    func testCommandParsingForCalendar() async throws {
        let command = "create event meeting at 2pm"
        
        do {
            let result = try await appIntegrationManager.executeCommand(command)
            XCTAssertTrue(result.success)
            XCTAssertTrue(result.output.contains("meeting"))
        } catch AppIntegrationError.appNotInstalled {
            // Calendar might not be available in test environment
            XCTSkip("Calendar not available in test environment")
        }
    }
    
    // MARK: - Integration Registration Tests
    
    func testIntegrationRegistration() {
        let mockIntegration = MockAppIntegration()
        appIntegrationManager.registerIntegration(mockIntegration)
        
        XCTAssertTrue(appIntegrationManager.isIntegrationAvailable(for: mockIntegration.bundleIdentifier))
        
        let retrievedIntegration = appIntegrationManager.getIntegration(for: mockIntegration.bundleIdentifier)
        XCTAssertNotNil(retrievedIntegration)
        XCTAssertEqual(retrievedIntegration?.bundleIdentifier, mockIntegration.bundleIdentifier)
    }
    
    func testGetAvailableIntegrations() {
        let mockIntegration = MockAppIntegration()
        appIntegrationManager.registerIntegration(mockIntegration)
        
        let integrations = appIntegrationManager.getAvailableIntegrations()
        XCTAssertTrue(integrations.contains { $0.bundleIdentifier == mockIntegration.bundleIdentifier })
    }
    
    func testGetSupportedCommands() {
        let mockIntegration = MockAppIntegration()
        appIntegrationManager.registerIntegration(mockIntegration)
        
        let commands = appIntegrationManager.getSupportedCommands(for: mockIntegration.bundleIdentifier)
        XCTAssertEqual(commands.count, mockIntegration.supportedCommands.count)
    }
    
    // MARK: - App Launch/Quit Tests
    
    func testLaunchApp() async throws {
        // Test with a system app that should always be available
        do {
            let result = try await appIntegrationManager.launchApp("com.apple.finder")
            XCTAssertTrue(result.success)
            XCTAssertTrue(result.output.contains("launched") || result.output.contains("Finder"))
        } catch {
            XCTFail("Failed to launch Finder: \(error)")
        }
    }
    
    func testLaunchNonExistentApp() async {
        do {
            _ = try await appIntegrationManager.launchApp("com.nonexistent.app")
            XCTFail("Should have thrown an error for non-existent app")
        } catch AppIntegrationError.appNotInstalled {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCommand() async {
        do {
            _ = try await appIntegrationManager.executeCommand("invalid command with no app")
            XCTFail("Should have thrown an error for invalid command")
        } catch AppIntegrationError.commandNotSupported {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCommandWithoutTargetApp() async {
        do {
            _ = try await appIntegrationManager.executeCommand("do something generic")
            XCTFail("Should have thrown an error for command without target app")
        } catch AppIntegrationError.commandNotSupported {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock Classes

class MockAppDiscoveryService: AppDiscoveryService {
    override func discoverInstalledApps() async {
        // Mock implementation - add some common apps
        await MainActor.run {
            discoveredApps = [
                AppDiscoveryResult(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari",
                    version: "16.0",
                    path: "/Applications/Safari.app",
                    isRunning: false,
                    supportedIntegrationMethods: [.urlScheme, .appleScript],
                    capabilities: AppCapabilities(canLaunch: true, canQuit: true)
                ),
                AppDiscoveryResult(
                    bundleIdentifier: "com.apple.mail",
                    displayName: "Mail",
                    version: "16.0",
                    path: "/Applications/Mail.app",
                    isRunning: false,
                    supportedIntegrationMethods: [.urlScheme, .appleScript],
                    capabilities: AppCapabilities(canLaunch: true, canQuit: true, canCreateDocuments: true)
                )
            ]
            isScanning = false
        }
    }
}

class MockAppIntegration: AppIntegration {
    let bundleIdentifier = "com.test.mockapp"
    let displayName = "Mock App"
    
    let supportedCommands = [
        CommandDefinition(
            name: "test_command",
            description: "A test command",
            integrationMethod: .appleScript
        )
    ]
    
    let integrationMethods: [IntegrationMethod] = [.appleScript]
    let isInstalled = true
    
    func canHandle(_ command: ParsedCommand) -> Bool {
        return command.targetApplication == bundleIdentifier
    }
    
    func execute(_ command: ParsedCommand) async throws -> CommandResult {
        return CommandResult(
            success: true,
            output: "Mock command executed",
            integrationMethod: .appleScript
        )
    }
    
    func getCapabilities() -> AppCapabilities {
        return AppCapabilities(canLaunch: true, canQuit: true)
    }
}

// MARK: - Command Parser Tests

class CommandParserTests: XCTestCase {
    
    var commandParser: CommandParser!
    
    override func setUp() {
        super.setUp()
        commandParser = CommandParser()
    }
    
    override func tearDown() {
        commandParser = nil
        super.tearDown()
    }
    
    func testParseSimpleAppLaunch() {
        let command = "open Safari"
        let parsed = commandParser.parseCommand(command)
        
        XCTAssertEqual(parsed.intent, .appControl)
        XCTAssertEqual(parsed.targetApplication, "com.apple.Safari")
        XCTAssertGreaterThan(parsed.confidence, 0.5)
    }
    
    func testParseEmailCommand() {
        let command = "send email to john@example.com about project update"
        let parsed = commandParser.parseCommand(command)
        
        XCTAssertEqual(parsed.intent, .appControl)
        XCTAssertEqual(parsed.targetApplication, "com.apple.mail")
        XCTAssertEqual(parsed.parameters["email"], "john@example.com")
        XCTAssertEqual(parsed.parameters["subject"], "project update")
    }
    
    func testParseURLCommand() {
        let command = "open google.com in Safari"
        let parsed = commandParser.parseCommand(command)
        
        XCTAssertEqual(parsed.intent, .appControl)
        XCTAssertEqual(parsed.targetApplication, "com.apple.Safari")
        XCTAssertTrue(parsed.parameters["url"]?.contains("google.com") == true)
    }
    
    func testParseCalendarCommand() {
        let command = "create event meeting at 2pm"
        let parsed = commandParser.parseCommand(command)
        
        XCTAssertEqual(parsed.intent, .appControl)
        XCTAssertEqual(parsed.targetApplication, "com.apple.iCal")
        XCTAssertEqual(parsed.parameters["time"], "2pm")
    }
    
    func testExtractAppCommands() {
        let input = "compose email to team@company.com about weekly standup"
        let commands = commandParser.extractAppCommands(input, for: "com.apple.mail")
        
        XCTAssertEqual(commands["to"], "team@company.com")
        XCTAssertEqual(commands["subject"], "weekly standup")
    }
}

// MARK: - App Discovery Tests

class AppDiscoveryServiceTests: XCTestCase {
    
    var appDiscovery: AppDiscoveryService!
    
    override func setUp() {
        super.setUp()
        appDiscovery = AppDiscoveryService()
    }
    
    override func tearDown() {
        appDiscovery = nil
        super.tearDown()
    }
    
    func testDiscoverInstalledApps() async {
        await appDiscovery.discoverInstalledApps()
        
        XCTAssertFalse(appDiscovery.discoveredApps.isEmpty)
        XCTAssertFalse(appDiscovery.isScanning)
        
        // Should find Finder (always present on macOS)
        let finder = appDiscovery.findApp(bundleIdentifier: "com.apple.finder")
        XCTAssertNotNil(finder)
        XCTAssertEqual(finder?.displayName, "Finder")
    }
    
    func testFindAppsByName() async {
        await appDiscovery.discoverInstalledApps()
        
        let safariApps = appDiscovery.findApps(byName: "Safari")
        if !safariApps.isEmpty {
            XCTAssertTrue(safariApps.first?.bundleIdentifier.contains("Safari") == true)
        }
    }
    
    func testIsAppInstalled() async {
        await appDiscovery.discoverInstalledApps()
        
        // Finder should always be installed
        XCTAssertTrue(appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.finder"))
        
        // Non-existent app should not be installed
        XCTAssertFalse(appDiscovery.isAppInstalled(bundleIdentifier: "com.nonexistent.app"))
    }
    
    func testGetAppCapabilities() async {
        await appDiscovery.discoverInstalledApps()
        
        let capabilities = appDiscovery.getAppCapabilities(bundleIdentifier: "com.apple.finder")
        XCTAssertNotNil(capabilities)
        XCTAssertTrue(capabilities?.canLaunch == true)
    }
}