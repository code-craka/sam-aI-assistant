import Foundation
import AppKit

// MARK: - App Integration Manager
@MainActor
class AppIntegrationManager: ObservableObject {
    
    // MARK: - Properties
    @Published var registeredIntegrations: [String: AppIntegration] = [:]
    @Published var isInitialized = false
    
    private let commandParser = CommandParser()
    private let appDiscovery = AppDiscoveryService()
    private let workspace = NSWorkspace.shared
    
    // Integration engines
    private lazy var urlSchemeHandler = URLSchemeHandler()
    private lazy var appleScriptEngine = AppleScriptEngine()
    private lazy var accessibilityController = AccessibilityController()
    
    // MARK: - Initialization
    
    init() {
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        // Discover installed apps
        await appDiscovery.discoverInstalledApps()
        
        // Register built-in integrations
        await registerBuiltInIntegrations()
        
        await MainActor.run {
            isInitialized = true
        }
    }
    
    // MARK: - Public Methods
    
    /// Execute a natural language command
    func executeCommand(_ command: String) async throws -> CommandResult {
        let parsedCommand = commandParser.parseCommand(command)
        
        // Find target application
        guard let targetApp = parsedCommand.targetApplication else {
            throw AppIntegrationError.commandNotSupported("No target application found in command")
        }
        
        // Get integration for the app
        guard let integration = registeredIntegrations[targetApp] else {
            throw AppIntegrationError.appNotInstalled(targetApp)
        }
        
        // Check if integration can handle the command
        guard integration.canHandle(parsedCommand) else {
            throw AppIntegrationError.commandNotSupported(parsedCommand.originalText)
        }
        
        // Execute the command
        return try await integration.execute(parsedCommand)
    }
    
    /// Register a custom app integration
    func registerIntegration(_ integration: AppIntegration) {
        registeredIntegrations[integration.bundleIdentifier] = integration
    }
    
    /// Get available integrations
    func getAvailableIntegrations() -> [AppIntegration] {
        return Array(registeredIntegrations.values)
    }
    
    /// Get integration for specific app
    func getIntegration(for bundleIdentifier: String) -> AppIntegration? {
        return registeredIntegrations[bundleIdentifier]
    }
    
    /// Check if app integration is available
    func isIntegrationAvailable(for bundleIdentifier: String) -> Bool {
        return registeredIntegrations[bundleIdentifier] != nil
    }
    
    /// Get supported commands for an app
    func getSupportedCommands(for bundleIdentifier: String) -> [CommandDefinition] {
        return registeredIntegrations[bundleIdentifier]?.supportedCommands ?? []
    }
    
    /// Launch application
    func launchApp(_ bundleIdentifier: String) async throws -> CommandResult {
        let startTime = Date()
        
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppIntegrationError.appNotInstalled(bundleIdentifier)
        }
        
