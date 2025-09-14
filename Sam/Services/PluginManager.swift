import Foundation
import Combine

// MARK: - Plugin Protocol
protocol SamPlugin {
    var identifier: String { get }
    var name: String { get }
    var version: String { get }
    var description: String { get }
    var author: String { get }
    var supportedCommands: [String] { get }
    var requiredPermissions: [PluginPermission] { get }
    
    func initialize() async throws
    func canHandle(_ command: String) -> Bool
    func execute(_ command: String, context: PluginContext) async throws -> PluginResult
    func cleanup() async
}

// MARK: - Plugin Permission System
enum PluginPermission: String, CaseIterable {
    case fileSystem = "file_system"
    case networkAccess = "network_access"
    case systemInfo = "system_info"
    case appControl = "app_control"
    case userNotifications = "user_notifications"
    case keychain = "keychain"
    
    var description: String {
        switch self {
        case .fileSystem:
            return "Access to file system operations"
        case .networkAccess:
            return "Access to network and internet"
        case .systemInfo:
            return "Access to system information"
        case .appControl:
            return "Control other applications"
        case .userNotifications:
            return "Send user notifications"
        case .keychain:
            return "Access to secure keychain storage"
        }
    }
}

// MARK: - Plugin Context
struct PluginContext {
    let userInput: String
    let conversationHistory: [ChatMessage]
    let systemInfo: SystemInfo?
    let currentDirectory: URL?
    let selectedFiles: [URL]
    let environment: [String: String]
    
    // Helper methods for plugins
    func getParameter(_ key: String) -> String? {
        return environment[key]
    }
    
    func hasPermission(_ permission: PluginPermission) -> Bool {
        // Check if plugin has required permission
        return PluginManager.shared.hasPermission(permission, for: self)
    }
}

// MARK: - Plugin Result
struct PluginResult {
    let success: Bool
    let output: String
    let data: [String: Any]?
    let followUpActions: [FollowUpAction]
    let executionTime: TimeInterval
    
    enum FollowUpAction {
        case openFile(URL)
        case runCommand(String)
        case showNotification(String)
        case updateUI(String)
    }
}

