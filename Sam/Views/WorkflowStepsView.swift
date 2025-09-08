//
//  WorkflowStepsView.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI
import UniformTypeIdentifiers

struct WorkflowStepsView: View {
    let steps: [WorkflowStepDefinition]
    @Binding var isEditing: Bool
    let onStepsChanged: ([WorkflowStepDefinition]) -> Void
    
    @State private var draggedStep: WorkflowStepDefinition?
    @State private var editingStep: WorkflowStepDefinition?
    @State private var showingAddStep = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workflow Steps")
                    .font(.headline)
                
                Spacer()
                
                if isEditing {
                    Button("Add Step") {
                        showingAddStep = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if steps.isEmpty {
                WorkflowStepsEmptyView {
                    showingAddStep = true
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        WorkflowStepView(
                            step: step,
                            stepNumber: index + 1,
                            isEditing: isEditing,
                            onEdit: {
                                editingStep = step
                            },
                            onDelete: {
                                deleteStep(step)
                            },
                            onMove: { direction in
                                moveStep(step, direction: direction)
                            }
                        )
                        .draggable(step) {
                            WorkflowStepDragPreview(step: step, stepNumber: index + 1)
                        }
                        .dropDestination(for: WorkflowStepDefinition.self) { droppedSteps, location in
                            guard let draggedStep = droppedSteps.first else { return false }
                            moveStepToPosition(draggedStep, targetStep: step)
                            return true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddStep) {
            AddWorkflowStepView { newStep in
                addStep(newStep)
            }
        }
        .sheet(item: $editingStep) { step in
            EditWorkflowStepView(step: step) { updatedStep in
                updateStep(updatedStep)
            }
        }
    }
    
    private func addStep(_ step: WorkflowStepDefinition) {
        var newSteps = steps
        newSteps.append(step)
        onStepsChanged(newSteps)
    }
    
    private func deleteStep(_ step: WorkflowStepDefinition) {
        var newSteps = steps
        newSteps.removeAll { $0.id == step.id }
        onStepsChanged(newSteps)
    }
    
    private func updateStep(_ updatedStep: WorkflowStepDefinition) {
        var newSteps = steps
        if let index = newSteps.firstIndex(where: { $0.id == updatedStep.id }) {
            newSteps[index] = updatedStep
            onStepsChanged(newSteps)
        }
    }
    
    private func moveStep(_ step: WorkflowStepDefinition, direction: MoveDirection) {
        var newSteps = steps
        guard let currentIndex = newSteps.firstIndex(where: { $0.id == step.id }) else { return }
        
        let newIndex: Int
        switch direction {
        case .up:
            newIndex = max(0, currentIndex - 1)
        case .down:
            newIndex = min(newSteps.count - 1, currentIndex + 1)
        }
        
        if newIndex != currentIndex {
            newSteps.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: newIndex > currentIndex ? newIndex + 1 : newIndex)
            onStepsChanged(newSteps)
        }
    }
    
    private func moveStepToPosition(_ draggedStep: WorkflowStepDefinition, targetStep: WorkflowStepDefinition) {
        var newSteps = steps
        
        guard let draggedIndex = newSteps.firstIndex(where: { $0.id == draggedStep.id }),
              let targetIndex = newSteps.firstIndex(where: { $0.id == targetStep.id }) else { return }
        
        newSteps.move(fromOffsets: IndexSet(integer: draggedIndex), toOffset: targetIndex > draggedIndex ? targetIndex + 1 : targetIndex)
        onStepsChanged(newSteps)
    }
}

enum MoveDirection {
    case up, down
}

struct WorkflowStepView: View {
    let step: WorkflowStepDefinition
    let stepNumber: Int
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMove: (MoveDirection) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            Text("\(stepNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(stepTypeColor(step.type))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.name)
                            .font(.headline)
                        
                        Text(step.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isEditing {
                        HStack(spacing: 4) {
                            Button(action: { onMove(.up) }) {
                                Image(systemName: "chevron.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Move up")
                            
                            Button(action: { onMove(.down) }) {
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Move down")
                            
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Edit step")
                            
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete step")
                        }
                    }
                }
                
                // Step parameters preview
                if !step.parameters.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(step.parameters.prefix(3)), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                                
                                Text(": \(String(describing: value.value))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        
                        if step.parameters.count > 3 {
                            Text("... and \(step.parameters.count - 3) more")
                                .font(.caption2)
                                .foregroundColor(.tertiary)
                        }
                    }
                }
                
                // Step options
                HStack(spacing: 12) {
                    if step.continueOnError {
                        Label("Continue on error", systemImage: "arrow.right.circle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if step.retryCount > 0 {
                        Label("Retry \(step.retryCount)x", systemImage: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if step.timeout != 30.0 {
                        Label("Timeout \(Int(step.timeout))s", systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if step.condition != nil {
                        Label("Conditional", systemImage: "questionmark.diamond")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEditing ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private func stepTypeColor(_ type: WorkflowStepType) -> Color {
        switch type {
        case .fileOperation:
            return .blue
        case .appControl:
            return .green
        case .systemCommand:
            return .orange
        case .userInput:
            return .purple
        case .conditional:
            return .pink
        case .delay:
            return .gray
        case .textProcessing:
            return .indigo
        case .notification:
            return .yellow
        }
    }
}

struct WorkflowStepDragPreview: View {
    let step: WorkflowStepDefinition
    let stepNumber: Int
    
    var body: some View {
        HStack {
            Text("\(stepNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            Text(step.name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

struct WorkflowStepsEmptyView: View {
    let onAddStep: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Steps")
                    .font(.headline)
                
                Text("Add steps to define what this workflow should do")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add First Step") {
                onAddStep()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: 300)
        .padding(.vertical, 32)
    }
}

// MARK: - Extensions

extension WorkflowStepType {
    var displayName: String {
        switch self {
        case .fileOperation:
            return "File Operation"
        case .appControl:
            return "App Control"
        case .systemCommand:
            return "System Command"
        case .userInput:
            return "User Input"
        case .conditional:
            return "Conditional"
        case .delay:
            return "Delay"
        case .textProcessing:
            return "Text Processing"
        case .notification:
            return "Notification"
        }
    }
}

extension WorkflowStepDefinition: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .workflowStep)
    }
}

extension UTType {
    static let workflowStep = UTType(exportedAs: "com.sam.workflow-step")
}

#Preview {
    let sampleSteps = [
        WorkflowStepDefinition(
            name: "Copy Files",
            type: .fileOperation,
            parameters: ["operation": "copy", "source": "~/Downloads", "destination": "~/Desktop"]
        ),
        WorkflowStepDefinition(
            name: "Open Safari",
            type: .appControl,
            parameters: ["app": "Safari", "url": "https://apple.com"]
        ),
        WorkflowStepDefinition(
            name: "Show Notification",
            type: .notification,
            parameters: ["title": "Task Complete", "message": "Files copied successfully"]
        )
    ]
    
    return WorkflowStepsView(
        steps: sampleSteps,
        isEditing: .constant(true),
        onStepsChanged: { _ in }
    )
    .padding()
}