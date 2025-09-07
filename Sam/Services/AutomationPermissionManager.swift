import Foundation
import AppKit

/// Manages automation permissions and security for AppleScript execution
class AutomationPermissionManager {
    
    // MARK: - Types
    
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case restricted
    }
    
    struct PermissionRequest {
        let targetApp: String
        let requestedAt: Date
        let purpose: String
    }
    
    // MARK: - Properties
    
    private var permissionCache: [String: PermissionStatus] = [:]
    private var permissionRequests: [PermissionRequest] = []
    
    // MARK: - Public Methods
    
    /// Check if automation permission is granted
    func checkAutomationPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Check if we have automation permission by attempting a simple system event
                let script = """
                tell application "System Events"
                    return true
                end tell
                """
                
                let appleScript = NSAppleScript(source: script)
                var errorDict: NSDictionary?
                let result = appleScript?.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    let errorCode = error[NSAppleScript.errorNumber] as? Int
                    // Error -1743 typically indicates permission denied
                    if errorCode == -1743 {
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: result != nil)
                }
            }
        }
    }
    
    /// Check permission for specific app
    func checkPermission(for app: String) async -> PermissionStatus {
        if let cached = permissionCache[app] {
            return cached
        }
        
        let status = await testAppPermission(app)
        permissionCache[app] = status
        return status
    }
    
    /// Request permission for app automation
    func requestPermission(for app: String, purpose: String) async -> Bool {
        let request = PermissionRequest(
            targetApp: app,
            requestedAt: Date(),
            purpose: purpose
        )
        permissionRequests.append(request)
        
        // Show permission dialog
        let granted = await showPermissionDialog(for: app, purpose: purpose)
        
        if granted {
            permissionCache[app] = .granted
        } else {
            permissionCache[app] = .denied
        }
        
        return granted
    }
    
    /// Get permission status for all apps
    func getAllPermissions() -> [String: PermissionStatus] {
        return permissionCache
    }
    
    /// Clear permission cache
    func clearPermissionCache() {
        permissionCache.removeAll()
    }
    
    /// Get permission requests history
    func getPermissionRequests() -> [PermissionRequest] {
        return permissionRequests
    }
    
    /// Check if app requires special permissions
    func requiresSpecialPermission(_ app: String) -> Bool {
        let specialApps = [
            "System Events",
            "Finder",
            "Mail",
            "Calendar",
            "Contacts",
            "Reminders",
            "Photos",
            "Music",
            "TV"
        ]
        return specialApps.contains(app)
    }
    
    /// Get permission guidance for user
    func getPermissionGuidance(for app: String) -> String {
        switch app.lowercased() {
        case "system events":
            return "System Events automation allows Sam to control system functions. Enable in System Preferences > Security & Privacy > Privacy > Automation."
        case "finder":
            return "Finder automation allows Sam to manage files and folders. Enable in System Preferences > Security & Privacy > Privacy > Automation."
        case "mail":
            return "Mail automation allows Sam to send and read emails. Enable in System Preferences > Security & Privacy > Privacy > Automation."
        case "calendar":
            return "Calendar automation allows Sam to create and manage events. Enable in System Preferences > Security & Privacy > Privacy > Automation."
        case "safari":
            return "Safari automation allows Sam to control web browsing. Enable in System Preferences > Security & Privacy > Privacy > Automation."
        default:
            return "App automation allows Sam to control \(app). Enable in System Preferences > Security & Privacy > Privacy > Automation."
        }
    }
    
    /// Validate script safety before execution
    func validateScriptSafety(_ script: String) -> (safe: Bool, issues: [String]) {
        var issues: [String] = []
        let lowercased = script.lowercased()
        
        // Check for potentially dangerous operations
        let dangerousCommands = [
            "do shell script \"rm -rf",
            "do shell script \"sudo",
            "delete every",
            "empty trash",
            "restart",
            "shut down",
            "format",
            "erase disk"
        ]
        
        for command in dangerousCommands {
            if lowercased.contains(command) {
                issues.append("Potentially dangerous command detected: \(command)")
            }
        }
        
        // Check for file system modifications outside user directory
        if lowercased.contains("/system/") || lowercased.contains("/library/") {
            issues.append("Script attempts to modify system directories")
        }
        
        // Check for network operations
        if lowercased.contains("curl") || lowercased.contains("wget") || lowercased.contains("download") {
            issues.append("Script contains network operations")
        }
        
        return (safe: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Private Methods
    
    private func testAppPermission(_ app: String) async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let script = """
                tell application "\(app)"
                    return name
                end tell
                """
                
                let appleScript = NSAppleScript(source: script)
                var errorDict: NSDictionary?
                let result = appleScript?.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    let errorCode = error[NSAppleScript.errorNumber] as? Int
                    switch errorCode {
                    case -1743:
                        continuation.resume(returning: .denied)
                    case -1728:
                        continuation.resume(returning: .notDetermined)
                    default:
                        continuation.resume(returning: .restricted)
                    }
                } else if result != nil {
                    continuation.resume(returning: .granted)
                } else {
                    continuation.resume(returning: .notDetermined)
                }
            }
        }
    }
    
    private func showPermissionDialog(for app: String, purpose: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Automation Permission Required"
                alert.informativeText = """
                Sam needs permission to control \(app) for: \(purpose)
                
                Please enable automation for Sam in:
                System Preferences > Security & Privacy > Privacy > Automation
                
                Then click "Retry" to continue.
                """
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Retry")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .informational
                
                let response = alert.runModal()
                
                switch response {
                case .alertFirstButtonReturn:
                    // Open System Preferences
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                    continuation.resume(returning: false)
                case .alertSecondButtonReturn:
                    // Retry - test permission again
                    Task {
                        let hasPermission = await self.checkAutomationPermission()
                        continuation.resume(returning: hasPermission)
                    }
                default:
                    continuation.resume(returning: false)
                }
            }
        }
    }
}