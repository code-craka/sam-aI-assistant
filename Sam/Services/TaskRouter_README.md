# Task Routing System

The Task Routing System is a central component of Sam AI Assistant that intelligently routes user requests between local and cloud processing based on task complexity, confidence levels, and system conditions.

## Overview

The system implements a hybrid processing approach that balances performance, privacy, and functionality by:

- **Local Processing**: Fast, private processing for simple, high-confidence tasks
- **Cloud Processing**: Advanced AI capabilities for complex reasoning and low-confidence tasks
- **Hybrid Processing**: Intelligent fallback between local and cloud based on conditions
- **Response Caching**: Intelligent caching with TTL and LRU eviction
- **Fallback Management**: Graceful degradation when processing fails

## Architecture

```
User Input → TaskRouter → [Local/Cloud/Hybrid] → Response Cache → User
                ↓
            TaskClassifier
                ↓
            RateLimiter → AIService/LocalProcessor
                ↓
            FallbackManager
```

## Core Components

### TaskRouter

The main orchestrator that:

- Determines optimal processing route
- Manages caching and fallback strategies
- Tracks performance metrics
- Handles error recovery

### ResponseCache

Intelligent caching system with:

- LRU eviction policy
- TTL-based expiration
- Memory usage monitoring
- Cache hit/miss statistics

### FallbackManager

Handles processing failures with:

- Multiple fallback strategies
- Exponential backoff retry logic
- Graceful degradation responses
- Error classification and recovery

## Processing Routes

### Local Processing

**When Used:**

- High confidence (>70%) simple tasks
- Privacy-sensitive requests
- System queries and file operations
- Rate limits exceeded

**Examples:**

```swift
"what's my battery level"     // System query
"open Safari"                 // App control
"copy file.txt to Desktop"    // File operation
```

### Cloud Processing

**When Used:**

- Low confidence (<70%) tasks
- Complex reasoning required
- Advanced text processing
- Multi-step workflows

**Examples:**

```swift
"analyze this document and provide insights"
"create a workflow for data processing"
"translate this text to multiple languages"
```

### Hybrid Processing

**When Used:**

- Moderate confidence (50-70%) tasks
- Tasks that benefit from both approaches
- Fallback scenarios

**Process:**

1. Attempt local processing first
2. If confidence is sufficient, use local result
3. Otherwise, fall back to cloud processing

## Caching Strategy

### Cache Keys

- SHA256 hash of normalized input
- Case-insensitive and whitespace-normalized

### TTL (Time To Live)

- Help content: 24 hours
- Calculations: 12 hours
- Text processing: 6 hours
- File operations: 30 minutes
- System queries: 5 minutes

### Eviction Policy

1. **Expired entries** removed first
2. **Memory pressure** triggers LRU eviction
3. **Cache size limits** enforce maximum entries

### Cache Exclusions

- Very large responses (>10KB)
- Time-sensitive data
- Personalized content
- Failed requests

## Error Handling & Fallbacks

### Fallback Strategies

1. **Local Only**: Force local processing, return helpful guidance
2. **Cloud Only**: Retry with cloud service, simplified parameters
3. **Graceful Degradation**: Provide alternative solutions and manual instructions
4. **Error Response**: User-friendly error with recovery suggestions

### Retry Logic

- Maximum 3 retry attempts
- Exponential backoff: 1s, 2s, 4s
- Different strategies per attempt

### Error Classification

```swift
enum TaskRoutingError {
    case cloudServiceUnavailable
    case rateLimitExceeded(waitTime: TimeInterval)
    case timeout
    case invalidCloudResponse
    case cacheError(String)
    case fallbackFailed
    case internalError(String)
}
```

## Performance Monitoring

### Routing Statistics

- Total requests and success rates
- Processing time metrics
- Route distribution (local/cloud/hybrid/cache)
- Cost and token usage tracking

### Health Monitoring

- Local processing health
- Cloud service availability
- Cache performance metrics
- Overall system status

## Usage Examples

### Basic Usage

