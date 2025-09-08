# AI Coding Agent Instructions for Sam macOS AI Assistant

## Project Overview

Sam is a native macOS AI assistant built with SwiftUI that performs actual tasks through natural language commands. Unlike traditional chatbots, Sam executes file operations, system queries, app control, and workflow automation while maintaining user privacy through hybrid local/cloud processing.

**Key Architecture:**
- **Frontend**: Native SwiftUI with MVVM pattern
- **Backend**: Modular service architecture with Managers/Services/Models
- **Data**: Core Data for persistence, Keychain for secure storage
- **AI**: Hybrid local/cloud processing with OpenAI integration
- **Integration**: Deep macOS APIs, AppleScript, URL schemes

## Essential Knowledge for Productivity

### 1. Core Architecture Patterns

**Manager Pattern**: All business logic lives in Managers (ChatManager, TaskManager, etc.)
```swift
@MainActor
class ChatManager: ObservableObject {
    // Always use @MainActor for UI-bound managers
    // Use @Published for SwiftUI bindings
    // Follow repository pattern for data access
}
```

**Service Pattern**: External integrations and system APIs
```swift
class AIService: ObservableObject {
    // Handle async operations with proper error handling
    // Use AsyncThrowingStream for streaming responses
    // Implement cost tracking and rate limiting
}
```

**Repository Pattern**: Data access abstraction
```swift
class ChatRepository {
    // Use Core Data contexts appropriately
    // Handle background operations safely
    // Implement proper error handling
}
```

### 2. Task Processing Flow

**Classification → Routing → Execution → Response**

1. **Task Classification**: Natural language → TaskType + parameters
2. **Route Selection**: Local vs Cloud based on complexity/confidence
3. **Execution**: Service delegation with progress tracking
4. **Response**: Streaming output with error handling

**Key Files:**
- `Services/TaskRouter.swift` - Main routing logic
- `Services/TaskClassifier.swift` - NLP classification
- `Models/TaskModels.swift` - Task data structures
- `Models/TaskRoutingModels.swift` - Routing types

### 3. Critical Development Workflows

**Building & Testing:**
```bash
# Use Swift Package Manager
swift build --build-tests -Xswiftc -diagnostic-style=llvm

# Run tests
swift test

# Code quality (pre-commit hooks)
swiftlint lint --config .swiftlint.yml
swiftformat --lint Sam/
```

**Xcode Integration:**
- Use Xcode 15+ with macOS 13+ deployment target
- Enable necessary entitlements for file access, accessibility, automation
- Configure Info.plist for required permissions

**Debugging Patterns:**
- Use `print()` statements liberally (removed in production)
- Implement comprehensive error logging
- Test with various input types and edge cases

### 4. Project-Specific Conventions

**Naming Conventions:**
- Services: `[Feature]Service` (AIService, FileSystemService)
- Managers: `[Feature]Manager` (ChatManager, TaskManager)
- Models: `[Feature]Models` (ChatModels, SystemModels)
- Views: PascalCase with View suffix (ChatView, SettingsView)

**Error Handling:**
```swift
enum SamError: LocalizedError {
    case taskClassification(TaskClassificationError)
    case fileOperation(FileOperationError)
    // Always provide user-friendly errorDescription
    // Include recoverySuggestion when possible
}
```

**Async Patterns:**
```swift
// Always use async/await over completion handlers
func processTask(_ input: String) async throws -> TaskResult {
    // Use AsyncThrowingStream for streaming
    // Handle cancellation properly
    // Track execution time and performance
}
```

**Privacy-First Approach:**
- Process locally when possible (80%+ of tasks)
- Only send complex queries to cloud
- Never upload file contents without consent
- Encrypt sensitive data with Keychain

### 5. Integration Points & Communication

**macOS APIs:**
- File operations: FileManager, NSWorkspace
- System info: IOKit, SystemConfiguration
- App control: NSRunningApplication, AppleScript
- Security: Keychain Services, entitlements

**External Services:**
- OpenAI API with function calling
- Cost tracking and rate limiting
- Response streaming and caching

**Cross-Component Communication:**
- NotificationCenter for UI updates
- Combine publishers for reactive updates
- Dependency injection for testability

### 6. Common Implementation Patterns

