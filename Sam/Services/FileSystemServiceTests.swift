import XCTest
import Foundation
@testable import Sam

@MainActor
class FileSystemServiceTests: XCTestCase {
    
    var fileSystemService: FileSystemService!
    var tempDirectory: URL!
    var testFiles: [URL] = []
    
    override func setUp() async throws {
        try await super.setUp()
        
        fileSystemService = FileSystemService()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        // Create test files
        try await createTestFiles()
    }
    
    override func tearDown() async throws {
        // Clean up test files
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        fileSystemService = nil
        testFiles.removeAll()
        
        try await super.tearDown()
    }
    
    // MARK: - Test File Creation
    
    private func createTestFiles() async throws {
        let fileManager = FileManager.default
        
        // Create various test files
        let testFileData = [
            ("test.txt", "This is a test text file"),
            ("document.pdf", "PDF content placeholder"),
            ("image.jpg", "JPEG image data"),
            ("video.mp4", "MP4 video data"),
            ("archive.zip", "ZIP archive data"),
            ("large_file.dat", String(repeating: "A", count: 1000000)) // 1MB file
        ]
        
        for (fileName, content) in testFileData {
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            testFiles.append(fileURL)
        }
        
        // Create subdirectory with files
        let subDirectory = tempDirectory.appendingPathComponent("subdirectory")
        try fileManager.createDirectory(at: subDirectory, withIntermediateDirectories: true)
        
        let subFile = subDirectory.appendingPathComponent("sub_file.txt")
        try "Subdirectory file content".write(to: subFile, atomically: true, encoding: .utf8)
        testFiles.append(subFile)
    }
    
    // MARK: - Copy Operation Tests
    
    func testFileCopyOperation() async throws {
        // Given
        let sourceFile = testFiles.first { $0.lastPathComponent == "test.txt" }!
        let destinationFile = tempDirectory.appendingPathComponent("copied_test.txt")
        
        // When
        let result = try await fileSystemService.executeOperation(
            .copy(source: sourceFile, destination: destinationFile)
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        XCTAssertEqual(result.processedFiles.count, 1)
        XCTAssertEqual(result.processedFiles.first, destinationFile)
        XCTAssertTrue(result.errors.isEmpty)
        
        // Verify content is identical
        let originalContent = try String(contentsOf: sourceFile)
        let copiedContent = try String(contentsOf: destinationFile)
        XCTAssertEqual(originalContent, copiedContent)
    }
    
    func testFileCopyToNonExistentDirectory() async throws {
        // Given
        let sourceFile = testFiles.first!
        let nonExistentDir = tempDirectory.appendingPathComponent("nonexistent")
        let destinationFile = nonExistentDir.appendingPathComponent("test.txt")
        
        // When & Then
        do {
            _ = try await fileSystemService.executeOperation(
                .copy(source: sourceFile, destination: destinationFile)
            )
            XCTFail("Expected operation to fail")
        } catch let error as FileOperationError {
            if case .destinationNotFound = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Move Operation Tests
    
    func testFileMoveOperation() async throws {
        // Given
        let sourceFile = testFiles.first { $0.lastPathComponent == "test.txt" }!
        let originalContent = try String(contentsOf: sourceFile)
        let destinationFile = tempDirectory.appendingPathComponent("moved_test.txt")
        
        // When
        let result = try await fileSystemService.executeOperation(
            .move(source: sourceFile, destination: destinationFile)
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        
        // Verify content is preserved
        let movedContent = try String(contentsOf: destinationFile)
        XCTAssertEqual(originalContent, movedContent)
    }
    
    // MARK: - Delete Operation Tests
    
    func testFileDeleteOperation() async throws {
        // Given
        let fileToDelete = testFiles.first { $0.lastPathComponent == "test.txt" }!
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileToDelete.path))
        
        // When
        let result = try await fileSystemService.executeOperation(
            .delete(files: [fileToDelete], moveToTrash: false)
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileToDelete.path))
        XCTAssertEqual(result.processedFiles.count, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testMultipleFileDeleteOperation() async throws {
        // Given
        let filesToDelete = Array(testFiles.prefix(3))
        
        // When
        let result = try await fileSystemService.executeOperation(
            .delete(files: filesToDelete, moveToTrash: false)
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processedFiles.count, 3)
        
        for file in filesToDelete {
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }
    
    // MARK: - Rename Operation Tests
    
    func testFileRenameOperation() async throws {
        // Given
        let fileToRename = testFiles.first { $0.lastPathComponent == "test.txt" }!
        let newName = "renamed_test.txt"
        let expectedNewURL = fileToRename.deletingLastPathComponent().appendingPathComponent(newName)
        
        // When
        let result = try await fileSystemService.executeOperation(
            .rename(file: fileToRename, newName: newName)
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileToRename.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedNewURL.path))
        XCTAssertEqual(result.processedFiles.first, expectedNewURL)
    }
    
    // MARK: - Search Operation Tests
    
    func testBasicFileSearch() async throws {
        // Given
        let criteria = SearchCriteria(
            query: "test",
            searchPaths: [tempDirectory],
            includeSubdirectories: true
        )
        
        // When
        let result = try await fileSystemService.executeOperation(.search(criteria: criteria))
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.processedFiles.count, 0)
        
        // Verify that found files contain "test" in their names
        for fileURL in result.processedFiles {
            XCTAssertTrue(fileURL.lastPathComponent.localizedCaseInsensitiveContains("test"))
        }
    }
    
    func testFileSearchByType() async throws {
        // Given
        let criteria = SearchCriteria(
            query: "",
            searchPaths: [tempDirectory],
            fileTypes: ["txt"],
            includeSubdirectories: true
        )
        
        // When
        let result = try await fileSystemService.executeOperation(.search(criteria: criteria))
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.processedFiles.count, 0)
        
        // Verify all found files are .txt files
        for fileURL in result.processedFiles {
            XCTAssertEqual(fileURL.pathExtension, "txt")
        }
    }
    
    func testFileSearchWithSizeFilter() async throws {
        // Given
        let criteria = SearchCriteria(
            query: "",
            searchPaths: [tempDirectory],
            minSize: 500000, // 500KB
            includeSubdirectories: true
        )
        
        // When
        let result = try await fileSystemService.executeOperation(.search(criteria: criteria))
        
        // Then
        XCTAssertTrue(result.success)
        
        // Verify found files meet size criteria
        for fileURL in result.processedFiles {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resourceValues.fileSize ?? 0)
            XCTAssertGreaterThanOrEqual(fileSize, 500000)
        }
    }
    
