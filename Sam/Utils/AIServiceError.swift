import Foundation

// MARK: - AI Service Errors
enum AIServiceError: SamErrorProtocol {
    case apiKeyMissing
    case apiKeyInvalid
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case quotaExceeded
    case networkError(Error)
    case invalidResponse(String)
    case modelNotAvailable(String)
    case contextLengthExceeded(current: Int, maximum: Int)
    case tokenLimitExceeded(used: Int, limit: Int)
    case streamingFailed(String)
    case functionCallFailed(String)
    case responseParsingFailed(String)
    case timeoutError
    case serverError(statusCode: Int, message: String)
    case localModelLoadFailed(String)
    case costLimitExceeded(current: Double, limit: Double)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is missing"
        case .apiKeyInvalid:
            return "OpenAI API key is invalid"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
            } else {
                return "Rate limit exceeded"
            }
        case .quotaExceeded:
            return "API quota exceeded"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let response):
            return "Invalid API response: \(response)"
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available"
        case .contextLengthExceeded(let current, let maximum):
            return "Context length exceeded: \(current) tokens (maximum: \(maximum))"
        case .tokenLimitExceeded(let used, let limit):
            return "Token limit exceeded: \(used) tokens used (limit: \(limit))"
        case .streamingFailed(let reason):
            return "Streaming failed: \(reason)"
        case .functionCallFailed(let reason):
            return "Function call failed: \(reason)"
        case .responseParsingFailed(let reason):
            return "Response parsing failed: \(reason)"
        case .timeoutError:
            return "Request timed out"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .localModelLoadFailed(let reason):
            return "Local model loading failed: \(reason)"
        case .costLimitExceeded(let current, let limit):
            return "Cost limit exceeded: $\(String(format: "%.4f", current)) (limit: $\(String(format: "%.4f", limit)))"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .apiKeyMissing:
            return "Add your OpenAI API key in Settings > AI Configuration."
        case .apiKeyInvalid:
            return "Check your OpenAI API key in Settings and ensure it's correct and active."
        case .rateLimitExceeded:
            return "Wait a moment before trying again, or upgrade your OpenAI plan for higher limits."
        case .quotaExceeded:
            return "Check your OpenAI billing and usage limits. You may need to add credits or upgrade your plan."
        case .networkError:
            return "Check your internet connection and try again."
        case .invalidResponse:
            return "This may be a temporary API issue. Try again in a few moments."
        case .modelNotAvailable:
            return "Try using a different AI model in Settings, or check if the model is still supported."
        case .contextLengthExceeded:
            return "Try shortening your input or breaking it into smaller parts."
        case .tokenLimitExceeded:
            return "Reduce the length of your request or increase your token limit in Settings."
        case .streamingFailed:
            return "Try again with streaming disabled, or check your network connection."
        case .functionCallFailed:
            return "The AI function call encountered an error. Try rephrasing your request."
        case .responseParsingFailed:
            return "The AI response was malformed. Try asking your question differently."
        case .timeoutError:
            return "The request took too long. Try again or use a simpler query."
        case .serverError:
            return "OpenAI servers are experiencing issues. Try again later."
        case .localModelLoadFailed:
            return "Try restarting the app or check if you have sufficient system resources."
        case .costLimitExceeded:
            return "Increase your cost limit in Settings or wait for the limit to reset."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .apiKeyMissing:
            return "No API key has been configured for OpenAI services."
        case .apiKeyInvalid:
            return "The provided API key is not valid or has been revoked."
        case .rateLimitExceeded:
            return "Too many requests have been made in a short time period."
        case .quotaExceeded:
            return "The API usage quota has been exceeded for the current billing period."
        case .networkError:
            return "A network connectivity issue prevented the API request from completing."
        case .invalidResponse:
            return "The API returned a response that could not be processed."
        case .modelNotAvailable:
            return "The requested AI model is not available or has been deprecated."
        case .contextLengthExceeded:
            return "The input text exceeds the maximum context length for the selected model."
        case .tokenLimitExceeded:
            return "The request would exceed the configured token usage limit."
        case .streamingFailed:
            return "The streaming response connection was interrupted or failed."
        case .functionCallFailed:
            return "The AI attempted to call a function but the call failed."
        case .responseParsingFailed:
            return "The AI response could not be parsed into the expected format."
        case .timeoutError:
            return "The API request exceeded the maximum allowed time."
        case .serverError:
            return "The OpenAI API servers returned an error response."
        case .localModelLoadFailed:
            return "The local AI model could not be loaded or initialized."
        case .costLimitExceeded:
            return "The API usage cost has exceeded the configured spending limit."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .apiKeyMissing, .apiKeyInvalid:
            return true
        case .rateLimitExceeded, .quotaExceeded:
            return true
        case .networkError, .timeoutError:
            return true
        case .invalidResponse, .responseParsingFailed:
            return true
        case .modelNotAvailable:
            return true
        case .contextLengthExceeded, .tokenLimitExceeded:
            return true
        case .streamingFailed, .functionCallFailed:
            return true
        case .serverError:
            return true
        case .localModelLoadFailed:
            return false
        case .costLimitExceeded:
            return true
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .apiKeyMissing, .apiKeyInvalid:
            return .high
        case .rateLimitExceeded, .quotaExceeded:
            return .medium
        case .networkError, .timeoutError:
            return .medium
        case .invalidResponse, .responseParsingFailed:
            return .low
        case .modelNotAvailable:
            return .medium
        case .contextLengthExceeded, .tokenLimitExceeded:
            return .low
        case .streamingFailed, .functionCallFailed:
            return .low
        case .serverError:
            return .high
        case .localModelLoadFailed:
            return .high
        case .costLimitExceeded:
            return .medium
        }
    }
    
    var errorCode: String {
        switch self {
        case .apiKeyMissing:
            return "AS001"
        case .apiKeyInvalid:
            return "AS002"
        case .rateLimitExceeded:
            return "AS003"
        case .quotaExceeded:
            return "AS004"
        case .networkError:
            return "AS005"
        case .invalidResponse:
            return "AS006"
        case .modelNotAvailable:
            return "AS007"
        case .contextLengthExceeded:
            return "AS008"
        case .tokenLimitExceeded:
            return "AS009"
        case .streamingFailed:
            return "AS010"
        case .functionCallFailed:
            return "AS011"
        case .responseParsingFailed:
            return "AS012"
        case .timeoutError:
            return "AS013"
        case .serverError:
            return "AS014"
        case .localModelLoadFailed:
            return "AS015"
        case .costLimitExceeded:
            return "AS016"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                info["retryAfter"] = retryAfter
            }
        case .networkError(let error):
            info["underlyingError"] = error.localizedDescription
        case .invalidResponse(let response), .streamingFailed(let reason), .functionCallFailed(let reason), .responseParsingFailed(let reason), .localModelLoadFailed(let reason):
            info["details"] = response
        case .modelNotAvailable(let model):
            info["model"] = model
        case .contextLengthExceeded(let current, let maximum):
            info["currentLength"] = current
            info["maximumLength"] = maximum
        case .tokenLimitExceeded(let used, let limit):
            info["tokensUsed"] = used
            info["tokenLimit"] = limit
        case .serverError(let statusCode, let message):
            info["statusCode"] = statusCode
            info["message"] = message
        case .costLimitExceeded(let current, let limit):
            info["currentCost"] = current
            info["costLimit"] = limit
        default:
            break
        }
        
        return info
    }
}