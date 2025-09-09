import Foundation

// MARK: - Main Error Hierarchy
enum SamError: LocalizedError {
    case taskClassification(TaskClassificationError)
    case fileOperation(FileOperationError)
    case systemAccess(SystemAccessError)
    case appIntegration(AppIntegrationError)
    case aiService(AIServiceError)
    case workflow(WorkflowError)
    case network(NetworkError)
    case permission(PermissionError)
    case validation(ValidationError)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .taskClassification(let error):
            return "Task Classification Error: \(error.localizedDescription)"
        case .fileOperation(let error):
            return "File Operation Error: \(error.localizedDescription)"
        case .systemAccess(let error):
            return "System Access Error: \(error.localizedDescription)"
        case .appIntegration(let error):
            return "App Integration Error: \(error.localizedDescription)"
        case .aiService(let error):
            return "AI Service Error: \(error.localizedDescription)"
        case .workflow(let error):
            return "Workflow Error: \(error.localizedDescription)"
        case .network(let error):
            return "Network Error: \(error.localizedDescription)"
        case .permission(let error):
            return "Permission Error: \(error.localizedDescription)"
        case .validation(let error):
            return "Validation Error: \(error.localizedDescription)"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .taskClassification(let error):
            return error.recoverySuggestion
        case .fileOperation(let error):
            return error.recoverySuggestion
        case .systemAccess(let error):
            return error.recoverySuggestion
        case .appIntegration(let error):
            return error.recoverySuggestion
        case .aiService(let error):
            return error.recoverySuggestion
        case .workflow(let error):
            return error.recoverySuggestion
        case .network(let error):
            return error.recoverySuggestion
        case .permission(let error):
            return error.recoverySuggestion
        case .validation(let error):
            return error.recoverySuggestion
        case .unknown:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .taskClassification(let error):
            return error.failureReason
        case .fileOperation(let error):
            return error.failureReason
        case .systemAccess(let error):
            return error.failureReason
        case .appIntegration(let error):
            return error.failureReason
        case .aiService(let error):
            return error.failureReason
        case .workflow(let error):
            return error.failureReason
        case .network(let error):
            return error.failureReason
        case .permission(let error):
            return error.failureReason
        case .validation(let error):
            return error.failureReason
        case .unknown:
            return "An unexpected error occurred."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .taskClassification(let error):
            return error.isRecoverable
        case .fileOperation(let error):
            return error.isRecoverable
        case .systemAccess(let error):
            return error.isRecoverable
        case .appIntegration(let error):
            return error.isRecoverable
        case .aiService(let error):
            return error.isRecoverable
        case .workflow(let error):
            return error.isRecoverable
        case .network(let error):
            return error.isRecoverable
        case .permission(let error):
            return error.isRecoverable
        case .validation(let error):
            return error.isRecoverable
        case .unknown:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .taskClassification(let error):
            return error.severity
        case .fileOperation(let error):
            return error.severity
        case .systemAccess(let error):
            return error.severity
        case .appIntegration(let error):
            return error.severity
        case .aiService(let error):
            return error.severity
        case .workflow(let error):
            return error.severity
        case .network(let error):
            return error.severity
        case .permission(let error):
            return error.severity
        case .validation(let error):
            return error.severity
        case .unknown:
            return .high
        }
    }
}

// MARK: - Error Severity
enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var description: String {
        switch self {
        case .low:
            return "Low Priority"
        case .medium:
            return "Medium Priority"
        case .high:
            return "High Priority"
        case .critical:
            return "Critical"
        }
    }
}

// MARK: - Base Error Protocol
protocol SamErrorProtocol: LocalizedError {
    var isRecoverable: Bool { get }
    var severity: ErrorSeverity { get }
    var errorCode: String { get }
    var userInfo: [String: Any] { get }
}