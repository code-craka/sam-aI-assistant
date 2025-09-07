import Foundation
import SwiftUI

@MainActor
class TaskManager: ObservableObject {
    @Published var isProcessingTask = false
    @Published var currentTask: ParsedCommand?
    @Published var taskHistory: [TaskResult] = []
    
    private let taskClassifier = TaskClassifier()
    private let fileSystemService = FileSystemService()
    private let systemService = SystemService()
    private let appIntegrationService = AppIntegrationService()
    
    // MARK: - Public Methods
    
    func processTask(_ input: String, context: ChatModels.ChatContext) async throws -> TaskResult {
        isProcessingTask = true
        currentTask = nil
        
        defer {
            isProcessingTask = false
            currentTask = nil
        }
        
        do {
            // Step 1: Classify the task
            let classification = await taskClassifier.classify(input)
            
            // Step 2: Parse the command
            let parsedCommand = ParsedCommand(
                originalText: input,
                intent: classification.taskType,
                parameters: classification.parameters,
                confidence: classification.confidence,
                requiresConfirmation: classification.requiresConfirmation
            )
            
            currentTask = parsedCommand
            
            // Step 3: Execute the task based on type
            let result = try await executeTask(parsedCommand, context: context)
            
            // Step 4: Store result in history
            taskHistory.append(result)
            
            return result
            
        } catch {
            let errorResult = TaskResult(
                success: false,
                output: "Failed to process task: \(error.localizedDescription)",
                errorMessage: error.localizedDescription
            )
            
            taskHistory.append(errorResult)
            throw error
        }
    }
    
    func retryLastTask() async throws -> TaskResult? {
        guard let lastTask = currentTask else {
            throw TaskManagerError.noTaskToRetry
        }
        
        // TODO: Get current context
        let context = ChatModels.ChatContext()
        return try await executeTask(lastTask, context: context)
    }
    
    func cancelCurrentTask() {
        // TODO: Implement task cancellation
        isProcessingTask = false
        currentTask = nil
    }
    
    // MARK: - Private Methods
    
    private func executeTask(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        let startTime = Date()
        
        // Check if task requires confirmation
        if command.requiresConfirmation {
            // TODO: Show confirmation dialog
            // For now, proceed with execution
        }
        
        let result: TaskResult
        
        switch command.intent {
        case .fileOperation:
            result = try await executeFileOperation(command, context: context)
            
        case .systemQuery:
            result = try await executeSystemQuery(command, context: context)
            
        case .appControl:
            result = try await executeAppControl(command, context: context)
            
        case .textProcessing:
            result = try await executeTextProcessing(command, context: context)
            
        case .calculation:
            result = try await executeCalculation(command, context: context)
            
        case .webQuery:
            result = try await executeWebQuery(command, context: context)
            
        case .automation:
            result = try await executeAutomation(command, context: context)
            
        case .settings:
            result = try await executeSettings(command, context: context)
            
        case .help:
            result = try await executeHelp(command, context: context)
            
        case .unknown:
            result = TaskResult(
                success: false,
                output: "I'm not sure how to help with that. Could you please rephrase your request?",
                errorMessage: "Unknown task type"
            )
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        return TaskResult(
            success: result.success,
            output: result.output,
            executionTime: executionTime,
            affectedFiles: result.affectedFiles,
            errorMessage: result.errorMessage,
            followUpSuggestions: result.followUpSuggestions,
            undoAction: result.undoAction
        )
    }
    
    // MARK: - Task Execution Methods
    
    private func executeFileOperation(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement file operations
        return TaskResult(
            success: true,
            output: "File operation completed successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like to see the affected files?", "Need help with another file operation?"]
        )
    }
    
