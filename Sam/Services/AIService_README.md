# AIService Implementation

## Overview

The AIService class provides comprehensive integration with OpenAI's API, including streaming responses, function calling, cost tracking, and usage monitoring. This implementation fulfills task 8 requirements:

- ✅ Create AIService class with OpenAI API client and authentication
- ✅ Add streaming response handling with AsyncThrowingStream
- ✅ Implement function calling support for structured task execution
- ✅ Create cost tracking and usage monitoring with token counting

## Key Components

### 1. AIService Class (`Services/AIService.swift`)

Main service class that orchestrates AI interactions:

```swift
@MainActor
class AIService: ObservableObject {
    @Published var currentUsage = ChatModels.UsageMetrics()
    @Published var isStreaming = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // Core functionality:
    func streamCompletion(messages:model:functions:) -> AsyncThrowingStream<String, Error>
    func generateCompletion(messages:model:functions:) async throws -> CompletionResponse
    func classifyTask(_ input: String) async throws -> TaskClassificationResult
}
```

**Features:**
- Real-time streaming responses with AsyncThrowingStream
- Function calling support for structured task execution
- Automatic rate limiting and error handling
- Usage metrics tracking and cost monitoring
- Connection status management

### 2. OpenAI Client (`Services/OpenAIClient.swift`)

Low-level HTTP client for OpenAI API:

```swift
class OpenAIClient {
    func generateCompletion(request: CompletionRequest) async throws -> CompletionResponse
    func streamCompletion(request: CompletionRequest) async throws -> AsyncThrowingStream<StreamChunk, Error>
}
```

**Features:**
- Secure API key management via Keychain
- Streaming and non-streaming completions
- Comprehensive error handling
- Automatic retry logic for transient failures

### 3. Cost Tracker (`Services/CostTracker.swift`)

Monitors API usage and costs:

```swift
@MainActor
class CostTracker: ObservableObject {
    @Published var dailyUsage: DailyUsage
    @Published var monthlyUsage: MonthlyUsage
    @Published var totalUsage: TotalUsage
    
    func trackUsage(tokens: Int, cost: Double, model: AIModel) async
    func calculateCost(tokens: Int, model: AIModel) -> Double
}
```

**Features:**
- Real-time cost calculation
- Daily, monthly, and total usage tracking
- Budget alerts and limits
- Usage export functionality
- Model-specific cost tracking

### 4. Rate Limiter (`Services/RateLimiter.swift`)

Prevents API rate limit violations:

```swift
actor RateLimiter {
    func checkRateLimit(estimatedTokens: Int) async throws
    func getCurrentStatus() -> RateLimitStatus
    func getTimeUntilAvailable(estimatedTokens: Int) -> TimeInterval?
}
```

**Features:**
- Request and token-based rate limiting
- Sliding window implementation
- Proactive rate limit checking
- Wait time calculations

### 5. Context Manager (`Services/ContextManager.swift`)

Manages conversation context and system information:

```swift
@MainActor
class ContextManager: ObservableObject {
    @Published var currentContext: ChatModels.ChatContext
    
    func updateContext() async
    func addToConversationHistory(_ message: ChatModels.ChatMessage)
    func getContextSummary() -> String
}
```

**Features:**
- System information gathering
- Conversation history management
- Context summarization for AI
- Periodic context updates

### 6. Keychain Manager (`Utils/KeychainManager.swift`)

Secure credential storage:

```swift
class KeychainManager {
    static let shared = KeychainManager()
    
    func storeAPIKey(_ apiKey: String) -> Bool
    func getAPIKey() -> String?
    func validateAPIKey(_ apiKey: String) -> Bool
}
```

**Features:**
- Secure API key storage in macOS Keychain
- API key validation
- Encryption key management
- User identifier storage

## Data Models

### OpenAI Models (`Models/OpenAIModels.swift`)

Complete type definitions for OpenAI API:

- `AIModel`: Enum with GPT-4, GPT-4 Turbo, GPT-3.5 Turbo
- `CompletionRequest`/`CompletionResponse`: API request/response types
- `StreamChunk`: Streaming response chunks
- `FunctionDefinition`: Function calling definitions
- `ConnectionStatus`: Service connection state

### Usage Tracking Models

- `UsageRecord`: Individual API call record
- `DailyUsage`/`MonthlyUsage`/`TotalUsage`: Aggregated usage statistics
- `ModelUsage`: Per-model usage breakdown
- `BudgetStatus`: Budget limit tracking

## Function Calling Support

The AIService supports OpenAI's function calling feature for structured task execution:

```swift
let functions = [
    FunctionDefinition(
        name: "execute_file_operation",
        description: "Execute file system operations",
        parameters: FunctionParameters(
            properties: [
                "operation": PropertyDefinition(type: "string", description: "Operation type"),
                "source": PropertyDefinition(type: "string", description: "Source path"),
                "destination": PropertyDefinition(type: "string", description: "Destination path")
            ]
        )
    )
]

let stream = aiService.streamCompletion(
    messages: messages,
    functions: functions
)
```

## Usage Examples

### Basic Streaming Chat

```swift
let aiService = AIService()
let messages = [ChatModels.ChatMessage(content: "Hello", isUserMessage: true)]

for try await chunk in aiService.streamCompletion(messages: messages) {
    print(chunk, terminator: "")
}
```

### Task Classification

```swift
let result = try await aiService.classifyTask("copy file.txt to Desktop")
print("Task Type: \(result.taskType)")
print("Confidence: \(result.confidence)")
print("Parameters: \(result.parameters)")
```

### Usage Monitoring

```swift
let usage = aiService.getUsageStatistics()
print("Total Cost: $\(usage.totalCost)")
print("Total Tokens: \(usage.totalTokens)")
print("Success Rate: \(usage.successfulTasks)/\(usage.totalMessages)")
```

## Error Handling

Comprehensive error handling with specific error types:

- `OpenAIError`: API-specific errors (rate limits, authentication, etc.)
- `AIServiceError`: Service-level errors (invalid responses, function calls, etc.)
- `RateLimitError`: Rate limiting violations
- `KeychainError`: Credential storage issues

## Security Features

- API keys stored securely in macOS Keychain
- No sensitive data in logs or error messages
- Secure network communication (HTTPS/TLS)
- Local processing prioritized for privacy

## Performance Optimizations

- Async/await for non-blocking operations
- Streaming responses for real-time feedback
- Rate limiting to prevent API violations
- Context size management to stay within token limits
- Efficient memory usage with proper cleanup

## Testing

The implementation includes comprehensive test coverage:

- Unit tests for all core functionality
- Mock classes for isolated testing
- Performance tests for critical paths
- Error handling validation
- Integration tests with real API calls

## Integration Points

The AIService integrates with other Sam components:

- **ChatManager**: Provides AI responses for chat interface
- **TaskManager**: Classifies and routes tasks
- **SettingsManager**: Manages AI configuration
- **WorkflowManager**: Executes multi-step AI workflows

## Requirements Fulfilled

✅ **Requirement 6.1**: Cloud AI processing with OpenAI integration
✅ **Requirement 6.2**: Real-time streaming responses
✅ **Requirement 6.3**: Cost tracking and usage monitoring
✅ **Requirement 6.4**: Rate limiting and error handling
✅ **Requirement 6.6**: Conversation context management

The AIService implementation provides a robust, secure, and efficient foundation for AI-powered features in the Sam macOS assistant.