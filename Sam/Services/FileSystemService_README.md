# FileSystemService

A comprehensive file system operations service for the Sam macOS AI Assistant that provides safe, efficient, and user-friendly file management capabilities.

## Overview

The `FileSystemService` is a core component of Sam that handles all file system operations through natural language commands. It provides a unified interface for file operations, search functionality, and intelligent file organization while maintaining safety and performance.

## Features

### Core File Operations
- **Copy**: Duplicate files and directories with integrity verification
- **Move**: Relocate files and directories safely
- **Delete**: Remove files with optional trash support
- **Rename**: Change file and directory names with validation

### Advanced Capabilities
- **Batch Processing**: Execute multiple operations with progress tracking
- **File Search**: Powerful search with metadata and content filtering
- **Smart Organization**: Auto-categorize files by type, date, or custom rules
- **Progress Tracking**: Real-time progress updates for long operations
- **Cancellation Support**: Cancel operations in progress
- **Undo Operations**: Reversible operations where possible

### Safety Features
- **Pre-flight Validation**: Check permissions and disk space before operations
- **User Confirmation**: Prompt for destructive operations
- **Error Recovery**: Graceful handling of failures with detailed error messages
- **Permission Management**: Respect macOS sandboxing and security

## Architecture

### Class Structure

```swift
@MainActor
class FileSystemService: ObservableObject {
    // Published properties for UI binding
    @Published var isProcessing: Bool
    @Published var currentOperation: String
    @Published var progress: Double
    
    // Core methods
    func executeOperation(_ operation: FileOperation) async throws -> OperationResult
    func executeBatchOperations(_ operations: [FileOperation]) async throws -> BatchOperationResult
    func searchFiles(criteria: SearchCriteria) async throws -> SearchResult
    func organizeFiles(in directory: URL, strategy: OrganizationStrategy) async throws -> OrganizationResult
}
```

### Data Models

#### FileOperation
Represents different types of file operations:
```swift
enum FileOperation {
    case copy(source: URL, destination: URL)
    case move(source: URL, destination: URL)
    case delete(files: [URL], moveToTrash: Bool)
    case rename(file: URL, newName: String)
    case organize(directory: URL, strategy: OrganizationStrategy)
    case search(criteria: SearchCriteria)
}
```

#### SearchCriteria
Configurable search parameters:
```swift
struct SearchCriteria {
    let query: String                    // Text to search for
    let searchPaths: [URL]              // Directories to search
    let fileTypes: [String]             // File extensions to include
    let includeSubdirectories: Bool     // Recursive search
    let searchContent: Bool             // Search inside files
    let minSize: Int64?                 // Minimum file size
    let maxSize: Int64?                 // Maximum file size
    let modifiedAfter: Date?            // Modified after date
    let modifiedBefore: Date?           // Modified before date
    let sortBy: SortOption              // Sort results by
}
```

#### OrganizationStrategy
File organization methods:
```swift
enum OrganizationStrategy {
    case byType                         // Organize by file type
    case byDate                         // Organize by modification date
    case bySize                         // Organize by file size
    case custom([OrganizationRule])     // Custom organization rules
}
```

## Usage Examples

### Basic File Operations

```swift
let fileService = FileSystemService()

// Copy a file
let copyResult = try await fileService.executeOperation(
    .copy(
        source: URL(fileURLWithPath: "/Users/john/document.pdf"),
        destination: URL(fileURLWithPath: "/Users/john/Desktop/document.pdf")
    )
)

// Move a file
let moveResult = try await fileService.executeOperation(
    .move(
        source: URL(fileURLWithPath: "/Users/john/Downloads/file.txt"),
        destination: URL(fileURLWithPath: "/Users/john/Documents/file.txt")
    )
)

// Delete files (move to trash)
let deleteResult = try await fileService.executeOperation(
    .delete(
        files: [URL(fileURLWithPath: "/Users/john/temp.txt")],
        moveToTrash: true
    )
)
```

### File Search

```swift
// Search for PDF files modified in the last week
let criteria = SearchCriteria(
    query: "",
    searchPaths: [URL(fileURLWithPath: "/Users/john/Documents")],
    fileTypes: ["pdf"],
    includeSubdirectories: true,
    modifiedAfter: Calendar.current.date(byAdding: .day, value: -7, to: Date())
)

let searchResult = try await fileService.executeOperation(.search(criteria: criteria))
print("Found \(searchResult.processedFiles.count) PDF files")
```

### File Organization

```swift
// Organize Downloads folder by file type
let organizeResult = try await fileService.executeOperation(
    .organize(
        directory: URL(fileURLWithPath: "/Users/john/Downloads"),
        strategy: .byType
    )
)

// Custom organization rules
let customRules = [
    OrganizationRule(
        name: "Work Documents",
        criteria: .nameContains("work"),
        targetFolder: "Work",
        priority: 1
    ),
    OrganizationRule(
        name: "Large Files",
        criteria: .sizeRange(min: 100_000_000, max: Int.max),
        targetFolder: "Large Files",
        priority: 2
    )
]

let customOrganizeResult = try await fileService.executeOperation(
    .organize(
        directory: URL(fileURLWithPath: "/Users/john/Desktop"),
        strategy: .custom(customRules)
    )
)
```

