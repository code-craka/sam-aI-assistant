//
//  AuditLogView.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

/// View for displaying audit logs and privacy operations
struct AuditLogView: View {
    
    // MARK: - Properties
    
    @State private var auditEvents: [AuditLogger.AuditEvent] = []
    @State private var filteredEvents: [AuditLogger.AuditEvent] = []
    @State private var selectedEventType: AuditLogger.AuditEventType? = nil
    @State private var selectedSeverity: AuditLogger.AuditEvent.Severity? = nil
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showingExportDialog = false
    @State private var showingClearConfirmation = false
    @State private var auditStatistics: AuditStatistics?
    
    private let auditLogger = AuditLogger.shared
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with statistics
            if let stats = auditStatistics {
                statisticsHeader(stats)
                    .padding()
                    .background(Color(.controlBackgroundColor))
            }
            
            // Filters
            filtersSection
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            Divider()
            
            // Events List
            if isLoading {
                Spacer()
                ProgressView("Loading audit events...")
                Spacer()
            } else if filteredEvents.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Events Found")
                        .font(.headline)
                    
                    Text("No audit events match your current filters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                eventsList
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Export") {
                    showingExportDialog = true
                }
                .disabled(auditEvents.isEmpty)
                
                Button("Clear") {
                    showingClearConfirmation = true
                }
                .disabled(auditEvents.isEmpty)
            }
        }
        .task {
            await loadAuditEvents()
        }
        .onChange(of: selectedEventType) { _ in
            filterEvents()
        }
        .onChange(of: selectedSeverity) { _ in
            filterEvents()
        }
        .onChange(of: searchText) { _ in
            filterEvents()
        }
        .sheet(isPresented: $showingExportDialog) {
            exportDialogView
        }
        .alert("Clear Audit Log", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await clearAuditLog()
                }
            }
        } message: {
            Text("This will permanently delete all audit log entries. This action cannot be undone.")
        }
    }
    
    // MARK: - Statistics Header
    
    private func statisticsHeader(_ stats: AuditStatistics) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(stats.totalEvents)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Log Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(stats.logFileSize), countStyle: .file))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            if let oldest = stats.oldestEvent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Oldest Event")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(oldest, style: .date)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            // Severity breakdown
            HStack(spacing: 16) {
                ForEach([AuditLogger.AuditEvent.Severity.low, .medium, .high, .critical], id: \.self) { severity in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(colorForSeverity(severity))
                            .frame(width: 8, height: 8)
                        Text("\(stats.severityCounts[severity] ?? 0)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search events...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            
            // Event Type Filter
            Picker("Type", selection: $selectedEventType) {
                Text("All Types").tag(nil as AuditLogger.AuditEventType?)
                ForEach(AuditLogger.AuditEventType.allCases, id: \.self) { type in
                    Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .tag(type as AuditLogger.AuditEventType?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            // Severity Filter
            Picker("Severity", selection: $selectedSeverity) {
                Text("All Levels").tag(nil as AuditLogger.AuditEvent.Severity?)
                ForEach([AuditLogger.AuditEvent.Severity.low, .medium, .high, .critical], id: \.self) { severity in
                    HStack {
                        Circle()
                            .fill(colorForSeverity(severity))
                            .frame(width: 8, height: 8)
                        Text(severity.rawValue.capitalized)
                    }
                    .tag(severity as AuditLogger.AuditEvent.Severity?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
    }
    
    // MARK: - Events List
    
    private var eventsList: some View {
        List(filteredEvents, id: \.id) { event in
            AuditEventRow(event: event)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Export Dialog
    
    private var exportDialogView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Audit Log")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Export the complete audit log for external analysis or backup.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack {
                    Button("Cancel") {
                        showingExportDialog = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Export") {
                        Task {
                            await exportAuditLog()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 300, height: 200)
        }
    }
    
    // MARK: - Methods
    
    private func loadAuditEvents() async {
        isLoading = true
        
        auditEvents = await auditLogger.getAllAuditEvents()
        auditStatistics = await auditLogger.getAuditStatistics()
        
        filterEvents()
        isLoading = false
    }
    
    private func filterEvents() {
        var filtered = auditEvents
        
        // Filter by event type
        if let selectedType = selectedEventType {
            filtered = filtered.filter { $0.type == selectedType }
        }
        
        // Filter by severity
        if let selectedSeverity = selectedSeverity {
            filtered = filtered.filter { $0.severity == selectedSeverity }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { event in
                event.description.localizedCaseInsensitiveContains(searchText) ||
                event.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
                event.metadata.values.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        filteredEvents = filtered
    }
    
    private func colorForSeverity(_ severity: AuditLogger.AuditEvent.Severity) -> Color {
        switch severity {
        case .low:
            return .green
        case .medium:
            return .blue
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private func exportAuditLog() async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "audit_log_\(Date().formatted(.iso8601.year().month().day())).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try await auditLogger.exportAuditLog(to: url)
            } catch {
                // Handle error
                print("Export failed: \(error)")
            }
        }
        
        showingExportDialog = false
    }
    
    private func clearAuditLog() async {
        do {
            try await auditLogger.clearAuditLog()
            await loadAuditEvents()
        } catch {
            // Handle error
            print("Clear failed: \(error)")
        }
    }
}

// MARK: - Audit Event Row

struct AuditEventRow: View {
    let event: AuditLogger.AuditEvent
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Severity indicator
                Circle()
                    .fill(colorForSeverity(event.severity))
                    .frame(width: 8, height: 8)
                
                // Timestamp
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                // Type
                Text(event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                
                Spacer()
                
                // User initiated indicator
                if event.userInitiated {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                // Expand button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Description
            Text(event.description)
                .font(.subheadline)
                .lineLimit(isExpanded ? nil : 2)
            
            // Metadata (when expanded)
            if isExpanded && !event.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Details:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(event.metadata.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text("\(key):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(event.metadata[key] ?? "")
                                .font(.caption)
                                .fontFamily(.monospaced)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private func colorForSeverity(_ severity: AuditLogger.AuditEvent.Severity) -> Color {
        switch severity {
        case .low:
            return .green
        case .medium:
            return .blue
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    AuditLogView()
}