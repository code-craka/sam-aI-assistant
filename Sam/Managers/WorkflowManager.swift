//
//  WorkflowManager.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import Combine
import CoreData

@MainActor
class WorkflowManager: ObservableObject {
    @Published var workflows: [WorkflowDefinition] = []
    @Published var isExecuting = false
    @Published var currentExecution: WorkflowExecutionContext?
    @Published var executionHistory: [WorkflowExecutionResult] = []
    @Published var scheduledWorkflows: [ScheduledWorkflow] = []
    
    private let workflowExecutor: WorkflowExecutor
    private let workflowScheduler: WorkflowScheduler
    private let workflowBuilder: WorkflowBuilder
    private let persistenceController: PersistenceController
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.workflowExecutor = WorkflowExecutor()
        self.workflowScheduler = WorkflowScheduler()
        self.workflowBuilder = WorkflowBuilder()
        self.persistenceController = PersistenceController.shared
        
        setupBindings()
        loadWorkflows()
    }
    
    // MARK: - Public Methods
    
    func createWorkflowFromDescription(_ description: String, name: String? = nil) async throws -> WorkflowDefinition {
        let workflow = try await workflowBuilder.buildWorkflowFromDescription(description, name: name)
        
        // Validate the workflow
        let validationResult = try await workflowBuilder.validateWorkflow(workflow)
        if !validationResult.isValid {
            let errorMessage = validationResult.issues.map { $0.message }.joined(separator: ", ")
            throw WorkflowError.invalidParameters(stepName: "Workflow", parameter: errorMessage)
        }
        
        // Save the workflow
        try await saveWorkflow(workflow)
        
        return workflow
    }
    
    func createWorkflowFromTemplate(_ template: WorkflowTemplate, parameters: [String: Any]) async throws -> WorkflowDefinition {
        let workflow = try await workflowBuilder.buildWorkflowFromTemplate(template, parameters: parameters)
        try await saveWorkflow(workflow)
        return workflow
    }
    
    func executeWorkflow(_ workflowId: UUID) async throws -> WorkflowExecutionResult {
        guard let workflow = workflows.first(where: { $0.id == workflowId }) else {
            throw WorkflowError.workflowNotFound(id: workflowId)
        }
        
        let result = try await workflowExecutor.executeWorkflow(workflow)
        executionHistory.append(result)
        
        // Save execution result
        try await saveExecutionResult(result)
        
        return result
    }
    
    func executeWorkflowManually(_ workflow: WorkflowDefinition) async throws -> WorkflowExecutionResult {
        let result = try await workflowExecutor.executeWorkflow(workflow)
        executionHistory.append(result)
        
        // Save execution result
        try await saveExecutionResult(result)
        
        return result
    }
    
    func pauseCurrentExecution() {
        workflowExecutor.pauseExecution()
    }
    
    func resumeCurrentExecution() {
        workflowExecutor.resumeExecution()
    }
    
    func cancelCurrentExecution() {
        workflowExecutor.cancelExecution()
    }
    
    func scheduleWorkflow(_ workflowId: UUID) throws {
        guard let workflow = workflows.first(where: { $0.id == workflowId }) else {
            throw WorkflowError.workflowNotFound(id: workflowId)
        }
        
        workflowScheduler.scheduleWorkflow(workflow)
    }
    
    func unscheduleWorkflow(_ workflowId: UUID) {
        workflowScheduler.unscheduleWorkflow(workflowId)
    }
    
    func updateWorkflow(_ workflow: WorkflowDefinition) async throws {
        // Validate the updated workflow
        let validationResult = try await workflowBuilder.validateWorkflow(workflow)
        if !validationResult.isValid {
            let errorMessage = validationResult.issues.map { $0.message }.joined(separator: ", ")
            throw WorkflowError.invalidParameters(stepName: "Workflow", parameter: errorMessage)
        }
        
        // Update in memory
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[index] = workflow
        }
        
        // Save to persistence
        try await saveWorkflow(workflow)
        
        // Reschedule if it was scheduled
        if scheduledWorkflows.contains(where: { $0.workflowId == workflow.id }) {
            workflowScheduler.unscheduleWorkflow(workflow.id)
            workflowScheduler.scheduleWorkflow(workflow)
        }
    }
    
    func deleteWorkflow(_ workflowId: UUID) async throws {
        // Unschedule if scheduled
        workflowScheduler.unscheduleWorkflow(workflowId)
        
        // Remove from memory
        workflows.removeAll { $0.id == workflowId }
        
        // Delete from persistence
        try await deleteWorkflowFromStorage(workflowId)
    }
    
    func duplicateWorkflow(_ workflowId: UUID, newName: String? = nil) async throws -> WorkflowDefinition {
        guard let originalWorkflow = workflows.first(where: { $0.id == workflowId }) else {
            throw WorkflowError.workflowNotFound(id: workflowId)
        }
        
        let duplicatedWorkflow = WorkflowDefinition(
            name: newName ?? "\(originalWorkflow.name) Copy",
            description: originalWorkflow.description,
            steps: originalWorkflow.steps,
            variables: originalWorkflow.variables,
            triggers: originalWorkflow.triggers,
            isEnabled: false, // Start disabled
            tags: originalWorkflow.tags
        )
        
        try await saveWorkflow(duplicatedWorkflow)
        return duplicatedWorkflow
    }
    
    func optimizeWorkflow(_ workflowId: UUID) async throws -> WorkflowDefinition {
        guard let workflow = workflows.first(where: { $0.id == workflowId }) else {
            throw WorkflowError.workflowNotFound(id: workflowId)
        }
        
        let optimizedWorkflow = try await workflowBuilder.optimizeWorkflow(workflow)
        try await updateWorkflow(optimizedWorkflow)
        
        return optimizedWorkflow
    }
    
    func getWorkflowExecutionHistory(_ workflowId: UUID) -> [WorkflowExecutionResult] {
        return executionHistory.filter { $0.workflowId == workflowId }
    }
    
    func getWorkflowsByTag(_ tag: String) -> [WorkflowDefinition] {
        return workflows.filter { $0.tags.contains(tag) }
    }
    
    func searchWorkflows(_ query: String) -> [WorkflowDefinition] {
        let lowercaseQuery = query.lowercased()
        return workflows.filter { workflow in
            workflow.name.lowercased().contains(lowercaseQuery) ||
            workflow.description.lowercased().contains(lowercaseQuery) ||
            workflow.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    func exportWorkflow(_ workflowId: UUID) throws -> Data {
        guard let workflow = workflows.first(where: { $0.id == workflowId }) else {
            throw WorkflowError.workflowNotFound(id: workflowId)
        }
        
        return try JSONEncoder().encode(workflow)
    }
    
    func importWorkflow(from data: Data) async throws -> WorkflowDefinition {
        let workflow = try JSONDecoder().decode(WorkflowDefinition.self, from: data)
        
        // Generate new ID to avoid conflicts
        let importedWorkflow = WorkflowDefinition(
            name: "\(workflow.name) (Imported)",
            description: workflow.description,
            steps: workflow.steps,
            variables: workflow.variables,
            triggers: workflow.triggers,
            isEnabled: false, // Start disabled
            tags: workflow.tags + ["imported"]
        )
        
        try await saveWorkflow(importedWorkflow)
        return importedWorkflow
    }
    
    func startMonitoring() {
        workflowScheduler.startMonitoring()
    }
    
    func stopMonitoring() {
        workflowScheduler.stopMonitoring()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind executor state
        workflowExecutor.$isExecuting
            .assign(to: &$isExecuting)
        
        workflowExecutor.$currentExecution
            .assign(to: &$currentExecution)
        
        workflowExecutor.$executionHistory
            .assign(to: &$executionHistory)
        
        // Bind scheduler state
        workflowScheduler.$scheduledWorkflows
            .assign(to: &$scheduledWorkflows)
    }
    
    private func loadWorkflows() {
        Task {
            do {
                let loadedWorkflows = try await loadWorkflowsFromStorage()
                await MainActor.run {
                    self.workflows = loadedWorkflows
                }
                
                // Schedule enabled workflows
                for workflow in loadedWorkflows where workflow.isEnabled {
                    workflowScheduler.scheduleWorkflow(workflow)
                }
            } catch {
                print("Failed to load workflows: \(error)")
            }
        }
    }
    
    private func saveWorkflow(_ workflow: WorkflowDefinition) async throws {
        // Update in memory
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[index] = workflow
        } else {
            workflows.append(workflow)
        }
        
        // Save to Core Data
        try await persistenceController.performBackgroundTask { context in
            let workflowEntity = Workflow(context: context)
            workflowEntity.id = workflow.id
            workflowEntity.name = workflow.name
            workflowEntity.descriptionText = workflow.description
            workflowEntity.isEnabled = workflow.isEnabled
            workflowEntity.createdAt = workflow.createdAt
            workflowEntity.lastExecuted = nil
            workflowEntity.executionCount = 0
            
            // Encode steps as JSON
            let stepsData = try JSONEncoder().encode(workflow.steps)
            workflowEntity.stepsData = stepsData
            
            try context.save()
        }
    }
    
    private func loadWorkflowsFromStorage() async throws -> [WorkflowDefinition] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
            let workflowEntities = try context.fetch(request)
            
            return workflowEntities.compactMap { entity in
                guard let id = entity.id,
                      let name = entity.name,
                      let description = entity.descriptionText,
                      let stepsData = entity.stepsData,
                      let createdAt = entity.createdAt else {
                    return nil
                }
                
                do {
                    let steps = try JSONDecoder().decode([WorkflowStepDefinition].self, from: stepsData)
                    
                    return WorkflowDefinition(
                        id: id,
                        name: name,
                        description: description,
                        steps: steps,
                        isEnabled: entity.isEnabled,
                        createdAt: createdAt
                    )
                } catch {
                    print("Failed to decode workflow steps: \(error)")
                    return nil
                }
            }
        }
    }
    
    private func deleteWorkflowFromStorage(_ workflowId: UUID) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<Workflow> = Workflow.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", workflowId as CVarArg)
            
            let workflows = try context.fetch(request)
            for workflow in workflows {
                context.delete(workflow)
            }
            
            try context.save()
        }
    }
    
    private func saveExecutionResult(_ result: WorkflowExecutionResult) async throws {
        // In a real implementation, we would save execution results to Core Data
        // For now, we'll just keep them in memory
        print("Execution result saved: \(result.executionId)")
    }
}

