import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

// MARK: - File System Service
@MainActor
class FileSystemService: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var currentOperation: String = ""
    @Published var progress: Double = 0.0

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?
    private let fileManager = FileManager.default
    private let metadataService = MetadataExtractionService()
    private let duplicateService = DuplicateDetectionService()
    private let smartOrganizationService = SmartOrganizationService()

    // MARK: - Safety Configuration
    private let maxFileSize: Int64 = 10_000_000_000  // 10GB limit
    private let minDiskSpaceRequired: Int64 = 1_000_000_000  // 1GB minimum

    // MARK: - File Operations

    /// Execute a file system operation
    func executeOperation(_ operation: FileOperation) async throws -> OperationResult {
        await MainActor.run {
            isProcessing = true
            currentOperation = operation.description
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 0.0
            }
        }

        // Pre-flight checks
        try await validateOperation(operation)

        // Execute operation
        let result = try await performOperation(operation)

        return result
    }

    /// Cancel current operation
    func cancelCurrentOperation() {
        currentTask?.cancel()
        Task { @MainActor in
            isProcessing = false
            currentOperation = ""
            progress = 0.0
        }
    }

    /// Undo the last operation if possible
    func undoLastOperation(_ result: OperationResult) async throws {
        guard let undoAction = result.undoAction else {
            throw FileOperationError.operationFailed("This operation cannot be undone")
        }

        await MainActor.run {
            isProcessing = true
            currentOperation = "Undoing operation..."
            progress = 0.5
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 0.0
            }
        }

        do {
            undoAction()
            await MainActor.run {
                progress = 1.0
            }
        } catch {
            throw FileOperationError.operationFailed(
                "Failed to undo operation: \(error.localizedDescription)")
        }
    }

    /// Check if operation can be undone
    func canUndo(_ result: OperationResult) -> Bool {
        return result.undoAction != nil
    }

    /// Get user-friendly error message with recovery suggestions
    func getErrorMessage(for error: FileOperationError) -> (message: String, suggestion: String?) {
        switch error {
        case .fileNotFound(let path):
            return (
                message: "File not found: \(URL(fileURLWithPath: path).lastPathComponent)",
                suggestion: "Please verify the file exists and try again"
            )

        case .destinationNotFound(let path):
            return (
                message:
                    "Destination folder not found: \(URL(fileURLWithPath: path).lastPathComponent)",
                suggestion: "Please create the destination folder first"
            )

        case .insufficientPermissions(let message):
            return (
                message: "Permission denied: \(message)",
                suggestion:
                    "Please check file permissions or try running with administrator privileges"
            )

        case .diskSpaceInsufficient:
            return (
                message: "Not enough disk space to complete the operation",
                suggestion: "Please free up disk space and try again"
            )

        case .fileAlreadyExists(let path):
            return (
                message: "File already exists: \(URL(fileURLWithPath: path).lastPathComponent)",
                suggestion: "Choose a different name or location, or delete the existing file first"
            )

        case .invalidFileName(let name):
            return (
                message: "Invalid file name: \(name)",
                suggestion: "Please use a valid file name without special characters"
            )

        case .operationCancelled:
            return (
                message: "Operation was cancelled",
                suggestion: "You can restart the operation if needed"
            )

        case .operationFailed(let message):
            return (
                message: "Operation failed: \(message)",
                suggestion: "Please check the file and try again"
            )

        case .directoryNotFound(let path):
            return (
                message: "Directory not found: \(URL(fileURLWithPath: path).lastPathComponent)",
                suggestion: "Please verify the directory exists and try again"
            )
        }
    }

    // MARK: - Batch Operations

    /// Execute multiple operations in batch with progress tracking
    func executeBatchOperations(_ operations: [FileOperation]) async throws -> BatchOperationResult
    {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Batch processing \(operations.count) operations"
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 0.0
            }
        }

        var results: [OperationResult] = []
        var errors: [FileOperationError] = []

        for (index, operation) in operations.enumerated() {
            // Check for cancellation
            if Task.isCancelled {
                throw FileOperationError.operationCancelled
            }

            // Update progress
            await MainActor.run {
                progress = Double(index) / Double(operations.count)
                currentOperation = "Processing: \(operation.description)"
            }

            do {
                let result = try await executeOperation(operation)
                results.append(result)
            } catch let error as FileOperationError {
                errors.append(error)
                // Continue with other operations unless it's a critical error
                if case .insufficientPermissions = error {
                    throw error
                }
            }
        }

        await MainActor.run {
            progress = 1.0
        }

        return BatchOperationResult(
            totalOperations: operations.count,
            successfulOperations: results.count,
            failedOperations: errors.count,
            results: results,
            errors: errors,
            summary: generateBatchSummary(results: results, errors: errors)
        )
    }

    // MARK: - File Search

    /// Search for files with various criteria
    func searchFiles(criteria: SearchCriteria) async throws -> SearchResult {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Searching files..."
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        var foundFiles: [FileInfo] = []
        let fileManager = FileManager.default

        // Get search directories
        let searchDirectories =
            criteria.searchPaths.isEmpty
            ? [fileManager.homeDirectoryForCurrentUser] : criteria.searchPaths

        for directory in searchDirectories {
            if Task.isCancelled {
                throw FileOperationError.operationCancelled
            }

            let files = try await searchInDirectory(directory, criteria: criteria)
            foundFiles.append(contentsOf: files)
        }

        // Sort results
        foundFiles.sort { file1, file2 in
            switch criteria.sortBy {
            case .name:
                return file1.name < file2.name
            case .dateModified:
                return file1.dateModified > file2.dateModified
            case .size:
                return file1.size > file2.size
            case .type:
                return file1.fileType < file2.fileType
            }
        }

        // Apply limit
        if let limit = criteria.maxResults {
            foundFiles = Array(foundFiles.prefix(limit))
        }

        return SearchResult(
            query: criteria.query,
            totalFound: foundFiles.count,
            files: foundFiles,
            searchTime: Date().timeIntervalSince(Date()),
            searchPaths: searchDirectories
        )
    }

    // MARK: - File Organization

    /// Organize files in a directory using specified strategy
    func organizeFiles(in directory: URL, strategy: OrganizationStrategy) async throws
        -> OrganizationResult
    {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Organizing files in \(directory.lastPathComponent)"
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        let fileManager = FileManager.default

        // Get all files in directory
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                URLResourceKey.contentTypeKey,
                URLResourceKey.contentModificationDateKey,
                URLResourceKey.fileSizeKey,
                URLResourceKey.isDirectoryKey,
            ])

        let files = contents.filter { url in
            let resourceValues = try? url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
            return !(resourceValues?.isDirectory ?? true)
        }

        var movedFiles: [URL] = []
        var createdFolders: [URL] = []
        var errors: [FileOperationError] = []

        for (index, file) in files.enumerated() {
            if Task.isCancelled {
                throw FileOperationError.operationCancelled
            }

            await MainActor.run {
                progress = Double(index) / Double(files.count)
                currentOperation = "Organizing: \(file.lastPathComponent)"
            }

            do {
                let targetFolder = try await determineTargetFolder(
                    for: file, in: directory, strategy: strategy)

                // Create folder if it doesn't exist
                if !fileManager.fileExists(atPath: targetFolder.path) {
                    try fileManager.createDirectory(
                        at: targetFolder, withIntermediateDirectories: true)
                    createdFolders.append(targetFolder)
                }

                // Move file
                let destination = targetFolder.appendingPathComponent(file.lastPathComponent)
                try fileManager.moveItem(at: file, to: destination)
                movedFiles.append(destination)

            } catch let error as FileOperationError {
                errors.append(error)
            } catch {
                errors.append(.operationFailed(error.localizedDescription))
            }
        }

        return OrganizationResult(
            strategy: strategy,
            processedFiles: files.count,
            movedFiles: movedFiles,
            createdFolders: createdFolders,
            errors: errors,
            summary: generateOrganizationSummary(
                movedCount: movedFiles.count,
                folderCount: createdFolders.count,
                errorCount: errors.count
            )
        )
    }

    // MARK: - Private Helper Methods

    /// Comprehensive validation with safety checks
    private func validateOperation(_ operation: FileOperation) async throws {
        // Check if operation requires user confirmation
        if await requiresUserConfirmation(operation) {
            let confirmed = await requestUserConfirmation(for: operation)
            if !confirmed {
                throw FileOperationError.operationCancelled
            }
        }

        // Perform operation-specific validation
        try await performOperationValidation(operation)

        // Check system resources
        try await validateSystemResources(for: operation)
    }

    /// Check if operation is dangerous and requires confirmation
    private func requiresUserConfirmation(_ operation: FileOperation) async -> Bool {
        switch operation {
        case .delete(let files, let moveToTrash):
            // Permanent deletion always requires confirmation
            if !moveToTrash { return true }

            // Large number of files requires confirmation
            if files.count > 10 { return true }

            // System or application files require confirmation
            return files.contains { isSystemOrApplicationFile($0) }

        case .move(let source, let destination):
            // Moving to system directories requires confirmation
            return isSystemDirectory(destination.deletingLastPathComponent())
                || isSystemOrApplicationFile(source)

        case .organize(let directory, _):
            // Organizing system directories requires confirmation
            return isSystemDirectory(directory)

        case .copy, .rename, .search:
            return false
        }
    }

    /// Request user confirmation for dangerous operations
    private func requestUserConfirmation(for operation: FileOperation) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Confirm Operation"
                alert.informativeText = self.getConfirmationMessage(for: operation)
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
        }
    }

    /// Get confirmation message for operation
    private func getConfirmationMessage(for operation: FileOperation) -> String {
        switch operation {
        case .delete(let files, let moveToTrash):
            let action = moveToTrash ? "move to trash" : "permanently delete"
            if files.count == 1 {
                return "Are you sure you want to \(action) '\(files.first!.lastPathComponent)'?"
            } else {
                return "Are you sure you want to \(action) \(files.count) files?"
            }
        case .move(let source, _):
            return
                "Are you sure you want to move '\(source.lastPathComponent)'? This may affect system functionality."
        case .organize(let directory, _):
            return
                "Are you sure you want to organize '\(directory.lastPathComponent)'? This will move files into new folders."
        default:
            return "Are you sure you want to perform this operation?"
        }
    }

    /// Perform detailed operation validation
    private func performOperationValidation(_ operation: FileOperation) async throws {
        switch operation {
        case .copy(let source, let destination):
            try await validateCopyOperation(source: source, destination: destination)

        case .move(let source, let destination):
            try await validateMoveOperation(source: source, destination: destination)

        case .delete(let files, _):
            try await validateDeleteOperation(files: files)

        case .rename(let file, let newName):
            try await validateRenameOperation(file: file, newName: newName)

        case .organize(let directory, _):
            try await validateOrganizeOperation(directory: directory)

        case .search:
            // No validation needed for search
            break

        case .extractMetadata(let files):
            // Validate files exist and are readable
            for file in files {
                guard fileManager.fileExists(atPath: file.path) else {
                    throw FileOperationError.fileNotFound(file.path)
                }
                guard fileManager.isReadableFile(atPath: file.path) else {
                    throw FileOperationError.insufficientPermissions(
                        "Cannot read file: \(file.lastPathComponent)")
                }
            }

        case .detectDuplicates(let directories, _):
            // Validate directories exist and are readable
            for directory in directories {
                guard fileManager.fileExists(atPath: directory.path) else {
                    throw FileOperationError.directoryNotFound(directory.path)
                }
                guard fileManager.isReadableFile(atPath: directory.path) else {
                    throw FileOperationError.insufficientPermissions(
                        "Cannot read directory: \(directory.lastPathComponent)")
                }
            }

        case .removeDuplicates(let groups, _):
            // Validate all files in groups exist and parent directories are writable
            for group in groups {
                for file in group.files {
                    guard fileManager.fileExists(atPath: file.url.path) else {
                        throw FileOperationError.fileNotFound(file.url.path)
                    }
                    let parentDir = file.url.deletingLastPathComponent()
                    guard fileManager.isWritableFile(atPath: parentDir.path) else {
                        throw FileOperationError.insufficientPermissions(
                            "Cannot modify directory: \(parentDir.lastPathComponent)")
                    }
                }
            }

        case .smartOrganize(let directory, _):
            // Same validation as organize operation
            try await validateOrganizeOperation(directory: directory)
        }
    }

    /// Validate copy operation
    private func validateCopyOperation(source: URL, destination: URL) async throws {
        // Check source exists and is readable
        guard fileManager.fileExists(atPath: source.path) else {
            throw FileOperationError.fileNotFound(source.path)
        }

        guard fileManager.isReadableFile(atPath: source.path) else {
            throw FileOperationError.insufficientPermissions(
                "Cannot read source file: \(source.lastPathComponent)")
        }

        // Check destination directory exists and is writable
        let destinationDir = destination.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: destinationDir.path) else {
            throw FileOperationError.destinationNotFound(destinationDir.path)
        }

        guard fileManager.isWritableFile(atPath: destinationDir.path) else {
            throw FileOperationError.insufficientPermissions(
                "Cannot write to destination: \(destinationDir.path)")
        }

        // Check if destination already exists
        if fileManager.fileExists(atPath: destination.path) {
            throw FileOperationError.fileAlreadyExists(destination.path)
        }

        // Check file size limits
        let sourceSize = try getFileSize(source)
        if sourceSize > maxFileSize {
            throw FileOperationError.operationFailed(
                "File too large: \(ByteCountFormatter.string(fromByteCount: sourceSize, countStyle: .file))"
            )
        }
    }

    /// Validate move operation
    private func validateMoveOperation(source: URL, destination: URL) async throws {
        // Perform same checks as copy
        try await validateCopyOperation(source: source, destination: destination)

        // Additional check: ensure source is writable (for deletion)
        let sourceDir = source.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: sourceDir.path) else {
            throw FileOperationError.insufficientPermissions(
                "Cannot remove source file from: \(sourceDir.path)")
        }
    }

    /// Validate delete operation
    private func validateDeleteOperation(files: [URL]) async throws {
        for file in files {
            guard fileManager.fileExists(atPath: file.path) else {
                throw FileOperationError.fileNotFound(file.path)
            }

            // Check if file is deletable
            let parentDir = file.deletingLastPathComponent()
            guard fileManager.isWritableFile(atPath: parentDir.path) else {
                throw FileOperationError.insufficientPermissions(
                    "Cannot delete file from: \(parentDir.path)")
            }

            // Warn about system files
            if isSystemOrApplicationFile(file) {
                throw FileOperationError.insufficientPermissions(
                    "Cannot delete system file: \(file.lastPathComponent)")
            }
        }
    }

    /// Validate rename operation
    private func validateRenameOperation(file: URL, newName: String) async throws {
        guard fileManager.fileExists(atPath: file.path) else {
            throw FileOperationError.fileNotFound(file.path)
        }

        // Validate new name
        guard isValidFileName(newName) else {
            throw FileOperationError.invalidFileName(newName)
        }

        // Check if new name already exists
        let newURL = file.deletingLastPathComponent().appendingPathComponent(newName)
        if fileManager.fileExists(atPath: newURL.path) {
            throw FileOperationError.fileAlreadyExists(newURL.path)
        }

        // Check write permissions
        let parentDir = file.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parentDir.path) else {
            throw FileOperationError.insufficientPermissions(
                "Cannot rename file in: \(parentDir.path)")
        }
    }

    /// Validate organize operation
    private func validateOrganizeOperation(directory: URL) async throws {
        guard fileManager.fileExists(atPath: directory.path) else {
            throw FileOperationError.directoryNotFound(directory.path)
        }

        guard fileManager.isWritableFile(atPath: directory.path) else {
            throw FileOperationError.insufficientPermissions(
                "Cannot organize files in: \(directory.path)")
        }

        // Check if directory has files to organize
        let contents = try fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        if contents.isEmpty {
            throw FileOperationError.operationFailed(
                "Directory is empty: \(directory.lastPathComponent)")
        }
    }

    /// Validate system resources
    private func validateSystemResources(for operation: FileOperation) async throws {
        // Check available disk space
        let requiredSpace = try await calculateRequiredSpace(for: operation)
        let availableSpace = try getAvailableDiskSpace()

        if availableSpace < requiredSpace + minDiskSpaceRequired {
            throw FileOperationError.diskSpaceInsufficient
        }
    }

    /// Calculate required disk space for operation
    private func calculateRequiredSpace(for operation: FileOperation) async throws -> Int64 {
        switch operation {
        case .copy(let source, _):
            return try getFileSize(source)
        case .move, .rename, .delete:
            return 0  // These don't require additional space
        case .organize(let directory, _):
            // Estimate space for creating folders (minimal)
            return 1024 * 1024  // 1MB buffer
        case .search:
            return 0
        case .extractMetadata, .detectDuplicates:
            return 0  // These operations don't require additional disk space
        case .removeDuplicates:
            return 0  // This operation frees up space
        case .smartOrganize:
            return 1024 * 1024  // 1MB buffer for creating folders
        }
    }

    /// Get file or directory size
    private func getFileSize(_ url: URL) throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [
            URLResourceKey.isDirectoryKey, URLResourceKey.fileSizeKey,
            URLResourceKey.totalFileSizeKey,
        ])

        if resourceValues.isDirectory == true {
            return resourceValues.totalFileSize?.int64Value ?? 0
        } else {
            return resourceValues.fileSize?.int64Value ?? 0
        }
    }

    /// Get available disk space
    private func getAvailableDiskSpace() throws -> Int64 {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let resourceValues = try homeURL.resourceValues(forKeys: [
            URLResourceKey.volumeAvailableCapacityKey
        ])
        return resourceValues.volumeAvailableCapacity?.int64Value ?? 0
    }

    /// Check if file is a system or application file
    private func isSystemOrApplicationFile(_ url: URL) -> Bool {
        let path = url.path
        let systemPaths = [
            "/System/",
            "/Library/",
            "/usr/",
            "/bin/",
            "/sbin/",
            "/Applications/",
        ]

        return systemPaths.contains { path.hasPrefix($0) }
    }

    /// Check if directory is a system directory
    private func isSystemDirectory(_ url: URL) -> Bool {
        let path = url.path
        let systemDirectories = [
            "/System",
            "/Library",
            "/usr",
            "/bin",
            "/sbin",
            "/Applications",
            "/private",
        ]

        return systemDirectories.contains { path.hasPrefix($0) }
    }

    /// Validate file name
    private func isValidFileName(_ name: String) -> Bool {
        // Check for empty name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        if name.rangeOfCharacter(from: invalidCharacters) != nil {
            return false
        }

        // Check for reserved names
        let reservedNames = [
            "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7",
            "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
        ]
        if reservedNames.contains(name.uppercased()) {
            return false
        }

        // Check length (macOS limit is 255 characters)
        if name.count > 255 {
            return false
        }

        return true
    }

    /// Perform the actual file operation with enhanced error handling and undo support
    private func performOperation(_ operation: FileOperation) async throws -> OperationResult {
        let startTime = Date()

        do {
            switch operation {
            case .copy(let source, let destination):
                return try await performCopyOperation(
                    source: source, destination: destination, startTime: startTime)

            case .move(let source, let destination):
                return try await performMoveOperation(
                    source: source, destination: destination, startTime: startTime)

            case .delete(let files, let moveToTrash):
                return try await performDeleteOperation(
                    files: files, moveToTrash: moveToTrash, startTime: startTime)

            case .rename(let file, let newName):
                return try await performRenameOperation(
                    file: file, newName: newName, startTime: startTime)

            case .organize(let directory, let strategy):
                return try await performOrganizeOperation(
                    directory: directory, strategy: strategy, startTime: startTime)

            case .search(let criteria):
                return try await performSearchOperation(criteria: criteria, startTime: startTime)

            case .extractMetadata(let files):
                return try await performMetadataExtractionOperation(
                    files: files, startTime: startTime)

            case .detectDuplicates(let directories, let methods):
                return try await performDuplicateDetectionOperation(
                    directories: directories, methods: methods, startTime: startTime)

            case .removeDuplicates(let groups, let keepStrategy):
                return try await performDuplicateRemovalOperation(
                    groups: groups, keepStrategy: keepStrategy, startTime: startTime)

            case .smartOrganize(let directory, let rules):
                return try await performSmartOrganizeOperation(
                    directory: directory, rules: rules, startTime: startTime)
            }
        } catch let error as FileOperationError {
            throw error
        } catch {
            throw FileOperationError.operationFailed(
                "Unexpected error: \(error.localizedDescription)")
        }
    }

    /// Perform copy operation with progress tracking
    private func performCopyOperation(source: URL, destination: URL, startTime: Date) async throws
        -> OperationResult
    {
        await MainActor.run {
            currentOperation = "Copying \(source.lastPathComponent)..."
            progress = 0.5
        }

        do {
            try fileManager.copyItem(at: source, to: destination)

            await MainActor.run {
                progress = 1.0
            }

            return OperationResult(
                success: true,
                processedFiles: [destination],
                errors: [],
                summary:
                    "Successfully copied '\(source.lastPathComponent)' to '\(destination.deletingLastPathComponent().lastPathComponent)'",
                executionTime: Date().timeIntervalSince(startTime),
                undoAction: { [weak self] in
                    try? self?.fileManager.removeItem(at: destination)
                }
            )
        } catch {
            throw FileOperationError.operationFailed(
                "Failed to copy file: \(error.localizedDescription)")
        }
    }

    /// Perform move operation with undo support
    private func performMoveOperation(source: URL, destination: URL, startTime: Date) async throws
        -> OperationResult
    {
        await MainActor.run {
            currentOperation = "Moving \(source.lastPathComponent)..."
            progress = 0.5
        }

        // Store original location for undo
        let originalSource = source

        do {
            try fileManager.moveItem(at: source, to: destination)

            await MainActor.run {
                progress = 1.0
            }

            return OperationResult(
                success: true,
                processedFiles: [destination],
                errors: [],
                summary:
                    "Successfully moved '\(originalSource.lastPathComponent)' to '\(destination.deletingLastPathComponent().lastPathComponent)'",
                executionTime: Date().timeIntervalSince(startTime),
                undoAction: { [weak self] in
                    try? self?.fileManager.moveItem(at: destination, to: originalSource)
                }
            )
        } catch {
            throw FileOperationError.operationFailed(
                "Failed to move file: \(error.localizedDescription)")
        }
    }

    /// Perform delete operation with trash support
    private func performDeleteOperation(files: [URL], moveToTrash: Bool, startTime: Date)
        async throws -> OperationResult
    {
        var processedFiles: [URL] = []
        var errors: [FileOperationError] = []
        var trashedItems: [(original: URL, trashed: URL)] = []

        for (index, file) in files.enumerated() {
            await MainActor.run {
                currentOperation = "Deleting \(file.lastPathComponent)..."
                progress = Double(index) / Double(files.count)
            }

            do {
                if moveToTrash {
                    var trashedURL: NSURL?
                    try fileManager.trashItem(at: file, resultingItemURL: &trashedURL)
                    processedFiles.append(file)

                    if let trashedURL = trashedURL as URL? {
                        trashedItems.append((original: file, trashed: trashedURL))
                    }
                } else {
                    try fileManager.removeItem(at: file)
                    processedFiles.append(file)
                }
            } catch {
                errors.append(
                    .operationFailed(
                        "Failed to delete '\(file.lastPathComponent)': \(error.localizedDescription)"
                    ))
            }
        }

        await MainActor.run {
            progress = 1.0
        }

        let action = moveToTrash ? "moved to trash" : "permanently deleted"
        let summary =
            if errors.isEmpty {
                "Successfully \(action) \(processedFiles.count) file(s)"
            } else {
                "\(action.capitalized) \(processedFiles.count) of \(files.count) files (\(errors.count) errors)"
            }

        // Create undo action for trash operations
        let undoAction: (() -> Void)? =
            if moveToTrash && !trashedItems.isEmpty {
                { [weak self] in
                    for item in trashedItems {
                        try? self?.fileManager.moveItem(at: item.trashed, to: item.original)
                    }
                }
            } else {
                nil
            }

        return OperationResult(
            success: errors.isEmpty,
            processedFiles: processedFiles,
            errors: errors,
            summary: summary,
            executionTime: Date().timeIntervalSince(startTime),
            undoAction: undoAction
        )
    }

    /// Perform rename operation with validation
    private func performRenameOperation(file: URL, newName: String, startTime: Date) async throws
        -> OperationResult
    {
        await MainActor.run {
            currentOperation = "Renaming \(file.lastPathComponent)..."
            progress = 0.5
        }

        let originalName = file.lastPathComponent
        let newURL = file.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try fileManager.moveItem(at: file, to: newURL)

            await MainActor.run {
                progress = 1.0
            }

            return OperationResult(
                success: true,
                processedFiles: [newURL],
                errors: [],
                summary: "Successfully renamed '\(originalName)' to '\(newName)'",
                executionTime: Date().timeIntervalSince(startTime),
                undoAction: { [weak self] in
                    try? self?.fileManager.moveItem(at: newURL, to: file)
                }
            )
        } catch {
            throw FileOperationError.operationFailed(
                "Failed to rename file: \(error.localizedDescription)")
        }
    }

    /// Perform organize operation with detailed tracking
    private func performOrganizeOperation(
        directory: URL, strategy: OrganizationStrategy, startTime: Date
    ) async throws -> OperationResult {
        let result = try await organizeFiles(in: directory, strategy: strategy)

        // Create undo action for organization
        let undoAction: (() -> Void)? =
            if !result.movedFiles.isEmpty {
                { [weak self] in
                    // Move files back to original directory
                    for movedFile in result.movedFiles {
                        let originalLocation = directory.appendingPathComponent(
                            movedFile.lastPathComponent)
                        try? self?.fileManager.moveItem(at: movedFile, to: originalLocation)
                    }

                    // Remove created folders if they're empty
                    for folder in result.createdFolders {
                        let contents = try? self?.fileManager.contentsOfDirectory(
                            at: folder, includingPropertiesForKeys: nil)
                        if contents?.isEmpty == true {
                            try? self?.fileManager.removeItem(at: folder)
                        }
                    }
                }
            } else {
                nil
            }

        return OperationResult(
            success: result.errors.isEmpty,
            processedFiles: result.movedFiles,
            errors: result.errors,
            summary: result.summary,
            executionTime: Date().timeIntervalSince(startTime),
            undoAction: undoAction
        )
    }

    /// Perform search operation
    private func performSearchOperation(criteria: SearchCriteria, startTime: Date) async throws
        -> OperationResult
    {
        let result = try await searchFiles(criteria: criteria)

        return OperationResult(
            success: true,
            processedFiles: result.files.map { $0.url },
            errors: [],
            summary: "Found \(result.totalFound) files matching '\(criteria.query)'",
            executionTime: Date().timeIntervalSince(startTime),
            undoAction: nil  // Search operations don't need undo
        )
    }

    /// Perform metadata extraction operation
    private func performMetadataExtractionOperation(files: [URL], startTime: Date) async throws
        -> OperationResult
    {
        let metadataMap = try await extractMetadataFromFiles(files)

        return OperationResult(
            success: true,
            processedFiles: files,
            errors: [],
            summary: "Extracted metadata from \(metadataMap.count) of \(files.count) files",
            executionTime: Date().timeIntervalSince(startTime),
            undoAction: nil  // Metadata extraction doesn't need undo
        )
    }

    /// Perform duplicate detection operation
    private func performDuplicateDetectionOperation(
        directories: [URL],
        methods: Set<DuplicateDetectionMethod>,
        startTime: Date
    ) async throws -> OperationResult {
        let result = try await detectDuplicates(in: directories, methods: methods)

        return OperationResult(
            success: true,
            processedFiles: [],
            errors: [],
            summary:
                "Found \(result.totalDuplicates) duplicates in \(result.duplicateGroups.count) groups. Potential savings: \(result.formattedSavings)",
            executionTime: Date().timeIntervalSince(startTime),
            undoAction: nil  // Detection doesn't need undo
        )
    }

    /// Perform duplicate removal operation
    private func performDuplicateRemovalOperation(
        groups: [DuplicateGroup],
        keepStrategy: KeepStrategy,
        startTime: Date
    ) async throws -> OperationResult {
        let result = try await removeDuplicates(from: groups, keepStrategy: keepStrategy)

        let errors = result.errors.map { error in
            FileOperationError.operationFailed(
                "Failed to remove \(error.file.lastPathComponent): \(error.error)")
        }

        return OperationResult(
            success: result.errors.isEmpty,
            processedFiles: result.removedFiles,
            errors: errors,
            summary:
                "Removed \(result.removedFiles.count) duplicate files, saved \(result.formattedSpaceSaved)",
            executionTime: Date().timeIntervalSince(startTime),
            undoAction: nil  // Files moved to trash, can be restored from there
        )
    }

    /// Perform smart organization operation
    private func performSmartOrganizeOperation(
        directory: URL,
        rules: [SmartOrganizationRule],
        startTime: Date
    ) async throws -> OperationResult {
        let result = try await organizeFilesWithMetadata(in: directory, rules: rules)

        let errors = result.errors.map { error in
            FileOperationError.operationFailed(error.localizedDescription)
        }

        return OperationResult(
            success: result.errors.isEmpty,
            processedFiles: result.movedFiles,
            errors: errors,
            summary: result.summary,
            executionTime: Date().timeIntervalSince(startTime),
            undoAction: nil  // Complex operation, undo would be difficult
        )
    }

    /// Search for files in a specific directory
    private func searchInDirectory(_ directory: URL, criteria: SearchCriteria) async throws
        -> [FileInfo]
    {
        let fileManager = FileManager.default
        var foundFiles: [FileInfo] = []

        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                URLResourceKey.contentTypeKey,
                URLResourceKey.contentModificationDateKey,
                URLResourceKey.fileSizeKey,
                URLResourceKey.isDirectoryKey,
                URLResourceKey.nameKey,
            ],
            options: criteria.includeSubdirectories ? [] : [.skipsSubdirectoryDescendants]
        )

        while let url = enumerator?.nextObject() as? URL {
            if Task.isCancelled {
                break
            }

            do {
                let resourceValues = try url.resourceValues(forKeys: [
                    URLResourceKey.contentTypeKey,
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.fileSizeKey,
                    URLResourceKey.isDirectoryKey,
                    URLResourceKey.nameKey,
                ])

                // Skip directories if not requested
                if resourceValues.isDirectory == true && !criteria.includeDirectories {
                    continue
                }

                // Check if file matches criteria
                if try await fileMatchesCriteria(
                    url, resourceValues: resourceValues, criteria: criteria)
                {
                    let fileInfo = FileInfo(
                        url: url,
                        name: resourceValues.name ?? url.lastPathComponent,
                        size: Int64(resourceValues.fileSize ?? 0),
                        dateModified: resourceValues.contentModificationDate ?? Date(),
                        fileType: resourceValues.contentType?.identifier ?? "unknown",
                        isDirectory: resourceValues.isDirectory ?? false
                    )
                    foundFiles.append(fileInfo)
                }
            } catch {
                // Skip files that can't be read
                continue
            }
        }

        return foundFiles
    }

    /// Check if a file matches the search criteria
    private func fileMatchesCriteria(
        _ url: URL, resourceValues: URLResourceValues, criteria: SearchCriteria
    ) async throws -> Bool {
        let fileName = resourceValues.name ?? url.lastPathComponent

        // Name matching
        if !criteria.query.isEmpty {
            let matchesName = fileName.localizedCaseInsensitiveContains(criteria.query)

            // Content search for text files
            var matchesContent = false
            if criteria.searchContent && !resourceValues.isDirectory! {
                matchesContent = try await searchFileContent(url, query: criteria.query)
            }

            if !matchesName && !matchesContent {
                return false
            }
        }

        // File type filtering
        if !criteria.fileTypes.isEmpty {
            let fileType = resourceValues.contentType?.identifier ?? "unknown"
            let matchesType = criteria.fileTypes.contains { type in
                fileType.contains(type) || fileName.hasSuffix(".\(type)")
            }
            if !matchesType {
                return false
            }
        }

        // Size filtering
        let fileSize = Int64(resourceValues.fileSize ?? 0)
        if let minSize = criteria.minSize, fileSize < minSize {
            return false
        }
        if let maxSize = criteria.maxSize, fileSize > maxSize {
            return false
        }

        // Date filtering
        let modificationDate = resourceValues.contentModificationDate ?? Date.distantPast
        if let afterDate = criteria.modifiedAfter, modificationDate < afterDate {
            return false
        }
        if let beforeDate = criteria.modifiedBefore, modificationDate > beforeDate {
            return false
        }

        return true
    }

    /// Search file content for text query
    private func searchFileContent(_ url: URL, query: String) async throws -> Bool {
        // Only search text files to avoid binary files
        let contentType = try url.resourceValues(forKeys: [URLResourceKey.contentTypeKey])
            .contentType

        guard let contentType = contentType,
            contentType.conforms(to: .text) || contentType.conforms(to: .plainText)
        else {
            return false
        }

        // Limit file size for content search (max 10MB)
        let fileSize = try url.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize ?? 0
        guard fileSize < 10_000_000 else {
            return false
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return content.localizedCaseInsensitiveContains(query)
        } catch {
            // Try other encodings or skip
            return false
        }
    }

    /// Determine target folder for file organization
    private func determineTargetFolder(
        for file: URL, in baseDirectory: URL, strategy: OrganizationStrategy
    ) async throws -> URL {
        switch strategy {
        case .byType:
            let fileType = try getFileCategory(for: file)
            return baseDirectory.appendingPathComponent(fileType.folderName)

        case .byDate:
            let resourceValues = try file.resourceValues(forKeys: [
                URLResourceKey.contentModificationDateKey
            ])
            let date = resourceValues.contentModificationDate ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let folderName = formatter.string(from: date)
            return baseDirectory.appendingPathComponent(folderName)

        case .bySize:
            let resourceValues = try file.resourceValues(forKeys: [URLResourceKey.fileSizeKey])
            let size = Int64(resourceValues.fileSize ?? 0)
            let sizeCategory = getSizeCategory(size)
            return baseDirectory.appendingPathComponent(sizeCategory.folderName)

        case .custom(let rules):
            for rule in rules {
                if try await fileMatchesRule(file, rule: rule) {
                    return baseDirectory.appendingPathComponent(rule.targetFolder)
                }
            }
            return baseDirectory.appendingPathComponent("Other")
        }
    }

    /// Get file category for organization
    private func getFileCategory(for file: URL) throws -> FileCategory {
        let contentType = try file.resourceValues(forKeys: [URLResourceKey.contentTypeKey])
            .contentType
        let fileExtension = file.pathExtension.lowercased()

        if let contentType = contentType {
            if contentType.conforms(to: .image) {
                return .images
            } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
                return .videos
            } else if contentType.conforms(to: .audio) {
                return .audio
            } else if contentType.conforms(to: .text) || contentType.conforms(to: .plainText) {
                return .documents
            } else if contentType.conforms(to: .archive) {
                return .archives
            }
        }

        // Fallback to extension-based detection
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp":
            return .images
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm":
            return .videos
        case "mp3", "wav", "aac", "flac", "ogg", "m4a":
            return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "md":
            return .documents
        case "zip", "rar", "7z", "tar", "gz":
            return .archives
        case "app", "pkg", "dmg", "exe":
            return .applications
        default:
            return .other
        }
    }

    /// Get size category for file
    private func getSizeCategory(_ size: Int64) -> SizeCategory {
        if size < 1_000_000 {  // < 1MB
            return .small
        } else if size < 100_000_000 {  // < 100MB
            return .medium
        } else {
            return .large
        }
    }

    /// Check if file matches organization rule
    private func fileMatchesRule(_ file: URL, rule: OrganizationRule) async throws -> Bool {
        switch rule.criteria {
        case .nameContains(let text):
            return file.lastPathComponent.localizedCaseInsensitiveContains(text)
        case .fileExtension(let ext):
            return file.pathExtension.lowercased() == ext.lowercased()
        case .contentType(let type):
            let contentType = try file.resourceValues(forKeys: [URLResourceKey.contentTypeKey])
                .contentType
            return contentType?.identifier.contains(type) ?? false
        case .sizeRange(let min, let max):
            let size = try file.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize ?? 0
            return size >= min && size <= max
        }
    }

    /// Generate summary for batch operations
    private func generateBatchSummary(results: [OperationResult], errors: [FileOperationError])
        -> String
    {
        let successCount = results.filter { $0.success }.count
        let totalFiles = results.reduce(0) { $0 + $1.processedFiles.count }

        if errors.isEmpty {
            return "Successfully completed \(successCount) operations affecting \(totalFiles) files"
        } else {
            return
                "Completed \(successCount) operations with \(errors.count) errors affecting \(totalFiles) files"
        }
    }

    /// Generate summary for organization operations
    private func generateOrganizationSummary(movedCount: Int, folderCount: Int, errorCount: Int)
        -> String
    {
        var summary = "Organized \(movedCount) files"
        if folderCount > 0 {
            summary += ", created \(folderCount) folders"
        }
        if errorCount > 0 {
            summary += " with \(errorCount) errors"
        }
        return summary
    }

    // MARK: - Metadata Extraction

    /// Extract metadata from a single file
    func extractFileMetadata(from url: URL) async throws -> FileMetadata {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Extracting metadata from \(url.lastPathComponent)..."
            progress = 0.5
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 0.0
            }
        }

        return try await metadataService.extractMetadata(from: url)
    }

    /// Extract metadata from multiple files with progress tracking
    func extractMetadataFromFiles(_ urls: [URL]) async throws -> [URL: FileMetadata] {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Extracting metadata from \(urls.count) files..."
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        return try await metadataService.extractMetadataFromFiles(urls) { processed, total in
            Task { @MainActor in
                self.progress = Double(processed) / Double(total)
                self.currentOperation = "Processed \(processed) of \(total) files..."
            }
        }
    }

    /// Search files with enhanced metadata filtering
    func searchFilesWithMetadata(criteria: SearchCriteria) async throws -> SearchResult {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Searching files with metadata..."
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        // First perform regular search
        let basicResult = try await searchFiles(criteria: criteria)

        // Then enhance with metadata for found files
        let metadataMap = try await metadataService.extractMetadataFromFiles(
            basicResult.files.map { $0.url }
        ) { processed, total in
            Task { @MainActor in
                self.progress = 0.5 + (Double(processed) / Double(total)) * 0.5
            }
        }

        // Create enhanced file info with metadata
        let enhancedFiles = basicResult.files.map { fileInfo in
            FileInfo(
                url: fileInfo.url,
                name: fileInfo.name,
                size: fileInfo.size,
                dateModified: fileInfo.dateModified,
                fileType: fileInfo.fileType,
                isDirectory: fileInfo.isDirectory,
                metadata: metadataMap[fileInfo.url]
            )
        }

        return SearchResult(
            query: basicResult.query,
            totalFound: basicResult.totalFound,
            files: enhancedFiles,
            searchTime: basicResult.searchTime,
            searchPaths: basicResult.searchPaths
        )
    }

    // MARK: - Duplicate Detection

    /// Detect duplicate files in specified directories
    func detectDuplicates(
        in directories: [URL],
        methods: Set<DuplicateDetectionMethod> = [.contentHash, .nameAndSize]
    ) async throws -> DuplicateDetectionResult {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Detecting duplicates..."
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        return try await duplicateService.detectDuplicates(in: directories, methods: methods) {
            progress, operation in
            Task { @MainActor in
                self.progress = progress
                self.currentOperation = operation
            }
        }
    }

    /// Remove duplicate files keeping originals
    func removeDuplicates(
        from groups: [DuplicateGroup],
        keepStrategy: KeepStrategy = .oldest
    ) async throws -> DuplicateRemovalResult {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Removing duplicates..."
            progress = 0.5
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        return try await duplicateService.removeDuplicates(from: groups, keepStrategy: keepStrategy)
    }

    // MARK: - Smart Organization

    /// Organize files using smart metadata-based rules
    func organizeFilesWithMetadata(
        in directory: URL,
        rules: [SmartOrganizationRule]? = nil
    ) async throws -> SmartOrganizationResult {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Smart organizing files..."
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        let organizationRules = rules ?? smartOrganizationService.createDefaultRules()

        return try await smartOrganizationService.organizeFilesWithMetadata(
            in: directory,
            rules: organizationRules,
            createSubfolders: true
        ) { progress, operation in
            Task { @MainActor in
                self.progress = progress
                self.currentOperation = operation
            }
        }
    }

    /// Organize photos by metadata (date, camera, location)
    func organizePhotosByMetadata(
        in directory: URL,
        method: PhotoOrganizationMethod = .dateAndCamera
    ) async throws -> SmartOrganizationResult {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Organizing photos by metadata..."
            progress = 0.0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                currentOperation = ""
                progress = 1.0
            }
        }

        return try await smartOrganizationService.organizePhotosByMetadata(
            in: directory, groupBy: method)
    }

    /// Get file information with metadata
    func getFileInfoWithMetadata(_ url: URL) async throws -> FileInfo {
        let resourceValues = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .contentTypeKey,
            .isDirectoryKey,
        ])

        let metadata = try await metadataService.extractMetadata(from: url)

        return FileInfo(
            url: url,
            name: url.lastPathComponent,
            size: Int64(resourceValues.fileSize ?? 0),
            dateModified: resourceValues.contentModificationDate ?? Date(),
            fileType: resourceValues.contentType?.description ?? url.pathExtension,
            isDirectory: resourceValues.isDirectory ?? false,
            metadata: metadata
        )
    }
}
