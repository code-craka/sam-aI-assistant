import XCTest
import Combine
@testable import Sam

@MainActor
final class ChatManagerTests: XCTestCase {
    var chatManager: ChatManager!
    var mockAIService: MockAIService!
    var mockTaskManager: MockTaskManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockAIService = MockAIService()
        mockTaskManager = MockTaskManager()
        chatManager = ChatManager(
            aiService: mockAIService,
            taskManager: mockTaskManager
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        chatManager = nil
        mockAIService = nil
        mockTaskManager = nil
        super.tearDown()
    }
    
    func testSendMessage() async throws {
        // Given
        let testMessage = "Hello, Sam!"
        mockAIService.mockResponse = "Hello! How can I help you today?"
        
        // When
        await chatManager.sendMessage(testMessage)
        
        // Then
        XCTAssertEqual(chatManager.messages.count, 2) // User message + AI response
        XCTAssertEqual(chatManager.messages.first?.content, testMessage)
        XCTAssertTrue(chatManager.messages.first?.isUserMessage ?? false)
        XCTAssertEqual(chatManager.messages.last?.content, "Hello! How can I help you today?")
        XCTAssertFalse(chatManager.messages.last?.isUserMessage ?? true)
    }
    
    func testMessagePersistence() async throws {
        // Given
        let testMessage = "Test persistence"
        mockAIService.mockResponse = "Response saved"
        
        // When
        await chatManager.sendMessage(testMessage)
        
        // Then
        XCTAssertTrue(mockTaskManager.saveMessageCalled)
        XCTAssertEqual(mockTaskManager.savedMessages.count, 2)
    }
    
    func testStreamingResponse() async throws {
        // Given
        let chunks = ["Hello", " there", "!"]
        mockAIService.mockStreamingChunks = chunks
        
        var receivedChunks: [String] = []
        chatManager.$currentStreamingResponse
            .compactMap { $0 }
            .sink { chunk in
                receivedChunks.append(chunk)
            }
            .store(in: &cancellables)
        
        // When
        await chatManager.sendMessage("Stream test")
        
        // Then
        XCTAssertEqual(receivedChunks.joined(), "Hello there!")
    }
    
    func testErrorHandling() async throws {
        // Given
        mockAIService.shouldThrowError = true
        
        // When
        await chatManager.sendMessage("Error test")
        
        // Then
        XCTAssertTrue(chatManager.hasError)
        XCTAssertNotNil(chatManager.lastError)
        XCTAssertEqual(chatManager.messages.count, 1) // Only user message
    }
    
    func testClearConversation() async throws {
        // Given
        await chatManager.sendMessage("Test message")
        XCTAssertFalse(chatManager.messages.isEmpty)
        
        // When
        chatManager.clearConversation()
        
        // Then
        XCTAssertTrue(chatManager.messages.isEmpty)
        XCTAssertTrue(mockTaskManager.clearMessagesCalled)
    }
}

// MARK: - Mock Classes

class MockAIService: AIServiceProtocol {
    var mockResponse = "Mock response"
    var mockStreamingChunks: [String] = []
    var shouldThrowError = false
    
    func generateResponse(for message: String) async throws -> String {
        if shouldThrowError {
            throw AIServiceError.apiError("Mock error")
        }
        return mockResponse
    }
    
    func streamResponse(for message: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                if shouldThrowError {
                    continuation.finish(throwing: AIServiceError.apiError("Mock error"))
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

class MockTaskManager: TaskManagerProtocol {
    var saveMessageCalled = false
    var clearMessagesCalled = false
    var savedMessages: [ChatMessage] = []
    
    func saveMessage(_ message: ChatMessage) async throws {
        saveMessageCalled = true
        savedMessages.append(message)
    }
    
    func clearMessages() async throws {
        clearMessagesCalled = true
        savedMessages.removeAll()
    }
    
    func loadMessages() async throws -> [ChatMessage] {
        return savedMessages
    }
}