//
//  WorkflowVariablesView.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct WorkflowVariablesView: View {
    let variables: [String: AnyCodable]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Variables")
                .font(.headline)

            LazyVStack(spacing: 8) {
                ForEach(Array(variables.keys.sorted()), id: \.self) { key in
                    WorkflowVariableView(
                        name: key,
                        value: variables[key]?.value
                    )
                }
            }
        }
    }
}

struct WorkflowVariableView: View {
    let name: String
    let value: Any?

    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            Text(formatValue(value))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "nil" }

        switch value {
        case let string as String:
            return "\"\(string)\""
        case let number as NSNumber:
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        case let array as [Any]:
            return "[\(array.count) items]"
        case let dict as [String: Any]:
            return "{\(dict.count) keys}"
        default:
            return String(describing: value)
        }
    }
}

struct WorkflowTriggersView: View {
    let triggers: [WorkflowTrigger]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Triggers")
                .font(.headline)

            LazyVStack(spacing: 8) {
                ForEach(triggers, id: \.id) { trigger in
                    WorkflowTriggerView(trigger: trigger)
                }
            }
        }
    }
}

struct WorkflowTriggerView: View {
    let trigger: WorkflowTrigger

    var body: some View {
        HStack {
            Image(systemName: triggerIcon)
                .foregroundColor(trigger.isEnabled ? .green : .gray)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(trigger.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !trigger.parameters.isEmpty {
                    Text(triggerDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if !trigger.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var triggerIcon: String {
        switch trigger.type {
        case .manual:
            return "hand.tap"
        case .scheduled:
            return "clock"
        case .fileChanged:
            return "doc.badge.gearshape"
        case .appLaunched:
            return "app.badge"
        case .systemEvent:
            return "gear"
        case .hotkey:
            return "keyboard"
        case .webhook:
            return "network"
        }
    }

    private var triggerDescription: String {
        switch trigger.type {
        case .manual:
            return "Triggered manually by user"
        case .scheduled:
            if let schedule = trigger.parameters["schedule"]?.value as? String {
                return "Schedule: \(schedule)"
            }
            return "Scheduled trigger"
        case .fileChanged:
            if let path = trigger.parameters["path"]?.value as? String {
                return "Watch: \(path)"
            }
            return "File change trigger"
        case .appLaunched:
            if let app = trigger.parameters["app"]?.value as? String {
                return "When \(app) launches"
            }
            return "App launch trigger"
        case .systemEvent:
            if let event = trigger.parameters["event"]?.value as? String {
                return "System event: \(event)"
            }
            return "System event trigger"
        case .hotkey:
            if let hotkey = trigger.parameters["hotkey"]?.value as? String {
                return "Hotkey: \(hotkey)"
            }
            return "Hotkey trigger"
        case .webhook:
            if let url = trigger.parameters["url"]?.value as? String {
                return "Webhook: \(url)"
            }
            return "Webhook trigger"
        }
    }
}

struct CreateWorkflowView: View {
    let workflowManager: WorkflowManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var naturalLanguageDescription = ""
    @State private var selectedTemplate: WorkflowTemplate?
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create New Workflow")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workflow Name")
                                .font(.headline)

                            TextField("Enter workflow name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)

                            TextField(
                                "Brief description of what this workflow does", text: $description,
                                axis: .vertical
                            )
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Creation Method")
                        .font(.headline)

                    VStack(spacing: 12) {
                        // Natural language creation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Describe in Natural Language")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            TextField(
                                "Describe what you want this workflow to do...",
                                text: $naturalLanguageDescription, axis: .vertical
                            )
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)

                            Text(
                                "Example: \"Copy all PDF files from Downloads to Desktop, then organize them by date\""
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)

                        // Template selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose from Template")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("Template", selection: $selectedTemplate) {
                                Text("None").tag(nil as WorkflowTemplate?)
                                ForEach(WorkflowManager.builtInTemplates, id: \.name) { template in
                                    Text(template.name).tag(template as WorkflowTemplate?)
                                }
                            }
                            .pickerStyle(.menu)

                            if let template = selectedTemplate {
                                Text(template.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("New Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createWorkflow()
                    }
                    .disabled(
                        name.isEmpty || isCreating
                            || (naturalLanguageDescription.isEmpty && selectedTemplate == nil))
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private func createWorkflow() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                if !naturalLanguageDescription.isEmpty {
                    // Create from natural language
                    _ = try await workflowManager.createWorkflowFromDescription(
                        naturalLanguageDescription,
                        name: name.isEmpty ? nil : name
                    )
                } else if let template = selectedTemplate {
                    // Create from template
                    _ = try await workflowManager.createWorkflowFromTemplate(
                        template,
                        parameters: [:]
                    )
                }

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

struct ImportWorkflowView: View {
    let workflowManager: WorkflowManager
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Import Workflow")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Select a workflow file (.json) to import")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Choose File...") {
                    importWorkflow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Import Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func importWorkflow() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            isImporting = true
            errorMessage = nil

            Task {
                do {
                    let data = try Data(contentsOf: url)
                    _ = try await workflowManager.importWorkflow(from: data)

                    await MainActor.run {
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isImporting = false
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension WorkflowTrigger.TriggerType {
    var displayName: String {
        switch self {
        case .manual:
            return "Manual"
        case .scheduled:
            return "Scheduled"
        case .fileChanged:
            return "File Changed"
        case .appLaunched:
            return "App Launched"
        case .systemEvent:
            return "System Event"
        case .hotkey:
            return "Hotkey"
        case .webhook:
            return "Webhook"
        }
    }
}

// MARK: - Workflow Template

struct WorkflowTemplate {
    let name: String
    let description: String
    let steps: [WorkflowStepDefinition]
    let variables: [String: AnyCodable]
    let triggers: [WorkflowTrigger]
    let tags: [String]
}

#Preview {
    let sampleVariables: [String: AnyCodable] = [
        "projectPath": AnyCodable("/Users/user/Projects"),
        "backupEnabled": AnyCodable(true),
        "maxFiles": AnyCodable(100),
    ]

    return WorkflowVariablesView(variables: sampleVariables)
        .padding()
}