// MARK: - Workflow Templates

extension WorkflowManager {
    static let builtInTemplates: [WorkflowTemplate] = [
        WorkflowTemplate(
            name: "Daily File Cleanup",
            description: "Clean up Downloads folder and organize Desktop files",
            steps: [
                WorkflowStepDefinition(
                    name: "Clean Downloads folder",
                    type: .fileOperation,
                    parameters: [
                        "operation": "organize",
                        "path": "~/Downloads",
                        "strategy": "by_date"
                    ]
                ),
                WorkflowStepDefinition(
                    name: "Organize Desktop",
                    type: .fileOperation,
                    parameters: [
                        "operation": "organize",
                        "path": "~/Desktop",
                        "strategy": "by_type"
                    ]
                ),
                WorkflowStepDefinition(
                    name: "Send completion notification",
                    type: .notification,
                    parameters: [
                        "title": "File Cleanup Complete",
                        "message": "Downloads and Desktop have been organized"
                    ]
                )
            ],
            variables: [:],
            triggers: [
                WorkflowTrigger(
                    type: .scheduled,
                    parameters: ["schedule": "0 9 * * *"] // Daily at 9 AM
                )
            ],
            tags: ["cleanup", "organization", "daily"]
        ),
        
        WorkflowTemplate(
            name: "Project Backup",
            description: "Backup project files to external drive",
            steps: [
                WorkflowStepDefinition(
                    name: "Copy project files",
                    type: .fileOperation,
                    parameters: [
                        "operation": "copy",
                        "source": "{{project_path}}",
                        "destination": "{{backup_path}}/{{project_name}}_backup_{{date}}"
                    ]
                ),
                WorkflowStepDefinition(
                    name: "Verify backup",
                    type: .fileOperation,
                    parameters: [
                        "operation": "verify",
                        "path": "{{backup_path}}/{{project_name}}_backup_{{date}}"
                    ]
                ),
                WorkflowStepDefinition(
                    name: "Send backup notification",
                    type: .notification,
                    parameters: [
                        "title": "Backup Complete",
                        "message": "{{project_name}} has been backed up successfully"
                    ]
                )
            ],
            variables: [
                "project_path": AnyCodable(""),
                "backup_path": AnyCodable(""),
                "project_name": AnyCodable(""),
                "date": AnyCodable("")
            ],
            triggers: [
                WorkflowTrigger(
                    type: .manual
                )
            ],
            tags: ["backup", "project", "safety"]
        )
    ]
}