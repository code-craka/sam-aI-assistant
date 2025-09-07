import Foundation

// MARK: - Rate Limiter
actor RateLimiter {
    
    // MARK: - Private Properties
    private var requestTimestamps: [Date] = []
    private var tokenUsage: [(timestamp: Date, tokens: Int)] = []
    private let maxRequestsPerMinute: Int
    private let maxTokensPerMinute: Int
    private let windowDuration: TimeInterval
    
    // MARK: - Initialization
    init(
        maxRequestsPerMinute: Int = AIConstants.maxRequestsPerMinute,
        maxTokensPerMinute: Int = AIConstants.maxTokensPerMinute,
        windowDuration: TimeInterval = AIConstants.rateLimitWindowSeconds
    ) {
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.maxTokensPerMinute = maxTokensPerMinute
        self.windowDuration = windowDuration
    }
    
    // MARK: - Public Methods
    
    /// Check if request is within rate limits
    func checkRateLimit(estimatedTokens: Int = 1000) async throws {
        let now = Date()
        
        // Clean old entries
        cleanOldEntries(before: now.addingTimeInterval(-windowDuration))
        
        // Check request rate limit
        if requestTimestamps.count >= maxRequestsPerMinute {
            let oldestRequest = requestTimestamps.first!
            let waitTime = windowDuration - now.timeIntervalSince(oldestRequest)
            
            if waitTime > 0 {
                throw RateLimitError.requestLimitExceeded(waitTime: waitTime)
            }
        }
        
        // Check token rate limit
        let currentTokenUsage = tokenUsage.reduce(0) { $0 + $1.tokens }
        if currentTokenUsage + estimatedTokens > maxTokensPerMinute {
            let oldestTokenUsage = tokenUsage.first!
            let waitTime = windowDuration - now.timeIntervalSince(oldestTokenUsage.timestamp)
            
            if waitTime > 0 {
                throw RateLimitError.tokenLimitExceeded(waitTime: waitTime)
            }
        }
        
        // Record this request
        requestTimestamps.append(now)
        tokenUsage.append((timestamp: now, tokens: estimatedTokens))
    }
    
    /// Get current rate limit status
    func getCurrentStatus() -> RateLimitStatus {
        let now = Date()
        cleanOldEntries(before: now.addingTimeInterval(-windowDuration))
        
        let currentRequests = requestTimestamps.count
        let currentTokens = tokenUsage.reduce(0) { $0 + $1.tokens }
        
        return RateLimitStatus(
            requestsUsed: currentRequests,
            maxRequests: maxRequestsPerMinute,
            tokensUsed: currentTokens,
            maxTokens: maxTokensPerMinute,
            windowDuration: windowDuration,
            nextResetTime: getNextResetTime()
        )
    }
    
    /// Reset rate limiter
    func reset() {
        requestTimestamps.removeAll()
        tokenUsage.removeAll()
    }
    
    /// Get time until next available slot
    func getTimeUntilAvailable(estimatedTokens: Int = 1000) -> TimeInterval? {
        let now = Date()
        cleanOldEntries(before: now.addingTimeInterval(-windowDuration))
        
        var maxWaitTime: TimeInterval = 0
        
        // Check request limit
        if requestTimestamps.count >= maxRequestsPerMinute {
            if let oldestRequest = requestTimestamps.first {
                let requestWaitTime = windowDuration - now.timeIntervalSince(oldestRequest)
                maxWaitTime = max(maxWaitTime, requestWaitTime)
            }
        }
        
        // Check token limit
        let currentTokenUsage = tokenUsage.reduce(0) { $0 + $1.tokens }
        if currentTokenUsage + estimatedTokens > maxTokensPerMinute {
            if let oldestTokenUsage = tokenUsage.first {
                let tokenWaitTime = windowDuration - now.timeIntervalSince(oldestTokenUsage.timestamp)
                maxWaitTime = max(maxWaitTime, tokenWaitTime)
            }
        }
        
        return maxWaitTime > 0 ? maxWaitTime : nil
    }
}

// MARK: - Private Methods
private extension RateLimiter {
    
    func cleanOldEntries(before cutoffTime: Date) {
        requestTimestamps.removeAll { $0 < cutoffTime }
        tokenUsage.removeAll { $0.timestamp < cutoffTime }
    }
    
    func getNextResetTime() -> Date {
        let now = Date()
        
        var earliestResetTime = now
        
        if let oldestRequest = requestTimestamps.first {
            let requestResetTime = oldestRequest.addingTimeInterval(windowDuration)
            earliestResetTime = max(earliestResetTime, requestResetTime)
        }
        
        if let oldestTokenUsage = tokenUsage.first {
            let tokenResetTime = oldestTokenUsage.timestamp.addingTimeInterval(windowDuration)
            earliestResetTime = max(earliestResetTime, tokenResetTime)
        }
        
        return earliestResetTime
    }
}

// MARK: - Rate Limit Error
enum RateLimitError: LocalizedError {
    case requestLimitExceeded(waitTime: TimeInterval)
    case tokenLimitExceeded(waitTime: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .requestLimitExceeded(let waitTime):
            return "Request rate limit exceeded. Please wait \(Int(waitTime)) seconds."
        case .tokenLimitExceeded(let waitTime):
            return "Token rate limit exceeded. Please wait \(Int(waitTime)) seconds."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .requestLimitExceeded, .tokenLimitExceeded:
            return "Wait for the rate limit window to reset, or consider upgrading your API plan."
        }
    }
    
    var waitTime: TimeInterval {
        switch self {
        case .requestLimitExceeded(let time), .tokenLimitExceeded(let time):
            return time
        }
    }
}

// MARK: - Rate Limit Status
struct RateLimitStatus {
    let requestsUsed: Int
    let maxRequests: Int
    let tokensUsed: Int
    let maxTokens: Int
    let windowDuration: TimeInterval
    let nextResetTime: Date
    
    var requestsRemaining: Int {
        return max(0, maxRequests - requestsUsed)
    }
    
    var tokensRemaining: Int {
        return max(0, maxTokens - tokensUsed)
    }
    
    var requestUsagePercentage: Double {
        return Double(requestsUsed) / Double(maxRequests)
    }
    
    var tokenUsagePercentage: Double {
        return Double(tokensUsed) / Double(maxTokens)
    }
    
    var isNearLimit: Bool {
        return requestUsagePercentage > 0.8 || tokenUsagePercentage > 0.8
    }
    
    var timeUntilReset: TimeInterval {
        return max(0, nextResetTime.timeIntervalSinceNow)
    }
}