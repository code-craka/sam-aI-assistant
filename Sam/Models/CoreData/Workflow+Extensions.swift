import CoreData
import Foundation

// MARK: - Workflow Extensions
extension Workflow {
    
    /// Computed property for category enum
    var workflowCategory: TaskType {
        get {
            return TaskType(rawValue: category) ?? .automation
        }
        set {
            category = newValue.rawValue
        }
    }
    
    /// Computed property for workflow steps
    var steps: [WorkflowStep] {
        get {
            guard let data = stepsData,
                  let steps = try? JSONDecoder().decode([WorkflowStep].self, from: data) else {
                return []
            }
            return steps
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                stepsData = data
            }
        }
    }
    
    /// Formatted creation date
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Formatted last executed date
    var formattedLastExecuted: String? {
        guard let lastExecuted = lastExecuted else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastExecuted)
    }
    
    /// Formatted estimated duration
    var formattedEstimatedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: estimatedDuration) ?? "0s"
    }
    
    /// Execution frequency description
    var executionFrequency: String {
        switch executionCount {
        case 0:
            return "Never executed"
        case 1:
            return "Executed once"
        case 2...10:
            return "Executed \(executionCount) times"
        case 11...50:
            return "Executed frequently (\(executionCount) times)"
        default:
            return "Executed very frequently (\(executionCount) times)"
        }
    }
    
    /// Check if workflow was recently executed (within last 24 hours)
    var isRecentlyExecuted: Bool {
        guard let lastExecuted = lastExecuted else { return false }
        return lastExecuted.timeIntervalSinceNow > -86400 // 24 hours
    }
    
    /// Check if workflow is recently created (within last 7 days)
    var isRecentlyCreated: Bool {
        return createdAt.timeIntervalSinceNow > -604800 // 7 days
    }
    
    /// Check if workflow is frequently executed (more than 10 times)
    var isFrequentlyExecuted: Bool {
        return executionCount > 10
    }
    
    /// Get number of steps
    var stepCount: Int {
        return steps.count
    }
    
    /// Get step types summary
    var stepTypesSummary: String {
        let stepTypes = steps.map { $0.type.rawValue }
        let uniqueTypes = Set(stepTypes)
        return uniqueTypes.sorted().joined(separator: ", ")
    }
    
    /// Check if workflow has conditional steps
    var hasConditionalSteps: Bool {
        return steps.contains { $0.type == .conditional }
    }
    
    /// Check if workflow has user input steps
    var hasUserInputSteps: Bool {
        return steps.contains { $0.type == .userInput }
    }
    
    /// Add a step to the workflow
    func addStep(_ step: WorkflowStep) {
        var currentSteps = steps
        currentSteps.append(step)
        steps = currentSteps
        updateEstimatedDuration()
    }
    
    /// Remove a step from the workflow
    func removeStep(at index: Int) {
        var currentSteps = steps
        guard index >= 0 && index < currentSteps.count else { return }
        currentSteps.remove(at: index)
        steps = currentSteps
        updateEstimatedDuration()
    }
    
    /// Move a step within the workflow
    func moveStep(from sourceIndex: Int, to destinationIndex: Int) {
        var currentSteps = steps
        guard sourceIndex >= 0 && sourceIndex < currentSteps.count,
              destinationIndex >= 0 && destinationIndex < currentSteps.count else { return }
        
        let step = currentSteps.remove(at: sourceIndex)
        currentSteps.insert(step, at: destinationIndex)
        steps = currentSteps
    }
    
    /// Update estimated duration based on steps
    private func updateEstimatedDuration() {
        let totalDuration = steps.reduce(0.0) { total, step in
            switch step.type {
            case .fileOperation:
                return total + 2.0 // 2 seconds per file operation
            case .systemCommand:
                return total + 1.0 // 1 second per system command
            case .appIntegration:
                return total + 3.0 // 3 seconds per app integration
            case .userInput:
                return total + 30.0 // 30 seconds for user input
            case .conditional:
                return total + 0.5 // 0.5 seconds for conditional logic
            case .delay:
                if let delayString = step.parameters["duration"],
                   let delay = Double(delayString) {
                    return total + delay
                }
                return total + 1.0
            case .notification:
                return total + 0.1 // 0.1 seconds for notification
            }
        }
        estimatedDuration = totalDuration
    }
    
    /// Record execution
    func recordExecution() {
        lastExecuted = Date()
        executionCount += 1
    }
    
    /// Encrypt workflow data
    func encrypt() throws {
        guard !isEncrypted else { return }
        try DataEncryptionService.shared.encryptWorkflow(self)
    }
    
    /// Get decrypted steps data
    var decryptedStepsData: Data? {
        if isEncrypted {
            do {
                return try DataEncryptionService.shared.decryptWorkflow(self)
            } catch {
                return nil
            }
        }
        return stepsData
    }
    
    /// Get decrypted steps
    var decryptedSteps: [WorkflowStep] {
        guard let data = decryptedStepsData,
              let steps = try? JSONDecoder().decode([WorkflowStep].self, from: data) else {
            return []
        }
        return steps
    }
    
    /// Check if workflow contains sensitive data
    var containsSensitiveData: Bool {
        let privacyManager = PrivacyManager()
        
        // Check workflow name and description
        let nameData = privacyManager.classifyDataSensitivity(name)
        let descData = privacyManager.classifyDataSensitivity(descriptionText)
        
        if nameData != .public || descData != .public {
            return true
        }
        
        // Check steps for sensitive parameters
        for step in steps {
            for (_, value) in step.parameters {
                if let stringValue = value as? String {
                    let sensitivity = privacyManager.classifyDataSensitivity(stringValue)
                    if sensitivity != .public {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Validation before saving
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateWorkflow()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateWorkflow()
    }
    
    private func validateWorkflow() throws {
        // Validate name is not empty
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw WorkflowValidationError.emptyName
        }
        
        // Validate description is not empty
        if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw WorkflowValidationError.emptyDescription
        }
        
        // Validate execution count is not negative
        if executionCount < 0 {
            throw WorkflowValidationError.negativeExecutionCount
        }
        
        // Validate estimated duration is not negative
        if estimatedDuration < 0 {
            throw WorkflowValidationError.negativeEstimatedDuration
        }
        
        // Validate category exists
        if TaskType(rawValue: category) == nil {
            throw WorkflowValidationError.invalidCategory
        }
        
        // Validate last executed is not before created date
        if let lastExecuted = lastExecuted, lastExecuted < createdAt {
            throw WorkflowValidationError.invalidExecutionDate
        }
        
        // Validate steps data is valid JSON
        if let data = stepsData {
            do {
                _ = try JSONDecoder().decode([WorkflowStep].self, from: data)
            } catch {
                throw WorkflowValidationError.invalidStepsData
            }
        }
    }
}

// MARK: - Fetch Requests
extension Workflow {
    
    /// Fetch request for workflows by category
    static func fetchRequest(category: TaskType) -> NSFetchRequest<Workflow> {
        let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workflow.lastExecuted, ascending: false)]
        return request
    }
    
    /// Fetch request for enabled workflows only
    static var enabledWorkflowsRequest: NSFetchRequest<Workflow> {
        let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workflow.lastExecuted, ascending: false)]
        return request
    }
    
    /// Fetch request for frequently executed workflows
    static var frequentlyExecutedRequest: NSFetchRequest<Workflow> {
        let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        request.predicate = NSPredicate(format: "executionCount > 10")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workflow.executionCount, ascending: false)]
        return request
    }
    
    /// Fetch request for recently created workflows
    static var recentlyCreatedRequest: NSFetchRequest<Workflow> {
        let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        let weekAgo = Date().addingTimeInterval(-604800)
        request.predicate = NSPredicate(format: "createdAt >= %@", weekAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workflow.createdAt, ascending: false)]
        return request
    }
    
    /// Fetch request for recently executed workflows
    static var recentlyExecutedRequest: NSFetchRequest<Workflow> {
        let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        let dayAgo = Date().addingTimeInterval(-86400)
        request.predicate = NSPredicate(format: "lastExecuted >= %@", dayAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workflow.lastExecuted, ascending: false)]
        return request
    }
    
    /// Search workflows by name or description
    static func searchRequest(term: String) -> NSFetchRequest<Workflow> {
        let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
        request.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR descriptionText CONTAINS[cd] %@",
            term, term
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workflow.executionCount, ascending: false)]
        return request
    }
}

