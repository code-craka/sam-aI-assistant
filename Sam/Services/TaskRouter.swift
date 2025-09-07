import Foundation
import Combine

// MARK: - Task Router
/// Central routing system that determines whether tasks should be processed locally or in the cloud
/// Implements hybrid processing logic, fallback mechanisms, caching, and error handling
@MainActor
class TaskRouter: ObservableObject {
    
    // MARK: - Published Properties
    @Published var routingStats = RoutingStatistics()
    @Published var cacheStats = CacheStatistics()
    @Published var isProcessing = false
    
    // MARK: - Private Properties
    private let taskClassifier: TaskClassifier
    private let aiService: AIService
    private let rateLimiter: RateLimiter
    private let costTracker: CostTracker
    private let responseCache: ResponseCache
    private let fallbackManager: FallbackManager
    
    // Configuration
    private let confidenceThreshold: Double = 0.7
    private let maxRetryAttempts: Int = 3
    private let cloudTimeoutInterval: TimeInterval = 30.0
    
    // MARK: - Initialization
    init(
        taskClassifier: TaskClassifier = TaskClassifier(),
        aiService: AIService = AIService(),
        rateLimiter: RateLimiter = RateLimiter(),
        costTracker: CostTracker = CostTracker()
    ) {
        self.taskClassifier = taskClassifier
        self.aiService = aiService
        self.rateLimiter = rateLimiter
        self.costTracker = costTracker
        self.responseCache = ResponseCache()
        self.fallbackManager = FallbackManager()
    }
    
    // MARK: - Public Methods
    
    /// Route and process user input through the appropriate processing pipeline
    func processInput(_ input: String) async throws -> TaskProcessingResult {
        isProcessing = true
        defer { isProcessing = false }
        
        let startTime = Date()
        
        do {
            // 1. Check cache first
            if let cachedResult = await responseCache.getCachedResponse(for: input) {
                await updateRoutingStats(route: .cache, success: true, duration: Date().timeIntervalSince(startTime))
                return cachedResult
            }
            
            // 2. Classify the task
            let classification = await taskClassifier.classify(input)
            
            // 3. Determine processing route
            let route = determineProcessingRoute(for: classification)
            
            // 4. Process based on route
            let result: TaskProcessingResult
            
            switch route {
            case .local:
                result = try await processLocally(input: input, classification: classification)
                
            case .cloud:
                result = try await processInCloud(input: input, classification: classification)
                
            case .hybrid:
                result = try await processHybrid(input: input, classification: classification)
                
            case .cache:
                // This shouldn't happen as we already checked cache
                throw TaskRoutingError.internalError("Invalid cache route")
            }
            
            // 5. Cache successful results
            if result.success {
                await responseCache.cacheResponse(input: input, result: result)
            }
            
            // 6. Update statistics
            let duration = Date().timeIntervalSince(startTime)
            await updateRoutingStats(route: route, success: result.success, duration: duration)
            
            return result
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            await updateRoutingStats(route: .local, success: false, duration: duration)
            
            // Try fallback processing
            return try await handleProcessingFailure(input: input, error: error)
        }
    }
    
    /// Get current routing statistics
    func getRoutingStatistics() -> RoutingStatistics {
        return routingStats
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> CacheStatistics {
        return cacheStats
    }
    
    /// Clear response cache
    func clearCache() async {
        await responseCache.clearCache()
        cacheStats = CacheStatistics()
    }
    
    /// Reset routing statistics
    func resetStatistics() {
        routingStats = RoutingStatistics()
    }
    
    /// Check system health and availability
    func checkSystemHealth() async -> SystemHealthStatus {
        let localHealth = await checkLocalProcessingHealth()
        let cloudHealth = await checkCloudProcessingHealth()
        let cacheHealth = await responseCache.getHealthStatus()
        
        return SystemHealthStatus(
            localProcessing: localHealth,
            cloudProcessing: cloudHealth,
            responseCache: cacheHealth,
            overallStatus: determineOverallHealth(local: localHealth, cloud: cloudHealth, cache: cacheHealth)
        )
    }
}

// MARK: - Private Processing Methods
private extension TaskRouter {
    
    /// Process task using local classification and processing
    func processLocally(input: String, classification: TaskClassificationResult) async throws -> TaskProcessingResult {
        let startTime = Date()
        
        // Use local task classifier result
        let result = TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: true,
            output: generateLocalResponse(for: classification),
            executionTime: Date().timeIntervalSince(startTime),
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
        
        return result
    }
    
