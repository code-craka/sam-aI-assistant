import XCTest
@testable import Sam

@MainActor
class ExtensibilityFrameworkTests: XCTestCase {
    var pluginManager: PluginManager!
    var commandExtensionManager: CommandExtensionManager!
    var externalAPIFramework: ExternalAPIFramework!
    var telemetryManager: TelemetryManager!
    
    override func setUp() {
        super.setUp()
        pluginManager = PluginManager.shared
        commandExtensionManager = CommandExtensionManager.shared
        externalAPIFramework = ExternalAPIFramework.shared
        telemetryManager = TelemetryManager.shared
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up test data
        Task {
            await telemetryManager.clearAllData()
        }
    }
    
    // MARK: - Plugin Manager Tests
    func testPluginRegistration() async {
        let mockPlugin = MockPlugin()
        
        // Test plugin loading
        XCTAssertTrue(pluginManager.loadedPlugins.isEmpty)
        
        // In a real implementation, we would test actual plugin loading
        // For now, we test the framework structure
        XCTAssertNotNil(pluginManager)
        XCTAssertFalse(pluginManager.isLoading)
    }
    
    func testPluginPermissions() {
        let context = PluginContext(
            userInput: "test command",
            conversationHistory: [],
            systemInfo: nil,
            currentDirectory: nil,
            selectedFiles: [],
            environment: [:]
        )
        
        // Test permission checking
        let hasPermission = pluginManager.hasPermission(.fileSystem, for: context)
        XCTAssertTrue(hasPermission) // Default implementation returns true
    }
    
    func testPluginExecution() async {
        let context = PluginContext(
            userInput: "test command",
            conversationHistory: [],
            systemInfo: nil,
            currentDirectory: nil,
            selectedFiles: [],
            environment: [:]
        )
        
        // Test command execution when no plugins are loaded
        let result = await pluginManager.executeCommand("test", context: context)
        XCTAssertNil(result) // Should return nil when no plugin can handle the command
    }
    
    // MARK: - Command Extension Manager Tests
    func testCommandExtensionRegistration() {
        let initialCount = commandExtensionManager.extensions.count
        
        let mockExtension = MockCommandExtension()
        commandExtensionManager.registerExtension(mockExtension)
        
        XCTAssertEqual(commandExtensionManager.extensions.count, initialCount + 1)
        XCTAssertNotNil(commandExtensionManager.extensions[mockExtension.identifier])
    }
    
    func testCommandExtensionUnregistration() {
        let mockExtension = MockCommandExtension()
        commandExtensionManager.registerExtension(mockExtension)
        
        let countAfterRegistration = commandExtensionManager.extensions.count
        
        commandExtensionManager.unregisterExtension(mockExtension.identifier)
        
        XCTAssertEqual(commandExtensionManager.extensions.count, countAfterRegistration - 1)
        XCTAssertNil(commandExtensionManager.extensions[mockExtension.identifier])
    }
    