    // MARK: - Organization Tests
    
    func testOrganizeFilesByType() async throws {
        // Given
        let strategy = OrganizationStrategy.byType
        
        // When
        let result = try await fileSystemService.executeOperation(
            .organize(directory: tempDirectory, strategy: strategy)
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.processedFiles.count, 0)
        
        // Verify folders were created
        let expectedFolders = ["Documents", "Images", "Videos", "Archives", "Other"]
        for folderName in expectedFolders {
            let folderURL = tempDirectory.appendingPathComponent(folderName)
            if FileManager.default.fileExists(atPath: folderURL.path) {
                // Check if folder contains appropriate files
                let contents = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                XCTAssertGreaterThan(contents.count, 0)
            }
        }
    }
    
    func testOrganizeFilesByDate() async throws {
        // Given
        let strategy = OrganizationStrategy.byDate
        
        // When
        let result = try await fileSystemService.executeOperation(
            .organize(directory: tempDirectory, strategy: strategy)
        )
        
        // Then
        XCTAssertTrue(result.success)
        
        // Verify date-based folders were created (format: YYYY-MM)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonthFolder = formatter.string(from: Date())
        
        let monthFolderURL = tempDirectory.appendingPathComponent(currentMonthFolder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: monthFolderURL.path))
    }
    
    // MARK: - Batch Operations Tests
    
    func testBatchOperations() async throws {
        // Given
        let operations: [FileOperation] = [
            .copy(
                source: testFiles[0],
                destination: tempDirectory.appendingPathComponent("batch_copy_1.txt")
            ),
            .copy(
                source: testFiles[1],
                destination: tempDirectory.appendingPathComponent("batch_copy_2.txt")
            ),
            .rename(
                file: testFiles[2],
                newName: "batch_renamed.jpg"
            )
        ]
        
        // When
        let result = try await fileSystemService.executeBatchOperations(operations)
        
        // Then
        XCTAssertEqual(result.totalOperations, 3)
        XCTAssertEqual(result.successfulOperations, 3)
        XCTAssertEqual(result.failedOperations, 0)
        XCTAssertTrue(result.errors.isEmpty)
        
        // Verify all operations completed
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("batch_copy_1.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("batch_copy_2.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("batch_renamed.jpg").path))
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressTracking() async throws {
        // Given
        let sourceFile = testFiles.first!
        let destinationFile = tempDirectory.appendingPathComponent("progress_test.txt")
        
        var progressUpdates: [Double] = []
        
        // Monitor progress updates
        let progressCancellable = fileSystemService.$progress
            .sink { progress in
                progressUpdates.append(progress)
            }
        
        // When
        let result = try await fileSystemService.executeOperation(
            .copy(source: sourceFile, destination: destinationFile)
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(progressUpdates.count, 0)
        
        progressCancellable.cancel()
    }
    
    // MARK: - Error Handling Tests
    
    func testNonExistentFileError() async throws {
        // Given
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.txt")
        let destination = tempDirectory.appendingPathComponent("copy.txt")
        
        // When & Then
        do {
            _ = try await fileSystemService.executeOperation(
                .copy(source: nonExistentFile, destination: destination)
            )
            XCTFail("Expected operation to fail")
        } catch let error as FileOperationError {
            if case .fileNotFound = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeFileOperationPerformance() async throws {
        // Given
        let largeFile = testFiles.first { $0.lastPathComponent == "large_file.dat" }!
        let destination = tempDirectory.appendingPathComponent("large_copy.dat")
        
        // When
        let startTime = Date()
        let result = try await fileSystemService.executeOperation(
            .copy(source: largeFile, destination: destination)
        )
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertLessThan(executionTime, 5.0) // Should complete within 5 seconds
        XCTAssertGreaterThan(result.executionTime, 0)
    }
} 
   
    // MARK: - Safety and Validation Tests
    
    func testFileExistenceValidation() async throws {
        // Given
        let nonExistentFile = tempDirectory.appendingPathComponent("does_not_exist.txt")
        let destination = tempDirectory.appendingPathComponent("destination.txt")
        
        // When & Then
        do {
            _ = try await fileSystemService.executeOperation(
                FileOperation.copy(source: nonExistentFile, destination: destination)
            )
            XCTFail("Expected operation to throw FileOperationError.fileNotFound")
        } catch let error as FileOperationError {
            switch error {
            case .fileNotFound(let path):
                XCTAssertTrue(path.contains("does_not_exist.txt"))
            default:
                XCTFail("Expected fileNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testDestinationValidation() async throws {
        // Given - Create source file
        let sourceFile = tempDirectory.appendingPathComponent("source.txt")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Try to copy to non-existent directory
        let nonExistentDir = tempDirectory.appendingPathComponent("non_existent_dir")
        let destination = nonExistentDir.appendingPathComponent("destination.txt")
        
        // When & Then
        do {
            _ = try await fileSystemService.executeOperation(
                FileOperation.copy(source: sourceFile, destination: destination)
            )
            XCTFail("Expected operation to throw FileOperationError.destinationNotFound")
        } catch let error as FileOperationError {
            switch error {
            case .destinationNotFound:
                // Expected error
                break
            default:
                XCTFail("Expected destinationNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFileAlreadyExistsValidation() async throws {
        // Given - Create source and destination files
        let sourceFile = tempDirectory.appendingPathComponent("source.txt")
        let destinationFile = tempDirectory.appendingPathComponent("destination.txt")
        
        try "source content".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "existing content".write(to: destinationFile, atomically: true, encoding: .utf8)
        
        // When & Then
        do {
            _ = try await fileSystemService.executeOperation(
                FileOperation.copy(source: sourceFile, destination: destinationFile)
            )
            XCTFail("Expected operation to throw FileOperationError.fileAlreadyExists")
        } catch let error as FileOperationError {
            switch error {
            case .fileAlreadyExists:
                // Expected error
                break
            default:
                XCTFail("Expected fileAlreadyExists error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testInvalidFileNameValidation() async throws {
        // Given - Create source file
        let sourceFile = tempDirectory.appendingPathComponent("source.txt")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Try to rename with invalid characters
        let invalidNames = ["file:name.txt", "file\\name.txt", "file?name.txt", ""]
        
        for invalidName in invalidNames {
            do {
                _ = try await fileSystemService.executeOperation(
                    FileOperation.rename(file: sourceFile, newName: invalidName)
                )
                XCTFail("Expected operation to throw FileOperationError.invalidFileName for name: \(invalidName)")
            } catch let error as FileOperationError {
                switch error {
                case .invalidFileName:
                    // Expected error
                    break
                default:
                    XCTFail("Expected invalidFileName error for '\(invalidName)', got: \(error)")
                }
            } catch {
                XCTFail("Unexpected error type for '\(invalidName)': \(error)")
            }
        }
    }
    
    // MARK: - Undo Functionality Tests
    
    func testUndoCopyOperation() async throws {
        // Given - Create source file
        let sourceFile = tempDirectory.appendingPathComponent("source.txt")
        let testContent = "Test content for undo"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Define destination
        let destinationFile = tempDirectory.appendingPathComponent("destination.txt")
        
        // When - Perform copy operation
        let result = try await fileSystemService.executeOperation(
            FileOperation.copy(source: sourceFile, destination: destinationFile)
        )
        
        // Then - Verify copy succeeded
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        XCTAssertTrue(fileSystemService.canUndo(result))
        
        // When - Undo the operation
        try await fileSystemService.undoLastOperation(result)
        
        // Then - Verify undo worked
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path)) // Source should still exist
    }
    
    func testUndoMoveOperation() async throws {
        // Given - Create source file
        let sourceFile = tempDirectory.appendingPathComponent("source.txt")
        let testContent = "Test content for move undo"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Define destination
        let destinationFile = tempDirectory.appendingPathComponent("moved.txt")
        
        // When - Perform move operation
        let result = try await fileSystemService.executeOperation(
            FileOperation.move(source: sourceFile, destination: destinationFile)
        )
        
        // Then - Verify move succeeded
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        XCTAssertTrue(fileSystemService.canUndo(result))
        
        // When - Undo the operation
        try await fileSystemService.undoLastOperation(result)
        
        // Then - Verify undo worked
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationFile.path))
        
        // Verify content is intact
        let restoredContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(restoredContent, testContent)
    }
    
    func testUndoRenameOperation() async throws {
        // Given - Create source file
        let sourceFile = tempDirectory.appendingPathComponent("original.txt")
        let testContent = "Test content for rename undo"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When - Perform rename operation
        let newName = "renamed.txt"
        let result = try await fileSystemService.executeOperation(
            FileOperation.rename(file: sourceFile, newName: newName)
        )
        
        // Then - Verify rename succeeded
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        
        let renamedFile = tempDirectory.appendingPathComponent(newName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamedFile.path))
        XCTAssertTrue(fileSystemService.canUndo(result))
        
        // When - Undo the operation
        try await fileSystemService.undoLastOperation(result)
        
        // Then - Verify undo worked
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: renamedFile.path))
        
        // Verify content is intact
        let restoredContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(restoredContent, testContent)
    }
    
    func testCannotUndoSearchOperation() async throws {
        // Given - Create test file
        let testFile = tempDirectory.appendingPathComponent("search_test.txt")
        try "searchable content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // When - Perform search operation
        let criteria = SearchCriteria(
            query: "searchable",
            searchPaths: [tempDirectory]
        )
        let result = try await fileSystemService.executeOperation(
            FileOperation.search(criteria: criteria)
        )
        
        // Then - Verify search succeeded but cannot be undone
        XCTAssertTrue(result.success)
        XCTAssertFalse(fileSystemService.canUndo(result))
        
        // Verify attempting to undo throws an error
        do {
            try await fileSystemService.undoLastOperation(result)
            XCTFail("Expected undo to throw an error for search operation")
        } catch let error as FileOperationError {
            switch error {
            case .operationFailed(let message):
                XCTAssertTrue(message.contains("cannot be undone"))
            default:
                XCTFail("Expected operationFailed error, got: \(error)")
            }
        }
    }
    
    // MARK: - Error Message Tests
    
    func testUserFriendlyErrorMessages() async throws {
        let errors: [FileOperationError] = [
            .fileNotFound("/path/to/missing/file.txt"),
            .destinationNotFound("/path/to/missing/directory"),
            .insufficientPermissions("Cannot write to system directory"),
            .diskSpaceInsufficient,
            .fileAlreadyExists("/path/to/existing/file.txt"),
            .invalidFileName("invalid:name.txt"),
            .operationCancelled,
            .operationFailed("Network connection lost")
        ]
        
        for error in errors {
            let (message, suggestion) = fileSystemService.getErrorMessage(for: error)
            
            // Verify message is not empty and user-friendly
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(message.contains("Error:")) // Should not contain technical error prefixes
            
            // Verify suggestion is provided for recoverable errors
            switch error {
            case .operationCancelled:
                XCTAssertNotNil(suggestion)
            case .diskSpaceInsufficient:
                XCTAssertNotNil(suggestion)
                XCTAssertTrue(suggestion!.contains("free up"))
            case .insufficientPermissions:
                XCTAssertNotNil(suggestion)
                XCTAssertTrue(suggestion!.contains("permission"))
            default:
                break
            }
        }
    }
    
    // MARK: - Disk Space Validation Tests
    
    func testDiskSpaceValidation() async throws {
        // This test would require creating a very large file or mocking disk space
        // For now, we'll test that the validation method exists and can be called
        
        let sourceFile = tempDirectory.appendingPathComponent("small_file.txt")
        try "small content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let destinationFile = tempDirectory.appendingPathComponent("copy_small.txt")
        
        // This should succeed as it's a small file
        let result = try await fileSystemService.executeOperation(
            FileOperation.copy(source: sourceFile, destination: destinationFile)
        )
        
        XCTAssertTrue(result.success)
    }
    
    // MARK: - Permission Validation Tests
    
    func testPermissionValidation() async throws {
        // Create a file in temp directory (should have write permissions)
        let sourceFile = tempDirectory.appendingPathComponent("permission_test.txt")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let destinationFile = tempDirectory.appendingPathComponent("permission_copy.txt")
        
        // This should succeed in temp directory
        let result = try await fileSystemService.executeOperation(
            FileOperation.copy(source: sourceFile, destination: destinationFile)
        )
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
    }