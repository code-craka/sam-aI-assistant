import Foundation
import SwiftUI

@MainActor
class WorkflowManager: ObservableObject {
    @Published var workflows: [Workflow] = []
    @Published var isExecutingWorkflow = false
    @Published var currentWorkflow: Workflow?
    @Published var currentStepIndex = 0
    @Published var executionProgress: Double = 0.0
    @Published var executionLog: [WorkflowExecutionLogEntry] = []
    
    private let taskManager = TaskManager()
    
    init() {
        loadWorkflows()
    }
    
    // MARK: - Public Methods
    
    func createWorkflow(from description: String) async throws -> Workflow {
        // TODO: Implement workflow creation from natural language
        // For now, create a simple placeholder workflow
        
        let workflow = Workflow(
            name: "Custom Workflow",
            description: description,
            steps: [],
            category: .automation,
            estimatedDuration: 30.0
        )
        
        workflows.append(workflow)
        saveWorkflows()
        
        return workflow
    }
    
    func executeWorkflow(_ workflow: Workflow) async throws {
        guard !isExecutingWorkflow else {
            throw WorkflowError.workflowAlreadyRunning
        }
        
        isExecutingWorkflow = true
        currentWorkflow = workflow
        currentStepIndex = 0
        executionProgress = 0.0
        executionLog.removeAll()
        
        defer {
            isExecutingWorkflow = false
            currentWorkflow = nil
            currentStepIndex = 0
            executionProgress = 0.0
        }
        
        do {
            logExecution("Starting workflow: \(workflow.name)", type: .info)
            
            for (index, step) in workflow.steps.enumerated() {
                currentStepIndex = index
                executionProgress = Double(index) / Double(workflow.steps.count)
                
                try await executeWorkflowStep(step, workflowId: workflow.id)
                
                // Update progress
                executionProgress = Double(index + 1) / Double(workflow.steps.count)
            }
            
            logExecution("Workflow completed successfully", type: .success)
            updateWorkflowExecutionCount(workflow.id)
            
        } catch {
            logExecution("Workflow failed: \(error.localizedDescription)", type: .error)
            throw error
        }
    }
    
    func cancelWorkflowExecution() {
        guard isExecutingWorkflow else { return }
        
        logExecution("Workflow execution cancelled by user", type: .warning)
        isExecutingWorkflow = false
        currentWorkflow = nil
        currentStepIndex = 0
        executionProgress = 0.0
    }
    
    func deleteWorkflow(_ workflow: Workflow) {
        workflows.removeAll { $0.id == workflow.id }
        saveWorkflows()
    }
    
    func duplicateWorkflow(_ workflow: Workflow) -> Workflow {
        let duplicatedWorkflow = Workflow(
            name: "\(workflow.name) Copy",
            description: workflow.description,
            steps: workflow.steps,
            category: workflow.category,
            estimatedDuration: workflow.estimatedDuration
        )
        
        workflows.append(duplicatedWorkflow)
        saveWorkflows()
        
        return duplicatedWorkflow
    }
    
    // MARK: - Private Methods
    
    private func executeWorkflowStep(_ step: WorkflowStep, workflowId: UUID) async throws {
        logExecution("Executing step: \(step.description)", type: .info)
        
        var retryCount = 0
        let maxRetries = step.retryCount
        
        while retryCount <= maxRetries {
            do {
                try await performStepExecution(step)
                logExecution("Step completed successfully", type: .success)
                return
                
            } catch {
                retryCount += 1
                
                if retryCount <= maxRetries {
                    logExecution("Step failed, retrying (\(retryCount)/\(maxRetries)): \(error.localizedDescription)", type: .warning)
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
                } else {
                    logExecution("Step failed after \(maxRetries) retries: \(error.localizedDescription)", type: .error)
                    
                    if step.continueOnError {
                        logExecution("Continuing workflow despite step failure", type: .warning)
                        return
                    } else {
                        throw error
                    }
                }
            }
        }
    }
    
    private func performStepExecution(_ step: WorkflowStep) async throws {
        switch step.type {
        case .fileOperation:
            try await executeFileOperationStep(step)
            
        case .systemCommand:
            try await executeSystemCommandStep(step)
            
        case .appIntegration:
            try await executeAppIntegrationStep(step)
            
        case .userInput:
            try await executeUserInputStep(step)
            
        case .conditional:
            try await executeConditionalStep(step)
            
        case .delay:
            try await executeDelayStep(step)
            
        case .notification:
            try await executeNotificationStep(step)
        }
    }
    
    private func executeFileOperationStep(_ step: WorkflowStep) async throws {
        // TODO: Implement file operation step execution
        logExecution("File operation: \(step.parameters)", type: .info)
    }
    
