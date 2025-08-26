import SwiftUI

// Simple test to verify our implementation compiles
struct TestRunner {
    static func testAppState() {
        let appState = AppState()
        print("AppState created successfully")
        print("Theme mode: \(appState.themeMode)")
        print("Sidebar visibility: \(appState.sidebarVisibility)")
    }
    
    static func testViews() {
        // Test that our views can be instantiated
        let contentView = ContentView()
        let settingsView = SettingsView()
        let aboutView = AboutView()
        
        print("All views created successfully")
    }
}

// Run tests
#if DEBUG
extension TestRunner {
    static func runAllTests() {
        testAppState()
        testViews()
        print("All tests passed!")
    }
}
#endif