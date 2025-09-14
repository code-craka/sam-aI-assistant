import Foundation
import AppKit
import Contacts
import EventKit
import Photos
import AVFoundation

/// Manages system permissions and access controls for Sam
@MainActor
class PermissionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var fileSystemAccess = false
    @Published var accessibilityAccess = false
    @Published var automationAccess = false
    @Published var contactsAccess = false
    @Published var calendarAccess = false
    @Published var remindersAccess = false
    @Published var photosAccess = false
    @Published var microphoneAccess = false
    @Published var cameraAccess = false
    @Published var fullDiskAccess = false
    
    // MARK: - Permission Status Tracking
    
    @Published var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    @Published var lastPermissionCheck = Date()
    
    // MARK: - Initialization
    
    init() {
        checkAllPermissions()
        
        // Set up periodic permission checking
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkAllPermissions()
            }
        }
    }
    
    // MARK: - Permission Checking
    
    func checkAllPermissions() {
        Task {
            await checkFileSystemAccess()
            await checkAccessibilityAccess()
            await checkAutomationAccess()
            await checkContactsAccess()
            await checkCalendarAccess()
            await checkRemindersAccess()
            await checkPhotosAccess()
            await checkMicrophoneAccess()
            await checkCameraAccess()
            await checkFullDiskAccess()
            
            lastPermissionCheck = Date()
        }
    }
    
    private func checkFileSystemAccess() async {
        // Check if we can access common directories
        let testPaths = [
            FileManager.default.homeDirectoryForCurrentUser,
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
            FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        ]
        
        var hasAccess = true
        for path in testPaths {
            if !FileManager.default.isReadableFile(atPath: path.path) {
                hasAccess = false
                break
            }
        }
        
        fileSystemAccess = hasAccess
        permissionStatuses[.fileSystem] = hasAccess ? .granted : .denied
    }
    
    private func checkAccessibilityAccess() async {
        let trusted = AXIsProcessTrusted()
        accessibilityAccess = trusted
        permissionStatuses[.accessibility] = trusted ? .granted : .denied
    }
    
    private func checkAutomationAccess() async {
        // Check if we can send Apple Events
        let canSendEvents = checkAppleEventPermission()
        automationAccess = canSendEvents
        permissionStatuses[.automation] = canSendEvents ? .granted : .denied
    }
    
    private func checkContactsAccess() async {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsAccess = status == .authorized
        permissionStatuses[.contacts] = PermissionStatus(from: status)
    }
    
    private func checkCalendarAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarAccess = status == .authorized
        permissionStatuses[.calendar] = PermissionStatus(from: status)
    }
    
    private func checkRemindersAccess() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        remindersAccess = status == .authorized
        permissionStatuses[.reminders] = PermissionStatus(from: status)
    }
    
    private func checkPhotosAccess() async {
        let status = PHPhotoLibrary.authorizationStatus()
        photosAccess = status == .authorized
        permissionStatuses[.photos] = PermissionStatus(from: status)
    }
    
    private func checkMicrophoneAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneAccess = status == .authorized
        permissionStatuses[.microphone] = PermissionStatus(from: status)
    }
    
    private func checkCameraAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAccess = status == .authorized
        permissionStatuses[.camera] = PermissionStatus(from: status)
    }
    
    private func checkFullDiskAccess() async {
        // Try to access a protected directory
        let protectedPath = "/Library/Application Support"
        let hasAccess = FileManager.default.isReadableFile(atPath: protectedPath)
        fullDiskAccess = hasAccess
        permissionStatuses[.fullDiskAccess] = hasAccess ? .granted : .denied
    }
    
    // MARK: - Permission Requests
    
    func requestPermission(_ type: PermissionType) async -> Bool {
        switch type {
        case .fileSystem:
            return await requestFileSystemAccess()
        case .accessibility:
            return await requestAccessibilityAccess()
        case .automation:
            return await requestAutomationAccess()
        case .contacts:
            return await requestContactsAccess()
        case .calendar:
            return await requestCalendarAccess()
        case .reminders:
            return await requestRemindersAccess()
        case .photos:
            return await requestPhotosAccess()
        case .microphone:
            return await requestMicrophoneAccess()
        case .camera:
            return await requestCameraAccess()
        case .fullDiskAccess:
            return await requestFullDiskAccess()
        }
    }
    
    func requestFileSystemAccess() async -> Bool {
        // Show file picker to trigger permission dialog
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Grant Sam access to your files to enable file operations"
        
        let result = panel.runModal()
        if result == .OK {
            await checkFileSystemAccess()
            return fileSystemAccess
        }
        
        return false
    }
    
    private func requestAccessibilityAccess() async -> Bool {
        // Guide user to System Preferences
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
        Sam needs accessibility access to control other applications and perform system tasks.
        
        Please:
        1. Open System Preferences > Security & Privacy > Privacy
        2. Select "Accessibility" from the list
        3. Click the lock to make changes
        4. Add Sam to the list of allowed applications
        """
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
        
        // Check again after user interaction
        await checkAccessibilityAccess()
        return accessibilityAccess
    }
    
    private func requestAutomationAccess() async -> Bool {
        // Guide user to System Preferences
        let alert = NSAlert()
        alert.messageText = "Automation Access Required"
        alert.informativeText = """
        Sam needs automation access to control other applications through AppleScript.
        
        Please:
        1. Open System Preferences > Security & Privacy > Privacy
        2. Select "Automation" from the list
        3. Find Sam in the list and enable access to the applications you want to control
        """
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAutomationPreferences()
        }
        
        await checkAutomationAccess()
        return automationAccess
    }
    
    private func requestContactsAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, error in
                Task { @MainActor in
                    self.contactsAccess = granted
                    self.permissionStatuses[.contacts] = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestCalendarAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            EKEventStore().requestAccess(to: .event) { granted, error in
                Task { @MainActor in
                    self.calendarAccess = granted
                    self.permissionStatuses[.calendar] = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestRemindersAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            EKEventStore().requestAccess(to: .reminder) { granted, error in
                Task { @MainActor in
                    self.remindersAccess = granted
                    self.permissionStatuses[.reminders] = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestPhotosAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                Task { @MainActor in
                    let granted = status == .authorized
                    self.photosAccess = granted
                    self.permissionStatuses[.photos] = PermissionStatus(from: status)
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestMicrophoneAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    self.microphoneAccess = granted
                    self.permissionStatuses[.microphone] = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestCameraAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.cameraAccess = granted
                    self.permissionStatuses[.camera] = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestFullDiskAccess() async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = """
        Sam needs full disk access to perform comprehensive file operations and system management.
        
        Please:
        1. Open System Preferences > Security & Privacy > Privacy
        2. Select "Full Disk Access" from the list
        3. Click the lock to make changes
        4. Add Sam to the list of allowed applications
        """
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openFullDiskAccessPreferences()
        }
        
        await checkFullDiskAccess()
        return fullDiskAccess
    }
    
    // MARK: - System Preferences Navigation
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func openAutomationPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
    
    private func openFullDiskAccessPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Permission Validation
    
    func validatePermissionsForTask(_ taskType: TaskType) -> PermissionValidationResult {
        let requiredPermissions = getRequiredPermissions(for: taskType)
        var missingPermissions: [PermissionType] = []
        var warnings: [String] = []
        
        for permission in requiredPermissions {
            let status = permissionStatuses[permission] ?? .notDetermined
            
            switch status {
            case .denied, .notDetermined:
                missingPermissions.append(permission)
            case .restricted:
                warnings.append("Permission \(permission.displayName) is restricted by system policy")
            case .granted:
                break
            }
        }
        
        return PermissionValidationResult(
            canProceed: missingPermissions.isEmpty,
            missingPermissions: missingPermissions,
            warnings: warnings,
            requiredPermissions: requiredPermissions
        )
    }
    
    private func getRequiredPermissions(for taskType: TaskType) -> [PermissionType] {
        switch taskType {
        case .fileOperation:
            return [.fileSystem]
        case .systemQuery:
            return []
        case .appControl:
            return [.accessibility, .automation]
        case .textProcessing:
            return []
        case .calculation:
            return []
        case .webQuery:
            return []
        case .automation:
            return [.accessibility, .automation]
        case .settings:
            return []
        case .help:
            return []
        }
    }
    
    // MARK: - Utility Methods
    
    private func checkAppleEventPermission() -> Bool {
        // Try to get information about a system process
        let script = """
        tell application "System Events"
            get name of first process
        end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        return error == nil && result != nil
    }
    
    func getPermissionSummary() -> PermissionSummary {
        let totalPermissions = PermissionType.allCases.count
        let grantedPermissions = permissionStatuses.values.filter { $0 == .granted }.count
        
        return PermissionSummary(
            totalPermissions: totalPermissions,
            grantedPermissions: grantedPermissions,
            deniedPermissions: permissionStatuses.values.filter { $0 == .denied }.count,
            restrictedPermissions: permissionStatuses.values.filter { $0 == .restricted }.count,
            undeterminedPermissions: permissionStatuses.values.filter { $0 == .notDetermined }.count,
            completionPercentage: Double(grantedPermissions) / Double(totalPermissions) * 100
        )
    }
    
    func resetPermissionRequests() {
        // Clear cached permission statuses to force re-checking
        permissionStatuses.removeAll()
        checkAllPermissions()
    }
}