// MARK: - Convenience Initializers
extension Workflow {
    
    /// Create a new workflow
    static func createWorkflow(
        name: String,
        description: String,
        category: TaskType = .automation,
        steps: [WorkflowStep] = [],
        in context: NSManagedObjectContext
    ) -> Workflow {
        let workflow = Workflow(context: context)
        workflow.id = UUID()
        workflow.name = name
        workflow.descriptionText = description
        workflow.workflowCategory = category
        workflow.createdAt = Date()
        workflow.executionCount = 0
        workflow.isEnabled = true
        workflow.steps = steps
        workflow.updateEstimatedDuration()
        return workflow
    }
}

// MARK: - Workflow Validation Errors
enum WorkflowValidationError: LocalizedError {
    case emptyName
    case emptyDescription
    case negativeExecutionCount
    case negativeEstimatedDuration
    case invalidCategory
    case invalidExecutionDate
    case invalidStepsData
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Workflow name cannot be empty"
        case .emptyDescription:
            return "Workflow description cannot be empty"
        case .negativeExecutionCount:
            return "Execution count cannot be negative"
        case .negativeEstimatedDuration:
            return "Estimated duration cannot be negative"
        case .invalidCategory:
            return "Invalid workflow category"
        case .invalidExecutionDate:
            return "Last executed date cannot be before creation date"
        case .invalidStepsData:
            return "Invalid workflow steps data"
        }
    }
}