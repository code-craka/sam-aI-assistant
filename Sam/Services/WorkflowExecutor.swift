//
//  WorkflowExecutor.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import Combine

@MainActor
class WorkflowExecutor: ObservableObject {
    @Published var isExecuting = false
    @Published var currentExecution: WorkflowExecutionContext?
    @Published var executionHistory: [WorkflowExecutionResult] = []
    
    private let fileSystemService: FileSystemService
    private let appIntegrationManager: AppIntegrationManager
    private let systemService: SystemService
    private let taskRouter: TaskRouter
    
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?
    
    init(
        fileSystemService: FileSystemService = FileSystemService(),
        appIntegrationManager: AppIntegrationManager = AppIntegrationManager(),
        systemService: SystemService = SystemService(),
        taskRouter: TaskRouter = TaskRouter()
    ) {
        self.fileSystemService = fileSystemService
        self.appIntegrationManager = appIntegrationManager
        self.systemService = systemService
        self.taskRouter = taskRouter
    }
    
    // MARK: - Public Methods
    
    func executeWorkflow(_ workflow: WorkflowDefinition) async throws -> WorkflowExecutionResult {
        guard !isExecuting else {
            throw WorkflowError.executionContextMissing
        }
        
        isExecuting = true
        let context = WorkflowExecutionContext(workflowId: workflow.id)
        currentExecution = context
        
        // Initialize workflow variables
        for (key, value) in workflow.variables {
            context.setVariable(key, value: value.value)
        }
        
        context.isRunning = true
        var stepResults: [WorkflowStepResult] = []
        var completedSteps = 0
        
        defer {
            isExecuting = false
            currentExecution = nil
            context.isRunning = false
            context.endTime = Date()
        }
        
        do {
            for (index, step) in workflow.steps.enumerated() {
                context.currentStepIndex = index
                
                // Check if execution should continue
                if context.isPaused {
                    try await waitForResume(context)
                }
                
                // Evaluate step condition if present
                if let condition = step.condition {
                    let conditionMet = try await evaluateCondition(condition, context: context)
                    if !conditionMet {
                        let skipResult = WorkflowStepResult(
                            stepId: step.id,
                            stepName: step.name,
                            success: true,
                            startTime: Date(),
                            endTime: Date(),
                            output: "Step skipped - condition not met"
                        )
                        stepResults.append(skipResult)
                        continue
                    }
                }
                
                // Execute step with retry logic
                let stepResult = try await executeStepWithRetry(step, context: context)
                stepResults.append(stepResult)
                
                if stepResult.success {
                    completedSteps += 1
                } else if !step.continueOnError {
                    throw WorkflowError.stepExecutionFailed(stepName: step.name, error: NSError(domain: "WorkflowError", code: -1, userInfo: [NSLocalizedDescriptionKey: stepResult.error ?? "Unknown error"]))
                }
            }
            
            let result = WorkflowExecutionResult(
                executionId: context.executionId,
                workflowId: workflow.id,
                success: completedSteps == workflow.steps.count,
                startTime: context.startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(context.startTime),
                completedSteps: completedSteps,
                totalSteps: workflow.steps.count,
                error: nil,
                stepResults: stepResults,
                variables: context.variables.mapValues { AnyCodable($0) }
            )
            
            executionHistory.append(result)
            return result
            
        } catch {
            let result = WorkflowExecutionResult(
                executionId: context.executionId,
                workflowId: workflow.id,
                success: false,
                startTime: context.startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(context.startTime),
                completedSteps: completedSteps,
                totalSteps: workflow.steps.count,
                error: error.localizedDescription,
                stepResults: stepResults,
                variables: context.variables.mapValues { AnyCodable($0) }
            )
            
            executionHistory.append(result)
            throw error
        }
    }
    
    func pauseExecution() {
        currentExecution?.isPaused = true
    }
    
    func resumeExecution() {
        currentExecution?.isPaused = false
    }
    
    func cancelExecution() {
        currentTask?.cancel()
        currentExecution?.isRunning = false
        currentExecution?.error = WorkflowError.userCancelled
        isExecuting = false
    }
    
    // MARK: - Private Methods
    
