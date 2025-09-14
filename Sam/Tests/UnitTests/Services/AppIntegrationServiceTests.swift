import XCTest
@testable import Sam

final class AppIntegrationServiceTests: XCTestCase {
    var appIntegrationService: AppIntegrationService!
    var mockAppleScriptEngine: MockAppleScriptEngine!
    var mockAppDiscoveryService: MockAppDiscoveryService!
    
    override func setUp() {
        super.setUp()
        mockAppleScriptEngine = MockAppleScriptEngine()
        mockAppDiscoveryService = MockAppDiscoveryService()
        appIntegrationService = AppIntegrationService(
            appleScriptEngine: mockAppleScriptEngine,
            appDiscoveryService: mockAppDiscoveryService
        )
    }
    
    override func tearDown() {
        appIntegrationService = nil
        mockAppleScriptEngine = nil
        mockAppDiscoveryService = nil
        super.tearDown()
    }
    
    // MARK: - App Discovery Tests
    
    func testDiscoverInstalledApps() async throws {
        // Given
        mockAppDiscoveryService.mockApps = [
            AppInfo(name: "Safari", bundleId: "com.apple.Safari", isActive: false),
            AppInfo(name: "Mail", bundleId: "com.apple.mail", isActive: false),
            AppInfo(name: "TextEdit", bundleId: "com.apple.TextEdit", isActive: false)
        ]
        
        // When
        let apps = try await appIntegrationService.discoverInstalledApps()
        
        // Then
        XCTAssertEqual(apps.count, 3)
        XCTAssertTrue(apps.contains { $0.name == "Safari" })
        XCTAssertTrue(apps.contains { $0.name == "Mail" })
        XCTAssertTrue(mockAppDiscoveryService.discoverAppsCalled)
    }
    
    func testGetAppCapabilities() async throws {
        // Given
        let bundleId = "com.apple.Safari"
        mockAppDiscoveryService.mockCapabilities = [
            AppCapability(type: .urlScheme, identifier: "http"),
            AppCapability(type: .appleScript, identifier: "open location"),
            AppCapability(type: .accessibility, identifier: "UI automation")
        ]
        
        // When
        let capabilities = try await appIntegrationService.getAppCapabilities(bundleId: bundleId)
        
        // Then
        XCTAssertEqual(capabilities.count, 3)
        XCTAssertTrue(capabilities.contains { $0.type == .urlScheme })
        XCTAssertTrue(capabilities.contains { $0.type == .appleScript })
        XCTAssertTrue(mockAppDiscoveryService.getCapabilitiesCalled)
    }
    
    // MARK: - App Control Tests
    
    func testLaunchApp() async throws {
        // Given
        let appName = "Safari"
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Application launched successfully",
            executionTime: 0.5
        )
        
