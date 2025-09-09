import Foundation

// MARK: - Permission Errors
enum PermissionError: SamErrorProtocol {
    case accessibilityNotGranted
    case automationNotGranted(String)
    case fullDiskAccessNotGranted
    case screenRecordingNotGranted
    case microphoneNotGranted
    case cameraNotGranted
    case contactsNotGranted
    case calendarsNotGranted
    case remindersNotGranted
    case photosNotGranted
    case locationNotGranted
    case notificationsNotGranted
    case fileSystemAccessDenied(URL)
    case keychainAccessDenied
    case networkAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission not granted"
        case .automationNotGranted(let app):
            return "Automation permission not granted for '\(app)'"
        case .fullDiskAccessNotGranted:
            return "Full disk access permission not granted"
        case .screenRecordingNotGranted:
            return "Screen recording permission not granted"
        case .microphoneNotGranted:
            return "Microphone access permission not granted"
        case .cameraNotGranted:
            return "Camera access permission not granted"
        case .contactsNotGranted:
            return "Contacts access permission not granted"
        case .calendarsNotGranted:
            return "Calendar access permission not granted"
        case .remindersNotGranted:
            return "Reminders access permission not granted"
        case .photosNotGranted:
            return "Photos access permission not granted"
        case .locationNotGranted:
            return "Location access permission not granted"
        case .notificationsNotGranted:
            return "Notifications permission not granted"
        case .fileSystemAccessDenied(let url):
            return "File system access denied for '\(url.lastPathComponent)'"
        case .keychainAccessDenied:
            return "Keychain access denied"
        case .networkAccessDenied:
            return "Network access permission denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Accessibility and add Sam to the list of allowed applications."
        case .automationNotGranted(let app):
            return "Go to System Preferences > Security & Privacy > Privacy > Automation and grant Sam permission to control '\(app)'."
        case .fullDiskAccessNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Full Disk Access and add Sam to the list."
        case .screenRecordingNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Screen Recording and add Sam to the list."
        case .microphoneNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Microphone and add Sam to the list."
        case .cameraNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Camera and add Sam to the list."
        case .contactsNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Contacts and add Sam to the list."
        case .calendarsNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Calendars and add Sam to the list."
        case .remindersNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Reminders and add Sam to the list."
        case .photosNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Photos and add Sam to the list."
        case .locationNotGranted:
            return "Go to System Preferences > Security & Privacy > Privacy > Location Services and enable location access for Sam."
        case .notificationsNotGranted:
            return "Go to System Preferences > Notifications and enable notifications for Sam."
        case .fileSystemAccessDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Files and Folders and grant Sam access to the required folders."
        case .keychainAccessDenied:
            return "Check your Keychain Access settings and ensure Sam is allowed to access the keychain."
        case .networkAccessDenied:
            return "Check your firewall settings and ensure Sam is allowed to access the network."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Sam needs accessibility permission to control other applications and system elements."
        case .automationNotGranted:
            return "Sam needs automation permission to send events and commands to other applications."
        case .fullDiskAccessNotGranted:
            return "Sam needs full disk access to read system information and access all files."
        case .screenRecordingNotGranted:
            return "Sam needs screen recording permission to capture screen content for analysis."
        case .microphoneNotGranted:
            return "Sam needs microphone access for voice commands and audio processing."
        case .cameraNotGranted:
            return "Sam needs camera access for visual analysis and image processing."
        case .contactsNotGranted:
            return "Sam needs contacts access to manage and search your address book."
        case .calendarsNotGranted:
            return "Sam needs calendar access to create and manage events."
        case .remindersNotGranted:
            return "Sam needs reminders access to create and manage tasks."
        case .photosNotGranted:
            return "Sam needs photos access to organize and analyze your photo library."
        case .locationNotGranted:
            return "Sam needs location access for location-based features and services."
        case .notificationsNotGranted:
            return "Sam needs notification permission to send alerts and updates."
        case .fileSystemAccessDenied:
            return "Sam needs file system access to perform file operations and management."
        case .keychainAccessDenied:
            return "Sam needs keychain access to securely store and retrieve credentials."
        case .networkAccessDenied:
            return "Sam needs network access to communicate with external services and APIs."
        }
    }
    
    var isRecoverable: Bool {
        return true // All permission errors are recoverable by granting the permission
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .accessibilityNotGranted, .automationNotGranted:
            return .high
        case .fullDiskAccessNotGranted, .fileSystemAccessDenied:
            return .high
        case .screenRecordingNotGranted, .keychainAccessDenied:
            return .medium
        case .microphoneNotGranted, .cameraNotGranted:
            return .low
        case .contactsNotGranted, .calendarsNotGranted, .remindersNotGranted:
            return .medium
        case .photosNotGranted, .locationNotGranted:
            return .low
        case .notificationsNotGranted, .networkAccessDenied:
            return .medium
        }
    }
    
    var errorCode: String {
        switch self {
        case .accessibilityNotGranted:
            return "PE001"
        case .automationNotGranted:
            return "PE002"
        case .fullDiskAccessNotGranted:
            return "PE003"
        case .screenRecordingNotGranted:
            return "PE004"
        case .microphoneNotGranted:
            return "PE005"
        case .cameraNotGranted:
            return "PE006"
        case .contactsNotGranted:
            return "PE007"
        case .calendarsNotGranted:
            return "PE008"
        case .remindersNotGranted:
            return "PE009"
        case .photosNotGranted:
            return "PE010"
        case .locationNotGranted:
            return "PE011"
        case .notificationsNotGranted:
            return "PE012"
        case .fileSystemAccessDenied:
            return "PE013"
        case .keychainAccessDenied:
            return "PE014"
        case .networkAccessDenied:
            return "PE015"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .automationNotGranted(let app):
            info["targetApp"] = app
        case .fileSystemAccessDenied(let url):
            info["filePath"] = url.path
        default:
            break
        }
        
        return info
    }
}