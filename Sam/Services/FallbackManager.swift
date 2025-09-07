import Foundation

// MARK: - Fallback Manager
/// Manages fallback strategies when primary processing methods fail
/// Implements graceful degradation and alternative processing approaches
actor FallbackManager {
    
    // MARK: - Private Properties
    private let maxRetryAttempts: Int = 3
    private let retryDelays: [TimeInterval] = [1.0, 2.0, 4.0] // Exponential backoff
    private var failureHistory: [String: FailureRecord] = [:]
    private let fallbackStrategies: [TaskType: [FallbackStrategy]]
    
    // MARK: - Initialization
    init() {
        // Define fallback strategies for each task type
        self.fallbackStrategies = [
            .fileOperation: [.localOnly, .gracefulDegradation, .errorResponse],
            .systemQuery: [.localOnly, .gracefulDegradation, .errorResponse],
            .appControl: [.localOnly, .gracefulDegradation, .errorResponse],
            .textProcessing: [.cloudOnly, .gracefulDegradation, .errorResponse],
            .calculation: [.localOnly, .cloudOnly, .errorResponse],
            .webQuery: [.cloudOnly, .gracefulDegradation, .errorResponse],
            .automation: [.gracefulDegradation, .localOnly, .errorResponse],
            .settings: [.localOnly, .errorResponse],
            .help: [.localOnly, .errorResponse],
            .unknown: [.gracefulDegradation, .errorResponse]
        ]
    }
    
    // MARK: - Public Methods
    
    /// Handle processing failure and attempt fallback strategies
    func handleFailure(input: String, error: Error) async -> TaskProcessingResult? {
        let inputHash = hashInput(input)
        
        // Record failure
        recordFailure(inputHash: inputHash, error: error)
        
        // Get failure history for this input
        guard let failureRecord = failureHistory[inputHash] else {
            return nil
        }
        
        // If we've exceeded max retries, return nil
        if failureRecord.attemptCount >= maxRetryAttempts {
            return createFinalErrorResponse(input: input, error: error)
        }
        
        // Try to classify the input for fallback strategy selection
        let classification = await attemptBasicClassification(input)
        let strategies = fallbackStrategies[classification.taskType] ?? [.errorResponse]
        
        // Try each fallback strategy
        for strategy in strategies {
            if let result = await attemptFallbackStrategy(
                strategy: strategy,
                input: input,
                classification: classification,
                originalError: error
            ) {
                return result
            }
        }
        
        // All fallback strategies failed
        return createFinalErrorResponse(input: input, error: error)
    }
    
    /// Get failure statistics for monitoring
    func getFailureStatistics() async -> FailureStatistics {
        let totalFailures = failureHistory.values.reduce(0) { $0 + $1.attemptCount }
        let uniqueFailures = failureHistory.count
        let recentFailures = failureHistory.values.filter { 
            $0.lastFailure.timeIntervalSinceNow > -3600 // Last hour
        }.count
        
        let errorTypes = Dictionary(grouping: failureHistory.values) { record in
            type(of: record.lastError).self
        }.mapValues { $0.count }
        
        return FailureStatistics(
            totalFailures: totalFailures,
            uniqueFailures: uniqueFailures,
            recentFailures: recentFailures,
            errorTypeBreakdown: errorTypes.mapKeys { String(describing: $0) }
        )
    }
    
    /// Clear failure history
    func clearFailureHistory() async {
        failureHistory.removeAll()
    }
    
    /// Check if input has recent failures
    func hasRecentFailures(for input: String) async -> Bool {
        let inputHash = hashInput(input)
        guard let record = failureHistory[inputHash] else { return false }
        
        // Consider failures recent if they occurred in the last 10 minutes
        return record.lastFailure.timeIntervalSinceNow > -600
    }
}

// MARK: - Private Methods
private extension FallbackManager {
    
    func recordFailure(inputHash: String, error: Error) {
        if var existing = failureHistory[inputHash] {
            existing.attemptCount += 1
            existing.lastFailure = Date()
            existing.lastError = error
            failureHistory[inputHash] = existing
        } else {
            failureHistory[inputHash] = FailureRecord(
                inputHash: inputHash,
                firstFailure: Date(),
                lastFailure: Date(),
                attemptCount: 1,
                lastError: error
            )
        }
    }
    
