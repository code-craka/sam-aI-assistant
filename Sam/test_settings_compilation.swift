import SwiftUI

// Simple test to verify SettingsView compiles correctly
struct SettingsTestView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        SettingsView()
            .environmentObject(appState)
    }
}

// Test that SettingsManager initializes correctly
func testSettingsManager() {
    let settingsManager = SettingsManager()
    print("SettingsManager initialized successfully")
    print("Has API Key: \(settingsManager.hasAPIKey)")
    print("Preferred Model: \(settingsManager.userPreferences.preferredModel.displayName)")
    print("Theme Mode: \(settingsManager.userPreferences.themeMode.displayName)")
}

// Run the test
testSettingsManager()