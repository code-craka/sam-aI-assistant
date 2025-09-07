import Foundation
import AppKit

// MARK: - App Discovery Service
class AppDiscoveryService: ObservableObject {
    
    // MARK: - Properties
    @Published var discoveredApps: [AppDiscoveryResult] = []
    @Published var isScanning = false
    
    private let workspace = NSWorkspace.shared
    private let fileManager = FileManager.default
    
    // Common application directories
    private let appDirectories = [
        "/Applications",
        "/System/Applications",
        "/System/Library/CoreServices",
        "~/Applications"
    ]
    
    // Known app integrations and their capabilities
    private let knownIntegrations: [String: (methods: [IntegrationMethod], capabilities: AppCapabilities)] = [
        "com.apple.Safari": (
            methods: [.urlScheme, .appleScript, .accessibility],
            capabilities: AppCapabilities(
                canLaunch: true,
                canQuit: true,
                canOpenFiles: true,
                canManageWindows: true,
                canAccessMenus: true,
                customCapabilities: [
                    "canOpenURL": true,
                    "canBookmark": true,
                    "canNavigate": true,
                    "canManageTabs": true
                ]
            )
        ),
        "com.apple.mail": (
            methods: [.urlScheme, .appleScript, .accessibility],
            capabilities: AppCapabilities(
                canLaunch: true,
                canQuit: true,
                canCreateDocuments: true,
                canOpenFiles: true,
                canSaveFiles: true,
                customCapabilities: [
                    "canCompose": true,
                    "canSend": true,
                    "canSearch": true,
                    "canManageMailboxes": true
                ]
            )
        ),
        "com.apple.iCal": (
            methods: [.urlScheme, .appleScript, .accessibility],
            capabilities: AppCapabilities(
                canLaunch: true,
                canQuit: true,
                canCreateDocuments: true,
                canSaveFiles: true,
                customCapabilities: [
                    "canCreateEvent": true,
                    "canCreateReminder": true,
                    "canSearch": true
                ]
            )
        ),
        "com.apple.finder": (
            methods: [.appleScript, .accessibility],
            capabilities: AppCapabilities(
                canLaunch: true,
                canOpenFiles: true,
                canManageWindows: true,
                canAccessMenus: true,
                customCapabilities: [
                    "canNavigate": true,
                    "canSearch": true,
                    "canCreateFolder": true,
                    "canRevealFile": true
                ]
            )
        ),
        "com.apple.Notes": (
            methods: [.urlScheme, .appleScript, .accessibility],
            capabilities: AppCapabilities(
                canLaunch: true,
                canQuit: true,
                canCreateDocuments: true,
                canSaveFiles: true,
                customCapabilities: [
                    "canCreateNote": true,
                    "canSearch": true,
                    "canShare": true
                ]
            )
        )
    ]
    
    // MARK: - Public Methods
    
    /// Discover all installed applications
    func discoverInstalledApps() async {
        await MainActor.run {
            isScanning = true
            discoveredApps.removeAll()
        }
        
        var apps: [AppDiscoveryResult] = []
        
        // Scan application directories
        for directory in appDirectories {
            let expandedPath = NSString(string: directory).expandingTildeInPath
            apps.append(contentsOf: await scanDirectory(expandedPath))
        }
        
        // Get running applications
        let runningApps = workspace.runningApplications
        for runningApp in runningApps {
            if let bundleId = runningApp.bundleIdentifier,
               let bundleURL = runningApp.bundleURL {
                
                // Update existing app or add new one
                if let index = apps.firstIndex(where: { $0.bundleIdentifier == bundleId }) {
                    var updatedApp = apps[index]
                    updatedApp = AppDiscoveryResult(
                        bundleIdentifier: updatedApp.bundleIdentifier,
                        displayName: updatedApp.displayName,
                        version: updatedApp.version,
                        path: updatedApp.path,
                        isRunning: true,
                        supportedIntegrationMethods: updatedApp.supportedIntegrationMethods,
                        capabilities: updatedApp.capabilities
                    )
                    apps[index] = updatedApp
                } else {
                    // Add running app that wasn't found in directories
                    let appInfo = await getAppInfo(at: bundleURL)
                    if let info = appInfo {
                        apps.append(AppDiscoveryResult(
                            bundleIdentifier: bundleId,
                            displayName: info.displayName,
                            version: info.version,
                            path: bundleURL.path,
                            isRunning: true,
                            supportedIntegrationMethods: info.supportedIntegrationMethods,
                            capabilities: info.capabilities
                        ))
                    }
                }
            }
        }
        
        // Sort apps by name
        apps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        
        await MainActor.run {
            discoveredApps = apps
            isScanning = false
        }
    }
    
