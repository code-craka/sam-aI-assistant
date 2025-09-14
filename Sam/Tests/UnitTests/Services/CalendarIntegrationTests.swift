import XCTest
@testable import Sam

class CalendarIntegrationTests: XCTestCase {
    
    var calendarIntegration: CalendarIntegration!
    var mockAppDiscovery: MockAppDiscoveryService!
    var mockURLSchemeHandler: MockURLSchemeHandler!
    var mockAppleScriptEngine: MockAppleScriptEngine!
    
    override func setUp() {
        super.setUp()
        mockAppDiscovery = MockAppDiscoveryService()
        mockURLSchemeHandler = MockURLSchemeHandler()
        mockAppleScriptEngine = MockAppleScriptEngine()
        
        calendarIntegration = CalendarIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
    }
    
    override func tearDown() {
        calendarIntegration = nil
        mockAppDiscovery = nil
        mockURLSchemeHandler = nil
        mockAppleScriptEngine = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testBundleIdentifier() {
        XCTAssertEqual(calendarIntegration.bundleIdentifier, "com.apple.iCal")
    }
    
    func testDisplayName() {
        XCTAssertEqual(calendarIntegration.displayName, "Calendar")
    }
    
    func testSupportedCommands() {
        let commands = calendarIntegration.supportedCommands
        XCTAssertGreaterThan(commands.count, 0)
        
        let commandNames = commands.map { $0.name }
        XCTAssertTrue(commandNames.contains("create_event"))
        XCTAssertTrue(commandNames.contains("create_reminder"))
        XCTAssertTrue(commandNames.contains("show_today"))
        XCTAssertTrue(commandNames.contains("show_tomorrow"))
        XCTAssertTrue(commandNames.contains("show_week"))
        XCTAssertTrue(commandNames.contains("delete_event"))
    }
    
    // MARK: - Event Creation Tests
    
    func testCreateEventBasic() async throws {
        mockAppleScriptEngine.scriptResult = "Event created successfully"
        
        let command = ParsedCommand(
            originalText: "create event meeting at 2pm",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("meeting"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    func testCreateEventWithTime() async throws {
        mockAppleScriptEngine.scriptResult = "Event created successfully"
        
        let command = ParsedCommand(
            originalText: "schedule lunch tomorrow at noon for 1 hour",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("lunch"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testCreateEventWithDuration() async throws {
        mockAppleScriptEngine.scriptResult = "Event created successfully"
        
        let command = ParsedCommand(
            originalText: "create event team standup at 9am for 30 minutes",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("team standup"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Reminder Creation Tests
    
    func testCreateReminder() async throws {
        mockAppleScriptEngine.scriptResult = "Created reminder: call John"
        
        let command = ParsedCommand(
            originalText: "remind me to call John",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("call John"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testCreateReminderWithTime() async throws {
        mockAppleScriptEngine.scriptResult = "Created reminder: dentist appointment"
        
        let command = ParsedCommand(
            originalText: "create reminder for dentist appointment tomorrow",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("dentist appointment"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Calendar View Tests
    
    func testShowTodaysEvents() async throws {
        mockAppleScriptEngine.scriptResult = "You have 3 events today"
        
        let command = ParsedCommand(
            originalText: "show today's events",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("3 events today"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testShowTomorrowEvents() async throws {
        mockAppleScriptEngine.scriptResult = "You have 2 events tomorrow"
        
        let command = ParsedCommand(
            originalText: "show tomorrow's events",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("2 events tomorrow"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    func testShowWeekEvents() async throws {
        mockAppleScriptEngine.scriptResult = "Showing this week's calendar"
        
        let command = ParsedCommand(
            originalText: "show this week",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("week's calendar"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Event Management Tests
    
    func testDeleteEvent() async throws {
        mockAppleScriptEngine.scriptResult = "Deleted 1 event(s) with title 'meeting'"
        
        let command = ParsedCommand(
            originalText: "delete event meeting",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        let result = try await calendarIntegration.execute(command)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Deleted"))
        XCTAssertTrue(result.output.contains("meeting"))
        XCTAssertEqual(result.integrationMethod, .appleScript)
    }
    
    // MARK: - Command Handling Tests
    
    func testCanHandleAppControlCommand() {
        let command = ParsedCommand(
            originalText: "create event meeting",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        XCTAssertTrue(calendarIntegration.canHandle(command))
    }
    
    func testCannotHandleWrongApp() {
        let command = ParsedCommand(
            originalText: "create event meeting",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.mail",
            requiresConfirmation: false
        )
        
        XCTAssertFalse(calendarIntegration.canHandle(command))
    }
    
    func testCannotHandleWrongIntent() {
        let command = ParsedCommand(
            originalText: "create event meeting",
            intent: .fileOperation,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        XCTAssertFalse(calendarIntegration.canHandle(command))
    }
    
    // MARK: - Error Handling Tests
    
    func testUnsupportedCommand() async {
        let command = ParsedCommand(
            originalText: "do something unsupported",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        do {
            _ = try await calendarIntegration.execute(command)
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
    
    func testAppleScriptFailure() async {
        mockAppleScriptEngine.shouldThrowError = true
        
        let command = ParsedCommand(
            originalText: "create event meeting",
            intent: .appControl,
            parameters: [:],
            confidence: 0.9,
            targetApplication: "com.apple.iCal",
            requiresConfirmation: false
        )
        
        do {
            _ = try await calendarIntegration.execute(command)
            XCTFail("Should have thrown an error")
        } catch let error as AppIntegrationError {
            if case .integrationMethodFailed(let method, _) = error {
                XCTAssertEqual(method, .appleScript)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Capabilities Tests
    
    func testGetCapabilities() {
        let capabilities = calendarIntegration.getCapabilities()
        
        XCTAssertTrue(capabilities.canLaunch)
        XCTAssertTrue(capabilities.canQuit)
        XCTAssertTrue(capabilities.canCreateDocuments)
        XCTAssertTrue(capabilities.canSaveFiles)
        
        XCTAssertEqual(capabilities.customCapabilities["canCreateEvent"], true)
        XCTAssertEqual(capabilities.customCapabilities["canCreateReminder"], true)
        XCTAssertEqual(capabilities.customCapabilities["canSearch"], true)
        XCTAssertEqual(capabilities.customCapabilities["canShowCalendar"], true)
    }
    
    // MARK: - Text Parsing Tests
    
    func testExtractEventTitle() {
        // This would test the private extractEventTitle method
        // In a real implementation, you might make these methods internal for testing
        // or test them indirectly through the execute method
    }
    
    func testExtractTime() {
        // Test time extraction logic
    }
    
    func testExtractDuration() {
        // Test duration extraction logic
    }
}