    private func executeStepWithRetry(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> WorkflowStepResult {
        var lastError: Error?
        let maxRetries = max(0, step.retryCount)
        
        for attempt in 0...maxRetries {
            let startTime = Date()
            
            do {
                let result = try await executeStep(step, context: context, attempt: attempt)
                return WorkflowStepResult(
                    stepId: step.id,
                    stepName: step.name,
                    success: true,
                    startTime: startTime,
                    endTime: Date(),
                    output: result,
                    retryCount: attempt
                )
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    // Wait before retry with exponential backoff
                    let delay = min(pow(2.0, Double(attempt)), 30.0)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        return WorkflowStepResult(
            stepId: step.id,
            stepName: step.name,
            success: false,
            startTime: Date(),
            endTime: Date(),
            error: lastError?.localizedDescription ?? "Unknown error",
            retryCount: maxRetries
        )
    }
    
    private func executeStep(_ step: WorkflowStep, context: WorkflowExecutionContext, attempt: Int) async throws -> String {
        // Create timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(step.timeout * 1_000_000_000))
            throw WorkflowError.timeoutExceeded(stepName: step.name)
        }
        
        let executionTask = Task {
            switch step.type {
            case .fileOperation:
                return try await executeFileOperation(step, context: context)
            case .appControl:
                return try await executeAppControl(step, context: context)
            case .systemCommand:
                return try await executeSystemCommand(step, context: context)
            case .userInput:
                return try await executeUserInput(step, context: context)
            case .conditional:
                return try await executeConditional(step, context: context)
            case .delay:
                return try await executeDelay(step, context: context)
            case .textProcessing:
                return try await executeTextProcessing(step, context: context)
            case .notification:
                return try await executeNotification(step, context: context)
            }
        }
        
        // Race between execution and timeout
        let result = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await timeoutTask.value }
            group.addTask { try await executionTask.value }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
        
        return result
    }
    
    // MARK: - Step Execution Methods
    
    private func executeFileOperation(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let operation = step.parameters["operation"]?.value as? String else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "operation")
        }
        
