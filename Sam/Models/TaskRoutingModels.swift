import Foundation

// MARK: - Task Processing Result
struct TaskProcessingResult: Codable {
    let input: String
    let classification: TaskClassificationResult
    let processingRoute: ProcessingRoute
    let success: Bool
    let output: String
    let executionTime: TimeInterval
    let tokensUsed: Int
    let cost: Double
    let cacheHit: Bool
    let error: TaskRoutingError?
    let timestamp: Date
    
    init(
        input: String,
        classification: TaskClassificationResult,
        processingRoute: ProcessingRoute,
        success: Bool,
        output: String,
        executionTime: TimeInterval,
        tokensUsed: Int,
        cost: Double,
        cacheHit: Bool,
        error: Error? = nil
    ) {
        self.input = input
        self.classification = classification
        self.processingRoute = processingRoute
        self.success = success
        self.output = output
        self.executionTime = executionTime
        self.tokensUsed = tokensUsed
        self.cost = cost
        self.cacheHit = cacheHit
        self.error = error as? TaskRoutingError
        self.timestamp = Date()
    }
}

// MARK: - Task Routing Error
enum TaskRoutingError: LocalizedError, Codable {
    case cloudServiceUnavailable
    case rateLimitExceeded(waitTime: TimeInterval)
    case timeout
    case invalidCloudResponse
    case cacheError(String)
    case fallbackFailed
    case internalError(String)
    
    var errorDescription: String? {
        switch self {
        case .cloudServiceUnavailable:
            return "Cloud AI service is currently unavailable"
        case .rateLimitExceeded(let waitTime):
            return "Rate limit exceeded. Please wait \(Int(waitTime)) seconds"
        case .timeout:
            return "Request timed out"
        case .invalidCloudResponse:
            return "Invalid response from cloud service"
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .fallbackFailed:
            return "All fallback mechanisms failed"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cloudServiceUnavailable:
            return "The system will attempt to process your request locally"
        case .rateLimitExceeded:
            return "Wait for the rate limit to reset or try a simpler request"
        case .timeout:
            return "Check your internet connection and try again"
        case .invalidCloudResponse:
            return "Try rephrasing your request"
        case .cacheError:
            return "Cache will be cleared automatically"
        case .fallbackFailed:
            return "Please try a different approach or contact support"
        case .internalError:
            return "Please restart the application if the problem persists"
        }
    }
}

// MARK: - Routing Statistics
struct RoutingStatistics: Codable {
    var totalRequests: Int = 0
    var totalSuccesses: Int = 0
    var totalFailures: Int = 0
    var totalProcessingTime: TimeInterval = 0
    var averageProcessingTime: TimeInterval = 0
    
    var localRequests: Int = 0
    var localSuccesses: Int = 0
    var cloudRequests: Int = 0
    var cloudSuccesses: Int = 0
    var hybridRequests: Int = 0
    var hybridSuccesses: Int = 0
    var cacheHits: Int = 0
    
    // Computed properties
    var successRate: Double {
        return totalRequests > 0 ? Double(totalSuccesses) / Double(totalRequests) : 0
    }
    
    var localSuccessRate: Double {
        return localRequests > 0 ? Double(localSuccesses) / Double(localRequests) : 0
    }
    
    var cloudSuccessRate: Double {
        return cloudRequests > 0 ? Double(cloudSuccesses) / Double(cloudRequests) : 0
    }
    
    var hybridSuccessRate: Double {
        return hybridRequests > 0 ? Double(hybridSuccesses) / Double(hybridRequests) : 0
    }
    
    var cacheHitRate: Double {
        return totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
    }
    
    var localProcessingPercentage: Double {
        return totalRequests > 0 ? Double(localRequests) / Double(totalRequests) : 0
    }
    
    var cloudProcessingPercentage: Double {
        return totalRequests > 0 ? Double(cloudRequests) / Double(totalRequests) : 0
    }
}

// MARK: - Cache Statistics
struct CacheStatistics: Codable {
    var totalEntries: Int = 0
    var totalHits: Int = 0
    var totalMisses: Int = 0
    var cacheSize: Int64 = 0 // in bytes
    var oldestEntry: Date?
    var newestEntry: Date?
    
    var hitRate: Double {
        let totalAccesses = totalHits + totalMisses
        return totalAccesses > 0 ? Double(totalHits) / Double(totalAccesses) : 0
    }
    