    func testCommandExecution() async {
        let mockExtension = MockCommandExtension()
        commandExtensionManager.registerExtension(mockExtension)
        
        let context = CommandContext(
            userInput: "mock test",
            parsedParameters: [:],
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            selectedFiles: [],
            environment: [:],
            user: nil
        )
        
        let result = await commandExtensionManager.executeCommand("mock test", context: context)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "Mock command executed")
    }
    
    func testCommandSearch() {
        let mockExtension = MockCommandExtension()
        commandExtensionManager.registerExtension(mockExtension)
        
        let results = commandExtensionManager.searchCommands("mock")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.identifier == mockExtension.identifier })
    }
    
    func testCommandsByCategory() {
        let mockExtension = MockCommandExtension()
        commandExtensionManager.registerExtension(mockExtension)
        
        let results = commandExtensionManager.getCommandsByCategory(.custom)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.identifier == mockExtension.identifier })
    }
    
    // MARK: - External API Framework Tests
    func testAPIRegistration() throws {
        let mockAPI = MockExternalAPI()
        
        try externalAPIFramework.registerAPI(mockAPI)
        
        XCTAssertNotNil(externalAPIFramework.registeredAPIs[mockAPI.identifier])
    }
    
    func testAPIUnregistration() throws {
        let mockAPI = MockExternalAPI()
        
        try externalAPIFramework.registerAPI(mockAPI)
        XCTAssertNotNil(externalAPIFramework.registeredAPIs[mockAPI.identifier])
        
        externalAPIFramework.unregisterAPI(mockAPI.identifier)
        XCTAssertNil(externalAPIFramework.registeredAPIs[mockAPI.identifier])
    }
    
    func testAPIConnection() async throws {
        let mockAPI = MockExternalAPI()
        try externalAPIFramework.registerAPI(mockAPI)
        
        let credentials = APICredentials(type: .apiKey, values: ["key": "test-key"])
        let connection = try await externalAPIFramework.connectToAPI(mockAPI.identifier, credentials: credentials)
        
        XCTAssertEqual(connection.identifier, mockAPI.identifier)
        XCTAssertTrue(connection.isConnected)
    }
    
    func testAPIExecution() async throws {
        let mockAPI = MockExternalAPI()
        try externalAPIFramework.registerAPI(mockAPI)
        
        let credentials = APICredentials(type: .apiKey, values: ["key": "test-key"])
        _ = try await externalAPIFramework.connectToAPI(mockAPI.identifier, credentials: credentials)
        
        let request = APIRequest(
            apiIdentifier: mockAPI.identifier,
            endpoint: "/test",
            method: .GET,
            headers: [:],
            parameters: [:],
            body: nil,
            timeout: 30
        )
        
        let response = try await externalAPIFramework.executeAPICall(request)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.statusCode, 200)
    }
    
    // MARK: - Telemetry Manager Tests
    func testEventTracking() {
        let initialEventCount = telemetryManager.analyticsData.totalEvents
        
        telemetryManager.track("test_event", properties: ["key": "value"])
        
        XCTAssertEqual(telemetryManager.analyticsData.totalEvents, initialEventCount + 1)
    }
    
    func testErrorTracking() {
        let initialErrorCount = telemetryManager.analyticsData.errorCount
        
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        telemetryManager.trackError(testError, context: ["context": "test"])
        
        XCTAssertEqual(telemetryManager.analyticsData.errorCount, initialErrorCount + 1)
    }
    
    func testPerformanceTracking() {
        telemetryManager.trackPerformance("test_operation", duration: 0.5, metadata: ["operation_type": "test"])
        
        // Verify that performance event was tracked
        XCTAssertTrue(telemetryManager.analyticsData.totalEvents > 0)
    }
    
    func testFeatureUsageTracking() {
        let feature = "test_feature"
        let initialUsage = telemetryManager.analyticsData.featureUsage[feature] ?? 0
        
        telemetryManager.trackFeatureUsage(feature, action: "used", metadata: [:])
        
        XCTAssertEqual(telemetryManager.analyticsData.featureUsage[feature], initialUsage + 1)
    }
    
    func testTelemetryPrivacy() {
        // Test that telemetry can be disabled
        telemetryManager.disableTelemetry()
        XCTAssertFalse(telemetryManager.isEnabled)
        
        // Test that events are not tracked when disabled
        let initialEventCount = telemetryManager.analyticsData.totalEvents
        telemetryManager.track("test_event_disabled")
        XCTAssertEqual(telemetryManager.analyticsData.totalEvents, initialEventCount)
        
        // Re-enable for other tests
        telemetryManager.enableTelemetry()
        XCTAssertTrue(telemetryManager.isEnabled)
    }
    
    func testAnalyticsReport() {
        // Add some test data
        telemetryManager.track("command_executed", properties: ["command": "test_command"])
        telemetryManager.trackError(NSError(domain: "Test", code: 1, userInfo: nil))
        
        let report = telemetryManager.getAnalytics()
        
        XCTAssertGreaterThan(report.totalEvents, 0)
        XCTAssertGreaterThanOrEqual(report.errorRate, 0.0)
        XCTAssertLessThanOrEqual(report.errorRate, 1.0)
    }
    
    // MARK: - Integration Tests
    func testPluginCommandIntegration() async {
        // Test that plugins can register command extensions
        let mockPlugin = MockPlugin()
        let mockExtension = MockCommandExtension()
        
        // In a real implementation, the plugin would register its commands
        commandExtensionManager.registerExtension(mockExtension)
        
        let context = CommandContext(
            userInput: "mock test",
            parsedParameters: [:],
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            selectedFiles: [],
            environment: [:],
            user: nil
        )
        
        let result = await commandExtensionManager.executeCommand("mock test", context: context)
        XCTAssertTrue(result.success)
        
        // Verify telemetry was tracked
        XCTAssertGreaterThan(telemetryManager.analyticsData.totalEvents, 0)
    }
    
    func testAPICommandIntegration() async throws {
        // Test that API integrations can be used through commands
        let mockAPI = MockExternalAPI()
        try externalAPIFramework.registerAPI(mockAPI)
        
        let credentials = APICredentials(type: .apiKey, values: ["key": "test-key"])
        _ = try await externalAPIFramework.connectToAPI(mockAPI.identifier, credentials: credentials)
        
        // Create a command that uses the API
        let apiCommand = APICommandExtension(apiFramework: externalAPIFramework)
        commandExtensionManager.registerExtension(apiCommand)
        
        let context = CommandContext(
            userInput: "api call test",
            parsedParameters: ["api": mockAPI.identifier, "endpoint": "/test"],
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            selectedFiles: [],
            environment: [:],
            user: nil
        )
        
        let result = await commandExtensionManager.executeCommand("api call test", context: context)
        XCTAssertTrue(result.success)
    }
    
    // MARK: - Performance Tests
    func testExtensibilityPerformance() {
        measure {
            // Test performance of extension registration
            for i in 0..<100 {
                let extension = MockCommandExtension(identifier: "mock_\(i)")
                commandExtensionManager.registerExtension(extension)
            }
            
            // Clean up
            for i in 0..<100 {
                commandExtensionManager.unregisterExtension("mock_\(i)")
            }
        }
    }
    
    func testTelemetryPerformance() {
        measure {
            // Test performance of telemetry tracking
            for i in 0..<1000 {
                telemetryManager.track("performance_test_\(i)", properties: ["index": i])
            }
        }
    }
}

