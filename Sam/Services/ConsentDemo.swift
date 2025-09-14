//
//  ConsentDemo.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

/// Demo application showing consent and transparency features
struct ConsentDemo: View {
    
    @StateObject private var consentManager = ConsentManager()
    @StateObject private var dataExportManager = DataExportManager()
    @StateObject private var transparencyManager: DataTransparencyManager
    
    @State private var showingConsentDialog = false
    @State private var showingPrivacySettings = false
    @State private var demoOutput = ""
    
    init() {
        let consentManager = ConsentManager()
        self._transparencyManager = StateObject(wrappedValue: DataTransparencyManager(consentManager: consentManager))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sam Privacy & Consent Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This demo shows how Sam handles user consent and data transparency")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Demo Actions
            VStack(spacing: 16) {
                Group {
                    Button("Test Cloud Processing Consent") {
                        Task {
                            await testCloudProcessingConsent()
                        }
                    }
                    
                    Button("Test File Access Consent") {
                        Task {
                            await testFileAccessConsent()
                        }
                    }
                    
                    Button("Test Data Export") {
                        Task {
                            await testDataExport()
                        }
                    }
                    
                    Button("Show Privacy Settings") {
                        showingPrivacySettings = true
                    }
                    
                    Button("Reset All Consents") {
                        Task {
                            await resetAllConsents()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            // Current Consent Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Consent Status:")
                    .font(.headline)
                
                ForEach(ConsentManager.ConsentType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: consentManager.hasConsent(for: type) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(consentManager.hasConsent(for: type) ? .green : .red)
                        
                        Text(type.title)
                        
                        Spacer()
                        
                        if let date = consentManager.getConsentDate(for: type) {
                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Demo Output
            if !demoOutput.isEmpty {
                ScrollView {
                    Text(demoOutput)
                        .font(.caption)
                        .fontFamily(.monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 800)
        .sheet(isPresented: $consentManager.showingConsentDialog) {
            if let request = consentManager.pendingConsentRequest {
                ConsentDialogView(request: request)
            }
        }
        .sheet(isPresented: $showingPrivacySettings) {
            NavigationView {
                PrivacySettingsView()
                    .navigationTitle("Privacy Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingPrivacySettings = false
                            }
                        }
                    }
            }
            .frame(width: 700, height: 600)
        }
    }
    
    // MARK: - Demo Methods
    
    private func testCloudProcessingConsent() async {
        appendOutput("Testing cloud processing consent...")
        
        let granted = await consentManager.requestConsent(
            for: .cloudProcessing,
            context: "Demo: Processing complex query about file organization"
        )
        
        if granted {
            appendOutput("✅ Cloud processing consent granted")
            
            // Simulate cloud request
            let success = await transparencyManager.requestCloudProcessing(
                provider: "OpenAI",
                queryType: "file_organization",
                dataSize: 1024,
                purpose: "Organize user files by type and date"
            )
            
            if success {
                appendOutput("🌐 Cloud processing request approved")
                
                // Simulate completion
                if let requestId = transparencyManager.currentCloudRequests.first?.id {
                    await transparencyManager.completeCloudRequest(
                        requestId: requestId,
                        success: true,
                        actualTokens: 150
                    )
                    appendOutput("✅ Cloud processing completed successfully")
                }
            } else {
                appendOutput("❌ Cloud processing request denied")
            }
        } else {
            appendOutput("❌ Cloud processing consent denied")
        }
    }
    
    private func testFileAccessConsent() async {
        appendOutput("Testing file access consent...")
        
        let granted = await consentManager.requestConsent(
            for: .fileAccess,
            context: "Demo: Organizing files in Downloads folder"
        )
        
        if granted {
            appendOutput("✅ File access consent granted")
            appendOutput("📁 Simulating file operations...")
            
            // Simulate file operations with audit logging
            let auditLogger = AuditLogger.shared
            await auditLogger.logFileOperation(
                operation: "organize",
                filePath: "~/Downloads",
                success: true
            )
            
            appendOutput("✅ File operations completed and logged")
        } else {
            appendOutput("❌ File access consent denied")
        }
    }
    
    private func testDataExport() async {
        appendOutput("Testing data export...")
        
        // Simulate export to temporary directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("demo_export")
        
        let result = await dataExportManager.exportAllData(to: tempDir, format: .json)
        
        if result.success {
            appendOutput("✅ Data export completed successfully")
            appendOutput("📊 Exported \(result.recordCount) records (\(result.fileSize) bytes)")
            if let path = result.exportPath {
                appendOutput("📁 Export location: \(path.path)")
            }
        } else {
            appendOutput("❌ Data export failed")
            if let error = result.error {
                appendOutput("Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func resetAllConsents() async {
        appendOutput("Resetting all consents...")
        await consentManager.resetAllConsents()
        appendOutput("🔄 All consents have been reset")
    }
    
    private func appendOutput(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        demoOutput += "[\(timestamp)] \(message)\n"
    }
}

// MARK: - Demo App

@main
struct ConsentDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ConsentDemo()
        }
    }
}

// MARK: - Preview

#Preview {
    ConsentDemo()
}