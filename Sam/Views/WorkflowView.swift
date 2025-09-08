//
//  WorkflowView.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI
import CoreData

struct WorkflowView: View {
    @StateObject private var workflowManager = WorkflowManager()
    @State private var selectedWorkflow: WorkflowDefinition?
    @State private var showingCreateWorkflow = false
    @State private var showingImportWorkflow = false
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var sortOrder = WorkflowSortOrder.name
    
    private let categories = ["All", "Automation", "File Operations", "System", "Productivity", "Custom"]
    
    var filteredWorkflows: [WorkflowDefinition] {
        var workflows = workflowManager.workflows
        
        // Filter by search text
        if !searchText.isEmpty {
            workflows = workflowManager.searchWorkflows(searchText)
        }
        
        // Filter by category
        if selectedCategory != "All" {
            workflows = workflows.filter { workflow in
                workflow.tags.contains { $0.lowercased() == selectedCategory.lowercased() }
            }
        }
        
        // Sort workflows
        switch sortOrder {
        case .name:
            workflows.sort { $0.name < $1.name }
        case .dateCreated:
            workflows.sort { $0.createdAt > $1.createdAt }
        case .lastExecuted:
            workflows.sort { ($0.modifiedAt) > ($1.modifiedAt) }
        case .executionCount:
            workflows.sort { $0.version > $1.version } // Using version as proxy for execution count
        }
        
        return workflows
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Workflow List
            VStack(spacing: 0) {
                // Header with controls
                VStack(spacing: 12) {
                    HStack {
                        Text("Workflows")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Menu {
                            Button("Create New Workflow") {
                                showingCreateWorkflow = true
                            }
                            Button("Import Workflow") {
                                showingImportWorkflow = true
                            }
                            Divider()
                            Button("Refresh") {
                                Task {
                                    // Reload workflows
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search workflows...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Category filter
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Sort options
                    Picker("Sort", selection: $sortOrder) {
                        Text("Name").tag(WorkflowSortOrder.name)
                        Text("Created").tag(WorkflowSortOrder.dateCreated)
                        Text("Modified").tag(WorkflowSortOrder.lastExecuted)
                        Text("Usage").tag(WorkflowSortOrder.executionCount)
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                
                Divider()
                
                // Workflow list
                List(filteredWorkflows, id: \.id, selection: $selectedWorkflow) { workflow in
                    WorkflowListItem(
                        workflow: workflow,
                        isSelected: selectedWorkflow?.id == workflow.id,
                        onExecute: {
                            Task {
                                await executeWorkflow(workflow)
                            }
                        },
                        onToggleEnabled: {
                            Task {
                                await toggleWorkflowEnabled(workflow)
                            }
                        }
                    )
                    .tag(workflow)
                }
                .listStyle(.sidebar)
            }
        } detail: {
            // Detail view
            if let workflow = selectedWorkflow {
                WorkflowDetailView(
                    workflow: workflow,
                    workflowManager: workflowManager,
                    onUpdate: { updatedWorkflow in
                        Task {
                            try await workflowManager.updateWorkflow(updatedWorkflow)
                        }
                    },
                    onDelete: {
                        Task {
                            try await workflowManager.deleteWorkflow(workflow.id)
                            selectedWorkflow = nil
                        }
                    },
                    onDuplicate: {
                        Task {
                            _ = try await workflowManager.duplicateWorkflow(workflow.id)
                        }
                    },
                    onExecute: {
                        Task {
                            await executeWorkflow(workflow)
                        }
                    }
                )
            } else {
                WorkflowEmptyStateView {
                    showingCreateWorkflow = true
                }
            }
        }
        .navigationTitle("Workflow Manager")
        .sheet(isPresented: $showingCreateWorkflow) {
            CreateWorkflowView(workflowManager: workflowManager)
        }
        .sheet(isPresented: $showingImportWorkflow) {
            ImportWorkflowView(workflowManager: workflowManager)
        }
        .onAppear {
            workflowManager.startMonitoring()
        }
        .onDisappear {
            workflowManager.stopMonitoring()
        }
    }
    
    private func executeWorkflow(_ workflow: WorkflowDefinition) async {
        do {
            let result = try await workflowManager.executeWorkflowManually(workflow)
            // Show success notification or result
            print("Workflow executed successfully: \(result.executionId)")
        } catch {
            // Show error alert
            print("Workflow execution failed: \(error.localizedDescription)")
        }
    }
    
    private func toggleWorkflowEnabled(_ workflow: WorkflowDefinition) async {
        let updatedWorkflow = WorkflowDefinition(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description,
            steps: workflow.steps,
            variables: workflow.variables,
            triggers: workflow.triggers,
            isEnabled: !workflow.isEnabled,
            createdAt: workflow.createdAt,
            modifiedAt: Date(),
            version: workflow.version,
            tags: workflow.tags
        )
        
        do {
            try await workflowManager.updateWorkflow(updatedWorkflow)
        } catch {
            print("Failed to toggle workflow: \(error.localizedDescription)")
        }
    }
}

enum WorkflowSortOrder: String, CaseIterable {
    case name = "Name"
    case dateCreated = "Date Created"
    case lastExecuted = "Last Executed"
    case executionCount = "Execution Count"
}

struct WorkflowListItem: View {
    let workflow: WorkflowDefinition
    let isSelected: Bool
    let onExecute: () -> Void
    let onToggleEnabled: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(workflow.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        Button(action: onExecute) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Execute workflow")
                        
                        Button(action: onToggleEnabled) {
                            Image(systemName: workflow.isEnabled ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundColor(workflow.isEnabled ? .green : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .help(workflow.isEnabled ? "Disable workflow" : "Enable workflow")
                    }
                    
                    Text("\(workflow.steps.count) steps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Tags
            if !workflow.tags.isEmpty {
                HStack {
                    ForEach(workflow.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if workflow.tags.count > 3 {
                        Text("+\(workflow.tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct WorkflowEmptyStateView: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Workflows")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first workflow to automate repetitive tasks")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create Workflow") {
                onCreate()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: 300)
    }
}

#Preview {
    WorkflowView()
}