import Foundation

// MARK: - Validation Errors
enum ValidationError: SamErrorProtocol {
    case emptyInput
    case invalidFormat(field: String, expected: String)
    case valueOutOfRange(field: String, value: Any, range: String)
    case requiredFieldMissing(String)
    case invalidCharacters(field: String, characters: String)
    case lengthExceeded(field: String, current: Int, maximum: Int)
    case lengthTooShort(field: String, current: Int, minimum: Int)
    case invalidEmail(String)
    case invalidURL(String)
    case invalidPath(String)
    case invalidDate(String)
    case invalidNumber(String)
    case duplicateValue(field: String, value: String)
    case dependencyValidationFailed(String)
    case customValidationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input cannot be empty"
        case .invalidFormat(let field, let expected):
            return "Invalid format for '\(field)'. Expected: \(expected)"
        case .valueOutOfRange(let field, let value, let range):
            return "Value '\(value)' for '\(field)' is out of range. Expected: \(range)"
        case .requiredFieldMissing(let field):
            return "Required field '\(field)' is missing"
        case .invalidCharacters(let field, let characters):
            return "Invalid characters in '\(field)': \(characters)"
        case .lengthExceeded(let field, let current, let maximum):
            return "'\(field)' is too long: \(current) characters (maximum: \(maximum))"
        case .lengthTooShort(let field, let current, let minimum):
            return "'\(field)' is too short: \(current) characters (minimum: \(minimum))"
        case .invalidEmail(let email):
            return "Invalid email address: '\(email)'"
        case .invalidURL(let url):
            return "Invalid URL: '\(url)'"
        case .invalidPath(let path):
            return "Invalid file path: '\(path)'"
        case .invalidDate(let date):
            return "Invalid date format: '\(date)'"
        case .invalidNumber(let number):
            return "Invalid number format: '\(number)'"
        case .duplicateValue(let field, let value):
            return "Duplicate value for '\(field)': '\(value)'"
        case .dependencyValidationFailed(let dependency):
            return "Dependency validation failed: \(dependency)"
        case .customValidationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyInput:
            return "Please provide a valid input value."
        case .invalidFormat(_, let expected):
            return "Please use the correct format: \(expected)"
        case .valueOutOfRange(_, _, let range):
            return "Please provide a value within the valid range: \(range)"
        case .requiredFieldMissing(let field):
            return "Please provide a value for '\(field)'"
        case .invalidCharacters(let field, _):
            return "Remove invalid characters from '\(field)' and use only allowed characters."
        case .lengthExceeded(let field, _, let maximum):
            return "Shorten '\(field)' to \(maximum) characters or less."
        case .lengthTooShort(let field, _, let minimum):
            return "Extend '\(field)' to at least \(minimum) characters."
        case .invalidEmail:
            return "Please provide a valid email address (e.g., user@example.com)."
        case .invalidURL:
            return "Please provide a valid URL (e.g., https://example.com)."
        case .invalidPath:
            return "Please provide a valid file path (e.g., /Users/username/Documents/file.txt)."
        case .invalidDate:
            return "Please provide a valid date format (e.g., YYYY-MM-DD or MM/DD/YYYY)."
        case .invalidNumber:
            return "Please provide a valid number format."
        case .duplicateValue(let field, _):
            return "Please provide a unique value for '\(field)'."
        case .dependencyValidationFailed:
            return "Ensure all dependencies are properly configured and available."
        case .customValidationFailed:
            return "Please check your input and try again."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .emptyInput:
            return "No input value was provided."
        case .invalidFormat:
            return "The input does not match the expected format."
        case .valueOutOfRange:
            return "The provided value is outside the acceptable range."
        case .requiredFieldMissing:
            return "A mandatory field was not provided."
        case .invalidCharacters:
            return "The input contains characters that are not allowed."
        case .lengthExceeded:
            return "The input exceeds the maximum allowed length."
        case .lengthTooShort:
            return "The input is shorter than the minimum required length."
        case .invalidEmail:
            return "The email address format is not valid."
        case .invalidURL:
            return "The URL format is not valid or the scheme is not supported."
        case .invalidPath:
            return "The file path format is not valid or contains invalid characters."
        case .invalidDate:
            return "The date format is not recognized or the date is invalid."
        case .invalidNumber:
            return "The number format is not valid or cannot be parsed."
        case .duplicateValue:
            return "The value already exists and duplicates are not allowed."
        case .dependencyValidationFailed:
            return "One or more dependencies failed their validation checks."
        case .customValidationFailed:
            return "The input failed custom validation rules."
        }
    }
    
    var isRecoverable: Bool {
        return true // All validation errors are recoverable by providing correct input
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .emptyInput, .requiredFieldMissing:
            return .medium
        case .invalidFormat, .valueOutOfRange:
            return .low
        case .invalidCharacters, .lengthExceeded, .lengthTooShort:
            return .low
        case .invalidEmail, .invalidURL, .invalidPath:
            return .low
        case .invalidDate, .invalidNumber:
            return .low
        case .duplicateValue:
            return .medium
        case .dependencyValidationFailed:
            return .high
        case .customValidationFailed:
            return .medium
        }
    }
    
    var errorCode: String {
        switch self {
        case .emptyInput:
            return "VE001"
        case .invalidFormat:
            return "VE002"
        case .valueOutOfRange:
            return "VE003"
        case .requiredFieldMissing:
            return "VE004"
        case .invalidCharacters:
            return "VE005"
        case .lengthExceeded:
            return "VE006"
        case .lengthTooShort:
            return "VE007"
        case .invalidEmail:
            return "VE008"
        case .invalidURL:
            return "VE009"
        case .invalidPath:
            return "VE010"
        case .invalidDate:
            return "VE011"
        case .invalidNumber:
            return "VE012"
        case .duplicateValue:
            return "VE013"
        case .dependencyValidationFailed:
            return "VE014"
        case .customValidationFailed:
            return "VE015"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .invalidFormat(let field, let expected):
            info["field"] = field
            info["expectedFormat"] = expected
        case .valueOutOfRange(let field, let value, let range):
            info["field"] = field
            info["value"] = value
            info["validRange"] = range
        case .requiredFieldMissing(let field):
            info["field"] = field
        case .invalidCharacters(let field, let characters):
            info["field"] = field
            info["invalidCharacters"] = characters
        case .lengthExceeded(let field, let current, let maximum):
            info["field"] = field
            info["currentLength"] = current
            info["maximumLength"] = maximum
        case .lengthTooShort(let field, let current, let minimum):
            info["field"] = field
            info["currentLength"] = current
            info["minimumLength"] = minimum
        case .invalidEmail(let email):
            info["email"] = email
        case .invalidURL(let url):
            info["url"] = url
        case .invalidPath(let path):
            info["path"] = path
        case .invalidDate(let date):
            info["date"] = date
        case .invalidNumber(let number):
            info["number"] = number
        case .duplicateValue(let field, let value):
            info["field"] = field
            info["value"] = value
        case .dependencyValidationFailed(let dependency):
            info["dependency"] = dependency
        case .customValidationFailed(let message):
            info["message"] = message
        case .emptyInput:
            break
        }
        
        return info
    }
}