import Foundation

// MARK: - Retry Configuration
struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let jitterRange: ClosedRange<Double>
    let retryableErrors: [String] // Error codes that should trigger retry
    
    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        jitterRange: 0.8...1.2,
        retryableErrors: [
            // Network errors
            "NE001", "NE002", "NE003", "NE007",
            // AI Service errors
            "AS003", "AS005", "AS013", "AS014",
            // System access errors
            "SA005", "SA009", "SA010", "SA011",
            // File operation errors
            "FO007", "FO008", "FO011", "FO012"
        ]
    )
    
    static let aggressive = RetryConfiguration(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        backoffMultiplier: 1.5,
        jitterRange: 0.9...1.1,
        retryableErrors: RetryConfiguration.default.retryableErrors
    )
    
    static let conservative = RetryConfiguration(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 15.0,
        backoffMultiplier: 3.0,
        jitterRange: 0.7...1.3,
        retryableErrors: ["NE001", "NE002", "AS003", "AS013"]
    )
}

// MARK: - Retry Result
enum RetryResult<T> {
    case success(T)
    case failure(SamError, attempts: Int)
    case cancelled
}

// MARK: - Retry Manager
@MainActor
class RetryManager: ObservableObject {
    @Published var activeRetries: [String: RetryOperation] = [:]
    
    private let configuration: RetryConfiguration
    private var cancellationTokens: [String: Bool] = [:]
    
    init(configuration: RetryConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    func executeWithRetry<T>(
        id: String = UUID().uuidString,
        configuration: RetryConfiguration? = nil,
        operation: @escaping () async throws -> T
    ) async -> RetryResult<T> {
        let config = configuration ?? self.configuration
        let retryOperation = RetryOperation(
            id: id,
            maxAttempts: config.maxAttempts,
            currentAttempt: 0
        )
        
        activeRetries[id] = retryOperation
        cancellationTokens[id] = false
        
        defer {
            activeRetries.removeValue(forKey: id)
            cancellationTokens.removeValue(forKey: id)
        }
        
        var lastError: SamError?
        
        for attempt in 1...config.maxAttempts {
            // Check for cancellation
            if cancellationTokens[id] == true {
                return .cancelled
            }
            
            retryOperation.currentAttempt = attempt
            
            do {
                let result = try await operation()
                return .success(result)
            } catch let error as SamError {
                lastError = error
                
                // Check if error is retryable
                if !isRetryable(error: error, configuration: config) {
                    return .failure(error, attempts: attempt)
                }
                
                // Don't delay after the last attempt
                if attempt < config.maxAttempts {
                    let delay = calculateDelay(
                        attempt: attempt,
                        configuration: config
                    )
                    
                    retryOperation.nextRetryAt = Date().addingTimeInterval(delay)
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // Convert unknown errors to SamError
                let samError = SamError.unknown(error.localizedDescription)
                return .failure(samError, attempts: attempt)
            }
        }
        
        return .failure(lastError ?? SamError.unknown("Unknown error"), attempts: config.maxAttempts)
    }
    
    func cancelRetry(id: String) {
        cancellationTokens[id] = true
    }
    
    func cancelAllRetries() {
        for id in cancellationTokens.keys {
            cancellationTokens[id] = true
        }
    }
    
    // MARK: - Private Methods
    
    private func isRetryable(error: SamError, configuration: RetryConfiguration) -> Bool {
        let errorCode = getErrorCode(from: error)
        return configuration.retryableErrors.contains(errorCode)
    }
    
    private func getErrorCode(from error: SamError) -> String {
        switch error {
        case .taskClassification(let tcError):
            return tcError.errorCode
        case .fileOperation(let foError):
            return foError.errorCode
        case .systemAccess(let saError):
            return saError.errorCode
        case .appIntegration(let aiError):
            return aiError.errorCode
        case .aiService(let asError):
            return asError.errorCode
        case .workflow(let wfError):
            return wfError.errorCode
        case .network(let neError):
            return neError.errorCode
        case .permission(let peError):
            return peError.errorCode
        case .validation(let veError):
            return veError.errorCode
        case .unknown:
            return "UE001"
        }
    }
    
    private func calculateDelay(attempt: Int, configuration: RetryConfiguration) -> TimeInterval {
        let exponentialDelay = configuration.baseDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))
        let cappedDelay = min(exponentialDelay, configuration.maxDelay)
        
        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: configuration.jitterRange)
        return cappedDelay * jitter
    }
}

// MARK: - Retry Operation
class RetryOperation: ObservableObject, Identifiable {
    let id: String
    let maxAttempts: Int
    @Published var currentAttempt: Int
    @Published var nextRetryAt: Date?
    
    init(id: String, maxAttempts: Int, currentAttempt: Int) {
        self.id = id
        self.maxAttempts = maxAttempts
        self.currentAttempt = currentAttempt
    }
    
    var progress: Double {
        return Double(currentAttempt) / Double(maxAttempts)
    }
    
    var remainingAttempts: Int {
        return maxAttempts - currentAttempt
    }
}

// MARK: - Retry Extensions
extension RetryManager {
    // Convenience method for simple operations
    func retry<T>(
        _ operation: @escaping () async throws -> T,
        maxAttempts: Int = 3
    ) async -> RetryResult<T> {
        let config = RetryConfiguration(
            maxAttempts: maxAttempts,
            baseDelay: configuration.baseDelay,
            maxDelay: configuration.maxDelay,
            backoffMultiplier: configuration.backoffMultiplier,
            jitterRange: configuration.jitterRange,
            retryableErrors: configuration.retryableErrors
        )
        
        return await executeWithRetry(configuration: config, operation: operation)
    }
    
    // Retry with custom error handling
    func retryWithCustomErrorHandling<T>(
        retryableErrorCodes: [String],
        operation: @escaping () async throws -> T
    ) async -> RetryResult<T> {
        let config = RetryConfiguration(
            maxAttempts: configuration.maxAttempts,
            baseDelay: configuration.baseDelay,
            maxDelay: configuration.maxDelay,
            backoffMultiplier: configuration.backoffMultiplier,
            jitterRange: configuration.jitterRange,
            retryableErrors: retryableErrorCodes
        )
        
        return await executeWithRetry(configuration: config, operation: operation)
    }
}

// MARK: - Circuit Breaker Pattern
class CircuitBreaker: ObservableObject {
    enum State {
        case closed    // Normal operation
        case open      // Failing, reject requests
        case halfOpen  // Testing if service recovered
    }
    
    @Published var state: State = .closed
    @Published var failureCount: Int = 0
    @Published var lastFailureTime: Date?
    
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    private let successThreshold: Int
    private var successCount: Int = 0
    
    init(failureThreshold: Int = 5, recoveryTimeout: TimeInterval = 60, successThreshold: Int = 3) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
        self.successThreshold = successThreshold
    }
    
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > recoveryTimeout {
                state = .halfOpen
                successCount = 0
            } else {
                throw SamError.unknown("Circuit breaker is open")
            }
        case .halfOpen:
            break
        case .closed:
            break
        }
        
        do {
            let result = try await operation()
            onSuccess()
            return result
        } catch {
            onFailure()
            throw error
        }
    }
    
    private func onSuccess() {
        switch state {
        case .halfOpen:
            successCount += 1
            if successCount >= successThreshold {
                state = .closed
                failureCount = 0
                successCount = 0
            }
        case .closed:
            failureCount = 0
        case .open:
            break
        }
    }
    
    private func onFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold {
            state = .open
        }
    }
}