**File Operations:**
```swift
// Always validate permissions first
try await validateFileAccess(url)

// Use FileManager for basic operations
let result = try await fileManager.copyItem(at: source, to: destination)

// Provide undo support for destructive operations
return OperationResult(success: true, undoAction: { /* rollback */ })
```

**AI Service Integration:**
```swift
// Always check rate limits
try await rateLimiter.checkRateLimit()

// Use streaming for better UX
let stream = try await client.streamCompletion(request: request)
for try await chunk in stream {
    // Process chunks incrementally
}
```

**Core Data Usage:**
```swift
// Use background context for heavy operations
let backgroundContext = persistenceController.backgroundContext

// Always save in appropriate context
try await backgroundContext.perform {
    // Data operations
    try backgroundContext.save()
}
```

### 7. Testing & Quality Assurance

**Unit Testing:**
```swift
class ChatManagerTests: XCTestCase {
    var chatManager: ChatManager!
    var mockAIService: MockAIService!
    
    override func setUp() {
        mockAIService = MockAIService()
        chatManager = ChatManager(aiService: mockAIService)
    }
}
```

**Integration Testing:**
- Test end-to-end task execution
- Verify file operations with temporary directories
- Test app integrations with mock services

**Performance Testing:**
- Monitor memory usage (<200MB baseline)
- Track response times (<2s for 90% of requests)
- Test with large file operations

### 8. Security & Privacy Considerations

**Data Handling:**
- Classify data sensitivity before processing
- Use local processing for personal/sensitive data
- Encrypt chat history and preferences
- Never log sensitive information

**API Security:**
- Store API keys in Keychain only
- Implement proper authentication
- Handle rate limiting gracefully
- Monitor costs and usage

**Permission Management:**
- Request minimal necessary permissions
- Explain permission requirements clearly
- Handle permission denials gracefully
- Provide manual alternatives when possible

### 9. Key Files & Directories

**Core Architecture:**
- `SamApp.swift` - App entry point and scene configuration
- `Managers/ChatManager.swift` - Main conversation orchestration
- `Services/TaskRouter.swift` - Task routing and execution
- `Models/ChatModels.swift` - Core data structures

**Integration Points:**
- `Services/AIService.swift` - OpenAI integration
- `Services/FileSystemService.swift` - File operations
- `Services/AppleScriptEngine.swift` - App automation
- `Models/PersistenceController.swift` - Core Data setup

**UI Components:**
- `Views/ContentView.swift` - Main chat interface
- `Views/SettingsView.swift` - Configuration panel
- `Views/MessageBubbleView.swift` - Individual messages

**Configuration:**
- `Package.swift` - Swift Package configuration
- `Info.plist` - App permissions and metadata
- `.swiftlint.yml` - Code quality rules

### 10. Development Best Practices

**Code Organization:**
- Keep managers focused on single responsibilities
- Use protocols for service interfaces
- Implement proper dependency injection
- Follow Swift concurrency best practices

**Error Handling:**
- Use typed errors with recovery suggestions
- Provide user-friendly error messages
- Implement graceful degradation
- Log errors for debugging without exposing sensitive data

**Performance:**
- Use lazy loading for heavy operations
- Implement caching for repeated queries
- Monitor memory usage and clean up resources
- Optimize UI updates with proper state management

**Testing:**
- Write tests for all new functionality
- Use mock services for external dependencies
- Test edge cases and error conditions
- Verify performance requirements are met

### 11. Common Pitfalls to Avoid

**Concurrency Issues:**
- Don't block main thread with heavy operations
- Use proper actor isolation for shared state
- Handle task cancellation correctly
- Avoid retain cycles in async code

**Memory Management:**
- Don't hold strong references to large objects
- Clean up observers and cancellables
- Use weak self in closures to prevent leaks
- Monitor for memory leaks in long-running tasks

**API Limitations:**
- Respect OpenAI rate limits and costs
- Handle API failures gracefully
- Cache responses when appropriate
- Provide offline functionality for local tasks

**macOS Integration:**
- Request permissions at appropriate times
- Handle permission denials gracefully
- Test on different macOS versions
- Respect system resource constraints

This knowledge base will help you be immediately productive in the Sam codebase. Focus on understanding the task routing system, manager/service patterns, and macOS integration points when implementing new features.