        switch operation {
        case "copy":
            guard let source = step.parameters["source"]?.value as? String,
                  let destination = step.parameters["destination"]?.value as? String else {
                throw WorkflowError.invalidParameters(stepName: step.name, parameter: "source/destination")
            }
            
            let sourceURL = URL(fileURLWithPath: expandVariables(source, context: context))
            let destURL = URL(fileURLWithPath: expandVariables(destination, context: context))
            
            let result = try await fileSystemService.executeOperation(.copy(source: sourceURL, destination: destURL))
            return result.summary
            
        case "move":
            guard let source = step.parameters["source"]?.value as? String,
                  let destination = step.parameters["destination"]?.value as? String else {
                throw WorkflowError.invalidParameters(stepName: step.name, parameter: "source/destination")
            }
            
            let sourceURL = URL(fileURLWithPath: expandVariables(source, context: context))
            let destURL = URL(fileURLWithPath: expandVariables(destination, context: context))
            
            let result = try await fileSystemService.executeOperation(.move(source: sourceURL, destination: destURL))
            return result.summary
            
        case "delete":
            guard let files = step.parameters["files"]?.value as? [String] else {
                throw WorkflowError.invalidParameters(stepName: step.name, parameter: "files")
            }
            
            let fileURLs = files.map { URL(fileURLWithPath: expandVariables($0, context: context)) }
            let moveToTrash = step.parameters["moveToTrash"]?.value as? Bool ?? true
            
            let result = try await fileSystemService.executeOperation(.delete(files: fileURLs, moveToTrash: moveToTrash))
            return result.summary
            
        default:
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "operation")
        }
    }
    
    private func executeAppControl(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let command = step.parameters["command"]?.value as? String else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "command")
        }
        
        let expandedCommand = expandVariables(command, context: context)
        let result = try await appIntegrationManager.executeCommand(expandedCommand, targetApp: step.parameters["app"]?.value as? String)
        
        // Store result in context variables if specified
        if let outputVariable = step.parameters["outputVariable"]?.value as? String {
            context.setVariable(outputVariable, value: result.output)
        }
        
        return result.output
    }
    
    private func executeSystemCommand(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let query = step.parameters["query"]?.value as? String else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "query")
        }
        
        let expandedQuery = expandVariables(query, context: context)
        let result = try await systemService.handleQuery(expandedQuery)
        
        // Store result in context variables if specified
        if let outputVariable = step.parameters["outputVariable"]?.value as? String {
            context.setVariable(outputVariable, value: result)
        }
        
        return result
    }
    
    private func executeUserInput(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let prompt = step.parameters["prompt"]?.value as? String else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "prompt")
        }
        
        let expandedPrompt = expandVariables(prompt, context: context)
        
        // For now, we'll simulate user input - in a real implementation,
        // this would show a dialog or prompt to the user
        let userInput = step.parameters["defaultValue"]?.value as? String ?? ""
        
        // Store input in context variables if specified
        if let inputVariable = step.parameters["inputVariable"]?.value as? String {
            context.setVariable(inputVariable, value: userInput)
        }
        
        return "User input received: \(userInput)"
    }
    
    private func executeConditional(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let condition = step.condition else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "condition")
        }
        
        let conditionMet = try await evaluateCondition(condition, context: context)
        return "Condition evaluated: \(conditionMet)"
    }
    
    private func executeDelay(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let duration = step.parameters["duration"]?.value as? Double else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "duration")
        }
        
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        return "Delayed for \(duration) seconds"
    }
    
    private func executeTextProcessing(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let text = step.parameters["text"]?.value as? String,
              let operation = step.parameters["operation"]?.value as? String else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "text/operation")
        }
        
        let expandedText = expandVariables(text, context: context)
        
        let result: String
        switch operation {
        case "uppercase":
            result = expandedText.uppercased()
        case "lowercase":
            result = expandedText.lowercased()
        case "trim":
            result = expandedText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "length":
            result = "\(expandedText.count)"
        default:
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "operation")
        }
        
        // Store result in context variables if specified
        if let outputVariable = step.parameters["outputVariable"]?.value as? String {
            context.setVariable(outputVariable, value: result)
        }
        
        return result
    }
    
    private func executeNotification(_ step: WorkflowStep, context: WorkflowExecutionContext) async throws -> String {
        guard let title = step.parameters["title"]?.value as? String else {
            throw WorkflowError.invalidParameters(stepName: step.name, parameter: "title")
        }
        
        let message = step.parameters["message"]?.value as? String ?? ""
        let expandedTitle = expandVariables(title, context: context)
        let expandedMessage = expandVariables(message, context: context)
        
        // In a real implementation, this would show a system notification
        print("Notification: \(expandedTitle) - \(expandedMessage)")
        
        return "Notification sent: \(expandedTitle)"
    }
    
    // MARK: - Helper Methods
    
    private func evaluateCondition(_ condition: WorkflowCondition, context: WorkflowExecutionContext) async throws -> Bool {
        let variableValue = context.getVariable(condition.variable)
        let conditionValue = condition.value.value
        
        switch condition.type {
        case .equals:
            return isEqual(variableValue, conditionValue)
        case .notEquals:
            return !isEqual(variableValue, conditionValue)
        case .contains:
            if let stringValue = variableValue as? String,
               let searchString = conditionValue as? String {
                return stringValue.contains(searchString)
            }
            return false
        case .greaterThan:
            return isGreaterThan(variableValue, conditionValue)
        case .lessThan:
            return isLessThan(variableValue, conditionValue)
        case .fileExists:
            if let path = conditionValue as? String {
                let expandedPath = expandVariables(path, context: context)
                return FileManager.default.fileExists(atPath: expandedPath)
            }
            return false
        case .appRunning:
            if let appName = conditionValue as? String {
                return await systemService.isAppRunning(appName)
            }
            return false
        case .custom:
            // Custom condition evaluation would be implemented here
            return true
        }
    }
    
    private func isEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (let l as String, let r as String):
            return l == r
        case (let l as Int, let r as Int):
            return l == r
        case (let l as Double, let r as Double):
            return l == r
        case (let l as Bool, let r as Bool):
            return l == r
        default:
            return false
        }
    }
    
    private func isGreaterThan(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (let l as Int, let r as Int):
            return l > r
        case (let l as Double, let r as Double):
            return l > r
        case (let l as String, let r as String):
            return l > r
        default:
            return false
        }
    }
    
    private func isLessThan(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (let l as Int, let r as Int):
            return l < r
        case (let l as Double, let r as Double):
            return l < r
        case (let l as String, let r as String):
            return l < r
        default:
            return false
        }
    }
    
    private func expandVariables(_ text: String, context: WorkflowExecutionContext) -> String {
        var result = text
        
        // Replace variables in format ${variableName}
        let regex = try! NSRegularExpression(pattern: "\\$\\{([^}]+)\\}")
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches.reversed() {
            let variableRange = Range(match.range(at: 1), in: text)!
            let variableName = String(text[variableRange])
            
            if let value = context.getVariable(variableName) {
                let fullRange = Range(match.range, in: text)!
                result.replaceSubrange(fullRange, with: "\(value)")
            }
        }
        
        return result
    }
    
    private func waitForResume(_ context: WorkflowExecutionContext) async throws {
        while context.isPaused && context.isRunning {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if !context.isRunning {
            throw WorkflowError.userCancelled
        }
    }
}

// MARK: - SystemService Extension

extension SystemService {
    func isAppRunning(_ appName: String) async -> Bool {
        // This would check if an app is currently running
        // For now, return false as a placeholder
        return false
    }
}