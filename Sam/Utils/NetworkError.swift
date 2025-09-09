import Foundation

// MARK: - Network Errors
enum NetworkError: SamErrorProtocol {
    case noConnection
    case connectionTimeout
    case hostUnreachable(String)
    case invalidURL(String)
    case sslError(String)
    case httpError(statusCode: Int, message: String?)
    case requestFailed(Error)
    case responseParsingFailed(String)
    case certificateError(String)
    case proxyError(String)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .connectionTimeout:
            return "Connection timed out"
        case .hostUnreachable(let host):
            return "Host '\(host)' is unreachable"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .sslError(let error):
            return "SSL/TLS error: \(error)"
        case .httpError(let statusCode, let message):
            if let message = message {
                return "HTTP error \(statusCode): \(message)"
            } else {
                return "HTTP error \(statusCode)"
            }
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .responseParsingFailed(let reason):
            return "Response parsing failed: \(reason)"
        case .certificateError(let error):
            return "Certificate error: \(error)"
        case .proxyError(let error):
            return "Proxy error: \(error)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Check your internet connection and try again."
        case .connectionTimeout:
            return "Check your internet connection and try again. The server may be slow or overloaded."
        case .hostUnreachable:
            return "Check the server address and your internet connection. The server may be down."
        case .invalidURL:
            return "Check the URL format and ensure it's correct."
        case .sslError:
            return "Check your system date and time, or try again later if it's a server-side certificate issue."
        case .httpError(let statusCode, _):
            switch statusCode {
            case 400:
                return "The request was invalid. Please check your input and try again."
            case 401:
                return "Authentication failed. Check your API key or credentials."
            case 403:
                return "Access forbidden. You may not have permission for this operation."
            case 404:
                return "The requested resource was not found."
            case 429:
                return "Too many requests. Please wait a moment and try again."
            case 500...599:
                return "Server error. Please try again later."
            default:
                return "An HTTP error occurred. Please try again."
            }
        case .requestFailed:
            return "Check your internet connection and try again."
        case .responseParsingFailed:
            return "The server response was invalid. Please try again."
        case .certificateError:
            return "There's an issue with the server's security certificate. Check your system date or try again later."
        case .proxyError:
            return "Check your proxy settings and ensure they're configured correctly."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noConnection:
            return "The device is not connected to the internet."
        case .connectionTimeout:
            return "The network request took too long to complete."
        case .hostUnreachable:
            return "The target server could not be reached."
        case .invalidURL:
            return "The provided URL is malformed or invalid."
        case .sslError:
            return "A secure connection could not be established."
        case .httpError:
            return "The server returned an HTTP error status code."
        case .requestFailed:
            return "The network request failed due to a system-level error."
        case .responseParsingFailed:
            return "The server response could not be parsed or understood."
        case .certificateError:
            return "The server's SSL certificate is invalid or untrusted."
        case .proxyError:
            return "The proxy server configuration is invalid or the proxy is unreachable."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .noConnection, .connectionTimeout, .hostUnreachable:
            return true
        case .invalidURL:
            return false
        case .sslError, .certificateError:
            return true
        case .httpError(let statusCode, _):
            return statusCode < 500 // Client errors are generally not recoverable, server errors might be
        case .requestFailed:
            return true
        case .responseParsingFailed:
            return true
        case .proxyError:
            return true
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .noConnection, .connectionTimeout:
            return .medium
        case .hostUnreachable:
            return .medium
        case .invalidURL:
            return .low
        case .sslError, .certificateError:
            return .high
        case .httpError(let statusCode, _):
            switch statusCode {
            case 400...499:
                return .medium
            case 500...599:
                return .high
            default:
                return .medium
            }
        case .requestFailed:
            return .medium
        case .responseParsingFailed:
            return .low
        case .proxyError:
            return .medium
        }
    }
    
    var errorCode: String {
        switch self {
        case .noConnection:
            return "NE001"
        case .connectionTimeout:
            return "NE002"
        case .hostUnreachable:
            return "NE003"
        case .invalidURL:
            return "NE004"
        case .sslError:
            return "NE005"
        case .httpError:
            return "NE006"
        case .requestFailed:
            return "NE007"
        case .responseParsingFailed:
            return "NE008"
        case .certificateError:
            return "NE009"
        case .proxyError:
            return "NE010"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .hostUnreachable(let host):
            info["host"] = host
        case .invalidURL(let url):
            info["url"] = url
        case .sslError(let error), .certificateError(let error), .proxyError(let error):
            info["details"] = error
        case .httpError(let statusCode, let message):
            info["statusCode"] = statusCode
            if let message = message {
                info["message"] = message
            }
        case .requestFailed(let error):
            info["underlyingError"] = error.localizedDescription
        case .responseParsingFailed(let reason):
            info["reason"] = reason
        default:
            break
        }
        
        return info
    }
}