    /// Process task using cloud AI service
    func processInCloud(input: String, classification: TaskClassificationResult) async throws -> TaskProcessingResult {
        let startTime = Date()
        
        // Check rate limits
        try await rateLimiter.checkRateLimit(estimatedTokens: estimateTokensForInput(input))
        
        // Check if cloud service is available
        let isAvailable = await aiService.checkAvailability()
        if !isAvailable {
            throw TaskRoutingError.cloudServiceUnavailable
        }
        
        // Create messages for AI processing
        let messages = createMessagesForCloudProcessing(input: input, classification: classification)
        
        // Process with timeout
        let result = try await withTimeout(cloudTimeoutInterval) {
            try await self.aiService.generateCompletion(
                messages: messages,
                model: selectOptimalModel(for: classification),
                temperature: 0.3
            )
        }
        
        guard let choice = result.choices.first else {
            throw TaskRoutingError.invalidCloudResponse
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        let tokensUsed = result.usage?.totalTokens ?? 0
        let cost = costTracker.calculateCost(tokens: tokensUsed, model: selectOptimalModel(for: classification))
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .cloud,
            success: true,
            output: choice.message.content ?? "No response generated",
            executionTime: executionTime,
            tokensUsed: tokensUsed,
            cost: cost,
            cacheHit: false
        )
    }
    
    /// Process task using hybrid approach (local classification + cloud processing)
    func processHybrid(input: String, classification: TaskClassificationResult) async throws -> TaskProcessingResult {
        // Start with local processing attempt
        do {
            let localResult = try await processLocally(input: input, classification: classification)
            
            // If local processing confidence is high enough, use it
            if classification.confidence >= confidenceThreshold {
                return localResult
            }
        } catch {
            // Local processing failed, continue to cloud
        }
        
        // Fall back to cloud processing for better accuracy
        return try await processInCloud(input: input, classification: classification)
    }
    
    /// Handle processing failures with fallback mechanisms
    func handleProcessingFailure(input: String, error: Error) async throws -> TaskProcessingResult {
        let fallbackResult = await fallbackManager.handleFailure(input: input, error: error)
        
        if let result = fallbackResult {
            return result
        }
        
        // If all fallbacks fail, return error result
        return TaskProcessingResult(
            input: input,
            classification: TaskClassificationResult(taskType: .unknown, confidence: 0.0),
            processingRoute: .local,
            success: false,
            output: "I'm sorry, I couldn't process your request. Error: \(error.localizedDescription)",
            executionTime: 0,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false,
            error: error
        )
    }
}

// MARK: - Route Determination
private extension TaskRouter {
    
    /// Determine the optimal processing route based on classification and system state
    func determineProcessingRoute(for classification: TaskClassificationResult) -> ProcessingRoute {
        // Check if we have a cached response first
        if responseCache.hasCachedResponse(for: classification) {
            return .cache
        }
        
        // Use classification's suggested route as baseline
        var route = classification.processingRoute
        
        // Override based on system conditions
        if shouldForceLocal(classification: classification) {
            route = .local
        } else if shouldForceCloud(classification: classification) {
            route = .cloud
        }
        
        return route
    }
    
    /// Check if task should be forced to local processing
    func shouldForceLocal(classification: TaskClassificationResult) -> Bool {
        // Force local for high-confidence simple tasks
        if classification.confidence >= 0.9 && classification.complexity == .simple {
            return true
        }
        
        // Force local if cloud service is unavailable
        if !aiService.connectionStatus.isConnected {
            return true
        }
        
        // Force local if rate limits are exceeded
        let rateLimitStatus = Task { await rateLimiter.getCurrentStatus() }
        if let status = try? rateLimitStatus.result.get(), status.isNearLimit {
            return true
        }
        
        // Force local for privacy-sensitive tasks
        if isPrivacySensitive(classification: classification) {
            return true
        }
        
        return false
    }
    
    /// Check if task should be forced to cloud processing
    func shouldForceCloud(classification: TaskClassificationResult) -> Bool {
        // Force cloud for low-confidence complex tasks
        if classification.confidence < 0.5 && classification.complexity == .complex {
            return true
        }
        
        // Force cloud for tasks that require advanced reasoning
        if requiresAdvancedReasoning(classification: classification) {
            return true
        }
        
        return false
    }
    