// MARK: - Mock Classes for Testing
class MockPlugin: SamPlugin {
    let identifier = "mock_plugin"
    let name = "Mock Plugin"
    let version = "1.0.0"
    let description = "A mock plugin for testing"
    let author = "Test Author"
    let supportedCommands = ["mock"]
    let requiredPermissions: [PluginPermission] = [.fileSystem]
    
    func initialize() async throws {
        // Mock initialization
    }
    
    func canHandle(_ command: String) -> Bool {
        return command.contains("mock")
    }
    
    func execute(_ command: String, context: PluginContext) async throws -> PluginResult {
        return PluginResult(
            success: true,
            output: "Mock plugin executed",
            data: nil,
            followUpActions: [],
            executionTime: 0.1
        )
    }
    
    func cleanup() async {
        // Mock cleanup
    }
}

class MockCommandExtension: CommandExtension {
    let identifier: String
    let name = "Mock Command"
    let description = "A mock command for testing"
    let keywords = ["mock", "test"]
    let parameters: [CommandParameter] = []
    let category = CommandCategory.custom
    
    init(identifier: String = "mock_command") {
        self.identifier = identifier
    }
    
    func execute(with parameters: [String: Any], context: CommandContext) async throws -> CommandResult {
        return CommandResult.success("Mock command executed")
    }
    
