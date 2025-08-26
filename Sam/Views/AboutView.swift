import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon and Title
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                
                Text("Sam AI Assistant")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("About Sam")
                    .font(.headline)
                
                Text("Sam is a native macOS AI assistant that performs actual tasks rather than just providing instructions. Built with privacy-first principles, Sam combines local processing with intelligent cloud integration to help you manage files, control applications, and automate workflows.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                Text("Key Features")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(icon: "folder", text: "File system operations")
                    FeatureRow(icon: "info.circle", text: "System information queries")
                    FeatureRow(icon: "app.badge", text: "Application integration")
                    FeatureRow(icon: "gearshape.2", text: "Workflow automation")
                    FeatureRow(icon: "hand.raised", text: "Privacy-first design")
                }
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("Built with SwiftUI for macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .controlSize(.large)
            }
        }
        .padding(30)
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About Sam AI Assistant")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 16)
                .accessibilityHidden(true)
            
            Text(text)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AboutView()
}