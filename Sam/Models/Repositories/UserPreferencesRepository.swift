import CoreData
import Foundation
import OSLog
import Combine

/// Repository for managing user preferences, shortcuts, and workflows
class UserPreferencesRepository: ObservableObject {
    private let persistenceController: PersistenceController
    private let logger = Logger(subsystem: "com.sam.assistant", category: "UserPreferencesRepository")
    
    @Published var currentPreferences: UserPreferences?
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        
        // Load preferences on initialization
        Task {
            await loadPreferences()
        }
    }
    
    // MARK: - User Preferences Management
    
    /// Load user preferences (creates default if none exist)
    @MainActor
    func loadPreferences() async {
        do {
            currentPreferences = try await getUserPreferences()
            logger.info("Loaded user preferences")
        } catch {
            logger.error("Failed to load user preferences: \(error.localizedDescription)")
        }
    }
    
    /// Get user preferences (creates default if none exist)
    func getUserPreferences() async throws -> UserPreferences {
        return try await persistenceController.performBackgroundTask { context in
            let request = UserPreferences.defaultRequest
            
            if let existing = try context.fetch(request).first {
                return existing
            } else {
                // Create default preferences
                let preferences = UserPreferences.createDefault(in: context)
                try self.persistenceController.saveBackground(context)
                self.logger.info("Created default user preferences")
                return preferences
            }
        }
    }
    
    /// Update user preferences
    func updatePreferences(_ preferences: UserPreferences) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = preferences.objectID
            guard let preferencesInContext = try? context.existingObject(with: objectID) as? UserPreferences else {
                throw UserPreferencesRepositoryError.preferencesNotFound
            }
            
            try self.persistenceController.saveBackground(context)
            self.logger.info("Updated user preferences")
        }
        
        // Update published property on main thread
        await MainActor.run {
            self.currentPreferences = preferences
        }
    }
    
    /// Reset preferences to defaults
    func resetToDefaults() async throws {
        guard let preferences = currentPreferences else {
            throw UserPreferencesRepositoryError.preferencesNotFound
        }
        
        try await persistenceController.performBackgroundTask { context in
            let objectID = preferences.objectID
            guard let preferencesInContext = try? context.existingObject(with: objectID) as? UserPreferences else {
                throw UserPreferencesRepositoryError.preferencesNotFound
            }
            
            preferencesInContext.resetToDefaults()
            try self.persistenceController.saveBackground(context)
            self.logger.info("Reset user preferences to defaults")
        }
        
        await loadPreferences()
    }
    
    // MARK: - Task Shortcuts Management
    
    /// Get all shortcuts
    func getAllShortcuts() async throws -> [TaskShortcut] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskShortcut.usageCount, ascending: false)]
            return try context.fetch(request)
        }
    }
    
    /// Get enabled shortcuts
    func getEnabledShortcuts() async throws -> [TaskShortcut] {
        return try await persistenceController.performBackgroundTask { context in
            let request = TaskShortcut.enabledShortcutsRequest
            return try context.fetch(request)
        }
    }
    
    /// Get shortcuts by category
    func getShortcuts(category: TaskType) async throws -> [TaskShortcut] {
        return try await persistenceController.performBackgroundTask { context in
            let request = TaskShortcut.fetchRequest(category: category)
            return try context.fetch(request)
        }
    }
    
    /// Get shortcuts with keyboard shortcuts
    func getKeyboardShortcuts() async throws -> [TaskShortcut] {
        return try await persistenceController.performBackgroundTask { context in
            let request = TaskShortcut.keyboardShortcutsRequest
            return try context.fetch(request)
        }
    }
    
    /// Search shortcuts
    func searchShortcuts(term: String) async throws -> [TaskShortcut] {
        return try await persistenceController.performBackgroundTask { context in
            let request = TaskShortcut.searchRequest(term: term)
            return try context.fetch(request)
        }
    }
    
    /// Create a new shortcut
    func createShortcut(
        name: String,
        command: String,
        category: TaskType,
        keyboardShortcut: String? = nil
    ) async throws -> TaskShortcut {
        guard let preferences = currentPreferences else {
            throw UserPreferencesRepositoryError.preferencesNotFound
        }
        
        return try await persistenceController.performBackgroundTask { context in
            let preferencesObjectID = preferences.objectID
            guard let preferencesInContext = try? context.existingObject(with: preferencesObjectID) as? UserPreferences else {
                throw UserPreferencesRepositoryError.preferencesNotFound
            }
            
            let shortcut = TaskShortcut.createShortcut(
                name: name,
                command: command,
                category: category,
                keyboardShortcut: keyboardShortcut,
                in: context
            )
            
            preferencesInContext.addShortcut(shortcut)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Created new shortcut: \(shortcut.name)")
            return shortcut
        }
    }
    
    /// Update shortcut
    func updateShortcut(_ shortcut: TaskShortcut) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = shortcut.objectID
            guard let shortcutInContext = try? context.existingObject(with: objectID) as? TaskShortcut else {
                throw UserPreferencesRepositoryError.shortcutNotFound
            }
            
            try self.persistenceController.saveBackground(context)
            self.logger.info("Updated shortcut: \(shortcutInContext.name)")
        }
    }
    
    /// Delete shortcut
    func deleteShortcut(_ shortcut: TaskShortcut) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = shortcut.objectID
            guard let shortcutInContext = try? context.existingObject(with: objectID) as? TaskShortcut else {
                throw UserPreferencesRepositoryError.shortcutNotFound
            }
            
            context.delete(shortcutInContext)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Deleted shortcut: \(shortcut.name)")
        }
    }
    
    /// Increment shortcut usage
    func incrementShortcutUsage(_ shortcut: TaskShortcut) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = shortcut.objectID
            guard let shortcutInContext = try? context.existingObject(with: objectID) as? TaskShortcut else {
                throw UserPreferencesRepositoryError.shortcutNotFound
            }
            
            shortcutInContext.incrementUsage()
            try self.persistenceController.saveBackground(context)
            self.logger.debug("Incremented usage for shortcut: \(shortcutInContext.name)")
        }
    }
    
    // MARK: - Workflow Management
    
    /// Get all workflows
    func getAllWorkflows() async throws -> [Workflow] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Workflow.lastExecuted, ascending: false)]
            return try context.fetch(request)
        }
    }
    
    /// Get enabled workflows
    func getEnabledWorkflows() async throws -> [Workflow] {
        return try await persistenceController.performBackgroundTask { context in
            let request = Workflow.enabledWorkflowsRequest
            return try context.fetch(request)
        }
    }
    
    /// Get workflows by category
    func getWorkflows(category: TaskType) async throws -> [Workflow] {
        return try await persistenceController.performBackgroundTask { context in
            let request = Workflow.fetchRequest(category: category)
            return try context.fetch(request)
        }
    }
    
    /// Search workflows
    func searchWorkflows(term: String) async throws -> [Workflow] {
        return try await persistenceController.performBackgroundTask { context in
            let request = Workflow.searchRequest(term: term)
            return try context.fetch(request)
        }
    }
    
    /// Create a new workflow
    func createWorkflow(
        name: String,
        description: String,
        category: TaskType = .automation,
        steps: [WorkflowStep] = []
    ) async throws -> Workflow {
        guard let preferences = currentPreferences else {
            throw UserPreferencesRepositoryError.preferencesNotFound
        }
        
        return try await persistenceController.performBackgroundTask { context in
            let preferencesObjectID = preferences.objectID
            guard let preferencesInContext = try? context.existingObject(with: preferencesObjectID) as? UserPreferences else {
                throw UserPreferencesRepositoryError.preferencesNotFound
            }
            
            let workflow = Workflow.createWorkflow(
                name: name,
                description: description,
                category: category,
                steps: steps,
                in: context
            )
            
            preferencesInContext.addWorkflow(workflow)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Created new workflow: \(workflow.name)")
            return workflow
        }
    }
    
    /// Update workflow
    func updateWorkflow(_ workflow: Workflow) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = workflow.objectID
            guard let workflowInContext = try? context.existingObject(with: objectID) as? Workflow else {
                throw UserPreferencesRepositoryError.workflowNotFound
            }
            
            try self.persistenceController.saveBackground(context)
            self.logger.info("Updated workflow: \(workflowInContext.name)")
        }
    }
    
    /// Delete workflow
    func deleteWorkflow(_ workflow: Workflow) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = workflow.objectID
            guard let workflowInContext = try? context.existingObject(with: objectID) as? Workflow else {
                throw UserPreferencesRepositoryError.workflowNotFound
            }
            
            context.delete(workflowInContext)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Deleted workflow: \(workflow.name)")
        }
    }
    
    /// Record workflow execution
    func recordWorkflowExecution(_ workflow: Workflow) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = workflow.objectID
            guard let workflowInContext = try? context.existingObject(with: objectID) as? Workflow else {
                throw UserPreferencesRepositoryError.workflowNotFound
            }
            
            workflowInContext.recordExecution()
            try self.persistenceController.saveBackground(context)
            self.logger.info("Recorded execution for workflow: \(workflowInContext.name)")
        }
    }
    
    // MARK: - Statistics
    
    /// Get user preferences statistics
    func getPreferencesStatistics() async throws -> PreferencesStatistics {
        return try await persistenceController.performBackgroundTask { context in
            // Total shortcuts
            let shortcutRequest: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
            let totalShortcuts = try context.count(for: shortcutRequest)
            
            // Enabled shortcuts
            let enabledShortcutRequest = TaskShortcut.enabledShortcutsRequest
            let enabledShortcuts = try context.count(for: enabledShortcutRequest)
            
            // Total workflows
            let workflowRequest: NSFetchRequest<Workflow> = Workflow.fetchRequest()
            let totalWorkflows = try context.count(for: workflowRequest)
            
            // Enabled workflows
            let enabledWorkflowRequest = Workflow.enabledWorkflowsRequest
            let enabledWorkflows = try context.count(for: enabledWorkflowRequest)
            
            // Most used shortcut
            let mostUsedShortcutRequest = TaskShortcut.frequentlyUsedRequest
            mostUsedShortcutRequest.fetchLimit = 1
            let mostUsedShortcut = try context.fetch(mostUsedShortcutRequest).first
            
            // Most executed workflow
            let mostExecutedWorkflowRequest = Workflow.frequentlyExecutedRequest
            mostExecutedWorkflowRequest.fetchLimit = 1
            let mostExecutedWorkflow = try context.fetch(mostExecutedWorkflowRequest).first
            
            return PreferencesStatistics(
                totalShortcuts: totalShortcuts,
                enabledShortcuts: enabledShortcuts,
                totalWorkflows: totalWorkflows,
                enabledWorkflows: enabledWorkflows,
                mostUsedShortcut: mostUsedShortcut,
                mostExecutedWorkflow: mostExecutedWorkflow
            )
        }
    }
}

// MARK: - Preferences Statistics
struct PreferencesStatistics {
    let totalShortcuts: Int
    let enabledShortcuts: Int
    let totalWorkflows: Int
    let enabledWorkflows: Int
    let mostUsedShortcut: TaskShortcut?
    let mostExecutedWorkflow: Workflow?
}

// MARK: - Repository Errors
enum UserPreferencesRepositoryError: LocalizedError {
    case preferencesNotFound
    case shortcutNotFound
    case workflowNotFound
    case invalidData
    case saveError(Error)
    
    var errorDescription: String? {
        switch self {
        case .preferencesNotFound:
            return "User preferences not found"
        case .shortcutNotFound:
            return "Task shortcut not found"
        case .workflowNotFound:
            return "Workflow not found"
        case .invalidData:
            return "Invalid data provided"
        case .saveError(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}