// MARK: - Supporting Types

enum PermissionType: String, CaseIterable {
    case fileSystem = "file_system"
    case accessibility = "accessibility"
    case automation = "automation"
    case contacts = "contacts"
    case calendar = "calendar"
    case reminders = "reminders"
    case photos = "photos"
    case microphone = "microphone"
    case camera = "camera"
    case fullDiskAccess = "full_disk_access"
    
    var displayName: String {
        switch self {
        case .fileSystem: return "File System Access"
        case .accessibility: return "Accessibility"
        case .automation: return "Automation"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .photos: return "Photos"
        case .microphone: return "Microphone"
        case .camera: return "Camera"
        case .fullDiskAccess: return "Full Disk Access"
        }
    }
    
    var description: String {
        switch self {
        case .fileSystem:
            return "Access to read and modify files on your Mac"
        case .accessibility:
            return "Control other applications and system elements"
        case .automation:
            return "Send commands to other applications via AppleScript"
        case .contacts:
            return "Access your contacts for integration features"
        case .calendar:
            return "Create and manage calendar events"
        case .reminders:
            return "Create and manage reminders"
        case .photos:
            return "Access your photo library for organization tasks"
        case .microphone:
            return "Record audio for voice commands"
        case .camera:
            return "Access camera for visual tasks"
        case .fullDiskAccess:
            return "Complete access to all files and system areas"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .fileSystem, .accessibility, .automation:
            return true
        default:
            return false
        }
    }
}

