import SwiftUI

struct CommandSuggestionsView: View {
    @ObservedObject var discoveryManager: CommandDiscoveryManager
    @State private var expandedSuggestion: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !discoveryManager.suggestions.isEmpty {
                suggestionsList
            }
            
            if !discoveryManager.contextualTips.isEmpty {
                contextualTipsSection
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
    
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.accentColor)
                
                Text("Suggestions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Dismiss All") {
                    dismissAllSuggestions()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(discoveryManager.suggestions.sorted(by: { $0.priority.rawValue > $1.priority.rawValue })) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        isExpanded: expandedSuggestion == suggestion.id,
                        onTap: { toggleExpansion(suggestion.id) },
                        onUse: { discoveryManager.useSuggestion(suggestion) },
                        onDismiss: { discoveryManager.dismissSuggestion(suggestion) }
                    )
                }
            }
        }
    }
    
    private var contextualTipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                Text("Tips")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            ContextualTipsView(tips: discoveryManager.contextualTips)
        }
    }
    
    private func toggleExpansion(_ suggestionId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedSuggestion = expandedSuggestion == suggestionId ? nil : suggestionId
        }
    }
    
    private func dismissAllSuggestions() {
        withAnimation {
            for suggestion in discoveryManager.suggestions {
                discoveryManager.dismissSuggestion(suggestion)
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: CommandSuggestion
    let isExpanded: Bool
    let onTap: () -> Void
    let onUse: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main content
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        priorityIndicator
                        
                        Text(suggestion.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        categoryBadge
                    }
                    
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                VStack(spacing: 4) {
                    Button(action: onUse) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Use suggestion")
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Dismiss")
                }
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Text("Command:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(suggestion.command)
                            .font(.caption)
                            .fontFamily(.monospaced)
                            .padding(6)
                            .background(Color(.quaternarySystemFill))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(suggestion.command, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy command")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(priorityColor.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
    }
    
    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
    }
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
    
    private var categoryBadge: some View {
        Text(categoryTitle)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor.opacity(0.2))
            .foregroundColor(categoryColor)
            .cornerRadius(4)
    }
    
    private var categoryTitle: String {
        switch suggestion.category {
        case .fileOperations: return "Files"
        case .systemInfo: return "System"
        case .appControl: return "Apps"
        case .workflows: return "Workflows"
        case .help: return "Help"
        }
    }
    
    private var categoryColor: Color {
        switch suggestion.category {
        case .fileOperations: return .blue
        case .systemInfo: return .green
        case .appControl: return .purple
        case .workflows: return .orange
        case .help: return .gray
        }
    }
}

// MARK: - Floating Suggestions View

struct FloatingSuggestionsView: View {
    @ObservedObject var discoveryManager: CommandDiscoveryManager
    @State private var isVisible = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                if discoveryManager.showingSuggestions && isVisible {
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(discoveryManager.suggestions.prefix(3)) { suggestion in
                            FloatingSuggestionCard(
                                suggestion: suggestion,
                                onUse: { discoveryManager.useSuggestion(suggestion) },
                                onDismiss: { discoveryManager.dismissSuggestion(suggestion) }
                            )
                        }
                        
                        if discoveryManager.suggestions.count > 3 {
                            Button("Show All (\(discoveryManager.suggestions.count))") {
                                // Show full suggestions view
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .padding()
        }
        .onChange(of: discoveryManager.showingSuggestions) { showing in
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = showing
            }
        }
    }
}

struct FloatingSuggestionCard: View {
    let suggestion: CommandSuggestion
    let onUse: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(suggestion.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 4) {
                Button(action: onUse) {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .frame(maxWidth: 200)
    }
}

// MARK: - Smart Input Suggestions

struct SmartInputSuggestionsView: View {
    let inputText: String
    let suggestions: [String]
    let onSuggestionSelected: (String) -> Void
    
    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionSelected(suggestion)
                    }) {
                        HStack {
                            Text(suggestion)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)
        }
    }
}

#Preview {
    let discoveryManager = CommandDiscoveryManager(
        chatManager: ChatManager(),
        contextManager: ContextManager()
    )
    
    return CommandSuggestionsView(discoveryManager: discoveryManager)
}