    var averageEntryAge: TimeInterval {
        guard let oldest = oldestEntry, let newest = newestEntry else { return 0 }
        return newest.timeIntervalSince(oldest) / Double(totalEntries)
    }
}

// MARK: - Health Status
enum HealthStatus: String, Codable {
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
    
    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .unhealthy: return "Unhealthy"
        }
    }
    
    var color: String {
        switch self {
        case .healthy: return "green"
        case .degraded: return "yellow"
        case .unhealthy: return "red"
        }
    }
}

// MARK: - System Health Status
struct SystemHealthStatus: Codable {
    let localProcessing: HealthStatus
    let cloudProcessing: HealthStatus
    let responseCache: HealthStatus
    let overallStatus: HealthStatus
    let timestamp: Date
    
    init(
        localProcessing: HealthStatus,
        cloudProcessing: HealthStatus,
        responseCache: HealthStatus,
        overallStatus: HealthStatus
    ) {
        self.localProcessing = localProcessing
        self.cloudProcessing = cloudProcessing
        self.responseCache = responseCache
        self.overallStatus = overallStatus
        self.timestamp = Date()
    }
}

// MARK: - Cache Entry
struct CacheEntry: Codable {
    let id: UUID
    let inputHash: String
    let result: TaskProcessingResult
    let createdAt: Date
    let accessCount: Int
    let lastAccessed: Date
    let expiresAt: Date
    
    init(inputHash: String, result: TaskProcessingResult, ttl: TimeInterval = 3600) {
        self.id = UUID()
        self.inputHash = inputHash
        self.result = result
        self.createdAt = Date()
        self.accessCount = 0
        self.lastAccessed = Date()
        self.expiresAt = Date().addingTimeInterval(ttl)
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
}

// MARK: - Fallback Strategy
enum FallbackStrategy: String, Codable, CaseIterable {
    case localOnly = "local_only"
    case cloudOnly = "cloud_only"
    case gracefulDegradation = "graceful_degradation"
    case errorResponse = "error_response"
    
    var displayName: String {
        switch self {
        case .localOnly: return "Local Processing Only"
        case .cloudOnly: return "Cloud Processing Only"
        case .gracefulDegradation: return "Graceful Degradation"
        case .errorResponse: return "Error Response"
        }
    }
    
    var description: String {
        switch self {
        case .localOnly:
            return "Always attempt local processing first, fall back to error if unavailable"
        case .cloudOnly:
            return "Always use cloud processing, fall back to error if unavailable"
        case .gracefulDegradation:
            return "Try optimal route, fall back to alternative processing methods"
        case .errorResponse:
            return "Return helpful error message when processing fails"
        }
    }
}

// MARK: - Processing Route Extensions
extension ProcessingRoute {
    var displayName: String {
        switch self {
        case .local: return "Local"
        case .cloud: return "Cloud"
        case .hybrid: return "Hybrid"
        }
    }
    
    var icon: String {
        switch self {
        case .local: return "desktopcomputer"
        case .cloud: return "icloud"
        case .hybrid: return "arrow.triangle.branch"
        }
    }
    
    var color: String {
        switch self {
        case .local: return "blue"
        case .cloud: return "purple"
        case .hybrid: return "orange"
        }
    }
}

// MARK: - Route Performance Metrics
struct RoutePerformanceMetrics: Codable {
    let route: ProcessingRoute
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var totalProcessingTime: TimeInterval = 0
    var totalTokensUsed: Int = 0
    var totalCost: Double = 0.0
    
    var successRate: Double {
        return totalRequests > 0 ? Double(successfulRequests) / Double(totalRequests) : 0
    }
    
    var averageProcessingTime: TimeInterval {
        return totalRequests > 0 ? totalProcessingTime / Double(totalRequests) : 0
    }
    
    var averageTokensPerRequest: Double {
        return totalRequests > 0 ? Double(totalTokensUsed) / Double(totalRequests) : 0
    }
    
    var averageCostPerRequest: Double {
        return totalRequests > 0 ? totalCost / Double(totalRequests) : 0
    }
    
    mutating func recordRequest(success: Bool, processingTime: TimeInterval, tokensUsed: Int, cost: Double) {
        totalRequests += 1
        if success {
            successfulRequests += 1
        } else {
            failedRequests += 1
        }
        totalProcessingTime += processingTime
        totalTokensUsed += tokensUsed
        totalCost += cost
    }
}