        do {
            try workspace.launchApplication(at: appURL, options: [], configuration: [:])
            
            let executionTime = Date().timeIntervalSince(startTime)
            let appName = appDiscovery.findApp(bundleIdentifier: bundleIdentifier)?.displayName ?? bundleIdentifier
            
            return CommandResult(
                success: true,
                output: "Successfully launched \(appName)",
                executionTime: executionTime,
                integrationMethod: .accessibility
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.accessibility, error.localizedDescription)
        }
    }
    
    /// Quit application
    func quitApp(_ bundleIdentifier: String) async throws -> CommandResult {
        let startTime = Date()
        
        guard let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AppIntegrationError.appNotRunning(bundleIdentifier)
        }
        
        let success = runningApp.terminate()
        let executionTime = Date().timeIntervalSince(startTime)
        let appName = appDiscovery.findApp(bundleIdentifier: bundleIdentifier)?.displayName ?? bundleIdentifier
        
        if success {
            return CommandResult(
                success: true,
                output: "Successfully quit \(appName)",
                executionTime: executionTime,
                integrationMethod: .accessibility
            )
        } else {
            throw AppIntegrationError.integrationMethodFailed(.accessibility, "Failed to quit application")
        }
    }
    
    // MARK: - Private Methods
    
    private func registerBuiltInIntegrations() async {
        // Register Safari integration
        if appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.Safari") {
            let safariIntegration = SafariIntegration(
                appDiscovery: appDiscovery,
                urlSchemeHandler: urlSchemeHandler,
                appleScriptEngine: appleScriptEngine
            )
            registeredIntegrations["com.apple.Safari"] = safariIntegration
        }
        
        // Register Mail integration
        if appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.mail") {
            let mailIntegration = MailIntegration(
                appDiscovery: appDiscovery,
                urlSchemeHandler: urlSchemeHandler,
                appleScriptEngine: appleScriptEngine
            )
            registeredIntegrations["com.apple.mail"] = mailIntegration
        }
        
        // Register Calendar integration
        if appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.iCal") {
            let calendarIntegration = CalendarIntegration(
                appDiscovery: appDiscovery,
                urlSchemeHandler: urlSchemeHandler,
                appleScriptEngine: appleScriptEngine
            )
            registeredIntegrations["com.apple.iCal"] = calendarIntegration
        }
        
        // Register Finder integration
        if appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.finder") {
            let finderIntegration = FinderIntegration(
                appDiscovery: appDiscovery,
                appleScriptEngine: appleScriptEngine
            )
            registeredIntegrations["com.apple.finder"] = finderIntegration
        }
        
        // Register Contacts integration
        if appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.AddressBook") {
            let contactsIntegration = ContactsIntegration(
                appDiscovery: appDiscovery,
                appleScriptEngine: appleScriptEngine
            )
            registeredIntegrations["com.apple.AddressBook"] = contactsIntegration
        }
        
        // Register Reminders integration
        if appDiscovery.isAppInstalled(bundleIdentifier: "com.apple.reminders") {
            let remindersIntegration = RemindersIntegration(
                appDiscovery: appDiscovery,
                appleScriptEngine: appleScriptEngine
            )
            registeredIntegrations["com.apple.reminders"] = remindersIntegration
        }
        
        // Register generic integration for other apps
        for app in appDiscovery.discoveredApps {
            if registeredIntegrations[app.bundleIdentifier] == nil {
                let genericIntegration = GenericAppIntegration(
                    appInfo: app,
                    appDiscovery: appDiscovery,
                    appleScriptEngine: appleScriptEngine,
                    accessibilityController: accessibilityController
                )
                registeredIntegrations[app.bundleIdentifier] = genericIntegration
            }
        }
    }
}

// MARK: - Integration Engines

/// URL Scheme Handler
class URLSchemeHandler {
    func openURL(_ url: URL) async throws -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let success = NSWorkspace.shared.open(url)
                continuation.resume(returning: success)
            }
        }
    }
    
    func canHandleScheme(_ scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }
}

/// AppleScript Engine
class AppleScriptEngine {
    func executeScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var errorDict: NSDictionary?
                
                if let result = appleScript?.executeAndReturnError(&errorDict) {
                    continuation.resume(returning: result.stringValue ?? "")
                } else if let error = errorDict {
                    let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown AppleScript error"
                    continuation.resume(throwing: AppIntegrationError.integrationMethodFailed(.appleScript, errorMessage))
                } else {
                    continuation.resume(throwing: AppIntegrationError.integrationMethodFailed(.appleScript, "Script execution failed"))
                }
            }
        }
    }
    
    func validateScript(_ script: String) -> Bool {
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        appleScript?.compileAndReturnError(&errorDict)
        return errorDict == nil
    }
}

/// Accessibility Controller
class AccessibilityController {
    func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func getApplicationElement(for bundleIdentifier: String) -> AXUIElement? {
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return nil
        }
        
        return AXUIElementCreateApplication(runningApp.processIdentifier)
    }
}