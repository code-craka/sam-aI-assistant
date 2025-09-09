import XCTest
@testable import Sam

final class AppAutomationIntegrationTests: XCTestCase {
    var appIntegrationManager: AppIntegrationManager!
    var appleScriptEngine: AppleScriptEngine!
    var permissionManager: AutomationPermissionManager!
    
    override func setUp() {
        super.setUp()
        permissionManager = AutomationPermissionManager()
        appleScriptEngine = AppleScriptEngine()
        appIntegrationManager = AppIntegrationManager(
            appleScriptEngine: appleScriptEngine,
            permissionManager: permissionManager
        )
    }
    
    override func tearDown() {
        appIntegrationManager = nil
        appleScriptEngine = nil
        permissionManager = nil
        super.tearDown()
    }
    
    // MARK: - Safari Integration Tests
    
    func testSafariURLOpening() async throws {
        // Skip if Safari is not available or permissions not granted
        try XCTSkipUnless(await checkSafariAvailability(), "Safari not available or permissions not granted")
        
        // Given
        let testURL = "https://www.apple.com"
        let command = ParsedCommand(
            originalText: "open \(testURL) in Safari",
            intent: .appControl,
            parameters: ["url": testURL, "app": "Safari"],
            confidence: 0.95,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("opened"))
        
        // Verify Safari is running
        let runningApps = NSWorkspace.shared.runningApplications
        let safariApp = runningApps.first { $0.bundleIdentifier == "com.apple.Safari" }
        XCTAssertNotNil(safariApp)
    }
    
    func testSafariBookmarkCreation() async throws {
        try XCTSkipUnless(await checkSafariAvailability(), "Safari not available")
        
        // Given
        let bookmarkName = "Test Bookmark"
        let bookmarkURL = "https://developer.apple.com"
        let command = ParsedCommand(
            originalText: "bookmark \(bookmarkURL) as \(bookmarkName)",
            intent: .appControl,
            parameters: [
                "action": "bookmark",
                "url": bookmarkURL,
                "name": bookmarkName,
                "app": "Safari"
            ],
            confidence: 0.9,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("bookmark"))
    }
    
    // MARK: - Mail Integration Tests
    
    func testMailComposition() async throws {
        try XCTSkipUnless(await checkMailAvailability(), "Mail not available")
        
        // Given
        let recipient = "test@example.com"
        let subject = "Test Email from Sam"
        let body = "This is a test email sent from Sam's integration tests."
        
        let command = ParsedCommand(
            originalText: "send email to \(recipient) with subject \(subject)",
            intent: .appControl,
            parameters: [
                "action": "compose",
                "to": [recipient],
                "subject": subject,
                "body": body,
                "app": "Mail"
            ],
            confidence: 0.95,
            requiresConfirmation: true
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("email"))
        
        // Verify Mail is running
        let runningApps = NSWorkspace.shared.runningApplications
        let mailApp = runningApps.first { $0.bundleIdentifier == "com.apple.mail" }
        XCTAssertNotNil(mailApp)
    }
    
    // MARK: - Calendar Integration Tests
    
    func testCalendarEventCreation() async throws {
        try XCTSkipUnless(await checkCalendarAvailability(), "Calendar not available")
        
        // Given
        let eventTitle = "Test Meeting"
        let eventDate = "tomorrow at 2 PM"
        let command = ParsedCommand(
            originalText: "create calendar event \(eventTitle) for \(eventDate)",
            intent: .appControl,
            parameters: [
                "action": "create_event",
                "title": eventTitle,
                "date": eventDate,
                "app": "Calendar"
            ],
            confidence: 0.9,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("event"))
    }
    
    // MARK: - Finder Integration Tests
    