    func attemptBasicClassification(_ input: String) async -> TaskClassificationResult {
        // Simple keyword-based classification for fallback scenarios
        let lowercaseInput = input.lowercased()
        
        if lowercaseInput.contains("battery") || lowercaseInput.contains("storage") || lowercaseInput.contains("memory") {
            return TaskClassificationResult(
                taskType: .systemQuery,
                confidence: 0.6,
                complexity: .simple,
                processingRoute: .local
            )
        }
        
        if lowercaseInput.contains("open") || lowercaseInput.contains("launch") || lowercaseInput.contains("close") {
            return TaskClassificationResult(
                taskType: .appControl,
                confidence: 0.6,
                complexity: .simple,
                processingRoute: .local
            )
        }
        
        if lowercaseInput.contains("copy") || lowercaseInput.contains("move") || lowercaseInput.contains("delete") {
            return TaskClassificationResult(
                taskType: .fileOperation,
                confidence: 0.6,
                complexity: .simple,
                processingRoute: .local
            )
        }
        
        if lowercaseInput.contains("help") || lowercaseInput.contains("how") {
            return TaskClassificationResult(
                taskType: .help,
                confidence: 0.7,
                complexity: .simple,
                processingRoute: .local
            )
        }
        
        return TaskClassificationResult(
            taskType: .unknown,
            confidence: 0.3,
            complexity: .simple,
            processingRoute: .local
        )
    }
    
    func attemptFallbackStrategy(
        strategy: FallbackStrategy,
        input: String,
        classification: TaskClassificationResult,
        originalError: Error
    ) async -> TaskProcessingResult? {
        
        switch strategy {
        case .localOnly:
            return await attemptLocalOnlyFallback(input: input, classification: classification)
            
        case .cloudOnly:
            return await attemptCloudOnlyFallback(input: input, classification: classification)
            
        case .gracefulDegradation:
            return await attemptGracefulDegradation(input: input, classification: classification, originalError: originalError)
            
        case .errorResponse:
            return createHelpfulErrorResponse(input: input, classification: classification, error: originalError)
        }
    }
    
    func attemptLocalOnlyFallback(input: String, classification: TaskClassificationResult) async -> TaskProcessingResult? {
        // Try to provide a basic local response
        switch classification.taskType {
        case .systemQuery:
            return createSystemQueryFallback(input: input, classification: classification)
            
        case .appControl:
            return createAppControlFallback(input: input, classification: classification)
            
        case .fileOperation:
            return createFileOperationFallback(input: input, classification: classification)
            
        case .help:
            return createHelpFallback(input: input, classification: classification)
            
        case .calculation:
            return createCalculationFallback(input: input, classification: classification)
            
        default:
            return nil
        }
    }
    
    func attemptCloudOnlyFallback(input: String, classification: TaskClassificationResult) async -> TaskProcessingResult? {
        // This would attempt cloud processing with reduced parameters
        // For now, return nil as this would require actual cloud service integration
        return nil
    }
    
    func attemptGracefulDegradation(
        input: String,
        classification: TaskClassificationResult,
        originalError: Error
    ) async -> TaskProcessingResult? {
        
        // Provide a degraded but helpful response
        let degradedOutput = createDegradedResponse(for: classification, originalError: originalError)
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: true,
            output: degradedOutput,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createDegradedResponse(for classification: TaskClassificationResult, originalError: Error) -> String {
        let baseMessage = "I encountered an issue processing your request, but I can still help. "
        
        switch classification.taskType {
        case .systemQuery:
            return baseMessage + "You can check system information manually through the Apple menu > About This Mac, or Activity Monitor for detailed system stats."
            
        case .fileOperation:
            return baseMessage + "You can perform file operations using Finder. For copying files, drag and drop or use Cmd+C and Cmd+V. For moving files, hold Option while dragging."
            
        case .appControl:
            return baseMessage + "You can open applications from the Applications folder, Spotlight (Cmd+Space), or Launchpad. To quit apps, use Cmd+Q."
            
        case .textProcessing:
            return baseMessage + "For text processing, you can use built-in macOS tools like TextEdit for basic editing, or Preview for PDF operations."
            
        case .webQuery:
            return baseMessage + "You can search the web using Safari or your preferred browser. Try opening Safari and using the search bar."
            
        case .automation:
            return baseMessage + "For automation tasks, consider using macOS Shortcuts app or Automator, which are built into your system."
            
        case .calculation:
            return baseMessage + "You can use the Calculator app (found in Applications/Utilities) or Spotlight for quick calculations."
            
        case .settings:
            return baseMessage + "You can access system settings through the Apple menu > System Preferences (or System Settings on newer macOS versions)."
            
        case .help:
            return "I'm Sam, your macOS AI assistant. I can help with file operations, system queries, app control, and more. Even when I encounter issues, I'll do my best to guide you to a solution."
            
        case .unknown:
            return baseMessage + "Could you please rephrase your request? I'm here to help with file operations, system information, app control, and various macOS tasks."
        }
    }
    
    func createHelpfulErrorResponse(
        input: String,
        classification: TaskClassificationResult,
        error: Error
    ) -> TaskProcessingResult {
        
        let errorMessage = createUserFriendlyErrorMessage(error: error, taskType: classification.taskType)
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: false,
            output: errorMessage,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false,
            error: error
        )
    }
    
