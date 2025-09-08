//
//  WorkflowDetailView.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct WorkflowDetailView: View {
    let workflow: WorkflowDefinition
    let workflowManager: WorkflowManager
    let onUpdate: (WorkflowDefinition) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onExecute: () -> Void
    
    @State private var isEditing = false
    @State private var showingExecutionHistory = false
    @State private var showingDeleteAlert = false
    @State private var currentExecution: WorkflowExecutionContext?
    
    var executionHistory: [WorkflowExecutionResult] {
        workflowManager.getWorkflowExecutionHistory(workflow.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                WorkflowHeaderView(
                    workflow: workflow,
                    isEditing: $isEditing,
                    onExecute: onExecute,
                    onEdit: { isEditing = true },
                    onDuplicate: onDuplicate,
                    onDelete: { showingDeleteAlert = true }
                )
                
                // Execution Status
                if let execution = workflowManager.currentExecution,
                   execution.workflowId == workflow.id {
                    WorkflowExecutionStatusView(execution: execution) {
                        workflowManager.cancelCurrentExecution()
                    }
                }
                
                // Workflow Steps
                WorkflowStepsView(
                    steps: workflow.steps,
                    isEditing: $isEditing,
                    onStepsChanged: { newSteps in
                        updateWorkflowSteps(newSteps)
                    }
                )
                
                // Variables
                if !workflow.variables.isEmpty {
                    WorkflowVariablesView(variables: workflow.variables)
                }
                
                // Triggers
                if !workflow.triggers.isEmpty {
                    WorkflowTriggersView(triggers: workflow.triggers)
                }
                
                // Execution History
                WorkflowExecutionHistoryView(
                    history: executionHistory,
                    showingHistory: $showingExecutionHistory
                )
            }
            .padding()
        }
        .navigationTitle(workflow.name)
        .navigationSubtitle("\(workflow.steps.count) steps")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                    }
                    
                    Button("Save") {
                        isEditing = false
                        // Save changes would be handled by onStepsChanged
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Menu {
                        Button("Execute") {
                            onExecute()
                        }
                        
                        Button("Edit") {
                            isEditing = true
                        }
                        
                        Button("Duplicate") {
                            onDuplicate()
                        }
                        
                        Divider()
                        
                        Button("Export...") {
                            exportWorkflow()
                        }
                        
                        Button("Delete", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Delete Workflow", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(workflow.name)'? This action cannot be undone.")
        }
        .sheet(isPresented: $showingExecutionHistory) {
            WorkflowExecutionHistoryDetailView(
                workflow: workflow,
                history: executionHistory
            )
        }
    }
    
    private func updateWorkflowSteps(_ newSteps: [WorkflowStepDefinition]) {
        let updatedWorkflow = WorkflowDefinition(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description,
            steps: newSteps,
            variables: workflow.variables,
            triggers: workflow.triggers,
            isEnabled: workflow.isEnabled,
            createdAt: workflow.createdAt,
            modifiedAt: Date(),
            version: workflow.version + 1,
            tags: workflow.tags
        )
        
        onUpdate(updatedWorkflow)
    }
    
    private func exportWorkflow() {
        do {
            let data = try workflowManager.exportWorkflow(workflow.id)
            
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.json]
            savePanel.nameFieldStringValue = "\(workflow.name).json"
            
            if savePanel.runModal() == .OK, let url = savePanel.url {
                try data.write(to: url)
            }
        } catch {
            print("Failed to export workflow: \(error.localizedDescription)")
        }
    }
}

struct WorkflowHeaderView: View {
    let workflow: WorkflowDefinition
    @Binding var isEditing: Bool
    let onExecute: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(workflow.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if workflow.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .help("Workflow is enabled")
                        } else {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                                .help("Workflow is disabled")
                        }
                    }
                    
                    Text(workflow.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Execute") {
                    onExecute()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!workflow.isEnabled)
            }
            
            // Metadata
            HStack(spacing: 16) {
                Label("\(workflow.steps.count) steps", systemImage: "list.number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("Created \(workflow.createdAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if workflow.modifiedAt != workflow.createdAt {
                    Label("Modified \(workflow.modifiedAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Tags
            if !workflow.tags.isEmpty {
                HStack {
                    ForEach(workflow.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct WorkflowExecutionStatusView: View {
    let execution: WorkflowExecutionContext
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Execution Status")
                    .font(.headline)
                
                Spacer()
                
                if execution.isRunning {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if execution.isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Running...")
                            .foregroundColor(.blue)
                    } else if execution.isPaused {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.orange)
                        Text("Paused")
                            .foregroundColor(.orange)
                    } else if let error = execution.error {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text("Step \(execution.currentStepIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(execution.currentStepIndex), total: Double(execution.variables.count))
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    let sampleWorkflow = WorkflowDefinition(
        name: "Sample Workflow",
        description: "A sample workflow for testing",
        steps: [
            WorkflowStepDefinition(
                name: "Step 1",
                type: .fileOperation,
                parameters: ["operation": "copy"]
            )
        ],
        tags: ["sample", "test"]
    )
    
    return WorkflowDetailView(
        workflow: sampleWorkflow,
        workflowManager: WorkflowManager(),
        onUpdate: { _ in },
        onDelete: { },
        onDuplicate: { },
        onExecute: { }
    )
}