    func testFinderWindowOpening() async throws {
        // Given
        let folderPath = "/Applications"
        let command = ParsedCommand(
            originalText: "open \(folderPath) in Finder",
            intent: .appControl,
            parameters: [
                "action": "open_folder",
                "path": folderPath,
                "app": "Finder"
            ],
            confidence: 0.95,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("opened"))
        
        // Verify Finder window is open
        let runningApps = NSWorkspace.shared.runningApplications
        let finderApp = runningApps.first { $0.bundleIdentifier == "com.apple.finder" }
        XCTAssertNotNil(finderApp)
    }
    
    func testFinderFileSelection() async throws {
        // Given
        let testFile = "/Applications/Calculator.app"
        let command = ParsedCommand(
            originalText: "select \(testFile) in Finder",
            intent: .appControl,
            parameters: [
                "action": "select_file",
                "path": testFile,
                "app": "Finder"
            ],
            confidence: 0.9,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("selected"))
    }
    
    // MARK: - System Apps Integration Tests
    
    func testSystemPreferencesOpening() async throws {
        // Given
        let preferencesPane = "Security & Privacy"
        let command = ParsedCommand(
            originalText: "open \(preferencesPane) in System Preferences",
            intent: .appControl,
            parameters: [
                "action": "open_preferences",
                "pane": preferencesPane,
                "app": "System Preferences"
            ],
            confidence: 0.9,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("opened"))
    }
    
    // MARK: - Third-Party App Integration Tests
    
    func testGenericAppLaunching() async throws {
        // Given
        let appName = "Calculator"
        let command = ParsedCommand(
            originalText: "open \(appName)",
            intent: .appControl,
            parameters: [
                "action": "launch",
                "app": appName
            ],
            confidence: 0.95,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("launched") || result.output.contains("opened"))
        
        // Verify app is running
        let runningApps = NSWorkspace.shared.runningApplications
        let calculatorApp = runningApps.first { $0.localizedName == "Calculator" }
        XCTAssertNotNil(calculatorApp)
        
        // Clean up - quit the app
        calculatorApp?.terminate()
    }
    
    func testAppQuitting() async throws {
        // Given - first launch Calculator
        let launchCommand = ParsedCommand(
            originalText: "open Calculator",
            intent: .appControl,
            parameters: ["action": "launch", "app": "Calculator"],
            confidence: 0.95,
            requiresConfirmation: false
        )
        _ = try await appIntegrationManager.executeCommand(launchCommand)
        
        // Wait a moment for app to launch
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // When - quit the app
        let quitCommand = ParsedCommand(
            originalText: "quit Calculator",
            intent: .appControl,
            parameters: ["action": "quit", "app": "Calculator"],
            confidence: 0.95,
            requiresConfirmation: false
        )
        let result = try await appIntegrationManager.executeCommand(quitCommand)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("quit") || result.output.contains("closed"))
        