enum PermissionStatus: String, CaseIterable {
    case notDetermined = "not_determined"
    case denied = "denied"
    case granted = "granted"
    case restricted = "restricted"
    
    var displayName: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .granted: return "Granted"
        case .restricted: return "Restricted"
        }
    }
    
    var color: String {
        switch self {
        case .granted: return "green"
        case .denied: return "red"
        case .restricted: return "orange"
        case .notDetermined: return "gray"
        }
    }
}

struct PermissionValidationResult {
    let canProceed: Bool
    let missingPermissions: [PermissionType]
    let warnings: [String]
    let requiredPermissions: [PermissionType]
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    var errorMessage: String? {
        guard !canProceed else { return nil }
        
        let permissionNames = missingPermissions.map { $0.displayName }.joined(separator: ", ")
        return "Missing required permissions: \(permissionNames)"
    }
}

struct PermissionSummary {
    let totalPermissions: Int
    let grantedPermissions: Int
    let deniedPermissions: Int
    let restrictedPermissions: Int
    let undeterminedPermissions: Int
    let completionPercentage: Double
    
    var isComplete: Bool {
        return grantedPermissions == totalPermissions
    }
    
    var hasIssues: Bool {
        return deniedPermissions > 0 || restrictedPermissions > 0
    }
}

// MARK: - Extensions

extension PermissionStatus {
    init(from status: CNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .granted
        case .restricted: self = .restricted
        @unknown default: self = .notDetermined
        }
    }
    
    init(from status: EKAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .granted
        case .restricted: self = .restricted
        @unknown default: self = .notDetermined
        }
    }
    
    init(from status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .granted
        case .restricted: self = .restricted
        case .limited: self = .granted // Treat limited as granted
        @unknown default: self = .notDetermined
        }
    }
    
    init(from status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .granted
        case .restricted: self = .restricted
        @unknown default: self = .notDetermined
        }
    }
}