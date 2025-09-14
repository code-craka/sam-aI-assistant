//
//  ConsentDialogView.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

/// Dialog view for requesting user consent for privacy-sensitive operations
struct ConsentDialogView: View {
    
    // MARK: - Properties
    
    let request: ConsentManager.ConsentRequest
    @Environment(\.dismiss) private var dismiss
    @State private var showingDetails = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundColor(iconColor)
                
                Text("Permission Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(request.type.title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("Sam needs your permission to:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(request.type.description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !request.context.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Text("Context: \(request.context)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Details Toggle
            DisclosureGroup("View Details", isExpanded: $showingDetails) {
                VStack(alignment: .leading, spacing: 16) {
                    // Benefits
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Benefits")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        ForEach(request.type.benefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.green)
                                Text(benefit)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                    
                    // Risks
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Considerations")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        ForEach(request.type.risks, id: \.self) { risk in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.orange)
                                Text(risk)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                    
                    // Privacy Note
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Privacy Protection")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("You can revoke this permission at any time in Settings. All operations are logged for transparency.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
            .font(.subheadline)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Deny") {
                    request.onDeny()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(request.isRequired ? "Required" : "Allow") {
                    request.onApprove()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(false) // Could add logic to disable if needed
            }
        }
        .padding(24)
        .frame(width: 480, height: 600)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch request.type {
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
    
    private var iconColor: Color {
        switch request.type {
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
}

// MARK: - Preview

#Preview {
    ConsentDialogView(
        request: ConsentManager.ConsentRequest(
            type: .cloudProcessing,
            context: "Processing complex query about file organization",
            isRequired: false,
            onApprove: {},
            onDeny: {}
        )
    )
}