import XCTest
@testable import Sam

// MARK: - Task Router Tests
@MainActor
class TaskRouterTests: XCTestCase {
    
    var taskRouter: TaskRouter!
    var mockTaskClassifier: MockTaskClassifier!
    var mockAIService: MockAIService!
    var mockRateLimiter: MockRateLimiter!
    var mockCostTracker: MockCostTracker!
    
    override func setUp() {
        super.setUp()
        
        mockTaskClassifier = MockTaskClassifier()
        mockAIService = MockAIService()
        mockRateLimiter = MockRateLimiter()
        mockCostTracker = MockCostTracker()
        
        taskRouter = TaskRouter(
            taskClassifier: mockTaskClassifier,
            aiService: mockAIService,
            rateLimiter: mockRateLimiter,
            costTracker: mockCostTracker
        )
    }
    
    override func tearDown() {
        taskRouter = nil
        mockTaskClassifier = nil
        mockAIService = nil
        mockRateLimiter = nil
        mockCostTracker = nil
        super.tearDown()
    }
    
    // MARK: - Local Processing Tests
    
    func testLocalProcessingForHighConfidenceSimpleTask() async throws {
        // Given
        let input = "what's my battery level"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .systemQuery,
            confidence: 0.95,
            parameters: ["queryType": "battery"],
            complexity: .simple,
            processingRoute: .local
        )
        
        // When
        let result = try await taskRouter.processInput(input)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processingRoute, .local)
        XCTAssertEqual(result.tokensUsed, 0)
        XCTAssertEqual(result.cost, 0.0)
        XCTAssertFalse(result.cacheHit)
    }
    
    func testCloudProcessingForLowConfidenceTask() async throws {
        // Given
        let input = "analyze this complex document and summarize the key insights"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .textProcessing,
            confidence: 0.4,
            parameters: [:],
            complexity: .complex,
            processingRoute: .cloud
        )
        
        mockAIService.mockResponse = CompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4-turbo-preview",
            choices: [
                CompletionResponse.Choice(
                    index: 0,
                    message: APIMessage(role: .assistant, content: "Analysis complete: The document contains..."),
                    finishReason: "stop"
                )
            ],
            usage: CompletionResponse.Usage(
                promptTokens: 100,
                completionTokens: 200,
                totalTokens: 300
            )
        )
        
        // When
        let result = try await taskRouter.processInput(input)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processingRoute, .cloud)
        XCTAssertEqual(result.tokensUsed, 300)
        XCTAssertGreaterThan(result.cost, 0.0)
        XCTAssertFalse(result.cacheHit)
    }
    
    func testHybridProcessingFallback() async throws {
        // Given
        let input = "organize my desktop files by type"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .fileOperation,
            confidence: 0.6, // Below threshold for local-only
            parameters: ["action": "organize", "location": "desktop"],
            complexity: .moderate,
            processingRoute: .hybrid
        )
        
        // When
        let result = try await taskRouter.processInput(input)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processingRoute, .cloud) // Should fall back to cloud for better accuracy
    }
    
    // MARK: - Caching Tests
    
    func testCacheHitForRepeatedQuery() async throws {
        // Given
        let input = "help"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .help,
            confidence: 0.9,
            parameters: [:],
            complexity: .simple,
            processingRoute: .local
        )
        
        // When - First request
        let firstResult = try await taskRouter.processInput(input)
        
        // Then - Should not be cached initially
        XCTAssertFalse(firstResult.cacheHit)
        
        // When - Second request (same input)
        let secondResult = try await taskRouter.processInput(input)
        
        // Then - Should be cached
        XCTAssertTrue(secondResult.cacheHit)
        XCTAssertEqual(firstResult.output, secondResult.output)
    }
    
    func testCacheStatistics() async throws {
        // Given
        let inputs = ["help", "battery level", "help", "storage info", "help"]
        
        for input in inputs {
            mockTaskClassifier.mockResult = TaskClassificationResult(
                taskType: .help,
                confidence: 0.9,
                complexity: .simple,
                processingRoute: .local
            )
            _ = try await taskRouter.processInput(input)
        }
        
        // When
        let stats = taskRouter.getCacheStatistics()
        
        // Then
        XCTAssertGreaterThan(stats.totalHits, 0)
        XCTAssertGreaterThan(stats.hitRate, 0.0)
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimitHandling() async throws {
        // Given
        let input = "complex analysis task"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .textProcessing,
            confidence: 0.3,
            complexity: .complex,
            processingRoute: .cloud
        )
        
        mockRateLimiter.shouldThrowRateLimit = true
        
        // When & Then
        do {
            _ = try await taskRouter.processInput(input)
            XCTFail("Expected rate limit error")
        } catch let error as RateLimitError {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Fallback Tests
    
    func testFallbackOnCloudServiceFailure() async throws {
        // Given
        let input = "summarize this text"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .textProcessing,
            confidence: 0.3,
            complexity: .complex,
            processingRoute: .cloud
        )
        
        mockAIService.shouldFail = true
        
        // When
        let result = try await taskRouter.processInput(input)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.output.contains("I'm sorry"))
    }
    
    // MARK: - System Health Tests
    
    func testSystemHealthCheck() async throws {
        // When
        let healthStatus = await taskRouter.checkSystemHealth()
        
        // Then
        XCTAssertNotNil(healthStatus.localProcessing)
        XCTAssertNotNil(healthStatus.cloudProcessing)
        XCTAssertNotNil(healthStatus.responseCache)
        XCTAssertNotNil(healthStatus.overallStatus)
    }
    
    // MARK: - Performance Tests
    
    func testProcessingPerformance() async throws {
        // Given
        let inputs = Array(repeating: "test query", count: 100)
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .help,
            confidence: 0.9,
            complexity: .simple,
            processingRoute: .local
        )
        
        // When
        let startTime = Date()
        
        for input in inputs {
            _ = try await taskRouter.processInput(input)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(executionTime, 5.0) // Should complete 100 requests in under 5 seconds
        
        let stats = taskRouter.getRoutingStatistics()
        XCTAssertEqual(stats.totalRequests, 100)
        XCTAssertGreaterThan(stats.cacheHits, 90) // Most should be cache hits after the first
    }
    
    // MARK: - Route Selection Tests
    
    func testPrivacySensitiveTasksUseLocalProcessing() async throws {
        // Given
        let input = "help me with my password manager"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .appControl,
            confidence: 0.8,
            parameters: ["appName": "password"],
            complexity: .moderate,
            processingRoute: .cloud // Would normally go to cloud
        )
        
        // When
        let result = try await taskRouter.processInput(input)
        
        // Then
        XCTAssertEqual(result.processingRoute, .local) // Should be forced to local for privacy
    }
    
    func testComplexTasksPreferCloudProcessing() async throws {
        // Given
        let input = "create a comprehensive workflow for data analysis"
        mockTaskClassifier.mockResult = TaskClassificationResult(
            taskType: .automation,
            confidence: 0.4,
            complexity: .advanced,
            processingRoute: .hybrid
        )
        
        // When
        let result = try await taskRouter.processInput(input)
        
        // Then
        XCTAssertEqual(result.processingRoute, .cloud) // Should prefer cloud for complex tasks
    }
}

