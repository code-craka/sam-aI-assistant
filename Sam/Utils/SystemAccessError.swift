import Foundation

// MARK: - System Access Errors
enum SystemAccessError: SamErrorProtocol {
    case accessibilityPermissionDenied
    case automationPermissionDenied
    case fullDiskAccessDenied
    case screenRecordingPermissionDenied
    case networkAccessDenied
    case batteryInfoUnavailable
    case systemInfoUnavailable(String)
    case processListUnavailable
    case volumeControlFailed(String)
    case brightnessControlFailed(String)
    case networkConfigurationFailed(String)
    case systemPreferencesAccessDenied
    case serviceUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required but not granted"
        case .automationPermissionDenied:
            return "Automation permission is required but not granted"
        case .fullDiskAccessDenied:
            return "Full disk access permission is required but not granted"
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required but not granted"
        case .networkAccessDenied:
            return "Network access permission is required but not granted"
        case .batteryInfoUnavailable:
            return "Battery information is not available on this system"
        case .systemInfoUnavailable(let info):
            return "System information '\(info)' is not available"
        case .processListUnavailable:
            return "Process list information is not available"
        case .volumeControlFailed(let reason):
            return "Volume control failed: \(reason)"
        case .brightnessControlFailed(let reason):
            return "Brightness control failed: \(reason)"
        case .networkConfigurationFailed(let reason):
            return "Network configuration failed: \(reason)"
        case .systemPreferencesAccessDenied:
            return "Access to system preferences is denied"
        case .serviceUnavailable(let service):
            return "System service '\(service)' is unavailable"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Accessibility and add Sam to the list of allowed applications."
        case .automationPermissionDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Automation and grant Sam permission to control other applications."
        case .fullDiskAccessDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Full Disk Access and add Sam to the list."
        case .screenRecordingPermissionDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Screen Recording and add Sam to the list."
        case .networkAccessDenied:
            return "Check your network connection and firewall settings. Ensure Sam is allowed to access the network."
        case .batteryInfoUnavailable:
            return "Battery information is only available on laptops and devices with batteries."
        case .systemInfoUnavailable:
            return "This system information may not be available on your macOS version or hardware configuration."
        case .processListUnavailable:
            return "Process information may require additional permissions. Try restarting Sam with administrator privileges."
        case .volumeControlFailed:
            return "Check that your audio system is working properly and no other applications are controlling volume."
        case .brightnessControlFailed:
            return "Brightness control may not be available on external displays or may require additional permissions."
        case .networkConfigurationFailed:
            return "Check your network settings and ensure you have administrator privileges for network changes."
        case .systemPreferencesAccessDenied:
            return "System preferences access may require administrator privileges or additional permissions."
        case .serviceUnavailable:
            return "The requested system service may be disabled or not available on your system configuration."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "The application needs accessibility permission to control other applications and system elements."
        case .automationPermissionDenied:
            return "The application needs automation permission to send events to other applications."
        case .fullDiskAccessDenied:
            return "The application needs full disk access to read system information and files."
        case .screenRecordingPermissionDenied:
            return "The application needs screen recording permission to capture screen content."
        case .networkAccessDenied:
            return "The application cannot access network resources due to permission restrictions."
        case .batteryInfoUnavailable:
            return "Battery information APIs are not available on this hardware configuration."
        case .systemInfoUnavailable:
            return "The requested system information is not exposed by macOS APIs on this system."
        case .processListUnavailable:
            return "Process enumeration requires elevated privileges or is restricted by system security."
        case .volumeControlFailed, .brightnessControlFailed:
            return "Hardware control APIs failed due to system restrictions or hardware limitations."
        case .networkConfigurationFailed:
            return "Network configuration changes require administrator privileges."
        case .systemPreferencesAccessDenied:
            return "System preferences modification requires elevated privileges."
        case .serviceUnavailable:
            return "The requested system service is not running or not available."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .accessibilityPermissionDenied, .automationPermissionDenied, .fullDiskAccessDenied, .screenRecordingPermissionDenied:
            return true
        case .networkAccessDenied:
            return true
        case .batteryInfoUnavailable, .systemInfoUnavailable, .processListUnavailable:
            return false
        case .volumeControlFailed, .brightnessControlFailed, .networkConfigurationFailed:
            return true
        case .systemPreferencesAccessDenied:
            return true
        case .serviceUnavailable:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .accessibilityPermissionDenied, .automationPermissionDenied:
            return .high
        case .fullDiskAccessDenied, .screenRecordingPermissionDenied:
            return .medium
        case .networkAccessDenied:
            return .medium
        case .batteryInfoUnavailable, .systemInfoUnavailable, .processListUnavailable:
            return .low
        case .volumeControlFailed, .brightnessControlFailed:
            return .low
        case .networkConfigurationFailed, .systemPreferencesAccessDenied:
            return .medium
        case .serviceUnavailable:
            return .medium
        }
    }
    
    var errorCode: String {
        switch self {
        case .accessibilityPermissionDenied:
            return "SA001"
        case .automationPermissionDenied:
            return "SA002"
        case .fullDiskAccessDenied:
            return "SA003"
        case .screenRecordingPermissionDenied:
            return "SA004"
        case .networkAccessDenied:
            return "SA005"
        case .batteryInfoUnavailable:
            return "SA006"
        case .systemInfoUnavailable:
            return "SA007"
        case .processListUnavailable:
            return "SA008"
        case .volumeControlFailed:
            return "SA009"
        case .brightnessControlFailed:
            return "SA010"
        case .networkConfigurationFailed:
            return "SA011"
        case .systemPreferencesAccessDenied:
            return "SA012"
        case .serviceUnavailable:
            return "SA013"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .systemInfoUnavailable(let infoType):
            info["infoType"] = infoType
        case .volumeControlFailed(let reason), .brightnessControlFailed(let reason), .networkConfigurationFailed(let reason):
            info["reason"] = reason
        case .serviceUnavailable(let service):
            info["service"] = service
        default:
            break
        }
        
        return info
    }
}