    private func executeSystemQuery(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement system queries
        return TaskResult(
            success: true,
            output: "System information retrieved successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like more detailed information?", "Need help with system settings?"]
        )
    }
    
    private func executeAppControl(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement app control
        return TaskResult(
            success: true,
            output: "App control command executed successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like to control another app?", "Need help with app automation?"]
        )
    }
    
    private func executeTextProcessing(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement text processing
        return TaskResult(
            success: true,
            output: "Text processing completed successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like to process more text?", "Need help with formatting?"]
        )
    }
    
    private func executeCalculation(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement calculations
        return TaskResult(
            success: true,
            output: "Calculation completed successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like to perform another calculation?", "Need help with unit conversions?"]
        )
    }
    
    private func executeWebQuery(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement web queries
        return TaskResult(
            success: true,
            output: "Web query completed successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like to search for something else?", "Need help opening a website?"]
        )
    }
    
    private func executeAutomation(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement automation
        return TaskResult(
            success: true,
            output: "Automation task completed successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like to create a workflow?", "Need help with more automation?"]
        )
    }
    
    private func executeSettings(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        // TODO: Implement settings management
        return TaskResult(
            success: true,
            output: "Settings updated successfully. (Implementation pending)",
            followUpSuggestions: ["Would you like to modify other settings?", "Need help with preferences?"]
        )
    }
    
    private func executeHelp(_ command: ParsedCommand, context: ChatModels.ChatContext) async throws -> TaskResult {
        let helpText = generateHelpText(for: command.parameters["topic"])
        
        return TaskResult(
            success: true,
            output: helpText,
            followUpSuggestions: [
                "Would you like help with a specific feature?",
                "Need examples of what I can do?",
                "Want to see keyboard shortcuts?"
            ]
        )
    }
    
    private func generateHelpText(for topic: String?) -> String {
        if let topic = topic?.lowercased() {
            switch topic {
            case "files", "file":
                return """
                I can help you with file operations:
                • Copy, move, rename, and delete files
                • Organize folders by type or date
                • Search for files and folders
                • Extract metadata from documents and images
                
                Examples:
                • "Copy report.pdf to Desktop"
                • "Organize Downloads by file type"
                • "Find all PDFs in Documents"
                """
                
            case "system":
                return """
                I can provide system information:
                • Battery level and charging status
                • Storage space and usage
                • Memory usage and performance
                • Network status and connections
                • Running applications
                
                Examples:
                • "What's my battery level?"
                • "How much storage space do I have?"
                • "Show me memory usage"
                """
                
            case "apps", "applications":
                return """
                I can control applications:
                • Open and close applications
                • Send emails and create calendar events
                • Control Safari bookmarks and tabs
                • Automate tasks across multiple apps
                
                Examples:
                • "Open Safari and go to apple.com"
                • "Send email to john@example.com"
                • "Create calendar event for tomorrow at 2pm"
                """
                
            default:
                break
            }
        }
        
        return """
        I'm Sam, your macOS AI assistant. I can help you with:
        
        📁 File Operations
        • Copy, move, organize files and folders
        • Search and manage your documents
        
        💻 System Information
        • Check battery, storage, memory usage
        • Monitor network and app status
        
        🚀 App Control
        • Open apps and websites
        • Send emails and create events
        • Automate multi-app workflows
        
        🔧 Automation
        • Create custom workflows
        • Set up recurring tasks
        • Streamline repetitive actions
        
        Just ask me in natural language what you'd like me to do!
        """
    }
}

// MARK: - Supporting Types

enum TaskManagerError: LocalizedError {
    case noTaskToRetry
    case taskCancelled
    case invalidParameters
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noTaskToRetry:
            return "No task available to retry"
        case .taskCancelled:
            return "Task was cancelled by user"
        case .invalidParameters:
            return "Invalid parameters provided for task"
        case .permissionDenied:
            return "Permission denied for requested operation"
        }
    }
}

// MARK: - Placeholder Services

class SystemService {
    // TODO: Implement system information queries
}

class AppIntegrationService {
    // TODO: Implement app integration and control
}