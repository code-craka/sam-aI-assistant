import Foundation

// MARK: - App Integration Errors
enum AppIntegrationError: SamErrorProtocol {
    case appNotFound(String)
    case appNotRunning(String)
    case appLaunchFailed(String, reason: String)
    case appleScriptError(String)
    case urlSchemeNotSupported(String)
    case accessibilityElementNotFound(String)
    case commandNotSupported(String, app: String)
    case parameterMissing(String)
    case automationTimeout(String)
    case permissionDenied(String)
    case scriptCompilationFailed(String)
    case integrationNotAvailable(String)
    
    var errorDescription: String? {
        switch self {
        case .appNotFound(let appName):
            return "Application '\(appName)' not found"
        case .appNotRunning(let appName):
            return "Application '\(appName)' is not running"
        case .appLaunchFailed(let appName, let reason):
            return "Failed to launch '\(appName)': \(reason)"
        case .appleScriptError(let error):
            return "AppleScript execution failed: \(error)"
        case .urlSchemeNotSupported(let scheme):
            return "URL scheme '\(scheme)' is not supported"
        case .accessibilityElementNotFound(let element):
            return "Accessibility element '\(element)' not found"
        case .commandNotSupported(let command, let app):
            return "Command '\(command)' is not supported by '\(app)'"
        case .parameterMissing(let parameter):
            return "Required parameter '\(parameter)' is missing"
        case .automationTimeout(let appName):
            return "Automation timeout for '\(appName)'"
        case .permissionDenied(let appName):
            return "Permission denied for '\(appName)' automation"
        case .scriptCompilationFailed(let error):
            return "Script compilation failed: \(error)"
        case .integrationNotAvailable(let appName):
            return "Integration not available for '\(appName)'"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .appNotFound:
            return "Install the application or check if it's available in your Applications folder."
        case .appNotRunning:
            return "Launch the application first, then try the command again."
        case .appLaunchFailed:
            return "Check if the application is properly installed and you have permission to run it."
        case .appleScriptError:
            return "The automation script encountered an error. Try a simpler command or check app permissions."
        case .urlSchemeNotSupported:
            return "This application doesn't support URL scheme automation. Try using AppleScript or accessibility methods."
        case .accessibilityElementNotFound:
            return "The UI element could not be found. Make sure the application window is visible and try again."
        case .commandNotSupported:
            return "This command is not available for this application. Check the list of supported commands."
        case .parameterMissing:
            return "Provide the required parameter in your command. For example, specify a file name or recipient."
        case .automationTimeout:
            return "The application took too long to respond. Try again or use a simpler command."
        case .permissionDenied:
            return "Grant automation permission in System Preferences > Security & Privacy > Privacy > Automation."
        case .scriptCompilationFailed:
            return "The automation script has syntax errors. This may be a bug - please report it."
        case .integrationNotAvailable:
            return "This application integration is not yet implemented. Check for app updates or use manual methods."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .appNotFound:
            return "The specified application is not installed on this system."
        case .appNotRunning:
            return "The target application must be running for this operation."
        case .appLaunchFailed:
            return "The system was unable to launch the application."
        case .appleScriptError:
            return "The AppleScript automation encountered an execution error."
        case .urlSchemeNotSupported:
            return "The application does not implement the required URL scheme handlers."
        case .accessibilityElementNotFound:
            return "The accessibility API could not locate the specified UI element."
        case .commandNotSupported:
            return "The requested command is not implemented for this application integration."
        case .parameterMissing:
            return "The command requires additional parameters that were not provided."
        case .automationTimeout:
            return "The automation operation exceeded the maximum allowed time."
        case .permissionDenied:
            return "The system denied permission to automate the target application."
        case .scriptCompilationFailed:
            return "The generated AppleScript contains syntax errors."
        case .integrationNotAvailable:
            return "No integration module is available for this application."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .appNotFound, .appNotRunning, .appLaunchFailed:
            return true
        case .appleScriptError, .urlSchemeNotSupported, .accessibilityElementNotFound:
            return true
        case .commandNotSupported, .integrationNotAvailable:
            return false
        case .parameterMissing:
            return true
        case .automationTimeout, .permissionDenied:
            return true
        case .scriptCompilationFailed:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .appNotFound, .appNotRunning:
            return .medium
        case .appLaunchFailed, .permissionDenied:
            return .high
        case .appleScriptError, .accessibilityElementNotFound, .automationTimeout:
            return .medium
        case .urlSchemeNotSupported, .commandNotSupported, .integrationNotAvailable:
            return .low
        case .parameterMissing:
            return .low
        case .scriptCompilationFailed:
            return .high
        }
    }
    
    var errorCode: String {
        switch self {
        case .appNotFound:
            return "AI001"
        case .appNotRunning:
            return "AI002"
        case .appLaunchFailed:
            return "AI003"
        case .appleScriptError:
            return "AI004"
        case .urlSchemeNotSupported:
            return "AI005"
        case .accessibilityElementNotFound:
            return "AI006"
        case .commandNotSupported:
            return "AI007"
        case .parameterMissing:
            return "AI008"
        case .automationTimeout:
            return "AI009"
        case .permissionDenied:
            return "AI010"
        case .scriptCompilationFailed:
            return "AI011"
        case .integrationNotAvailable:
            return "AI012"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .appNotFound(let appName), .appNotRunning(let appName), .automationTimeout(let appName), .permissionDenied(let appName), .integrationNotAvailable(let appName):
            info["appName"] = appName
        case .appLaunchFailed(let appName, let reason):
            info["appName"] = appName
            info["reason"] = reason
        case .appleScriptError(let error), .scriptCompilationFailed(let error):
            info["error"] = error
        case .urlSchemeNotSupported(let scheme):
            info["scheme"] = scheme
        case .accessibilityElementNotFound(let element):
            info["element"] = element
        case .commandNotSupported(let command, let app):
            info["command"] = command
            info["app"] = app
        case .parameterMissing(let parameter):
            info["parameter"] = parameter
        }
        
        return info
    }
}