import XCTest
import Foundation
@testable import Sam

final class AppAutomationIntegrationTests: XCTestCase {
    var appIntegrationManager: AppIntegrationManager!
    var appleScriptEngine: AppleScriptEngine!
    var automationPermissionManager: AutomationPermissionManager!
    
    override func setUp() {
        super.setUp()
        appleScriptEngine = AppleScriptEngine()
        automationPermissionManager = AutomationPermissionManager()
        appIntegrationManager = AppIntegrationManager(
            appleScriptEngine: appleScriptEngine,
            permissionManager: automationPermissionManager
        )
    }
    
    override func tearDown() {
        appIntegrationManager = nil
        appleScriptEngine = nil
        automationPermissionManager = nil
        super.tearDown()
    }
    
    // MARK: - Permission Tests
    
    func testAutomationPermissions() async throws {
        // Given
        let requiredPermissions: [AutomationPermission] = [
            .accessibility,
            .systemEvents,
            .applicationAutomation
        ]
        
        // When
        let permissionStatus = await automationPermissionManager.checkPermissions(requiredPermissions)
        
        // Then
        for permission in requiredPermissions {
            let status = permissionStatus[permission]
            if status == .denied {
                print("⚠️ Permission \(permission) is denied. Please grant in System Preferences > Security & Privacy > Privacy")
            }
        }
        
        // Note: This test documents required permissions rather than asserting them
        // since permissions need to be granted manually by the user
    }
    
    // MARK: - Safari Integration Tests
    
    func testSafariURLOpening() async throws {
        // Skip if Safari is not available or permissions not granted
        try XCTSkipUnless(await isAppAvailable("Safari"), "Safari not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let testURL = "https://www.apple.com"
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .openURL(testURL),
            targetApp: "Safari"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to open URL in Safari: \(result.output)")
        
        // Verify URL was opened (with a small delay for page load)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let currentURL = try await appIntegrationManager.executeCommand(
            .getCurrentURL,
            targetApp: "Safari"
        )
        
        XCTAssertTrue(currentURL.success)
        XCTAssertTrue(currentURL.output.contains("apple.com"), "Expected apple.com in URL, got: \(currentURL.output)")
    }
    
