#!/usr/bin/env swift

import SwiftUI

// Demo script to test the onboarding and help system
// This demonstrates the key components of task 29

@main
struct OnboardingDemo: App {
    var body: some Scene {
        WindowGroup {
            OnboardingDemoView()
        }
    }
}

struct OnboardingDemoView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var helpManager = HelpManager()
    @StateObject private var commandSuggestionManager = CommandSuggestionManager()
    @State private var showingOnboarding = false
    @State private var showingHelp = false
    @State private var showingCommandPalette = false
    @State private var showingKeyboardShortcuts = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sam Onboarding & Help System Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Task 29 Implementation")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Show Onboarding Flow") {
                    onboardingManager.resetOnboarding()
                    showingOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Show Help System") {
                    showingHelp = true
                }
                .buttonStyle(.bordered)
                
                Button("Show Command Palette") {
                    showingCommandPalette = true
                }
                .buttonStyle(.bordered)
                
                Button("Show Keyboard Shortcuts") {
                    showingKeyboardShortcuts = true
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Features Implemented:")
                    .font(.headline)
                
                FeatureCheckmark(text: "Welcome flow with feature introduction")
                FeatureCheckmark(text: "Permission setup and API configuration")
                FeatureCheckmark(text: "In-app help system with categories")
                FeatureCheckmark(text: "Command examples and tutorials")
                FeatureCheckmark(text: "Contextual tips and suggestions")
                FeatureCheckmark(text: "Command discovery and suggestion system")
                FeatureCheckmark(text: "Keyboard shortcuts reference")
                FeatureCheckmark(text: "Smart command palette with search")
            }
            
            Spacer()
            
            Text("Onboarding Status: \(onboardingManager.isCompleted ? "Completed" : "Not Started")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .environmentObject(onboardingManager)
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
                .environmentObject(helpManager)
        }
        .sheet(isPresented: $showingCommandPalette) {
            CommandPaletteView()
        }
        .sheet(isPresented: $showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
    }
}

struct FeatureCheckmark: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

// MARK: - Mock Implementations for Demo

// These would normally be imported from the main app
class MockChatManager: ObservableObject {
    func sendMessage(_ message: String) async {
        print("Mock: Sending message: \(message)")
    }
}

class MockContextManager: ObservableObject {
    func getRecentFiles() -> [URL] {
        return [
            URL(fileURLWithPath: "/Users/demo/Documents/report.pdf"),
            URL(fileURLWithPath: "/Users/demo/Downloads/image.jpg"),
            URL(fileURLWithPath: "/Users/demo/Desktop/notes.txt")
        ]
    }
}

// Print demo information
print("=== Sam Onboarding & Help System Demo ===")
print("Task 29: Create onboarding and help system")
print("")
print("Components implemented:")
print("✓ OnboardingView - Multi-step welcome flow")
print("✓ HelpView - Comprehensive help system")
print("✓ CommandPaletteView - Command discovery")
print("✓ KeyboardShortcutsView - Shortcuts reference")
print("✓ CommandSuggestionsView - Contextual suggestions")
print("✓ OnboardingManager - State management")
print("✓ HelpManager - Help system coordination")
print("✓ CommandDiscoveryManager - Smart suggestions")
print("✓ AnalyticsManager - Usage tracking")
print("")
print("Features:")
print("• Welcome flow with feature introduction and setup")
print("• In-app help system with command examples and tutorials")
print("• Contextual tips and suggestions for new users")
print("• Command discovery and suggestion system")
print("• Keyboard shortcuts reference")
print("• Smart command palette with search and filtering")
print("• Permission setup guidance")
print("• API configuration assistance")
print("")
print("Run the demo to see the onboarding and help system in action!")