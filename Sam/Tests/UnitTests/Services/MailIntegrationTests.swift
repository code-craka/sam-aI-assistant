import XCTest
@testable import Sam

class MailIntegrationTests: XCTestCase {
    
    var mailIntegration: MailIntegration!
    var mockAppDiscovery: MockAppDiscoveryService!
    var mockURLSchemeHandler: MockURLSchemeHandler!
    var mockAppleScriptEngine: MockAppleScriptEngine!
    
    override func setUp() {
        super.setUp()
        mockAppDiscovery = MockAppDiscoveryService()
        mockURLSchemeHandler = MockURLSchemeHandler()
        mockAppleScriptEngine = MockAppleScriptEngine()
        
        mailIntegration = MailIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
    }
    
    override func tearDown() {
        mailIntegration = nil
        mockAppDiscovery = nil
        mockURLSchemeHandler = nil
        mockAppleScriptEngine = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testBundleIdentifier() {
        XCTAssertEqual(mailIntegration.bundleIdentifier, "com.apple.mail")
    }
    
    func testDisplayName() {
        XCTAssertEqual(mailIntegration.displayName, "Mail")
    }
    
    func testSupportedCommands() {
        let commands = mailIntegration.supportedCommands
        XCTAssertGreaterThan(commands.count, 0)
        
        let commandNames = commands.map { $0.name }
        XCTAssertTrue(commandNames.contains("compose_email"))
        XCTAssertTrue(commandNames.contains("search_emails"))
        XCTAssertTrue(commandNames.contains("check_new_mail"))
        XCTAssertTrue(commandNames.contains("create_mailbox"))
        XCTAssertTrue(commandNames.contains("reply_email"))
        XCTAssertTrue(commandNames.contains("forward_email"))
    }
    
    func testIntegrationMethods() {
        let methods = mailIntegration.integrationMethods
        XCTAssertTrue(methods.contains(.urlScheme))
        XCTAssertTrue(methods.contains(.appleScript))
        XCTAssertTrue(methods.contains(.accessibility))
    }
    
    // MARK: - Command Handling Tests
    
    func testCanHandleAppControlCommand() {
        let command = ParsedCommand(
            originalText: "send email to john@example.com",
            intent: .appControl,
            parameters: ["email": "john@example.com"],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        XCTAssertTrue(mailIntegration.canHandle(command))
    }
    
    func testCannotHandleWrongApp() {
        let command = ParsedCommand(
            originalText: "send email to john@example.com",
            intent: .appControl,
            parameters: ["email": "john@example.com"],
            confidence: 0.9,
            targetApplication: "com.apple.safari",
            requiresConfirmation: false
        )
        
        XCTAssertFalse(mailIntegration.canHandle(command))
    }
    
    func testCannotHandleWrongIntent() {
        let command = ParsedCommand(
            originalText: "send email to john@example.com",
            intent: .fileOperation,
            parameters: ["email": "john@example.com"],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        XCTAssertFalse(mailIntegration.canHandle(command))
    }
    
    // MARK: - Email Composition Tests
    
    func testComposeEmailWithParameters() async throws {
        mockURLSchemeHandler.shouldSucceed = true
        
        let command = ParsedCommand(
            originalText: "send email to john@example.com",
            intent: .appControl,
            parameters: ["email": "john@example.com", "subject": "Test Subject"],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        let result = try await mailIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("john@example.com"))
        XCTAssertEqual(result.integrationMethod, .urlScheme)
        XCTAssertTrue(mockURLSchemeHandler.openURLCalled)
    }
    
    func testComposeEmailFromNaturalLanguage() async throws {
        mockURLSchemeHandler.shouldSucceed = true
        
        let command = ParsedCommand(
            originalText: "send email to sarah@company.com about project update",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        let result = try await mailIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("sarah@company.com"))
        XCTAssertEqual(result.integrationMethod, .urlScheme)
    }
    
    // MARK: - Email Search Tests
    
    func testSearchEmails() async throws {
        mockAppleScriptEngine.scriptResult = "Found 5 emails matching 'project update'"
        
        let command = ParsedCommand(
            originalText: "search emails for project update",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        let result = try await mailIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Found 5 emails"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    // MARK: - Mail Management Tests
    
    func testCheckNewMail() async throws {
        mockAppleScriptEngine.scriptResult = "Checking for new mail..."
        
        let command = ParsedCommand(
            originalText: "check mail",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        let result = try await mailIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Checking for new mail"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testCreateMailbox() async throws {
        mockAppleScriptEngine.scriptResult = "Created mailbox 'Projects'"
        
        let command = ParsedCommand(
            originalText: "create mailbox for projects",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        let result = try await mailIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Projects"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Reply and Forward Tests
    
    func testReplyToEmail() async throws {
        mockAppleScriptEngine.scriptResult = "Opened reply to: Meeting Tomorrow"
        
        let command = ParsedCommand(
            originalText: "reply to this email",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        let result = try await mailIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("reply"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testForwardEmail() async throws {
        mockAppleScriptEngine.scriptResult = "Forwarding email to team@company.com"
        
        let command = ParsedCommand(
            originalText: "forward this email to team@company.com",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        let result = try await mailIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("team@company.com"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Error Handling Tests
    
    func testUnsupportedCommand() async {
        let command = ParsedCommand(
            originalText: "do something unsupported",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        do {
            _ = try await mailIntegration.execute(command)
            XCTFail("Should have thrown an error")
        } catch let error as AppIntegrationError {
            if case .commandNotSupported = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testURLSchemeFailure() async {
        mockURLSchemeHandler.shouldSucceed = false
        
        let command = ParsedCommand(
            originalText: "send email to john@example.com",
            intent: .appControl,
            parameters: ["email": "john@example.com"],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        do {
            _ = try await mailIntegration.execute(command)
            XCTFail("Should have thrown an error")
        } catch let error as AppIntegrationError {
            if case .integrationMethodFailed(let method, _) = error {
                XCTAssertEqual(method, .urlScheme)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Capabilities Tests
    
    func testGetCapabilities() {
        let capabilities = mailIntegration.getCapabilities()
        
        XCTAssertTrue(capabilities.canLaunch)
        XCTAssertTrue(capabilities.canQuit)
        XCTAssertTrue(capabilities.canCreateDocuments)
        
        XCTAssertEqual(capabilities.customCapabilities["canCompose"], true)
        XCTAssertEqual(capabilities.customCapabilities["canSend"], true)
        XCTAssertEqual(capabilities.customCapabilities["canSearch"], true)
        XCTAssertEqual(capabilities.customCapabilities["canManageMailboxes"], true)
        XCTAssertEqual(capabilities.customCapabilities["canCheckMail"], true)
    }
}

// MARK: - Mock Classes

class MockURLSchemeHandler {
    var shouldSucceed = true
    var openURLCalled = false
    var lastURL: URL?
    
    func openURL(_ url: URL) async throws -> Bool {
        openURLCalled = true
        lastURL = url
        return shouldSucceed
    }
}

class MockAppleScriptEngine {
    var scriptResult = "Mock result"
    var executeScriptCalled = false
    var lastScript: String?
    var shouldThrowError = false
    
    func executeScript(_ script: String) async throws -> String {
        executeScriptCalled = true
        lastScript = script
        
        if shouldThrowError {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, "Mock error")
        }
        
        return scriptResult
    }
}

class MockAppDiscoveryService {
    var installedApps: [String] = ["com.apple.mail", "com.apple.iCal", "com.apple.AddressBook", "com.apple.reminders"]
    
    func isAppInstalled(bundleIdentifier: String) -> Bool {
        return installedApps.contains(bundleIdentifier)
    }
}