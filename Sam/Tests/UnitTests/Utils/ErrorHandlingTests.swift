import XCTest
@testable import Sam

@MainActor
class ErrorHandlingTests: XCTestCase {
    var errorHandlingService: ErrorHandlingService!
    var retryManager: RetryManager!
    var errorLogger: ErrorLogger!
    
    override func setUp() {
        super.setUp()
        errorHandlingService = ErrorHandlingService.shared
        retryManager = RetryManager()
        errorLogger = ErrorLogger.shared
    }
    
    override func tearDown() {
        errorHandlingService.dismissCurrentError()
        errorLogger.clearLogs()
        super.tearDown()
    }
    
    // MARK: - Error Hierarchy Tests
    
    func testSamErrorHierarchy() {
        let fileError = FileOperationError.fileNotFound(URL(fileURLWithPath: "/test/file.txt"))
        let samError = SamError.fileOperation(fileError)
        
        XCTAssertEqual(samError.errorDescription, "File Operation Error: File not found: file.txt")
        XCTAssertTrue(samError.isRecoverable)
        XCTAssertEqual(samError.severity, .low)
        XCTAssertNotNil(samError.recoverySuggestion)
    }
    
    func testTaskClassificationError() {
        let tcError = TaskClassificationError.lowConfidence(0.3)
        let samError = SamError.taskClassification(tcError)
        
        XCTAssertEqual(tcError.errorCode, "TC002")
        XCTAssertTrue(tcError.isRecoverable)
        XCTAssertEqual(tcError.severity, .low)
        XCTAssertEqual(tcError.userInfo["confidence"] as? Double, 0.3)
    }
    
    func testAIServiceError() {
        let aiError = AIServiceError.rateLimitExceeded(retryAfter: 60)
        let samError = SamError.aiService(aiError)
        
        XCTAssertEqual(aiError.errorCode, "AS003")
        XCTAssertTrue(aiError.isRecoverable)
        XCTAssertEqual(aiError.severity, .medium)
        XCTAssertEqual(aiError.userInfo["retryAfter"] as? TimeInterval, 60)
    }
    
    // MARK: - Error Handling Service Tests
    
    func testErrorHandling() {
        let error = SamError.fileOperation(.fileNotFound(URL(fileURLWithPath: "/test.txt")))
        
        errorHandlingService.handle(error, context: "Test context", showToUser: false)
        
        XCTAssertEqual(errorHandlingService.errorHistory.count, 1)
        XCTAssertEqual(errorHandlingService.errorHistory.first?.context, "Test context")
        XCTAssertFalse(errorHandlingService.errorHistory.first?.wasShownToUser ?? true)
    }
    
    func testErrorSuggestions() {
        let apiKeyError = SamError.aiService(.apiKeyMissing)
        let suggestions = errorHandlingService.getErrorSuggestions(for: apiKeyError)
        
        XCTAssertTrue(suggestions.contains { $0.action == .openSettings })
        XCTAssertTrue(suggestions.contains { $0.action == .getHelp })
    }
    
    func testErrorResolution() {
        let error = SamError.validation(.emptyInput)
        errorHandlingService.handle(error, context: "Test", showToUser: false)
        
        guard let errorId = errorHandlingService.errorHistory.first?.id else {
            XCTFail("Error not added to history")
            return
        }
        
        errorHandlingService.resolveError(errorId)
        
        XCTAssertTrue(errorHandlingService.errorHistory.first?.wasResolved ?? false)
    }
    
    // MARK: - Retry Manager Tests
    
    func testRetrySuccess() async {
        var attemptCount = 0
        
        let result = await retryManager.retry {
            attemptCount += 1
            if attemptCount < 2 {
                throw SamError.network(.connectionTimeout)
            }
            return "Success"
        }
        
        switch result {
        case .success(let value):
            XCTAssertEqual(value, "Success")
            XCTAssertEqual(attemptCount, 2)
        case .failure, .cancelled:
            XCTFail("Expected success")
        }
    }
    