// MARK: - Mock Classes

class MockTaskClassifier: TaskClassifier {
    var mockResult: TaskClassificationResult?
    
    override func classify(_ input: String) async -> TaskClassificationResult {
        return mockResult ?? TaskClassificationResult(
            taskType: .unknown,
            confidence: 0.5,
            complexity: .simple,
            processingRoute: .local
        )
    }
    
    override func quickClassify(_ input: String) -> TaskClassificationResult? {
        return mockResult
    }
}

class MockAIService: AIService {
    var mockResponse: CompletionResponse?
    var shouldFail = false
    
    override func generateCompletion(
        messages: [ChatModels.ChatMessage],
        model: AIModel = .gpt4Turbo,
        functions: [FunctionDefinition]? = nil,
        temperature: Float = AIConstants.openAITemperature
    ) async throws -> CompletionResponse {
        
        if shouldFail {
            throw AIServiceError.networkTimeout
        }
        
        return mockResponse ?? CompletionResponse(
            id: "mock-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: model.rawValue,
            choices: [
                CompletionResponse.Choice(
                    index: 0,
                    message: APIMessage(role: .assistant, content: "Mock response"),
                    finishReason: "stop"
                )
            ],
            usage: CompletionResponse.Usage(
                promptTokens: 50,
                completionTokens: 100,
                totalTokens: 150
            )
        )
    }
    
    override func checkAvailability() async -> Bool {
        return !shouldFail
    }
}

class MockRateLimiter: RateLimiter {
    var shouldThrowRateLimit = false
    
    override func checkRateLimit(estimatedTokens: Int = 1000) async throws {
        if shouldThrowRateLimit {
            throw RateLimitError.requestLimitExceeded(waitTime: 60)
        }
    }
    
    override func getCurrentStatus() -> RateLimitStatus {
        return RateLimitStatus(
            requestsUsed: shouldThrowRateLimit ? 60 : 10,
            maxRequests: 60,
            tokensUsed: shouldThrowRateLimit ? 90000 : 10000,
            maxTokens: 90000,
            windowDuration: 60,
            nextResetTime: Date().addingTimeInterval(60)
        )
    }
}

class MockCostTracker: CostTracker {
    override func calculateCost(tokens: Int, model: AIModel) -> Double {
        return Double(tokens) * model.costPerToken
    }
    
    override func trackUsage(tokens: Int, cost: Double, model: AIModel) async {
        // Mock implementation - no actual tracking
    }
}