```swift
let taskRouter = TaskRouter()

// Process user input
let result = try await taskRouter.processInput("what's my battery level")

print("Route: \(result.processingRoute)")
print("Success: \(result.success)")
print("Output: \(result.output)")
print("Cache Hit: \(result.cacheHit)")
```

### Advanced Configuration

```swift
let taskRouter = TaskRouter(
    taskClassifier: customClassifier,
    aiService: customAIService,
    rateLimiter: customRateLimiter,
    costTracker: customCostTracker
)

// Check system health
let health = await taskRouter.checkSystemHealth()
print("Overall Status: \(health.overallStatus)")

// Get performance statistics
let stats = taskRouter.getRoutingStatistics()
print("Success Rate: \(stats.successRate)")
print("Cache Hit Rate: \(stats.cacheHitRate)")
```

### Cache Management

```swift
// Clear cache
await taskRouter.clearCache()

// Get cache statistics
let cacheStats = taskRouter.getCacheStatistics()
print("Cache Size: \(cacheStats.cacheSize) bytes")
print("Hit Rate: \(cacheStats.hitRate)")
```

## Configuration

### Constants (in Constants.swift)

```swift
// Rate Limiting
static let maxRequestsPerMinute = 60
static let maxTokensPerMinute = 90000
static let rateLimitWindowSeconds: TimeInterval = 60

// Classification Thresholds
static let minimumConfidenceThreshold = 0.6
static let localProcessingThreshold = 0.8
static let confirmationRequiredThreshold = 0.9

// Execution Limits
static let maxExecutionTime: TimeInterval = 300.0
static let maxRetryAttempts = 3
```

### Cache Configuration

```swift
// Cache Limits
maxCacheSize: 1000 entries
defaultTTL: 3600 seconds (1 hour)
maxMemoryUsage: 50MB
```

## Testing

The system includes comprehensive tests covering:

- **Unit Tests**: Individual component functionality
- **Integration Tests**: End-to-end routing scenarios
- **Performance Tests**: Response time and throughput
- **Fallback Tests**: Error handling and recovery
- **Cache Tests**: Caching behavior and eviction

Run tests with:

```bash
xcodebuild test -project Sam.xcodeproj -scheme Sam -destination 'platform=macOS'
```

## Privacy & Security

### Local Processing Priority

- Privacy-sensitive tasks automatically use local processing
- No data sent to external services for local routes
- User control over cloud processing preferences

### Data Handling

- Input normalization removes sensitive patterns
- Cache entries exclude personal information
- Secure API key storage via Keychain Services

### Rate Limiting

- Prevents API abuse and cost overruns
- Graceful degradation when limits exceeded
- User notification of rate limit status

## Future Enhancements

### Planned Features

- **Machine Learning**: Adaptive routing based on user patterns
- **Custom Models**: Local AI model integration
- **Plugin System**: Extensible processing modules
- **Analytics**: Detailed usage and performance analytics

### Optimization Opportunities

- **Predictive Caching**: Pre-load likely responses
- **Batch Processing**: Group similar requests
- **Smart Prefetching**: Anticipate follow-up queries
- **Context Awareness**: Route based on conversation context

## Troubleshooting

### Common Issues

**High Cache Miss Rate**

- Check TTL settings for task types
- Verify input normalization
- Review cache exclusion rules

**Slow Response Times**

- Monitor cloud service latency
- Check rate limiting status
- Verify local processing health

**Frequent Fallbacks**

- Review confidence thresholds
- Check AI service availability
- Analyze error patterns

### Debug Mode

Enable verbose logging in debug builds:

```swift
#if DEBUG
struct DebugSettings {
    static let enableVerboseLogging = true
    static let enablePerformanceMonitoring = true
}
#endif
```

## Contributing

When contributing to the task routing system:

1. **Maintain backward compatibility** with existing interfaces
2. **Add comprehensive tests** for new functionality
3. **Update documentation** for API changes
4. **Consider performance impact** of modifications
5. **Follow privacy-first principles** in design decisions

## License

This code is part of the Sam AI Assistant project and follows the project's licensing terms.