    func testRetryFailure() async {
        let result = await retryManager.retry(maxAttempts: 2) {
            throw SamError.network(.connectionTimeout)
        }
        
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error, let attempts):
            XCTAssertEqual(attempts, 2)
            if case .network(.connectionTimeout) = error {
                // Expected
            } else {
                XCTFail("Unexpected error type")
            }
        case .cancelled:
            XCTFail("Expected failure, not cancellation")
        }
    }
    
    func testRetryConfiguration() {
        let config = RetryConfiguration.aggressive
        
        XCTAssertEqual(config.maxAttempts, 5)
        XCTAssertEqual(config.baseDelay, 0.5)
        XCTAssertEqual(config.backoffMultiplier, 1.5)
    }
    
    // MARK: - Error Logger Tests
    
    func testErrorLogging() {
        let error = SamError.systemAccess(.accessibilityPermissionDenied)
        
        errorLogger.log(error, category: "Test")
        
        XCTAssertTrue(errorLogger.recentErrors.count > 0)
        XCTAssertEqual(errorLogger.recentErrors.last?.category, "Test")
        XCTAssertEqual(errorLogger.recentErrors.last?.level, .error)
    }
    
    func testLogLevels() {
        errorLogger.debug("Debug message")
        errorLogger.info("Info message")
        errorLogger.warning("Warning message")
        errorLogger.error("Error message")
        errorLogger.critical("Critical message")
        
        let debugLogs = errorLogger.recentErrors.filter { $0.level == .debug }
        let criticalLogs = errorLogger.recentErrors.filter { $0.level == .critical }
        
        XCTAssertTrue(debugLogs.count > 0)
        XCTAssertTrue(criticalLogs.count > 0)
    }
    
    func testLogStatistics() {
        // Add some test errors
        for i in 0..<5 {
            errorLogger.error("Test error \(i)")
        }
        
        let stats = errorLogger.getLogStatistics()
        
        XCTAssertTrue(stats.totalErrors >= 5)
        XCTAssertEqual(stats.sessionId, errorLogger.sessionId)
    }
    
    // MARK: - Validation Error Tests
    
    func testValidationErrors() {
        let emptyInputError = ValidationError.emptyInput
        XCTAssertEqual(emptyInputError.errorCode, "VE001")
        XCTAssertTrue(emptyInputError.isRecoverable)
        
        let lengthError = ValidationError.lengthExceeded(field: "message", current: 1000, maximum: 500)
        XCTAssertEqual(lengthError.errorCode, "VE006")
        XCTAssertEqual(lengthError.userInfo["currentLength"] as? Int, 1000)
        XCTAssertEqual(lengthError.userInfo["maximumLength"] as? Int, 500)
    }
    
    func testPermissionErrors() {
        let accessibilityError = PermissionError.accessibilityNotGranted
        XCTAssertEqual(accessibilityError.errorCode, "PE001")
        XCTAssertEqual(accessibilityError.severity, .high)
        XCTAssertTrue(accessibilityError.isRecoverable)
        
        let automationError = PermissionError.automationNotGranted("Safari")
        XCTAssertEqual(automationError.userInfo["targetApp"] as? String, "Safari")
    }
    
    // MARK: - Network Error Tests
    
    func testNetworkErrors() {
        let noConnectionError = NetworkError.noConnection
        XCTAssertEqual(noConnectionError.errorCode, "NE001")
        XCTAssertEqual(noConnectionError.severity, .medium)
        XCTAssertTrue(noConnectionError.isRecoverable)
        
        let httpError = NetworkError.httpError(statusCode: 404, message: "Not Found")
        XCTAssertEqual(httpError.userInfo["statusCode"] as? Int, 404)
        XCTAssertEqual(httpError.userInfo["message"] as? String, "Not Found")
    }
    
    // MARK: - Performance Tests
    
    func testErrorHandlingPerformance() {
        measure {
            for i in 0..<100 {
                let error = SamError.validation(.emptyInput)
                errorHandlingService.handle(error, context: "Performance test \(i)", showToUser: false)
            }
        }
    }
    
    func testRetryPerformance() async {
        await measureAsync {
            let _ = await retryManager.retry {
                return "Success"
            }
        }
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    func measureAsync(_ block: @escaping () async -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Log the time for manual verification
        print("Async operation took \(timeElapsed) seconds")
    }
}