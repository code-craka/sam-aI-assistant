import Foundation

// MARK: - File Operation Errors
enum FileOperationError: SamErrorProtocol {
    case fileNotFound(URL)
    case insufficientPermissions(URL)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case destinationExists(URL)
    case invalidPath(String)
    case operationCancelled
    case copyFailed(source: URL, destination: URL, reason: String)
    case moveFailed(source: URL, destination: URL, reason: String)
    case deleteFailed(URL, reason: String)
    case renameFailed(URL, newName: String, reason: String)
    case searchFailed(String)
    case metadataExtractionFailed(URL, reason: String)
    case organizationFailed(URL, reason: String)
    case batchOperationPartialFailure([URL], [Error])
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .insufficientPermissions(let url):
            return "Insufficient permissions to access: \(url.lastPathComponent)"
        case .insufficientDiskSpace(let required, let available):
            return "Insufficient disk space. Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))"
        case .destinationExists(let url):
            return "Destination already exists: \(url.lastPathComponent)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .operationCancelled:
            return "File operation was cancelled"
        case .copyFailed(let source, let destination, let reason):
            return "Failed to copy '\(source.lastPathComponent)' to '\(destination.lastPathComponent)': \(reason)"
        case .moveFailed(let source, let destination, let reason):
            return "Failed to move '\(source.lastPathComponent)' to '\(destination.lastPathComponent)': \(reason)"
        case .deleteFailed(let url, let reason):
            return "Failed to delete '\(url.lastPathComponent)': \(reason)"
        case .renameFailed(let url, let newName, let reason):
            return "Failed to rename '\(url.lastPathComponent)' to '\(newName)': \(reason)"
        case .searchFailed(let query):
            return "File search failed for query: '\(query)'"
        case .metadataExtractionFailed(let url, let reason):
            return "Failed to extract metadata from '\(url.lastPathComponent)': \(reason)"
        case .organizationFailed(let url, let reason):
            return "Failed to organize files in '\(url.lastPathComponent)': \(reason)"
        case .batchOperationPartialFailure(let files, let errors):
            return "Batch operation partially failed. \(errors.count) of \(files.count) operations failed."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Check if the file exists and verify the file path is correct."
        case .insufficientPermissions:
            return "Grant Sam permission to access this location in System Preferences > Security & Privacy > Privacy > Files and Folders."
        case .insufficientDiskSpace:
            return "Free up disk space by deleting unnecessary files or moving files to external storage."
        case .destinationExists:
            return "Choose a different destination name or delete the existing file first."
        case .invalidPath:
            return "Provide a valid file path. Use absolute paths or paths relative to your home directory."
        case .operationCancelled:
            return "The operation was cancelled. You can try again if needed."
        case .copyFailed, .moveFailed:
            return "Check file permissions and ensure the destination directory exists and is writable."
        case .deleteFailed:
            return "Ensure the file is not in use by another application and you have permission to delete it."
        case .renameFailed:
            return "Ensure the new name is valid and doesn't conflict with existing files."
        case .searchFailed:
            return "Try a different search query or check if the search location is accessible."
        case .metadataExtractionFailed:
            return "The file may be corrupted or in an unsupported format."
        case .organizationFailed:
            return "Check that you have write permissions to the directory and sufficient disk space."
        case .batchOperationPartialFailure:
            return "Review the failed operations and try them individually to identify specific issues."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .fileNotFound:
            return "The specified file or directory does not exist at the given path."
        case .insufficientPermissions:
            return "The application does not have the required permissions to access this file or directory."
        case .insufficientDiskSpace:
            return "There is not enough free disk space to complete the operation."
        case .destinationExists:
            return "A file or directory with the same name already exists at the destination."
        case .invalidPath:
            return "The provided path contains invalid characters or format."
        case .operationCancelled:
            return "The user or system cancelled the file operation."
        case .copyFailed, .moveFailed, .deleteFailed, .renameFailed:
            return "The file system operation failed due to system-level restrictions or errors."
        case .searchFailed:
            return "The file search operation encountered an error or timeout."
        case .metadataExtractionFailed:
            return "Unable to read or parse the file's metadata information."
        case .organizationFailed:
            return "The file organization process encountered errors while categorizing or moving files."
        case .batchOperationPartialFailure:
            return "Some operations in the batch failed while others succeeded."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .fileNotFound, .insufficientPermissions, .destinationExists, .invalidPath:
            return true
        case .insufficientDiskSpace:
            return true
        case .operationCancelled:
            return true
        case .copyFailed, .moveFailed, .deleteFailed, .renameFailed:
            return true
        case .searchFailed, .metadataExtractionFailed, .organizationFailed:
            return true
        case .batchOperationPartialFailure:
            return true
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .fileNotFound, .destinationExists, .invalidPath, .operationCancelled:
            return .low
        case .insufficientPermissions, .searchFailed, .metadataExtractionFailed:
            return .medium
        case .insufficientDiskSpace, .copyFailed, .moveFailed, .deleteFailed, .renameFailed:
            return .high
        case .organizationFailed, .batchOperationPartialFailure:
            return .medium
        }
    }
    
    var errorCode: String {
        switch self {
        case .fileNotFound:
            return "FO001"
        case .insufficientPermissions:
            return "FO002"
        case .insufficientDiskSpace:
            return "FO003"
        case .destinationExists:
            return "FO004"
        case .invalidPath:
            return "FO005"
        case .operationCancelled:
            return "FO006"
        case .copyFailed:
            return "FO007"
        case .moveFailed:
            return "FO008"
        case .deleteFailed:
            return "FO009"
        case .renameFailed:
            return "FO010"
        case .searchFailed:
            return "FO011"
        case .metadataExtractionFailed:
            return "FO012"
        case .organizationFailed:
            return "FO013"
        case .batchOperationPartialFailure:
            return "FO014"
        }
    }
    
    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue,
            "isRecoverable": isRecoverable
        ]
        
        switch self {
        case .fileNotFound(let url), .insufficientPermissions(let url), .destinationExists(let url):
            info["filePath"] = url.path
        case .insufficientDiskSpace(let required, let available):
            info["requiredSpace"] = required
            info["availableSpace"] = available
        case .invalidPath(let path):
            info["path"] = path
        case .copyFailed(let source, let destination, let reason), .moveFailed(let source, let destination, let reason):
            info["sourcePath"] = source.path
            info["destinationPath"] = destination.path
            info["reason"] = reason
        case .deleteFailed(let url, let reason):
            info["filePath"] = url.path
            info["reason"] = reason
        case .renameFailed(let url, let newName, let reason):
            info["filePath"] = url.path
            info["newName"] = newName
            info["reason"] = reason
        case .searchFailed(let query):
            info["query"] = query
        case .metadataExtractionFailed(let url, let reason), .organizationFailed(let url, let reason):
            info["filePath"] = url.path
            info["reason"] = reason
        case .batchOperationPartialFailure(let files, let errors):
            info["totalFiles"] = files.count
            info["failedCount"] = errors.count
            info["failedFiles"] = files.map { $0.path }
        case .operationCancelled:
            break
        }
        
        return info
    }
}