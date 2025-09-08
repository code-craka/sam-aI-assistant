//
//  WorkflowStepEditView.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct AddWorkflowStepView: View {
    let onAdd: (WorkflowStepDefinition) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: WorkflowStepType = .fileOperation
    @State private var stepName = ""
    @State private var parameters: [String: Any] = [:]
    @State private var continueOnError = false
    @State private var retryCount = 0
    @State private var timeout: Double = 30.0
    @State private var hasCondition = false
    @State private var condition: WorkflowCondition?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Step Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Step Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter step name", text: $stepName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Step Type")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Step Type", selection: $selectedType) {
                                    ForEach(WorkflowStepType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedType) { _ in
                                    parameters = getDefaultParameters(for: selectedType)
                                }
                            }
                        }
                    }
                    
                    // Step Parameters
                    WorkflowStepParametersView(
                        stepType: selectedType,
                        parameters: $parameters
                    )
                    
                    // Advanced Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Options")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Continue on Error", isOn: $continueOnError)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Retry Count")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Stepper(value: $retryCount, in: 0...5) {
                                    Text("\(retryCount) retries")
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Timeout")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Slider(value: $timeout, in: 5...300, step: 5)
                                    Text("\(Int(timeout))s")
                                        .frame(width: 40)
                                }
                            }
                            
                            Toggle("Add Condition", isOn: $hasCondition)
                            
                            if hasCondition {
                                WorkflowConditionEditView(condition: $condition)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Add Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addStep()
                    }
                    .disabled(stepName.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            parameters = getDefaultParameters(for: selectedType)
        }
    }
    
    private func addStep() {
        let step = WorkflowStepDefinition(
            name: stepName,
            type: selectedType,
            parameters: parameters,
            continueOnError: continueOnError,
            retryCount: retryCount,
            timeout: timeout,
            condition: hasCondition ? condition : nil
        )
        
        onAdd(step)
        dismiss()
    }
    
    private func getDefaultParameters(for type: WorkflowStepType) -> [String: Any] {
        switch type {
        case .fileOperation:
            return ["operation": "copy", "source": "", "destination": ""]
        case .appControl:
            return ["app": "", "command": ""]
        case .systemCommand:
            return ["query": ""]
        case .userInput:
            return ["prompt": "", "inputVariable": "userInput"]
        case .conditional:
            return [:]
        case .delay:
            return ["duration": 1.0]
        case .textProcessing:
            return ["text": "", "operation": "uppercase", "outputVariable": "result"]
        case .notification:
            return ["title": "", "message": ""]
        }
    }
}

struct EditWorkflowStepView: View {
    let step: WorkflowStepDefinition
    let onUpdate: (WorkflowStepDefinition) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var stepName: String
    @State private var parameters: [String: Any]
    @State private var continueOnError: Bool
    @State private var retryCount: Int
    @State private var timeout: Double
    @State private var hasCondition: Bool
    @State private var condition: WorkflowCondition?
    
    init(step: WorkflowStepDefinition, onUpdate: @escaping (WorkflowStepDefinition) -> Void) {
        self.step = step
        self.onUpdate = onUpdate
        
        _stepName = State(initialValue: step.name)
        _parameters = State(initialValue: step.parameters.mapValues { $0.value })
        _continueOnError = State(initialValue: step.continueOnError)
        _retryCount = State(initialValue: step.retryCount)
        _timeout = State(initialValue: step.timeout)
        _hasCondition = State(initialValue: step.condition != nil)
        _condition = State(initialValue: step.condition)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Step Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Step Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter step name", text: $stepName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Step Type")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(step.type.displayName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    // Step Parameters
                    WorkflowStepParametersView(
                        stepType: step.type,
                        parameters: $parameters
                    )
                    
                    // Advanced Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Options")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Continue on Error", isOn: $continueOnError)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Retry Count")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Stepper(value: $retryCount, in: 0...5) {
                                    Text("\(retryCount) retries")
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Timeout")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Slider(value: $timeout, in: 5...300, step: 5)
                                    Text("\(Int(timeout))s")
                                        .frame(width: 40)
                                }
                            }
                            
                            Toggle("Add Condition", isOn: $hasCondition)
                            
                            if hasCondition {
                                WorkflowConditionEditView(condition: $condition)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateStep()
                    }
                    .disabled(stepName.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func updateStep() {
        let updatedStep = WorkflowStepDefinition(
            id: step.id,
            name: stepName,
            type: step.type,
            parameters: parameters,
            continueOnError: continueOnError,
            retryCount: retryCount,
            timeout: timeout,
            condition: hasCondition ? condition : nil
        )
        
        onUpdate(updatedStep)
        dismiss()
    }
}