    private func executeSystemCommandStep(_ step: WorkflowStep) async throws {
        // TODO: Implement system command step execution
        logExecution("System command: \(step.parameters)", type: .info)
    }
    
    private func executeAppIntegrationStep(_ step: WorkflowStep) async throws {
        // TODO: Implement app integration step execution
        logExecution("App integration: \(step.parameters)", type: .info)
    }
    
    private func executeUserInputStep(_ step: WorkflowStep) async throws {
        // TODO: Implement user input step execution
        logExecution("User input required: \(step.description)", type: .info)
    }
    
    private func executeConditionalStep(_ step: WorkflowStep) async throws {
        // TODO: Implement conditional step execution
        logExecution("Conditional check: \(step.parameters)", type: .info)
    }
    
    private func executeDelayStep(_ step: WorkflowStep) async throws {
        guard let delayString = step.parameters["duration"],
              let delay = TimeInterval(delayString) else {
            throw WorkflowError.invalidStepParameters
        }
        
        logExecution("Waiting for \(delay) seconds", type: .info)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    private func executeNotificationStep(_ step: WorkflowStep) async throws {
        guard let message = step.parameters["message"] else {
            throw WorkflowError.invalidStepParameters
        }
        
        // TODO: Show system notification
        logExecution("Notification: \(message)", type: .info)
    }
    
    private func logExecution(_ message: String, type: WorkflowExecutionLogEntry.LogType) {
        let logEntry = WorkflowExecutionLogEntry(
            message: message,
            type: type,
            stepIndex: currentStepIndex
        )
        executionLog.append(logEntry)
    }
    
    private func loadWorkflows() {
        // TODO: Load workflows from Core Data
        // For now, create some sample workflows
        workflows = createSampleWorkflows()
    }
    
    private func saveWorkflows() {
        // TODO: Save workflows to Core Data
    }
    
    private func updateWorkflowExecutionCount(_ workflowId: UUID) {
        if let index = workflows.firstIndex(where: { $0.id == workflowId }) {
            let workflow = workflows[index]
            workflows[index] = Workflow(
                id: workflow.id,
                name: workflow.name,
                description: workflow.description,
                steps: workflow.steps,
                createdAt: workflow.createdAt,
                lastExecuted: Date(),
                executionCount: workflow.executionCount + 1,
                isEnabled: workflow.isEnabled,
                category: workflow.category,
                estimatedDuration: workflow.estimatedDuration
            )
            saveWorkflows()
        }
    }
    
    private func createSampleWorkflows() -> [Workflow] {
        let cleanupWorkflow = Workflow(
            name: "Daily Cleanup",
            description: "Clean up Downloads folder and empty trash",
            steps: [
                WorkflowStep(
                    type: .fileOperation,
                    parameters: ["action": "organize", "path": "~/Downloads"],
                    description: "Organize Downloads folder"
                ),
                WorkflowStep(
                    type: .systemCommand,
                    parameters: ["command": "empty_trash"],
                    description: "Empty trash"
                ),
                WorkflowStep(
                    type: .notification,
                    parameters: ["message": "Daily cleanup completed"],
                    description: "Show completion notification"
                )
            ],
            category: .automation,
            estimatedDuration: 60.0
        )
        
        let backupWorkflow = Workflow(
            name: "Document Backup",
            description: "Backup important documents to external drive",
            steps: [
                WorkflowStep(
                    type: .fileOperation,
                    parameters: ["action": "backup", "source": "~/Documents", "destination": "/Volumes/Backup"],
                    description: "Backup Documents folder"
                ),
                WorkflowStep(
                    type: .notification,
                    parameters: ["message": "Document backup completed"],
                    description: "Show completion notification"
                )
            ],
            category: .automation,
            estimatedDuration: 300.0
        )
        
        return [cleanupWorkflow, backupWorkflow]
    }
}

// MARK: - Supporting Types

struct WorkflowExecutionLogEntry: Identifiable {
    let id = UUID()
    let message: String
    let type: LogType
    let timestamp: Date
    let stepIndex: Int
    
    init(message: String, type: LogType, stepIndex: Int) {
        self.message = message
        self.type = type
        self.timestamp = Date()
        self.stepIndex = stepIndex
    }
    
    enum LogType {
        case info
        case success
        case warning
        case error
        
        var color: Color {
            switch self {
            case .info: return .primary
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }
}

enum WorkflowError: LocalizedError {
    case workflowAlreadyRunning
    case invalidStepParameters
    case stepExecutionFailed(String)
    case workflowNotFound
    
    var errorDescription: String? {
        switch self {
        case .workflowAlreadyRunning:
            return "A workflow is already running"
        case .invalidStepParameters:
            return "Invalid parameters for workflow step"
        case .stepExecutionFailed(let message):
            return "Step execution failed: \(message)"
        case .workflowNotFound:
            return "Workflow not found"
        }
    }
}