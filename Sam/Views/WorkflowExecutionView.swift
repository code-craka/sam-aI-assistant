//
//  WorkflowExecutionView.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct WorkflowExecutionProgressView: View {
    let execution: WorkflowExecutionContext
    let workflow: WorkflowDefinition
    let onCancel: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    
    @State private var showingDetails = false
    
    var currentStep: WorkflowStepDefinition? {
        guard execution.currentStepIndex < workflow.steps.count else { return nil }
        return workflow.steps[execution.currentStepIndex]
    }
    
    var progress: Double {
        guard workflow.steps.count > 0 else { return 0 }
        return Double(execution.currentStepIndex) / Double(workflow.steps.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Executing Workflow")
                        .font(.headline)
                    
                    Text(workflow.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if execution.isRunning {
                        if execution.isPaused {
                            Button("Resume") {
                                onResume()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Pause") {
                                onPause()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Step \(execution.currentStepIndex + 1) of \(workflow.steps.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            // Current step
            if let step = currentStep {
                WorkflowExecutionStepView(
                    step: step,
                    stepNumber: execution.currentStepIndex + 1,
                    isActive: execution.isRunning && !execution.isPaused,
                    isPaused: execution.isPaused
                )
            }
            
            // Execution details toggle
            Button(action: { showingDetails.toggle() }) {
                HStack {
                    Text("Execution Details")
                        .font(.caption)
                    
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            
            if showingDetails {
                WorkflowExecutionDetailsView(execution: execution, workflow: workflow)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct WorkflowExecutionStepView: View {
    let step: WorkflowStepDefinition
    let stepNumber: Int
    let isActive: Bool
    let isPaused: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step indicator
            ZStack {
                Circle()
                    .fill(stepStatusColor)
                    .frame(width: 24, height: 24)
                
                if isActive && !isPaused {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if isPaused {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                } else {
                    Text("\(stepNumber)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(step.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isActive && !isPaused {
                    Text("Executing...")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if isPaused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
    }
    
    private var stepStatusColor: Color {
        if isActive {
            return isPaused ? .orange : .blue
        } else {
            return .gray
        }
    }
}

struct WorkflowExecutionDetailsView: View {
    let execution: WorkflowExecutionContext
    let workflow: WorkflowDefinition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Execution info
            VStack(alignment: .leading, spacing: 8) {
                Text("Execution Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Started")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(execution.startTime.formatted(date: .omitted, time: .standard))
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duration")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDuration(Date().timeIntervalSince(execution.startTime)))
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            // Variables
            if !execution.variables.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Variables")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(execution.variables.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(String(describing: execution.variables[key] ?? ""))
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                
                Divider()
            }
            
            // Step progress
            VStack(alignment: .leading, spacing: 8) {
                Text("Step Progress")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ForEach(Array(workflow.steps.enumerated()), id: \.element.id) { index, step in
                    HStack {
                        Image(systemName: stepIcon(for: index))
                            .font(.caption2)
                            .foregroundColor(stepColor(for: index))
                            .frame(width: 12)
                        
                        Text(step.name)
                            .font(.caption2)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(stepStatus(for: index))
                            .font(.caption2)
                            .foregroundColor(stepColor(for: index))
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
    
    private func stepIcon(for index: Int) -> String {
        if index < execution.currentStepIndex {
            return "checkmark.circle.fill"
        } else if index == execution.currentStepIndex {
            if execution.isPaused {
                return "pause.circle.fill"
            } else if execution.isRunning {
                return "arrow.right.circle.fill"
            } else {
                return "circle"
            }
        } else {
            return "circle"
        }
    }
    
    private func stepColor(for index: Int) -> Color {
        if index < execution.currentStepIndex {
            return .green
        } else if index == execution.currentStepIndex {
            if execution.isPaused {
                return .orange
            } else if execution.isRunning {
                return .blue
            } else {
                return .gray
            }
        } else {
            return .gray
        }
    }
    
    private func stepStatus(for index: Int) -> String {
        if index < execution.currentStepIndex {
            return "Complete"
        } else if index == execution.currentStepIndex {
            if execution.isPaused {
                return "Paused"
            } else if execution.isRunning {
                return "Running"
            } else {
                return "Pending"
            }
        } else {
            return "Pending"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct WorkflowExecutionHistoryView: View {
    let history: [WorkflowExecutionResult]
    @Binding var showingHistory: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Execution History")
                    .font(.headline)
                
                Spacer()
                
                if !history.isEmpty {
                    Button("View All") {
                        showingHistory = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if history.isEmpty {
                Text("No previous executions")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(history.prefix(5), id: \.executionId) { result in
                        WorkflowExecutionHistoryItem(result: result)
                    }
                    
                    if history.count > 5 {
                        Button("View \(history.count - 5) more executions") {
                            showingHistory = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    }
                }
            }
        }
    }
}

struct WorkflowExecutionHistoryItem: View {
    let result: WorkflowExecutionResult
    
    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(result.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                    
                    Spacer()
                    
                    Text(formatDuration(result.duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("\(result.completedSteps)/\(result.totalSteps) steps completed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let error = result.error {
                    Text("Error: \(error)")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

struct WorkflowExecutionHistoryDetailView: View {
    let workflow: WorkflowDefinition
    let history: [WorkflowExecutionResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(history, id: \.executionId) { result in
                WorkflowExecutionResultDetailView(result: result, workflow: workflow)
            }
            .navigationTitle("Execution History")
            .navigationSubtitle(workflow.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct WorkflowExecutionResultDetailView: View {
    let result: WorkflowExecutionResult
    let workflow: WorkflowDefinition
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.startTime.formatted(date: .abbreviated, time: .standard))
                        .font(.headline)
                    
                    Text("\(result.completedSteps)/\(result.totalSteps) steps completed in \(formatDuration(result.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(showingDetails ? "Hide Details" : "Show Details") {
                    showingDetails.toggle()
                }
                .buttonStyle(.bordered)
            }
            
            if let error = result.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step Results")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(result.stepResults, id: \.id) { stepResult in
                        WorkflowStepResultView(stepResult: stepResult)
                    }
                }
            }
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

struct WorkflowStepResultView: View {
    let stepResult: WorkflowStepResult
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: stepResult.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(stepResult.success ? .green : .red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stepResult.stepName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(formatDuration(stepResult.duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let output = stepResult.output {
                    Text(output)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let error = stepResult.error {
                    Text("Error: \(error)")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                
                if stepResult.retryCount > 0 {
                    Text("Retried \(stepResult.retryCount) times")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        return String(format: "%.2fs", duration)
    }
}

#Preview {
    let sampleExecution = WorkflowExecutionContext(workflowId: UUID())
    sampleExecution.currentStepIndex = 1
    sampleExecution.isRunning = true
    
    let sampleWorkflow = WorkflowDefinition(
        name: "Sample Workflow",
        description: "A sample workflow",
        steps: [
            WorkflowStepDefinition(name: "Step 1", type: .fileOperation),
            WorkflowStepDefinition(name: "Step 2", type: .appControl),
            WorkflowStepDefinition(name: "Step 3", type: .notification)
        ]
    )
    
    return WorkflowExecutionProgressView(
        execution: sampleExecution,
        workflow: sampleWorkflow,
        onCancel: { },
        onPause: { },
        onResume: { }
    )
    .padding()
}