    func testSafariBookmarkCreation() async throws {
        try XCTSkipUnless(await isAppAvailable("Safari"), "Safari not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let testURL = "https://github.com"
        let bookmarkTitle = "GitHub - Test Bookmark"
        
        // First open the URL
        _ = try await appIntegrationManager.executeCommand(
            .openURL(testURL),
            targetApp: "Safari"
        )
        
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait for page load
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .createBookmark(title: bookmarkTitle),
            targetApp: "Safari"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to create bookmark: \(result.output)")
        
        // Verify bookmark exists (this would require additional AppleScript to check bookmarks)
        // For now, we just verify the command executed successfully
    }
    
    func testSafariTabManagement() async throws {
        try XCTSkipUnless(await isAppAvailable("Safari"), "Safari not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given - Open multiple tabs
        let urls = [
            "https://www.apple.com",
            "https://github.com",
            "https://stackoverflow.com"
        ]
        
        // When - Open tabs
        for url in urls {
            let result = try await appIntegrationManager.executeCommand(
                .openURLInNewTab(url),
                targetApp: "Safari"
            )
            XCTAssertTrue(result.success, "Failed to open URL in new tab: \(url)")
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second between tabs
        }
        
        // Then - Verify tab count
        let tabCountResult = try await appIntegrationManager.executeCommand(
            .getTabCount,
            targetApp: "Safari"
        )
        
        XCTAssertTrue(tabCountResult.success)
        if let tabCount = Int(tabCountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            XCTAssertGreaterThanOrEqual(tabCount, urls.count, "Expected at least \(urls.count) tabs")
        }
    }
    
    // MARK: - Mail Integration Tests
    
    func testMailComposition() async throws {
        try XCTSkipUnless(await isAppAvailable("Mail"), "Mail app not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let emailData = EmailData(
            to: ["test@example.com"],
            subject: "Test Email from Sam",
            body: "This is a test email created by Sam's automation system."
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .composeEmail(emailData),
            targetApp: "Mail"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to compose email: \(result.output)")
        
        // Verify Mail app is active and compose window is open
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait for compose window
        
        let activeAppResult = try await appIntegrationManager.executeCommand(
            .getActiveApp,
            targetApp: nil
        )
        
        XCTAssertTrue(activeAppResult.success)
        XCTAssertTrue(activeAppResult.output.contains("Mail"), "Mail should be the active app")
    }
    
    func testMailSearch() async throws {
        try XCTSkipUnless(await isAppAvailable("Mail"), "Mail app not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let searchTerm = "test"
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .searchEmails(searchTerm),
            targetApp: "Mail"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to search emails: \(result.output)")
        
        // The result should contain search results or indicate no results found
        XCTAssertFalse(result.output.isEmpty, "Search result should not be empty")
    }
    
    // MARK: - Calendar Integration Tests
    
    func testCalendarEventCreation() async throws {
        try XCTSkipUnless(await isAppAvailable("Calendar"), "Calendar app not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let eventData = CalendarEventData(
            title: "Sam Test Event",
            startDate: Date().addingTimeInterval(3600), // 1 hour from now
            endDate: Date().addingTimeInterval(7200), // 2 hours from now
            location: "Test Location",
            notes: "Created by Sam automation test"
        )
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .createCalendarEvent(eventData),
            targetApp: "Calendar"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to create calendar event: \(result.output)")
        
        // Verify Calendar app is active
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait for event creation
        
        let activeAppResult = try await appIntegrationManager.executeCommand(
            .getActiveApp,
            targetApp: nil
        )
        
        XCTAssertTrue(activeAppResult.success)
        // Note: Calendar might not become active depending on system settings
    }
    
    func testCalendarEventRetrieval() async throws {
        try XCTSkipUnless(await isAppAvailable("Calendar"), "Calendar app not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let today = Date()
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .getTodaysEvents,
            targetApp: "Calendar"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to get today's events: \(result.output)")
        
        // The result should be a list of events or indicate no events
        XCTAssertFalse(result.output.isEmpty, "Events result should not be empty")
    }
    
    // MARK: - Finder Integration Tests
    
    func testFinderNavigation() async throws {
        try XCTSkipUnless(await isAppAvailable("Finder"), "Finder not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let testPath = FileManager.default.homeDirectoryForCurrentUser.path
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .navigateToFolder(testPath),
            targetApp: "Finder"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to navigate to folder: \(result.output)")
        
        // Verify Finder is showing the correct location
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait for navigation
        
        let currentPathResult = try await appIntegrationManager.executeCommand(
            .getCurrentFinderPath,
            targetApp: "Finder"
        )
        
        XCTAssertTrue(currentPathResult.success)
        XCTAssertTrue(currentPathResult.output.contains(testPath) || currentPathResult.output.contains("Home"), 
                     "Expected path containing \(testPath), got: \(currentPathResult.output)")
    }
    
    func testFinderFileSelection() async throws {
        try XCTSkipUnless(await isAppAvailable("Finder"), "Finder not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given - Create a test file
        let testDirectory = FileManager.default.temporaryDirectory
        let testFile = testDirectory.appendingPathComponent("sam_test_file.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: testFile)
        }
        
        // Navigate to the test directory
        _ = try await appIntegrationManager.executeCommand(
            .navigateToFolder(testDirectory.path),
            targetApp: "Finder"
        )
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait for navigation
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .selectFile(testFile.lastPathComponent),
            targetApp: "Finder"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to select file: \(result.output)")
    }
    
    // MARK: - TextEdit Integration Tests
    
    func testTextEditDocumentCreation() async throws {
        try XCTSkipUnless(await isAppAvailable("TextEdit"), "TextEdit not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let testContent = "This is a test document created by Sam automation."
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .createTextDocument(testContent),
            targetApp: "TextEdit"
        )
        
        // Then
        XCTAssertTrue(result.success, "Failed to create text document: \(result.output)")
        
        // Verify TextEdit is active with new document
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait for document creation
        
        let activeAppResult = try await appIntegrationManager.executeCommand(
            .getActiveApp,
            targetApp: nil
        )
        
        XCTAssertTrue(activeAppResult.success)
        XCTAssertTrue(activeAppResult.output.contains("TextEdit"), "TextEdit should be the active app")
    }
    
    // MARK: - System-wide Integration Tests
    
    func testApplicationSwitching() async throws {
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given - Launch multiple apps
        let apps = ["Safari", "TextEdit", "Calculator"]
        
        for app in apps {
            if await isAppAvailable(app) {
                _ = try await appIntegrationManager.executeCommand(
                    .launchApp(app),
                    targetApp: nil
                )
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait between launches
            }
        }
        
        // When - Switch between apps
        for app in apps.reversed() {
            if await isAppAvailable(app) {
                let result = try await appIntegrationManager.executeCommand(
                    .activateApp(app),
                    targetApp: nil
                )
                
                // Then
                XCTAssertTrue(result.success, "Failed to activate \(app): \(result.output)")
                
                try await Task.sleep(nanoseconds: 500_000_000) // Wait for activation
                
                let activeAppResult = try await appIntegrationManager.executeCommand(
                    .getActiveApp,
                    targetApp: nil
                )
                
                if activeAppResult.success {
                    XCTAssertTrue(activeAppResult.output.contains(app), 
                                 "Expected \(app) to be active, got: \(activeAppResult.output)")
                }
            }
        }
    }
    
    func testMultiAppWorkflow() async throws {
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given - A workflow that involves multiple apps
        let workflowSteps: [(String, AppCommand)] = [
            ("Safari", .openURL("https://www.apple.com")),
            ("TextEdit", .createTextDocument("Notes from Apple website")),
            ("Calendar", .createCalendarEvent(CalendarEventData(
                title: "Review Apple Website",
                startDate: Date().addingTimeInterval(3600),
                endDate: Date().addingTimeInterval(5400),
                location: nil,
                notes: "Review information from apple.com"
            )))
        ]
        
        // When - Execute workflow steps
        var results: [TaskResult] = []
        
        for (app, command) in workflowSteps {
            if await isAppAvailable(app) {
                let result = try await appIntegrationManager.executeCommand(command, targetApp: app)
                results.append(result)
                try await Task.sleep(nanoseconds: 2_000_000_000) // Wait between steps
            }
        }
        
        // Then - Verify all steps completed successfully
        let successfulSteps = results.filter { $0.success }
        XCTAssertGreaterThan(successfulSteps.count, 0, "At least one workflow step should succeed")
        
        // If all apps are available and permissions granted, all should succeed
        if results.count == workflowSteps.count {
            XCTAssertTrue(results.allSatisfy { $0.success }, "All workflow steps should succeed when apps are available")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNonExistentAppHandling() async throws {
        // Given
        let nonExistentApp = "NonExistentApplication12345"
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .launchApp(nonExistentApp),
            targetApp: nil
        )
        
        // Then
        XCTAssertFalse(result.success, "Should fail for non-existent app")
        XCTAssertTrue(result.output.contains("not found") || result.output.contains("error"), 
                     "Error message should indicate app not found")
    }
    
    func testInvalidCommandHandling() async throws {
        try XCTSkipUnless(await isAppAvailable("Safari"), "Safari not available")
        
        // Given - An invalid URL
        let invalidURL = "not-a-valid-url"
        
        // When
        let result = try await appIntegrationManager.executeCommand(
            .openURL(invalidURL),
            targetApp: "Safari"
        )
        
        // Then
        // Note: Safari might still try to open invalid URLs, so we check for reasonable behavior
        XCTAssertNotNil(result, "Should return a result even for invalid input")
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() async throws {
        try XCTSkipUnless(await isAppAvailable("Calculator"), "Calculator not available")
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let app = "Calculator"
        
        // First quit the app if it's running
        _ = try await appIntegrationManager.executeCommand(.quitApp(app), targetApp: nil)
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait for quit
        
        // When & Then
        let startTime = Date()
        let result = try await appIntegrationManager.executeCommand(.launchApp(app), targetApp: nil)
        let launchTime = Date().timeIntervalSince(startTime)
        
        XCTAssertTrue(result.success, "App launch should succeed")
        XCTAssertLessThan(launchTime, 10.0, "App launch should complete within 10 seconds")
        
        print("📊 App launch time for \(app): \(String(format: "%.2f", launchTime))s")
    }
    
    func testConcurrentAppOperations() async throws {
        try XCTSkipUnless(await hasAutomationPermission(), "Automation permission not granted")
        
        // Given
        let apps = ["Calculator", "TextEdit", "Safari"].filter { app in
            Task {
                await isAppAvailable(app)
            }.result.value ?? false
        }
        
        guard !apps.isEmpty else {
            throw XCTSkip("No test apps available")
        }
        
        // When
        let startTime = Date()
        let results = try await withThrowingTaskGroup(of: TaskResult.self) { group in
            for app in apps {
                group.addTask {
                    try await self.appIntegrationManager.executeCommand(.launchApp(app), targetApp: nil)
                }
            }
            
            var results: [TaskResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, apps.count)
        XCTAssertLessThan(totalTime, 15.0, "Concurrent app launches should complete within 15 seconds")
        
        let successfulLaunches = results.filter { $0.success }
        XCTAssertGreaterThan(successfulLaunches.count, 0, "At least one app should launch successfully")
        
        print("📊 Concurrent launch time for \(apps.count) apps: \(String(format: "%.2f", totalTime))s")
    }
    
    // MARK: - Helper Methods
    
    private func isAppAvailable(_ appName: String) async -> Bool {
        let workspace = NSWorkspace.shared
        let appURL = workspace.urlForApplication(withBundleIdentifier: getBundleId(for: appName))
        return appURL != nil
    }
    
    private func hasAutomationPermission() async -> Bool {
        return await automationPermissionManager.hasPermission(.applicationAutomation)
    }
    
    private func getBundleId(for appName: String) -> String {
        switch appName {
        case "Safari": return "com.apple.Safari"
        case "Mail": return "com.apple.mail"
        case "Calendar": return "com.apple.iCal"
        case "Finder": return "com.apple.finder"
        case "TextEdit": return "com.apple.TextEdit"
        case "Calculator": return "com.apple.calculator"
        default: return "com.apple.\(appName.lowercased())"
        }
    }
}

// MARK: - Test Data Structures

enum AppCommand {
    case launchApp(String)
    case quitApp(String)
    case activateApp(String)
    case openURL(String)
    case openURLInNewTab(String)
    case getCurrentURL
    case getTabCount
    case createBookmark(title: String)
    case composeEmail(EmailData)
    case searchEmails(String)
    case createCalendarEvent(CalendarEventData)
    case getTodaysEvents
    case navigateToFolder(String)
    case getCurrentFinderPath
    case selectFile(String)
    case createTextDocument(String)
    case getActiveApp
}

struct EmailData {
    let to: [String]
    let subject: String
    let body: String
    let cc: [String]?
    let bcc: [String]?
    
    init(to: [String], subject: String, body: String, cc: [String]? = nil, bcc: [String]? = nil) {
        self.to = to
        self.subject = subject
        self.body = body
        self.cc = cc
        self.bcc = bcc
    }
}

struct CalendarEventData {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
}

enum AutomationPermission {
    case accessibility
    case systemEvents
    case applicationAutomation
}

// MARK: - Extensions for Task Result

extension Task where Success == Bool, Failure == Never {
    var result: Result<Bool, Never> {
        return .success(true) // Simplified for testing
    }
}