    func createFinalErrorResponse(input: String, error: Error) -> TaskProcessingResult {
        let classification = TaskClassificationResult(taskType: .unknown, confidence: 0.0)
        
        let finalMessage = """
        I apologize, but I'm unable to process your request at the moment. This could be due to:
        
        • Temporary service issues
        • Network connectivity problems
        • System resource limitations
        
        Please try again in a few moments, or rephrase your request. If the problem persists, you can:
        • Check your internet connection
        • Restart the Sam application
        • Try a simpler version of your request
        
        I'm here to help once the issue is resolved!
        """
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: false,
            output: finalMessage,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false,
            error: error
        )
    }
    
    func createUserFriendlyErrorMessage(error: Error, taskType: TaskType) -> String {
        let baseMessage = "I encountered an issue: "
        
        if let routingError = error as? TaskRoutingError {
            switch routingError {
            case .cloudServiceUnavailable:
                return baseMessage + "The cloud AI service is temporarily unavailable. I'll try to help using local processing."
                
            case .rateLimitExceeded(let waitTime):
                return baseMessage + "I've reached the rate limit. Please wait \(Int(waitTime)) seconds before trying again."
                
            case .timeout:
                return baseMessage + "The request timed out. Please check your internet connection and try again."
                
            case .invalidCloudResponse:
                return baseMessage + "I received an unexpected response. Please try rephrasing your request."
                
            case .cacheError:
                return baseMessage + "There was a caching issue, but this shouldn't affect your request. Please try again."
                
            case .fallbackFailed:
                return baseMessage + "All processing methods failed. Please try a simpler request or restart the app."
                
            case .internalError:
                return baseMessage + "An internal error occurred. Please restart the app if this continues."
            }
        }
        
        return baseMessage + error.localizedDescription + ". Please try again or rephrase your request."
    }
    
    // MARK: - Specific Fallback Creators
    
    func createSystemQueryFallback(input: String, classification: TaskClassificationResult) -> TaskProcessingResult {
        let output = "I can help you check system information. You can find detailed system info in Apple menu > About This Mac, or use Activity Monitor for real-time stats."
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: true,
            output: output,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createAppControlFallback(input: String, classification: TaskClassificationResult) -> TaskProcessingResult {
        let output = "I can guide you with app control. Use Spotlight (Cmd+Space) to quickly open apps, or find them in the Applications folder. Use Cmd+Q to quit apps."
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: true,
            output: output,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createFileOperationFallback(input: String, classification: TaskClassificationResult) -> TaskProcessingResult {
        let output = "I can help with file operations. Use Finder for file management - drag and drop to move files, Cmd+C/Cmd+V to copy, or right-click for more options."
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: true,
            output: output,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createHelpFallback(input: String, classification: TaskClassificationResult) -> TaskProcessingResult {
        let output = """
        I'm Sam, your macOS AI assistant! I can help you with:
        
        • File operations (copy, move, organize files)
        • System information (battery, storage, memory)
        • App control (open, close applications)
        • Text processing and calculations
        • Automation and workflows
        
        Just tell me what you'd like to do in natural language!
        """
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: true,
            output: output,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createCalculationFallback(input: String, classification: TaskClassificationResult) -> TaskProcessingResult {
        let output = "I can help with calculations. For complex math, try the Calculator app or use Spotlight - just type your calculation and press Enter."
        
        return TaskProcessingResult(
            input: input,
            classification: classification,
            processingRoute: .local,
            success: true,
            output: output,
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func hashInput(_ input: String) -> String {
        return String(input.hash)
    }
}

// MARK: - Supporting Data Models

struct FailureRecord {
    let inputHash: String
    let firstFailure: Date
    var lastFailure: Date
    var attemptCount: Int
    var lastError: Error
}

struct FailureStatistics {
    let totalFailures: Int
    let uniqueFailures: Int
    let recentFailures: Int
    let errorTypeBreakdown: [String: Int]
}

// MARK: - Dictionary Extension
private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: self.map { (transform($0.key), $0.value) })
    }
}