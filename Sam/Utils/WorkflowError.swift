import Foundation

// MARK: - Workflow Errors
enum WorkflowError: SamErrorProtocol {
    case workflowNotFound(String)
    case invalidWorkflowDefinition(String)
    case stepExecutionFailed(stepIndex: Int, stepName: String, error: Error)
    case workflowCancelled
    case workflowTimeout(TimeInterval)
    case dependencyNotMet(String)
    case variableNotFound(String)
    case conditionalEvaluationFailed(String)
    case loopLimitExceeded(Int)
    case recursionLimitExceeded(Int)
    case workflowValidationFailed([String])
    case schedulingFailed(String)
    case concurrencyLimitExceeded(Int)
    
    var errorDescription: String? {
        switch self {
        case .workflowNotFound(let name):
            return "Workflow '\(name)' not found"
        case .invalidWorkflowDefinition(let reason):
            return "Invalid workflow definition: \(reason)"
        case .stepExecutionFailed(let stepIndex, let stepName, let error):
            return "Step \(stepIndex + 1) '\(stepName)' failed: \(error.localizedDescription)"
        case .workflowCancelled:
            return "Workflow execution was cancelled"
        case .workflowTimeout(let timeout):
            return "Workflow execution timed out after \(timeout) seconds"
        case .dependencyNotMet(let dependency):
            return "Workflow dependency not met: \(dependency)"
        case .variableNotFound(let variable):
            return "Workflow variable '\(variable)' not found"
        case .conditionalEvaluationFailed(let condition):
            return "Conditional evaluation failed: \(condition)"
        case .loopLimitExceeded(let limit):
            return "Loop limit exceeded: \(limit) iterations"
        case .recursionLimitExceeded(let limit):
            return "Recursion limit exceeded: \(limit) levels"
        case .workflowValidationFailed(let errors):
            return "Workflow validation failed: \(errors.joined(separator: ", "))"
        case .schedulingFailed(let reason):
            return "Workflow scheduling failed: \(reason)"
        case .concurrencyLimitExceeded(let limit):
            return "Concurrency limit exceeded: \(limit) concurrent workflows"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .workflowNotFound:
            return "Check the workflow name and ensure it exists in your saved workflows."
        case .invalidWorkflowDefinition:
            return "Review the workflow definition and fix any syntax or structure errors."
        case .stepExecutionFailed:
            return "Check the failed step configuration and ensure all required parameters are provided."
        case .workflowCancelled:
            return "The workflow was cancelled. You can restart it if needed."
        case .workflowTimeout:
            return "The workflow took too long to complete. Consider breaking it into smaller parts or increasing the timeout."
        case .dependencyNotMet:
            return "Ensure all required dependencies are available before running the workflow."
        case .variableNotFound:
            return "Define the missing variable or check the variable name for typos."
        case .conditionalEvaluationFailed:
            return "Review the conditional logic and ensure all referenced variables exist."
        case .loopLimitExceeded:
            return "Check your loop conditions to prevent infinite loops, or increase the loop limit if needed."
        case .recursionLimitExceeded:
            return "Reduce the recursion depth or restructure the workflow to avoid deep recursion."
        case .workflowValidationFailed:
            return "Fix the validation errors in your workflow definition before executing."
        case .schedulingFailed:
            return "Check the scheduling configuration and ensure the system has resources available."
        case .concurrencyLimitExceeded:
            return "Wait for other workflows to complete or increase the concurrency limit in settings."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .workflowNotFound:
            return "The specified workflow does not exist in the workflow registry."
        case .invalidWorkflowDefinition:
            return "The workflow definition contains syntax errors or invalid structure."
        case .stepExecutionFailed:
            return "A workflow step encountered an error during execution."
        case .workflowCancelled:
            return "The user or system cancelled the workflow execution."
        case .workflowTimeout:
            return "The workflow execution exceeded the maximum allowed time."
        case .dependencyNotMet:
            return "A required dependency for workflow execution is not available."
        case .variableNotFound:
            return "A referenced workflow variable has not been defined or initialized."
        case .conditionalEvaluationFailed:
            return "A conditional expression in the workflow could not be evaluated."
        case .loopLimitExceeded:
            return "A loop in the workflow exceeded the maximum iteration limit."
        case .recursionLimitExceeded:
            return "Recursive workflow calls exceeded the maximum depth limit."
        case .workflowValidationFailed:
            return "The workflow definition failed validation checks."
        case .schedulingFailed:
            return "The workflow could not be scheduled for execution."
        case .concurrencyLimitExceeded:
            return "Too many workflows are running concurrently."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .workflowNotFound, .invalidWorkflowDefinition:
            return true
        case .stepExecutionFailed:
            return true
        case .workflowCancelled:
            return true
        case .workflowTimeout:
            return true
        case .dependencyNotMet, .variableNotFound:
            return true
        case .conditionalEvaluationFailed:
            return true
        case .loopLimitExceeded, .recursionLimitExceeded:
            return false
        case .workflowValidationFailed:
            return true
        case .schedulingFailed:
            return true
        case .concurrencyLimitExceeded:
            return true
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .workflowNotFound, .invalidWorkflowDefinition:
            return .medium
        case .stepExecutionFailed:
            return .high
        case .workflowCancelled:
            return .low
        case .workflowTimeout:
            return .medium
        case .dependencyNotMet, .variableNotFound:
            return .medium
        case .conditionalEvaluationFailed:
            return .medium
        case .loopLimitExceeded, .recursionLimitExceeded:
            return .high
        case .workflowValidationFailed:
            return .medium
        case .schedulingFailed:
            return .high
        case .concurrencyLimitExceeded:
            return .medium
        }
    }
    
    var errorCode: String {
        switch self {
        case .workflowNotFound:
            return "WF001"
        case .invalidWorkflowDefinition:
            return "WF002"
        case .stepExecutionFailed:
            return "WF003"
        case .workflowCancelled:
            return "WF004"
        case .workflowTimeout:
            return "WF005"
        case .dependencyNotMet:
            return "WF006"
        case .variableNotFound:
            return "WF007"
        case .conditionalEvaluationFailed:
            return "WF008"
        case .loopLimitExceeded:
            return "WF009"
        case .recursionLimitExceeded:
            return "WF010"
        case .workflowValidationFailed:
            return "WF011"
        case .schedulingFailed:
            return "WF012"
        case .concurrencyLimitExceeded:
            return "WF013"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .workflowNotFound(let name):
            info["workflowName"] = name
        case .invalidWorkflowDefinition(let reason), .dependencyNotMet(let dependency), .variableNotFound(let variable), .conditionalEvaluationFailed(let condition), .schedulingFailed(let reason):
            info["details"] = reason
        case .stepExecutionFailed(let stepIndex, let stepName, let error):
            info["stepIndex"] = stepIndex
            info["stepName"] = stepName
            info["underlyingError"] = error.localizedDescription
        case .workflowTimeout(let timeout):
            info["timeout"] = timeout
        case .loopLimitExceeded(let limit), .recursionLimitExceeded(let limit), .concurrencyLimitExceeded(let limit):
            info["limit"] = limit
        case .workflowValidationFailed(let errors):
            info["validationErrors"] = errors
        case .workflowCancelled:
            break
        }
        
        return info
    }
}