### Batch Operations

```swift
let operations: [FileOperation] = [
    .copy(
        source: URL(fileURLWithPath: "/path/to/file1.txt"),
        destination: URL(fileURLWithPath: "/path/to/backup/file1.txt")
    ),
    .copy(
        source: URL(fileURLWithPath: "/path/to/file2.txt"),
        destination: URL(fileURLWithPath: "/path/to/backup/file2.txt")
    ),
    .delete(
        files: [URL(fileURLWithPath: "/path/to/temp.txt")],
        moveToTrash: true
    )
]

let batchResult = try await fileService.executeBatchOperations(operations)
print("Completed \(batchResult.successfulOperations)/\(batchResult.totalOperations) operations")
```

### Progress Monitoring

```swift
// Monitor progress in SwiftUI
struct FileOperationView: View {
    @StateObject private var fileService = FileSystemService()
    
    var body: some View {
        VStack {
            if fileService.isProcessing {
                ProgressView(fileService.currentOperation, value: fileService.progress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            Button("Start Operation") {
                Task {
                    try await fileService.executeOperation(/* operation */)
                }
            }
        }
    }
}
```

## Error Handling

The service provides comprehensive error handling with specific error types:

```swift
enum FileOperationError: LocalizedError {
    case fileNotFound(String)
    case destinationNotFound(String)
    case insufficientPermissions(String)
    case operationFailed(String)
    case operationCancelled
    case diskSpaceInsufficient
    case fileAlreadyExists(String)
    
    var errorDescription: String? { /* ... */ }
    var recoverySuggestion: String? { /* ... */ }
}
```

### Error Handling Example

```swift
do {
    let result = try await fileService.executeOperation(operation)
    print("Operation successful: \(result.summary)")
} catch let error as FileOperationError {
    switch error {
    case .insufficientPermissions(let message):
        print("Permission error: \(message)")
        // Show permission request UI
    case .diskSpaceInsufficient:
        print("Not enough disk space")
        // Show disk cleanup options
    default:
        print("Operation failed: \(error.localizedDescription)")
    }
}
```

## Performance Considerations

### Optimization Features
- **Lazy Loading**: Process files on-demand during search
- **Background Processing**: Long operations run on background queues
- **Memory Management**: Automatic cleanup of large file operations
- **Cancellation**: Cancel operations to free resources
- **Progress Tracking**: Minimal overhead progress updates

### Best Practices
1. **Use batch operations** for multiple files to reduce overhead
2. **Set appropriate search limits** to avoid memory issues
3. **Monitor progress** for long-running operations
4. **Handle cancellation** gracefully in UI
5. **Validate inputs** before starting operations

## Integration with Sam

The FileSystemService integrates seamlessly with Sam's natural language processing:

```swift
// Example integration with TaskClassifier
if taskType == .fileOperation {
    let operation = parseFileOperation(from: userInput)
    let result = try await fileSystemService.executeOperation(operation)
    return TaskResult(
        success: result.success,
        output: result.summary,
        executionTime: result.executionTime,
        affectedFiles: result.processedFiles
    )
}
```

## Testing

The service includes comprehensive tests covering:
- Basic file operations (copy, move, delete, rename)
- Search functionality with various criteria
- File organization strategies
- Batch operations
- Error handling scenarios
- Performance benchmarks

Run tests with:
```bash
swift test --filter FileSystemServiceTests
```

## Security and Privacy

### Security Features
- **Permission Validation**: Check file system permissions before operations
- **Sandboxing Support**: Respect macOS app sandboxing restrictions
- **Safe Defaults**: Conservative defaults for destructive operations
- **Input Validation**: Sanitize file paths and names

### Privacy Protection
- **Local Processing**: All operations performed locally
- **No Data Collection**: No file content or metadata sent to external services
- **User Control**: Explicit confirmation for sensitive operations
- **Audit Trail**: Optional logging of file operations

## Requirements

- macOS 13.0+ (Ventura)
- Swift 5.9+
- Foundation framework
- UniformTypeIdentifiers framework

## Dependencies

- Foundation (file system operations)
- UniformTypeIdentifiers (file type detection)
- Combine (reactive programming)
- SwiftUI (UI integration)

## Future Enhancements

- **Cloud Storage Integration**: Support for iCloud Drive operations
- **Network File Systems**: SMB/AFP network share support
- **Advanced Search**: Spotlight integration for system-wide search
- **File Versioning**: Track file changes and provide version history
- **Compression Support**: Built-in archive creation and extraction
- **Metadata Editing**: Modify file metadata and extended attributes