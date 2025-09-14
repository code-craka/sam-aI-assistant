import XCTest
@testable import Sam

// MARK: - AI Service Tests
@MainActor
class AIServiceTests: XCTestCase {
    
    var aiService: AIService!
    
    override func setUp() {
        super.setUp()
        aiService = AIService()
    }
    
    override func tearDown() {
        aiService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testAIServiceInitialization() {
        XCTAssertNotNil(aiService)
        XCTAssertFalse(aiService.isStreaming)
        XCTAssertEqual(aiService.connectionStatus, .disconnected)
        XCTAssertEqual(aiService.currentUsage.totalMessages, 0)
        XCTAssertEqual(aiService.currentUsage.totalTokens, 0)
        XCTAssertEqual(aiService.currentUsage.totalCost, 0.0)
    }
    
    // MARK: - Usage Statistics Tests
    
    func testUsageStatisticsInitialState() {
        let usage = aiService.getUsageStatistics()
        
        XCTAssertEqual(usage.totalMessages, 0)
        XCTAssertEqual(usage.totalTokens, 0)
        XCTAssertEqual(usage.totalCost, 0.0)
        XCTAssertEqual(usage.successfulTasks, 0)
        XCTAssertEqual(usage.failedTasks, 0)
    }
    
    func testResetUsageStatistics() {
        // First, simulate some usage
        Task {
            await aiService.updateUsageMetrics(tokens: 100, cost: 0.01, model: .gpt35Turbo)
        }
        
        // Reset statistics
        aiService.resetUsageStatistics()
        
        let usage = aiService.getUsageStatistics()
        XCTAssertEqual(usage.totalMessages, 0)
        XCTAssertEqual(usage.totalTokens, 0)
        XCTAssertEqual(usage.totalCost, 0.0)
    }
    
    // MARK: - Task Classification Tests
    
    func testTaskClassificationWithValidInput() async {
        // This test would require a valid API key and network connection
        // For now, we'll test the structure
        
        let input = "copy file.txt to Desktop"
        
        do {
            let result = try await aiService.classifyTask(input)
            
            // Verify the result structure
            XCTAssertNotNil(result.taskType)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            
        } catch {
            // Expected to fail without valid API key
            XCTAssertTrue(error is OpenAIError)
        }
    }
    
    // MARK: - Model Selection Tests
    
    func testAIModelProperties() {
        let gpt4 = AIModel.gpt4
        XCTAssertEqual(gpt4.displayName, "GPT-4")
        XCTAssertEqual(gpt4.maxTokens, AIConstants.gpt4MaxTokens)
        XCTAssertEqual(gpt4.costPerToken, AIConstants.gpt4CostPerToken)
        
        let gpt4Turbo = AIModel.gpt4Turbo
        XCTAssertEqual(gpt4Turbo.displayName, "GPT-4 Turbo")
        XCTAssertTrue(gpt4Turbo.isRecommended)
        
        let gpt35Turbo = AIModel.gpt35Turbo
        XCTAssertEqual(gpt35Turbo.displayName, "GPT-3.5 Turbo")
        XCTAssertEqual(gpt35Turbo.maxTokens, AIConstants.gpt35TurboMaxTokens)
    }
    
    // MARK: - Connection Status Tests
    
    func testConnectionStatusDisplayText() {
        XCTAssertEqual(ConnectionStatus.disconnected.displayText, "Disconnected")
        XCTAssertEqual(ConnectionStatus.connecting.displayText, "Connecting...")
        XCTAssertEqual(ConnectionStatus.connected.displayText, "Connected")
        XCTAssertEqual(ConnectionStatus.error("Test error").displayText, "Error: Test error")
    }
    
    func testConnectionStatusIsConnected() {
        XCTAssertFalse(ConnectionStatus.disconnected.isConnected)
        XCTAssertFalse(ConnectionStatus.connecting.isConnected)
        XCTAssertTrue(ConnectionStatus.connected.isConnected)
        XCTAssertFalse(ConnectionStatus.error("Test").isConnected)
    }
    
    // MARK: - Error Handling Tests
    
    func testAIServiceErrorDescriptions() {
        let invalidResponse = AIServiceError.invalidResponse
        XCTAssertNotNil(invalidResponse.errorDescription)
        XCTAssertNotNil(invalidResponse.recoverySuggestion)
        
        let functionCallFailed = AIServiceError.functionCallFailed("test_function")
        XCTAssertTrue(functionCallFailed.errorDescription?.contains("test_function") == true)
        
        let rateLimitExceeded = AIServiceError.rateLimitExceeded
        XCTAssertNotNil(rateLimitExceeded.errorDescription)
        XCTAssertNotNil(rateLimitExceeded.recoverySuggestion)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfUsageMetricsUpdate() {
        measure {
            Task {
                await aiService.updateUsageMetrics(tokens: 100, cost: 0.01, model: .gpt35Turbo)
            }
        }
    }
}

// MARK: - Mock Classes for Testing

class MockOpenAIClient: OpenAIClient {
    var shouldSucceed = true
    var mockResponse: CompletionResponse?
    
    override func generateCompletion(request: CompletionRequest) async throws -> CompletionResponse {
        if !shouldSucceed {
            throw OpenAIError.networkError(NSError(domain: "Test", code: 0))
        }
        
        return mockResponse ?? CompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: request.model,
            choices: [
                CompletionResponse.Choice(
                    index: 0,
                    message: APIMessage(role: .assistant, content: "Test response"),
                    finishReason: "stop"
                )
            ],
            usage: CompletionResponse.Usage(
                promptTokens: 10,
                completionTokens: 20,
                totalTokens: 30
            )
        )
    }
}

class MockCostTracker: CostTracker {
    var trackUsageCalled = false
    var lastTrackedTokens: Int?
    var lastTrackedCost: Double?
    var lastTrackedModel: AIModel?
    
    override func trackUsage(tokens: Int, cost: Double, model: AIModel) async {
        trackUsageCalled = true
        lastTrackedTokens = tokens
        lastTrackedCost = cost
        lastTrackedModel = model
        
        await super.trackUsage(tokens: tokens, cost: cost, model: model)
    }
}