        // Verify app is no longer running
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let runningApps = NSWorkspace.shared.runningApplications
        let calculatorApp = runningApps.first { $0.localizedName == "Calculator" }
        XCTAssertNil(calculatorApp)
    }
    
    // MARK: - AppleScript Engine Integration Tests
    
    func testAppleScriptExecution() async throws {
        // Given
        let script = """
        tell application "System Events"
            return name of every process whose background only is false
        end tell
        """
        
        // When
        let result = try await appleScriptEngine.executeScript(script)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.output.isEmpty)
        XCTAssertNil(result.error)
    }
    
    func testAppleScriptWithError() async throws {
        // Given
        let invalidScript = "tell application \"NonExistentApp\" to activate"
        
        // When
        let result = try await appleScriptEngine.executeScript(invalidScript)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }
    
    // MARK: - Complex Workflow Integration Tests
    
    func testMultiStepWorkflow() async throws {
        // Given - a workflow that opens Safari, navigates to a URL, and creates a bookmark
        let commands = [
            ParsedCommand(
                originalText: "open Safari",
                intent: .appControl,
                parameters: ["action": "launch", "app": "Safari"],
                confidence: 0.95,
                requiresConfirmation: false
            ),
            ParsedCommand(
                originalText: "go to apple.com",
                intent: .appControl,
                parameters: ["action": "navigate", "url": "https://www.apple.com", "app": "Safari"],
                confidence: 0.9,
                requiresConfirmation: false
            ),
            ParsedCommand(
                originalText: "bookmark this page as Apple Homepage",
                intent: .appControl,
                parameters: ["action": "bookmark", "name": "Apple Homepage", "app": "Safari"],
                confidence: 0.85,
                requiresConfirmation: false
            )
        ]
        
        // When
        var results: [CommandResult] = []
        for command in commands {
            let result = try await appIntegrationManager.executeCommand(command)
            results.append(result)
            
            // Small delay between commands
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.success })
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testHandleNonExistentApp() async throws {
        // Given
        let command = ParsedCommand(
            originalText: "open NonExistentApp",
            intent: .appControl,
            parameters: ["action": "launch", "app": "NonExistentApp"],
            confidence: 0.8,
            requiresConfirmation: false
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(command)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.output.contains("not found") || result.output.contains("error"))
    }
    
    func testHandlePermissionDenied() async throws {
        // Given - simulate permission denied scenario
        let restrictedCommand = ParsedCommand(
            originalText: "access system keychain",
            intent: .appControl,
            parameters: ["action": "access_keychain"],
            confidence: 0.7,
            requiresConfirmation: true
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(restrictedCommand)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.output.contains("permission") || result.output.contains("access denied"))
    }
    
    // MARK: - Performance Integration Tests
    
    func testAppLaunchPerformance() async throws {
        // Given
        let command = ParsedCommand(
            originalText: "open TextEdit",
            intent: .appControl,
            parameters: ["action": "launch", "app": "TextEdit"],
            confidence: 0.95,
            requiresConfirmation: false
        )
        
        // When
        let startTime = Date()
        let result = try await appIntegrationManager.executeCommand(command)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertLessThan(executionTime, 5.0, "App launch took too long")
        
        // Clean up
        if let textEditApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "TextEdit" }) {
            textEditApp.terminate()
        }
    }
    
    func testConcurrentAppOperations() async throws {
        // Given
        let commands = [
            ParsedCommand(originalText: "open Calculator", intent: .appControl, parameters: ["action": "launch", "app": "Calculator"], confidence: 0.95, requiresConfirmation: false),
            ParsedCommand(originalText: "open TextEdit", intent: .appControl, parameters: ["action": "launch", "app": "TextEdit"], confidence: 0.95, requiresConfirmation: false),
            ParsedCommand(originalText: "open Preview", intent: .appControl, parameters: ["action": "launch", "app": "Preview"], confidence: 0.95, requiresConfirmation: false)
        ]
        
        // When
        let startTime = Date()
        let results = try await withThrowingTaskGroup(of: CommandResult.self) { group in
            for command in commands {
                group.addTask {
                    try await self.appIntegrationManager.executeCommand(command)
                }
            }
            
            var results: [CommandResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.success })
        XCTAssertLessThan(executionTime, 10.0, "Concurrent operations took too long")
        
        // Clean up
        let appsToQuit = ["Calculator", "TextEdit", "Preview"]
        for appName in appsToQuit {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) {
                app.terminate()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkSafariAvailability() async -> Bool {
        let safariPath = "/Applications/Safari.app"
        return FileManager.default.fileExists(atPath: safariPath) && 
               await permissionManager.hasAutomationPermission(for: "com.apple.Safari")
    }
    
    private func checkMailAvailability() async -> Bool {
        let mailPath = "/System/Applications/Mail.app"
        return FileManager.default.fileExists(atPath: mailPath) && 
               await permissionManager.hasAutomationPermission(for: "com.apple.mail")
    }
    
    private func checkCalendarAvailability() async -> Bool {
        let calendarPath = "/System/Applications/Calendar.app"
        return FileManager.default.fileExists(atPath: calendarPath) && 
               await permissionManager.hasAutomationPermission(for: "com.apple.iCal")
    }
}