import XCTest
@testable import Sam

final class AIServiceTests: XCTestCase {
    var aiService: AIService!
    var mockOpenAIClient: MockOpenAIClient!
    var mockCostTracker: MockCostTracker!
    
    override func setUp() {
        super.setUp()
        mockOpenAIClient = MockOpenAIClient()
        mockCostTracker = MockCostTracker()
        aiService = AIService(
            client: mockOpenAIClient,
            costTracker: mockCostTracker
        )
    }
    
    override func tearDown() {
        aiService = nil
        mockOpenAIClient = nil
        mockCostTracker = nil
        super.tearDown()
    }
    
    // MARK: - Basic Response Generation Tests
    
    func testGenerateResponse() async throws {
        // Given
        let testMessage = "Hello, how are you?"
        mockOpenAIClient.mockResponse = "I'm doing well, thank you!"
        
        // When
        let response = try await aiService.generateResponse(for: testMessage)
        
        // Then
        XCTAssertEqual(response, "I'm doing well, thank you!")
        XCTAssertTrue(mockOpenAIClient.generateResponseCalled)
        XCTAssertTrue(mockCostTracker.trackUsageCalled)
    }
    
    func testGenerateResponseWithError() async throws {
        // Given
        let testMessage = "Test message"
        mockOpenAIClient.shouldThrowError = true
        
        // When & Then
        do {
            _ = try await aiService.generateResponse(for: testMessage)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AIServiceError)
        }
    }
    
    // MARK: - Streaming Response Tests
    
    func testStreamingResponse() async throws {
        // Given
        let testMessage = "Stream this response"
        let expectedChunks = ["Hello", " there", "!"]
        mockOpenAIClient.mockStreamingChunks = expectedChunks
        
        var receivedChunks: [String] = []
        
        // When
        let stream = aiService.streamResponse(for: testMessage)
        for try await chunk in stream {
            receivedChunks.append(chunk)
        }
        
        // Then
        XCTAssertEqual(receivedChunks, expectedChunks)
        XCTAssertTrue(mockOpenAIClient.streamResponseCalled)
    }
    
    func testStreamingResponseWithError() async throws {
        // Given
        let testMessage = "Test streaming error"
        mockOpenAIClient.shouldThrowStreamingError = true
        
        // When & Then
        let stream = aiService.streamResponse(for: testMessage)
        do {
            for try await _ in stream {
                // Should not reach here
            }
            XCTFail("Expected streaming error")
        } catch {
            XCTAssertTrue(error is AIServiceError)
        }
    }
    
    // MARK: - Function Calling Tests
    
    func testFunctionCalling() async throws {
        // Given
        let functions = [
            FunctionDefinition(
                name: "get_weather",
                description: "Get weather information",
                parameters: ["location": "string"]
            )
        ]
        mockOpenAIClient.mockFunctionCall = FunctionCall(
            name: "get_weather",
            arguments: ["location": "San Francisco"]
        )
        
        // When
        let result = try await aiService.generateResponseWithFunctions(
            message: "What's the weather in San Francisco?",
            functions: functions
        )
        
        // Then
        XCTAssertNotNil(result.functionCall)
        XCTAssertEqual(result.functionCall?.name, "get_weather")
        XCTAssertEqual(result.functionCall?.arguments["location"] as? String, "San Francisco")
    }
    
    // MARK: - Model Selection Tests
    
    func testModelSelection() async throws {
        // Given
        let simpleMessage = "Hello"
        let complexMessage = "Analyze this complex data and provide detailed insights with multiple perspectives"
        
        // When
        _ = try await aiService.generateResponse(for: simpleMessage)
        let simpleModel = mockOpenAIClient.lastUsedModel
        
        _ = try await aiService.generateResponse(for: complexMessage)
        let complexModel = mockOpenAIClient.lastUsedModel
        
        // Then
        XCTAssertEqual(simpleModel, "gpt-3.5-turbo")
        XCTAssertEqual(complexModel, "gpt-4-turbo-preview")
    }
    
    // MARK: - Cost Tracking Tests
    
    func testCostTracking() async throws {
        // Given
        let testMessage = "Test cost tracking"
        mockOpenAIClient.mockTokenCount = 150
        
        // When
        _ = try await aiService.generateResponse(for: testMessage)
        
        // Then
        XCTAssertTrue(mockCostTracker.trackUsageCalled)
        XCTAssertEqual(mockCostTracker.lastTokenCount, 150)
        XCTAssertGreaterThan(mockCostTracker.lastCost, 0)
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimiting() async throws {
        // Given
        mockOpenAIClient.simulateRateLimit = true
        
        // When & Then
        do {
            _ = try await aiService.generateResponse(for: "Test rate limit")
            XCTFail("Expected rate limit error")
        } catch AIServiceError.rateLimitExceeded {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Context Management Tests
    
    func testContextManagement() async throws {
        // Given
        let messages = [
            "Hello",
            "How are you?",
            "What's the weather like?"
        ]
        
        // When
        for message in messages {
            _ = try await aiService.generateResponse(for: message)
        }
        
        // Then
        XCTAssertEqual(mockOpenAIClient.contextMessages.count, messages.count * 2) // User + AI messages
    }
    
    func testContextTruncation() async throws {
        // Given
        let longContext = Array(repeating: "Long message", count: 100)
        
        // When
        for message in longContext {
            _ = try await aiService.generateResponse(for: message)
        }
        
        // Then
        XCTAssertLessThan(mockOpenAIClient.contextMessages.count, 50) // Should be truncated
    }
    
    // MARK: - Performance Tests
    
    func testResponsePerformance() {
        measure {
            Task {
                _ = try? await aiService.generateResponse(for: "Quick test")
            }
        }
    }
    
    func testConcurrentRequests() async throws {
        // Given
        let messages = Array(1...10).map { "Message \($0)" }
        
        // When
        let startTime = Date()
        await withTaskGroup(of: Void.self) { group in
            for message in messages {
                group.addTask {
                    _ = try? await self.aiService.generateResponse(for: message)
                }
            }
        }
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(executionTime, 10.0, "Concurrent requests took too long")
    }
}

// MARK: - Mock Classes

class MockOpenAIClient: OpenAIClientProtocol {
    var mockResponse = "Mock response"
    var mockStreamingChunks: [String] = []
    var mockFunctionCall: FunctionCall?
    var mockTokenCount = 100
    var shouldThrowError = false
    var shouldThrowStreamingError = false
    var simulateRateLimit = false
    var lastUsedModel = ""
    var contextMessages: [ChatMessage] = []
    
    var generateResponseCalled = false
    var streamResponseCalled = false
    
    func generateResponse(messages: [ChatMessage], model: String) async throws -> OpenAIResponse {
        generateResponseCalled = true
        lastUsedModel = model
        contextMessages.append(contentsOf: messages)
        
        if simulateRateLimit {
            throw AIServiceError.rateLimitExceeded
        }
        
        if shouldThrowError {
            throw AIServiceError.apiError("Mock error")
        }
        
        return OpenAIResponse(
            content: mockResponse,
            functionCall: mockFunctionCall,
            tokenCount: mockTokenCount
        )
    }
    
    func streamResponse(messages: [ChatMessage], model: String) -> AsyncThrowingStream<String, Error> {
        streamResponseCalled = true
        lastUsedModel = model
        
        return AsyncThrowingStream { continuation in
            Task {
                if shouldThrowStreamingError {
                    continuation.finish(throwing: AIServiceError.apiError("Mock streaming error"))
                    return
                }
                
                for chunk in mockStreamingChunks {
                    continuation.yield(chunk)
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
                }
                continuation.finish()
            }
        }
    }
}

class MockCostTracker: CostTrackerProtocol {
    var trackUsageCalled = false
    var lastTokenCount = 0
    var lastCost: Double = 0
    
    func trackUsage(tokens: Int, model: String) {
        trackUsageCalled = true
        lastTokenCount = tokens
        lastCost = Double(tokens) * 0.00001 // Mock cost calculation
    }
    
    func getTotalCost() -> Double {
        return lastCost
    }
}