        // When
        let result = try await appIntegrationService.launchApp(appName)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "Application launched successfully")
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    func testQuitApp() async throws {
        // Given
        let appName = "TextEdit"
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Application quit successfully",
            executionTime: 0.3
        )
        
        // When
        let result = try await appIntegrationService.quitApp(appName)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    func testActivateApp() async throws {
        // Given
        let appName = "Mail"
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Application activated",
            executionTime: 0.2
        )
        
        // When
        let result = try await appIntegrationService.activateApp(appName)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    // MARK: - Safari Integration Tests
    
    func testOpenURL() async throws {
        // Given
        let url = "https://www.apple.com"
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "URL opened in Safari",
            executionTime: 0.4
        )
        
        // When
        let result = try await appIntegrationService.openURL(url)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
        XCTAssertTrue(mockAppleScriptEngine.lastScript?.contains(url) ?? false)
    }
    
    func testCreateBookmark() async throws {
        // Given
        let url = "https://github.com"
        let title = "GitHub"
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Bookmark created",
            executionTime: 0.3
        )
        
        // When
        let result = try await appIntegrationService.createBookmark(url: url, title: title)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    func testGetCurrentTab() async throws {
        // Given
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "https://www.apple.com",
            executionTime: 0.1
        )
        
        // When
        let result = try await appIntegrationService.getCurrentTabURL()
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "https://www.apple.com")
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    // MARK: - Mail Integration Tests
    
    func testComposeEmail() async throws {
        // Given
        let emailData = EmailComposition(
            to: ["test@example.com"],
            cc: [],
            bcc: [],
            subject: "Test Subject",
            body: "Test email body"
        )
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Email composed",
            executionTime: 0.6
        )
        
        // When
        let result = try await appIntegrationService.composeEmail(emailData)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    func testSendEmail() async throws {
        // Given
        let emailData = EmailComposition(
            to: ["recipient@example.com"],
            cc: [],
            bcc: [],
            subject: "Automated Email",
            body: "This is an automated email"
        )
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Email sent",
            executionTime: 1.2
        )
        
        // When
        let result = try await appIntegrationService.sendEmail(emailData)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    // MARK: - Calendar Integration Tests
    
    func testCreateCalendarEvent() async throws {
        // Given
        let eventData = CalendarEvent(
            title: "Team Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600), // 1 hour later
            location: "Conference Room A",
            notes: "Weekly team sync"
        )
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Event created",
            executionTime: 0.8
        )
        
        // When
        let result = try await appIntegrationService.createCalendarEvent(eventData)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    func testGetUpcomingEvents() async throws {
        // Given
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Meeting at 2 PM, Call at 4 PM",
            executionTime: 0.4
        )
        
        // When
        let result = try await appIntegrationService.getUpcomingEvents(days: 1)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Meeting"))
        XCTAssertTrue(mockAppleScriptEngine.executeScriptCalled)
    }
    
    // MARK: - Error Handling Tests
    
    func testAppNotFound() async throws {
        // Given
        let nonExistentApp = "NonExistentApp"
        mockAppleScriptEngine.shouldThrowError = true
        mockAppleScriptEngine.mockError = AppIntegrationError.appNotFound(nonExistentApp)
        
        // When & Then
        do {
            _ = try await appIntegrationService.launchApp(nonExistentApp)
            XCTFail("Expected error to be thrown")
        } catch AppIntegrationError.appNotFound(let appName) {
            XCTAssertEqual(appName, nonExistentApp)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testScriptExecutionFailure() async throws {
        // Given
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: false,
            output: "Script execution failed",
            executionTime: 0.1
        )
        
        // When
        let result = try await appIntegrationService.launchApp("Safari")
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.output, "Script execution failed")
    }
    
    func testPermissionDenied() async throws {
        // Given
        mockAppleScriptEngine.shouldThrowError = true
        mockAppleScriptEngine.mockError = AppIntegrationError.permissionDenied("Automation access required")
        
        // When & Then
        do {
            _ = try await appIntegrationService.launchApp("Safari")
            XCTFail("Expected permission error")
        } catch AppIntegrationError.permissionDenied {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentAppOperations() async throws {
        // Given
        let operations = [
            { try await self.appIntegrationService.launchApp("Safari") },
            { try await self.appIntegrationService.launchApp("Mail") },
            { try await self.appIntegrationService.launchApp("Calendar") },
            { try await self.appIntegrationService.launchApp("TextEdit") }
        ]
        
        mockAppleScriptEngine.mockResult = AppleScriptResult(
            success: true,
            output: "Operation completed",
            executionTime: 0.5
        )
        
        // When
        let startTime = Date()
        let results = try await withThrowingTaskGroup(of: TaskResult.self) { group in
            for operation in operations {
                group.addTask {
                    try await operation()
                }
            }
            
            var results: [TaskResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results.allSatisfy { $0.success })
        XCTAssertLessThan(executionTime, 3.0, "Concurrent app operations took too long")
    }
    
    func testAppIntegrationPerformance() {
        measure {
            Task {
                _ = try? await self.appIntegrationService.launchApp("Safari")
            }
        }
    }
    
    // MARK: - Integration Method Selection Tests
    
    func testIntegrationMethodSelection() async throws {
        // Given
        let bundleId = "com.apple.Safari"
        mockAppDiscoveryService.mockCapabilities = [
            AppCapability(type: .urlScheme, identifier: "http"),
            AppCapability(type: .appleScript, identifier: "open location")
        ]
        
        // When
        let method = try await appIntegrationService.selectBestIntegrationMethod(for: bundleId, action: "open_url")
        
        // Then
        XCTAssertEqual(method, .urlScheme) // URL scheme should be preferred for URL operations
    }
    
    func testFallbackIntegrationMethod() async throws {
        // Given
        let bundleId = "com.unknown.app"
        mockAppDiscoveryService.mockCapabilities = [] // No specific capabilities
        
        // When
        let method = try await appIntegrationService.selectBestIntegrationMethod(for: bundleId, action: "generic_action")
        
        // Then
        XCTAssertEqual(method, .accessibility) // Should fallback to accessibility
    }
}

// MARK: - Mock Classes

class MockAppleScriptEngine: AppleScriptEngineProtocol {
    var mockResult: AppleScriptResult?
    var shouldThrowError = false
    var mockError: Error?
    var executeScriptCalled = false
    var lastScript: String?
    
    func executeScript(_ script: String) async throws -> AppleScriptResult {
        executeScriptCalled = true
        lastScript = script
        
        if shouldThrowError {
            throw mockError ?? AppIntegrationError.scriptExecutionFailed("Mock error")
        }
        
        return mockResult ?? AppleScriptResult(
            success: true,
            output: "Mock script result",
            executionTime: 0.1
        )
    }
    
    func compileScript(_ script: String) async throws -> CompiledScript {
        return CompiledScript(id: UUID(), script: script, compiledAt: Date())
    }
}

class MockAppDiscoveryService: AppDiscoveryServiceProtocol {
    var mockApps: [AppInfo] = []
    var mockCapabilities: [AppCapability] = []
    var discoverAppsCalled = false
    var getCapabilitiesCalled = false
    
    func discoverInstalledApps() async throws -> [AppInfo] {
        discoverAppsCalled = true
        return mockApps
    }
    
    func getAppCapabilities(bundleId: String) async throws -> [AppCapability] {
        getCapabilitiesCalled = true
        return mockCapabilities
    }
    
    func isAppInstalled(bundleId: String) async -> Bool {
        return mockApps.contains { $0.bundleId == bundleId }
    }
}

// MARK: - Test Data Structures

struct EmailComposition {
    let to: [String]
    let cc: [String]
    let bcc: [String]
    let subject: String
    let body: String
}

struct CalendarEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
}

enum IntegrationMethod {
    case urlScheme
    case appleScript
    case accessibility
    case nativeSDK
}

struct AppCapability {
    let type: IntegrationMethod
    let identifier: String
}

struct CompiledScript {
    let id: UUID
    let script: String
    let compiledAt: Date
}