struct WorkflowStepParametersView: View {
    let stepType: WorkflowStepType
    @Binding var parameters: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Parameters")
                .font(.headline)
            
            switch stepType {
            case .fileOperation:
                FileOperationParametersView(parameters: $parameters)
            case .appControl:
                AppControlParametersView(parameters: $parameters)
            case .systemCommand:
                SystemCommandParametersView(parameters: $parameters)
            case .userInput:
                UserInputParametersView(parameters: $parameters)
            case .conditional:
                ConditionalParametersView(parameters: $parameters)
            case .delay:
                DelayParametersView(parameters: $parameters)
            case .textProcessing:
                TextProcessingParametersView(parameters: $parameters)
            case .notification:
                NotificationParametersView(parameters: $parameters)
            }
        }
    }
}

struct FileOperationParametersView: View {
    @Binding var parameters: [String: Any]
    
    private var operation: String {
        get { parameters["operation"] as? String ?? "copy" }
        set { parameters["operation"] = newValue }
    }
    
    private var source: String {
        get { parameters["source"] as? String ?? "" }
        set { parameters["source"] = newValue }
    }
    
    private var destination: String {
        get { parameters["destination"] as? String ?? "" }
        set { parameters["destination"] = newValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Operation")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Operation", selection: Binding(
                    get: { operation },
                    set: { operation = $0 }
                )) {
                    Text("Copy").tag("copy")
                    Text("Move").tag("move")
                    Text("Delete").tag("delete")
                    Text("Rename").tag("rename")
                    Text("Organize").tag("organize")
                }
                .pickerStyle(.menu)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Path")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter source path", text: Binding(
                    get: { source },
                    set: { source = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            if operation != "delete" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Destination Path")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter destination path", text: Binding(
                        get: { destination },
                        set: { destination = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
}

struct AppControlParametersView: View {
    @Binding var parameters: [String: Any]
    
    private var app: String {
        get { parameters["app"] as? String ?? "" }
        set { parameters["app"] = newValue }
    }
    
    private var command: String {
        get { parameters["command"] as? String ?? "" }
        set { parameters["command"] = newValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Application")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter application name", text: Binding(
                    get: { app },
                    set: { app = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Command")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter command to execute", text: Binding(
                    get: { command },
                    set: { command = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
        }
    }
}

struct SystemCommandParametersView: View {
    @Binding var parameters: [String: Any]
    
    private var query: String {
        get { parameters["query"] as? String ?? "" }
        set { parameters["query"] = newValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Query")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Enter system query", text: Binding(
                get: { query },
                set: { query = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
        }
    }
}

struct UserInputParametersView: View {
    @Binding var parameters: [String: Any]
    
    private var prompt: String {
        get { parameters["prompt"] as? String ?? "" }
        set { parameters["prompt"] = newValue }
    }
    
    private var inputVariable: String {
        get { parameters["inputVariable"] as? String ?? "userInput" }
        set { parameters["inputVariable"] = newValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter prompt for user", text: Binding(
                    get: { prompt },
                    set: { prompt = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Variable Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Variable to store input", text: Binding(
                    get: { inputVariable },
                    set: { inputVariable = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct ConditionalParametersView: View {
    @Binding var parameters: [String: Any]
    
    var body: some View {
        Text("Conditional steps are configured using the condition settings below.")
            .font(.body)
            .foregroundColor(.secondary)
            .italic()
    }
}

struct DelayParametersView: View {
    @Binding var parameters: [String: Any]
    
    private var duration: Double {
        get { parameters["duration"] as? Double ?? 1.0 }
        set { parameters["duration"] = newValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration (seconds)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Slider(value: Binding(
                    get: { duration },
                    set: { duration = $0 }
                ), in: 0.1...60.0, step: 0.1)
                
                Text(String(format: "%.1fs", duration))
                    .frame(width: 50)
            }
        }
    }
}

struct TextProcessingParametersView: View {
    @Binding var parameters: [String: Any]
    
    private var text: String {
        get { parameters["text"] as? String ?? "" }
        set { parameters["text"] = newValue }
    }
    
    private var operation: String {
        get { parameters["operation"] as? String ?? "uppercase" }
        set { parameters["operation"] = newValue }
    }
    
    private var outputVariable: String {
        get { parameters["outputVariable"] as? String ?? "result" }
        set { parameters["outputVariable"] = newValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Text to Process")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter text or variable name", text: Binding(
                    get: { text },
                    set: { text = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Operation")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Operation", selection: Binding(
                    get: { operation },
                    set: { operation = $0 }
                )) {
                    Text("Uppercase").tag("uppercase")
                    Text("Lowercase").tag("lowercase")
                    Text("Trim").tag("trim")
                    Text("Length").tag("length")
                }
                .pickerStyle(.menu)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Output Variable")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Variable to store result", text: Binding(
                    get: { outputVariable },
                    set: { outputVariable = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct NotificationParametersView: View {
    @Binding var parameters: [String: Any]
    
    private var title: String {
        get { parameters["title"] as? String ?? "" }
        set { parameters["title"] = newValue }
    }
    
    private var message: String {
        get { parameters["message"] as? String ?? "" }
        set { parameters["message"] = newValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Notification title", text: Binding(
                    get: { title },
                    set: { title = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Message")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Notification message", text: Binding(
                    get: { message },
                    set: { message = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
        }
    }
}

struct WorkflowConditionEditView: View {
    @Binding var condition: WorkflowCondition?
    
    @State private var conditionType: WorkflowCondition.ConditionType = .equals
    @State private var variable = ""
    @State private var value = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Condition")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                Picker("Condition Type", selection: $conditionType) {
                    Text("Equals").tag(WorkflowCondition.ConditionType.equals)
                    Text("Not Equals").tag(WorkflowCondition.ConditionType.notEquals)
                    Text("Contains").tag(WorkflowCondition.ConditionType.contains)
                    Text("Greater Than").tag(WorkflowCondition.ConditionType.greaterThan)
                    Text("Less Than").tag(WorkflowCondition.ConditionType.lessThan)
                    Text("File Exists").tag(WorkflowCondition.ConditionType.fileExists)
                    Text("App Running").tag(WorkflowCondition.ConditionType.appRunning)
                }
                .pickerStyle(.menu)
                
                TextField("Variable name", text: $variable)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Value to compare", text: $value)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .onChange(of: conditionType) { _ in updateCondition() }
        .onChange(of: variable) { _ in updateCondition() }
        .onChange(of: value) { _ in updateCondition() }
        .onAppear {
            if let existingCondition = condition {
                conditionType = existingCondition.type
                variable = existingCondition.variable
                value = String(describing: existingCondition.value.value)
            }
        }
    }
    
    private func updateCondition() {
        condition = WorkflowCondition(
            type: conditionType,
            variable: variable,
            value: value
        )
    }
}

#Preview {
    AddWorkflowStepView { _ in }
}