import Foundation

// MARK: - Task Classification Errors
enum TaskClassificationError: SamErrorProtocol {
    case invalidInput(String)
    case lowConfidence(Double)
    case unsupportedTaskType(String)
    case parameterExtractionFailed(String)
    case modelLoadingFailed(String)
    case processingTimeout
    case contextTooLarge(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let input):
            return "Invalid input provided: '\(input)'"
        case .lowConfidence(let confidence):
            return "Task classification confidence too low: \(String(format: "%.2f", confidence * 100))%"
        case .unsupportedTaskType(let type):
            return "Unsupported task type: \(type)"
        case .parameterExtractionFailed(let reason):
            return "Failed to extract parameters: \(reason)"
        case .modelLoadingFailed(let reason):
            return "Failed to load classification model: \(reason)"
        case .processingTimeout:
            return "Task classification timed out"
        case .contextTooLarge(let size):
            return "Input context too large: \(size) characters"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidInput:
            return "Please provide a clear, specific command. Try rephrasing your request."
        case .lowConfidence:
            return "Your request was unclear. Please be more specific about what you want to do."
        case .unsupportedTaskType:
            return "This type of task is not yet supported. Try a different approach or check available commands."
        case .parameterExtractionFailed:
            return "Please provide more specific details like file names, paths, or app names."
        case .modelLoadingFailed:
            return "Restart the app or check if you have sufficient system resources available."
        case .processingTimeout:
            return "Try breaking down your request into smaller, simpler commands."
        case .contextTooLarge:
            return "Please shorten your input or break it into multiple smaller requests."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidInput:
            return "The input text could not be parsed or understood."
        case .lowConfidence:
            return "The classification model was not confident enough in its prediction."
        case .unsupportedTaskType:
            return "The requested task type is not implemented in the current version."
        case .parameterExtractionFailed:
            return "Required parameters could not be identified from the input."
        case .modelLoadingFailed:
            return "The local classification model failed to initialize."
        case .processingTimeout:
            return "Classification took longer than the allowed time limit."
        case .contextTooLarge:
            return "The input exceeds the maximum context size for processing."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .invalidInput, .lowConfidence, .parameterExtractionFailed, .contextTooLarge:
            return true
        case .unsupportedTaskType, .modelLoadingFailed, .processingTimeout:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .invalidInput, .lowConfidence, .parameterExtractionFailed:
            return .low
        case .unsupportedTaskType, .contextTooLarge:
            return .medium
        case .modelLoadingFailed, .processingTimeout:
            return .high
        }
    }
    
    var errorCode: String {
        switch self {
        case .invalidInput:
            return "TC001"
        case .lowConfidence:
            return "TC002"
        case .unsupportedTaskType:
            return "TC003"
        case .parameterExtractionFailed:
            return "TC004"
        case .modelLoadingFailed:
            return "TC005"
        case .processingTimeout:
            return "TC006"
        case .contextTooLarge:
            return "TC007"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .invalidInput(let input):
            info["input"] = input
        case .lowConfidence(let confidence):
            info["confidence"] = confidence
        case .unsupportedTaskType(let type):
            info["taskType"] = type
        case .parameterExtractionFailed(let reason):
            info["reason"] = reason
        case .modelLoadingFailed(let reason):
            info["reason"] = reason
        case .contextTooLarge(let size):
            info["contextSize"] = size
        case .processingTimeout:
            break
        }
        
        return info
    }
}