    /// Check if task contains privacy-sensitive information
    func isPrivacySensitive(classification: TaskClassificationResult) -> Bool {
        let sensitiveKeywords = ["password", "credit card", "ssn", "personal", "private", "confidential"]
        let input = classification.parameters.values.joined(separator: " ").lowercased()
        
        return sensitiveKeywords.contains { input.contains($0) }
    }
    
    /// Check if task requires advanced reasoning capabilities
    func requiresAdvancedReasoning(classification: TaskClassificationResult) -> Bool {
        switch classification.taskType {
        case .textProcessing, .automation:
            return classification.complexity == .complex || classification.complexity == .advanced
        case .calculation:
            return classification.parameters.keys.contains("complex_math")
        default:
            return false
        }
    }
}

// MARK: - Helper Methods
private extension TaskRouter {
    
    func generateLocalResponse(for classification: TaskClassificationResult) -> String {
        switch classification.taskType {
        case .systemQuery:
            return "System information retrieved locally"
        case .fileOperation:
            return "File operation completed"
        case .appControl:
            return "Application control executed"
        case .calculation:
            return "Calculation performed"
        default:
            return "Task processed locally"
        }
    }
    
    func createMessagesForCloudProcessing(input: String, classification: TaskClassificationResult) -> [ChatModels.ChatMessage] {
        let systemMessage = ChatModels.ChatMessage(
            content: createSystemPrompt(for: classification),
            isUserMessage: false,
            timestamp: Date()
        )
        
        let userMessage = ChatModels.ChatMessage(
            content: input,
            isUserMessage: true,
            timestamp: Date()
        )
        
        return [systemMessage, userMessage]
    }
    
    func createSystemPrompt(for classification: TaskClassificationResult) -> String {
        let basePrompt = "You are Sam, a helpful macOS AI assistant. "
        
        switch classification.taskType {
        case .fileOperation:
            return basePrompt + "Help the user with file operations on their Mac. Provide clear, actionable instructions."
        case .systemQuery:
            return basePrompt + "Provide system information and help with macOS queries."
        case .appControl:
            return basePrompt + "Help control and interact with macOS applications."
        case .textProcessing:
            return basePrompt + "Help with text analysis, summarization, and processing tasks."
        case .automation:
            return basePrompt + "Help create and manage automated workflows on macOS."
        default:
            return basePrompt + "Provide helpful assistance with the user's request."
        }
    }
    
    func selectOptimalModel(for classification: TaskClassificationResult) -> AIModel {
        switch classification.complexity {
        case .simple:
            return .gpt35Turbo
        case .moderate:
            return .gpt4Turbo
        case .complex, .advanced:
            return .gpt4
        }
    }
    
    func estimateTokensForInput(_ input: String) -> Int {
        // Rough estimation: ~4 characters per token
        return max(100, input.count / 4)
    }
    
    func updateRoutingStats(route: ProcessingRoute, success: Bool, duration: TimeInterval) async {
        routingStats.totalRequests += 1
        routingStats.totalProcessingTime += duration
        
        switch route {
        case .local:
            routingStats.localRequests += 1
            if success { routingStats.localSuccesses += 1 }
        case .cloud:
            routingStats.cloudRequests += 1
            if success { routingStats.cloudSuccesses += 1 }
        case .hybrid:
            routingStats.hybridRequests += 1
            if success { routingStats.hybridSuccesses += 1 }
        case .cache:
            routingStats.cacheHits += 1
        }
        
        if success {
            routingStats.totalSuccesses += 1
        } else {
            routingStats.totalFailures += 1
        }
        
        routingStats.averageProcessingTime = routingStats.totalProcessingTime / Double(routingStats.totalRequests)
    }
    
    func checkLocalProcessingHealth() async -> HealthStatus {
        // Check if local classifier is working
        let testResult = await taskClassifier.quickClassify("test input")
        return testResult != nil ? .healthy : .degraded
    }
    
    func checkCloudProcessingHealth() async -> HealthStatus {
        let isAvailable = await aiService.checkAvailability()
        return isAvailable ? .healthy : .unhealthy
    }
    
    func determineOverallHealth(local: HealthStatus, cloud: HealthStatus, cache: HealthStatus) -> HealthStatus {
        if local == .healthy && (cloud == .healthy || cloud == .degraded) {
            return .healthy
        } else if local == .degraded || cloud == .degraded {
            return .degraded
        } else {
            return .unhealthy
        }
    }
}

// MARK: - Timeout Helper
private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TaskRoutingError.timeout
        }
        
        guard let result = try await group.next() else {
            throw TaskRoutingError.timeout
        }
        
        group.cancelAll()
        return result
    }
}