//
//  PrivacySettingsView.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

/// Privacy and data management settings view
struct PrivacySettingsView: View {
    
    // MARK: - Properties
    
    @StateObject private var consentManager = ConsentManager()
    @StateObject private var dataExportManager = DataExportManager()
    @State private var showingExportDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAuditLog = false
    @State private var selectedExportFormat: DataExportManager.ExportFormat = .json
    @State private var selectedDataTypes: Set<DataExportManager.DataType> = Set(DataExportManager.DataType.allCases)
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy & Data")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Manage your data and privacy preferences")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Consent Management
                consentSection
                
                Divider()
                
                // Data Export
                dataExportSection
                
                Divider()
                
                // Data Deletion
                dataDeletionSection
                
                Divider()
                
                // Audit & Transparency
                auditSection
            }
            .padding()
        }
        .sheet(isPresented: $showingExportDialog) {
            exportDialogView
        }
        .sheet(isPresented: $showingAuditLog) {
            auditLogView
        }
        .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                Task {
                    await deleteAllData()
                }
            }
        } message: {
            Text("This will permanently delete all your data including chat history, settings, and workflows. This action cannot be undone.")
        }
    }
    
    // MARK: - Consent Section
    
    private var consentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)
            
            Text("Control what Sam can access and do on your Mac")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(ConsentManager.ConsentType.allCases, id: \.self) { type in
                    consentCard(for: type)
                }
            }
        }
    }
    
    private func consentCard(for type: ConsentManager.ConsentType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: type))
                    .foregroundColor(iconColor(for: type))
                    .font(.title2)
                
                Spacer()
                
                Toggle("", isOn: binding(for: type))
                    .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            if let date = consentManager.getConsentDate(for: type) {
                Text("Granted: \(date, style: .date)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Data Export Section
    
    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Export")
                .font(.headline)
            
            Text("Export your data for backup or transfer to another service")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export All Data")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let lastExport = dataExportManager.lastExportDate {
                            Text("Last export: \(lastExport, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never exported")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Export...") {
                        showingExportDialog = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(dataExportManager.isExporting)
                }
                
                if dataExportManager.isExporting {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: dataExportManager.exportProgress)
                        Text(dataExportManager.exportStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Data Deletion Section
    
    private var dataDeletionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Deletion")
                .font(.headline)
            
            Text("Permanently remove your data from Sam")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delete All Data")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Permanently removes all chat history, settings, workflows, and audit logs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Delete All...") {
                        showingDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Audit Section
    
    private var auditSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transparency & Audit")
                .font(.headline)
            
            Text("View logs of all privacy-sensitive operations")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audit Log")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("View all data access, consent changes, and privacy operations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("View Log") {
                        showingAuditLog = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Export Dialog
    
    private var exportDialogView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Your Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Format Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Format")
                        .font(.headline)
                    
                    Picker("Format", selection: $selectedExportFormat) {
                        ForEach(DataExportManager.ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Data Type Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data to Export")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(DataExportManager.DataType.allCases, id: \.self) { dataType in
                            Toggle(dataType.displayName, isOn: Binding(
                                get: { selectedDataTypes.contains(dataType) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDataTypes.insert(dataType)
                                    } else {
                                        selectedDataTypes.remove(dataType)
                                    }
                                }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack {
                    Button("Cancel") {
                        showingExportDialog = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Export") {
                        Task {
                            await exportData()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedDataTypes.isEmpty)
                }
            }
            .padding()
            .frame(width: 400, height: 500)
        }
    }
    
    // MARK: - Audit Log View
    
    private var auditLogView: some View {
        NavigationView {
            AuditLogView()
                .navigationTitle("Audit Log")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showingAuditLog = false
                        }
                    }
                }
        }
        .frame(width: 600, height: 500)
    }
    
    // MARK: - Helper Methods
    
    private func binding(for type: ConsentManager.ConsentType) -> Binding<Bool> {
        switch type {
        case .cloudProcessing:
            return $consentManager.cloudProcessingConsent
        case .fileAccess:
            return $consentManager.fileAccessConsent
        case .systemAccess:
            return $consentManager.systemAccessConsent
        case .dataCollection:
            return $consentManager.dataCollectionConsent
        case .automation:
            return Binding(
                get: { consentManager.hasConsent(for: type) },
                set: { granted in
                    Task {
                        if granted {
                            await consentManager.grantConsent(for: type, context: "Settings toggle")
                        } else {
                            await consentManager.revokeConsent(for: type)
                        }
                    }
                }
            )
        case .networkAccess:
            return Binding(
                get: { consentManager.hasConsent(for: type) },
                set: { granted in
                    Task {
                        if granted {
                            await consentManager.grantConsent(for: type, context: "Settings toggle")
                        } else {
                            await consentManager.revokeConsent(for: type)
                        }
                    }
                }
            )
        }
    }
    
    private func iconName(for type: ConsentManager.ConsentType) -> String {
        switch type {
        case .cloudProcessing:
            return "cloud.fill"
        case .fileAccess:
            return "folder.fill"
        case .systemAccess:
            return "desktopcomputer"
        case .dataCollection:
            return "chart.bar.fill"
        case .automation:
            return "gearshape.2.fill"
        case .networkAccess:
            return "network"
        }
    }
    
    private func iconColor(for type: ConsentManager.ConsentType) -> Color {
        switch type {
        case .cloudProcessing:
            return .blue
        case .fileAccess:
            return .orange
        case .systemAccess:
            return .purple
        case .dataCollection:
            return .green
        case .automation:
            return .red
        case .networkAccess:
            return .cyan
        }
    }
    
    private func exportData() async {
        // Show file picker and export
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Sam_Export_\(Date().formatted(.iso8601.year().month().day()))"
        
        if panel.runModal() == .OK, let url = panel.url {
            let _ = await dataExportManager.exportAllData(to: url, format: selectedExportFormat)
        }
        
        showingExportDialog = false
    }
    
    private func deleteAllData() async {
        let _ = await dataExportManager.deleteAllData()
        await consentManager.resetAllConsents()
    }
}

// MARK: - Preview

#Preview {
    PrivacySettingsView()
}