// MARK: - Plugin Manager
@MainActor
class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    @Published var loadedPlugins: [String: SamPlugin] = [:]
    @Published var pluginPermissions: [String: Set<PluginPermission>] = [:]
    @Published var isLoading = false
    
    private let pluginsDirectory: URL
    private let securityManager = PluginSecurityManager()
    private let telemetryManager = TelemetryManager.shared
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                in: .userDomainMask).first!
        pluginsDirectory = appSupport.appendingPathComponent("Sam/Plugins")
        
        // Create plugins directory if it doesn't exist
        try? FileManager.default.createDirectory(at: pluginsDirectory, 
                                               withIntermediateDirectories: true)
    }
    
    // MARK: - Plugin Loading
    func loadPlugins() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let pluginURLs = try FileManager.default.contentsOfDirectory(
                at: pluginsDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "samplugin" }
            
            for pluginURL in pluginURLs {
                await loadPlugin(at: pluginURL)
            }
            
            telemetryManager.track("plugins_loaded", properties: [
                "count": loadedPlugins.count
            ])
        } catch {
            print("Failed to load plugins: \(error)")
        }
    }
    
    private func loadPlugin(at url: URL) async {
        do {
            // Validate plugin security
            try await securityManager.validatePlugin(at: url)
            
            // Load plugin manifest
            let manifestURL = url.appendingPathComponent("manifest.json")
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)
            
            // Create plugin instance (simplified - would use dynamic loading in real implementation)
            if let plugin = await createPluginInstance(from: manifest, at: url) {
                try await plugin.initialize()
                loadedPlugins[plugin.identifier] = plugin
                pluginPermissions[plugin.identifier] = Set(plugin.requiredPermissions)
                
                telemetryManager.track("plugin_loaded", properties: [
                    "plugin_id": plugin.identifier,
                    "plugin_name": plugin.name,
                    "version": plugin.version
                ])
            }
        } catch {
            print("Failed to load plugin at \(url): \(error)")
            telemetryManager.track("plugin_load_failed", properties: [
                "plugin_url": url.path,
                "error": error.localizedDescription
            ])
        }
    }
    
    private func createPluginInstance(from manifest: PluginManifest, at url: URL) async -> SamPlugin? {
        // In a real implementation, this would use dynamic loading
        // For now, return nil as we'd need actual plugin implementations
        return nil
    }
    
    // MARK: - Plugin Execution
    func executeCommand(_ command: String, context: PluginContext) async -> PluginResult? {
        let startTime = Date()
        
        // Find plugin that can handle the command
        for (_, plugin) in loadedPlugins {
            if plugin.canHandle(command) {
                do {
                    let result = try await plugin.execute(command, context: context)
                    
                    telemetryManager.track("plugin_command_executed", properties: [
                        "plugin_id": plugin.identifier,
                        "command": command,
                        "success": result.success,
                        "execution_time": result.executionTime
                    ])
                    
                    return result
                } catch {
                    telemetryManager.track("plugin_command_failed", properties: [
                        "plugin_id": plugin.identifier,
                        "command": command,
                        "error": error.localizedDescription
                    ])
                    
                    return PluginResult(
                        success: false,
                        output: "Plugin execution failed: \(error.localizedDescription)",
                        data: nil,
                        followUpActions: [],
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Permission Management
    func hasPermission(_ permission: PluginPermission, for context: PluginContext) -> Bool {
        // Implementation would check actual permissions
        return true
    }
    
    func requestPermission(_ permission: PluginPermission, for pluginId: String) async -> Bool {
        // Show permission request dialog to user
        // For now, return true
        return true
    }
    
    // MARK: - Plugin Management
    func installPlugin(from url: URL) async throws {
        // Validate and install plugin
        try await securityManager.validatePlugin(at: url)
        
        let destinationURL = pluginsDirectory.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destinationURL)
        
        await loadPlugin(at: destinationURL)
    }
    
    func uninstallPlugin(_ pluginId: String) async {
        if let plugin = loadedPlugins[pluginId] {
            await plugin.cleanup()
            loadedPlugins.removeValue(forKey: pluginId)
            pluginPermissions.removeValue(forKey: pluginId)
            
            telemetryManager.track("plugin_uninstalled", properties: [
                "plugin_id": pluginId
            ])
        }
    }
    
    func enablePlugin(_ pluginId: String) {
        // Enable plugin functionality
        telemetryManager.track("plugin_enabled", properties: ["plugin_id": pluginId])
    }
    
    func disablePlugin(_ pluginId: String) {
        // Disable plugin functionality
        telemetryManager.track("plugin_disabled", properties: ["plugin_id": pluginId])
    }
}

// MARK: - Plugin Manifest
struct PluginManifest: Codable {
    let identifier: String
    let name: String
    let version: String
    let description: String
    let author: String
    let supportedCommands: [String]
    let requiredPermissions: [String]
    let entryPoint: String
    let dependencies: [String]
    let minimumSamVersion: String
}

// MARK: - Plugin Security Manager
class PluginSecurityManager {
    func validatePlugin(at url: URL) async throws {
        // Validate plugin signature, check for malicious code, etc.
        // For now, just check if manifest exists
        let manifestURL = url.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PluginError.invalidManifest
        }
    }
}

// MARK: - Plugin Errors
enum PluginError: LocalizedError {
    case invalidManifest
    case securityValidationFailed
    case permissionDenied
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidManifest:
            return "Plugin manifest is invalid or missing"
        case .securityValidationFailed:
            return "Plugin failed security validation"
        case .permissionDenied:
            return "Plugin permission denied"
        case .executionFailed(let reason):
            return "Plugin execution failed: \(reason)"
        }
    }
}