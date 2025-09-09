import SwiftUI
import CoreData

@main
struct SamApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup("Sam AI Assistant") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
                .onAppear {
                    setupAppearance()
                    initializePerformanceMonitoring()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1000, height: 700)
        .commands {
            SamCommands()
        }
        
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 500)
    }
    
    private func setupAppearance() {
        // Configure app-wide appearance settings
        NSApp.appearance = appState.nsAppearance
    }
    
    private func initializePerformanceMonitoring() {
        // Initialize performance monitoring system
        PerformanceSetup.initializePerformanceMonitoring()
        
        #if DEBUG
        // Run performance demo in debug builds
        Task {
            await PerformanceDemo.runQuickTest()
        }
        #endif
    }
}

struct SamCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Chat") {
                NotificationCenter.default.post(name: .newChatRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])
            
            Divider()
            
            Button("Clear Chat History") {
                NotificationCenter.default.post(name: .clearChatRequested, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }
        
        CommandGroup(after: .sidebar) {
            Button("Toggle Sidebar") {
                NotificationCenter.default.post(name: .toggleSidebarRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }
        
        CommandGroup(after: .windowArrangement) {
            Button("Focus Chat Input") {
                NotificationCenter.default.post(name: .focusChatInputRequested, object: nil)
            }
            .keyboardShortcut("/", modifiers: [.command])
        }
        
        CommandGroup(after: .help) {
            Button("Sam Help") {
                NotificationCenter.default.post(name: .helpRequested, object: nil)
            }
            .keyboardShortcut("?", modifiers: [.command])
            
            Button("About Sam") {
                NotificationCenter.default.post(name: .aboutRequested, object: nil)
            }
        }
    }
}

// MARK: - Core Data Stack is now in PersistenceController.swift
// 
// MARK: - Notification Names

extension Notification.Name {
    static let newChatRequested = Notification.Name("newChatRequested")
    static let clearChatRequested = Notification.Name("clearChatRequested")
    static let toggleSidebarRequested = Notification.Name("toggleSidebarRequested")
    static let focusChatInputRequested = Notification.Name("focusChatInputRequested")
    static let helpRequested = Notification.Name("helpRequested")
    static let aboutRequested = Notification.Name("aboutRequested")
    static let switchToWorkflowsRequested = Notification.Name("switchToWorkflowsRequested")
}