    /// Find specific app by bundle identifier
    func findApp(bundleIdentifier: String) -> AppDiscoveryResult? {
        return discoveredApps.first { $0.bundleIdentifier == bundleIdentifier }
    }
    
    /// Find apps by name (fuzzy matching)
    func findApps(byName name: String) -> [AppDiscoveryResult] {
        let lowercaseName = name.lowercased()
        return discoveredApps.filter { app in
            app.displayName.lowercased().contains(lowercaseName) ||
            app.bundleIdentifier.lowercased().contains(lowercaseName)
        }
    }
    
    /// Check if app is installed
    func isAppInstalled(bundleIdentifier: String) -> Bool {
        return discoveredApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }
    
    /// Check if app is currently running
    func isAppRunning(bundleIdentifier: String) -> Bool {
        return workspace.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }
    
    /// Get app capabilities
    func getAppCapabilities(bundleIdentifier: String) -> AppCapabilities? {
        return findApp(bundleIdentifier: bundleIdentifier)?.capabilities
    }
    
    /// Get supported integration methods for app
    func getSupportedIntegrationMethods(bundleIdentifier: String) -> [IntegrationMethod] {
        return findApp(bundleIdentifier: bundleIdentifier)?.supportedIntegrationMethods ?? []
    }
    
    // MARK: - Private Methods
    
    private func scanDirectory(_ path: String) async -> [AppDiscoveryResult] {
        var apps: [AppDiscoveryResult] = []
        
        guard fileManager.fileExists(atPath: path) else { return apps }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            for item in contents {
                let itemPath = (path as NSString).appendingPathComponent(item)
                
                if item.hasSuffix(".app") {
                    let appURL = URL(fileURLWithPath: itemPath)
                    if let appInfo = await getAppInfo(at: appURL) {
                        apps.append(appInfo)
                    }
                }
            }
        } catch {
            print("Error scanning directory \(path): \(error)")
        }
        
        return apps
    }
    
    private func getAppInfo(at url: URL) async -> AppDiscoveryResult? {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return nil }
        
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                         bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                         url.deletingPathExtension().lastPathComponent
        
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        
        // Determine supported integration methods
        let integrationMethods = await determineSupportedIntegrationMethods(for: bundleId, bundle: bundle)
        
        // Get capabilities
        let capabilities = getCapabilities(for: bundleId, bundle: bundle)
        
        // Check if app is running
        let isRunning = workspace.runningApplications.contains { $0.bundleIdentifier == bundleId }
        
        return AppDiscoveryResult(
            bundleIdentifier: bundleId,
            displayName: displayName,
            version: version,
            path: url.path,
            isRunning: isRunning,
            supportedIntegrationMethods: integrationMethods,
            capabilities: capabilities
        )
    }
    
    private func determineSupportedIntegrationMethods(for bundleId: String, bundle: Bundle) async -> [IntegrationMethod] {
        var methods: [IntegrationMethod] = []
        
        // Check if we have known integration info
        if let knownInfo = knownIntegrations[bundleId] {
            return knownInfo.methods
        }
        
        // Check for URL schemes
        if let urlTypes = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
            if !urlTypes.isEmpty {
                methods.append(.urlScheme)
            }
        }
        
        // All apps support AppleScript to some degree
        methods.append(.appleScript)
        
        // All apps support Accessibility API
        methods.append(.accessibility)
        
        // Check for native SDK support (this would be app-specific)
        if await hasNativeSDKSupport(bundleId: bundleId) {
            methods.append(.nativeSDK)
        }
        
        // GUI automation is always available as fallback
        methods.append(.guiAutomation)
        
        return methods.sorted { $0.priority < $1.priority }
    }
    
    private func hasNativeSDKSupport(bundleId: String) async -> Bool {
        // This would check for specific SDK integrations
        // For now, return false as most apps don't have native SDK support
        return false
    }
    
    private func getCapabilities(for bundleId: String, bundle: Bundle) -> AppCapabilities {
        // Check if we have known capabilities
        if let knownInfo = knownIntegrations[bundleId] {
            return knownInfo.capabilities
        }
        
        // Determine capabilities based on app type and bundle info
        var capabilities = AppCapabilities()
        
        // Check document types
        if let documentTypes = bundle.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]] {
            if !documentTypes.isEmpty {
                capabilities = AppCapabilities(
                    canLaunch: true,
                    canQuit: true,
                    canCreateDocuments: true,
                    canOpenFiles: true,
                    canSaveFiles: true
                )
            }
        }
        
        // Check if it's a system app
        if bundleId.hasPrefix("com.apple.") {
            capabilities = AppCapabilities(
                canLaunch: true,
                canQuit: true,
                canManageWindows: true,
                canAccessMenus: true
            )
        }
        
        return capabilities
    }
}