    func validate(parameters: [String: Any]) -> ValidationResult {
        return ValidationResult.valid
    }
    
    func getHelp() -> CommandHelp {
        return CommandHelp(
            usage: "mock [test]",
            examples: ["mock test"],
            notes: "This is a mock command for testing",
            relatedCommands: []
        )
    }
}

class MockExternalAPI: ExternalAPI {
    let identifier = "mock_api"
    let name = "Mock API"
    let description = "A mock API for testing"
    let version = "1.0.0"
    let baseURL = "https://api.mock.com"
    let supportedMethods: [APIRequest.HTTPMethod] = [.GET, .POST]
    let requiredCredentials: [APICredentials.CredentialType] = [.apiKey]
    let rateLimits = RateLimitConfiguration(requestsPerMinute: 100, requestsPerHour: 1000, burstLimit: 10)
    
    func createConnection(with credentials: APICredentials) async throws -> APIConnection {
        return MockAPIConnection(apiId: identifier, credentials: credentials)
    }
    
    func validateCredentials(_ credentials: APICredentials) async throws -> Bool {
        return true
    }
    
    func getEndpoints() -> [APIEndpoint] {
        return [
            APIEndpoint(
                path: "/test",
                method: .GET,
                description: "Test endpoint",
                parameters: [],
                responseSchema: nil
            )
        ]
    }
}

class MockAPIConnection: APIConnection {
    let identifier: String
    let type = ConnectionType.http
    var isConnected = true
    
    private let credentials: APICredentials
    
    init(apiId: String, credentials: APICredentials) {
        self.identifier = apiId
        self.credentials = credentials
    }
    
    func execute(_ request: APIRequest) async throws -> APIResponse {
        return APIResponse.success(statusCode: 200, data: "Mock response".data(using: .utf8))
    }
    
    func disconnect() async {
        isConnected = false
    }
    
    func healthCheck() async -> Bool {
        return isConnected
    }
}

class APICommandExtension: CommandExtension {
    let identifier = "api_command"
    let name = "API Command"
    let description = "Execute API calls through commands"
    let keywords = ["api", "call"]
    let parameters: [CommandParameter] = [
        CommandParameter(
            name: "api",
            type: .string,
            description: "API identifier",
            isRequired: true,
            defaultValue: nil,
            validationRules: []
        ),
        CommandParameter(
            name: "endpoint",
            type: .string,
            description: "API endpoint",
            isRequired: true,
            defaultValue: nil,
            validationRules: []
        )
    ]
    let category = CommandCategory.custom
    
    private let apiFramework: ExternalAPIFramework
    
    init(apiFramework: ExternalAPIFramework) {
        self.apiFramework = apiFramework
    }
    
    func execute(with parameters: [String: Any], context: CommandContext) async throws -> CommandResult {
        guard let apiId = parameters["api"] as? String,
              let endpoint = parameters["endpoint"] as? String else {
            return CommandResult.failure("Missing required parameters")
        }
        
        let request = APIRequest(
            apiIdentifier: apiId,
            endpoint: endpoint,
            method: .GET,
            headers: [:],
            parameters: [:],
            body: nil,
            timeout: 30
        )
        
        do {
            let response = try await apiFramework.executeAPICall(request)
            return CommandResult.success("API call completed: \(response.statusCode)")
        } catch {
            return CommandResult.failure("API call failed: \(error.localizedDescription)")
        }
    }
    
    func validate(parameters: [String: Any]) -> ValidationResult {
        guard parameters["api"] != nil, parameters["endpoint"] != nil else {
            return ValidationResult.invalid(["Missing required parameters: api, endpoint"])
        }
        return ValidationResult.valid
    }
    
    func getHelp() -> CommandHelp {
        return CommandHelp(
            usage: "api call <api> <endpoint>",
            examples: ["api call mock_api /test"],
            notes: "Execute API calls through the external API framework",
            relatedCommands: []
        )
    }
}