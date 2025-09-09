import XCTest
import Foundation
@testable import Sam

final class FileSystemServiceTests: XCTestCase {
    var fileSystemService: FileSystemService!
    var testDirectory: URL!
    var mockPermissionManager: MockPermissionManager!
    
    override func setUp() {
        super.setUp()
        mockPermissionManager = MockPermissionManager()
        fileSystemService = FileSystemService(permissionManager: mockPermissionManager)
        
        // Create temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceTests_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(
                at: testDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create test directory: \(error)")
        }
    }
    
    override func tearDown() {
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        fileSystemService = nil
        mockPermissionManager = nil
        super.tearDown()
    }
    
    // MARK: - File Operation Validation Tests
    
    func testValidateFileOperation() async throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("source.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        try "Test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
        
        // When & Then
        try await fileSystemService.validateOperation(operation)
        // Should not throw
    }
    
    func testValidateOperationWithMissingSource() async throws {
        // Given
        let nonExistentFile = testDirectory.appendingPathComponent("missing.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        
        let operation = FileOperation.copy(source: nonExistentFile, destination: destinationFile)
        
        // When & Then
        do {
            try await fileSystemService.validateOperation(operation)
            XCTFail("Expected validation to fail")
        } catch FileOperationError.fileNotFound {
            // Expected
        }
    }
    
    func testValidateOperationWithInsufficientPermissions() async throws {
        // Given
        mockPermissionManager.hasFileSystemAccess = false
        let sourceFile = testDirectory.appendingPathComponent("source.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        
        let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
        
        // When & Then
        do {
            try await fileSystemService.validateOperation(operation)
            XCTFail("Expected validation to fail")
        } catch FileOperationError.insufficientPermissions {
            // Expected
        }
    }
    
    // MARK: - File Copy Tests
    
    func testCopyFile() async throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("source.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        let testContent = "Test file content"
        
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        XCTAssertEqual(result.processedFiles.count, 1)
        XCTAssertEqual(result.processedFiles.first, destinationFile)
        
        let copiedContent = try String(contentsOf: destinationFile, encoding: .utf8)
        XCTAssertEqual(copiedContent, testContent)
    }
    
    func testCopyFileWithOverwrite() async throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("source.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        
        try "Original content".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "Existing content".write(to: destinationFile, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        let finalContent = try String(contentsOf: destinationFile, encoding: .utf8)
        XCTAssertEqual(finalContent, "Original content")
    }
    
    // MARK: - File Move Tests
    
    func testMoveFile() async throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("move_source.txt")
        let destinationFile = testDirectory.appendingPathComponent("move_destination.txt")
        let testContent = "Content to move"
        
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.move(source: sourceFile, destination: destinationFile)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        
        let movedContent = try String(contentsOf: destinationFile, encoding: .utf8)
        XCTAssertEqual(movedContent, testContent)
    }
    
    // MARK: - File Delete Tests
    
    func testDeleteFile() async throws {
        // Given
        let fileToDelete = testDirectory.appendingPathComponent("delete_me.txt")
        try "Delete this content".write(to: fileToDelete, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.delete(files: [fileToDelete], moveToTrash: false)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileToDelete.path))
        XCTAssertEqual(result.processedFiles.count, 1)
    }
    
    func testDeleteMultipleFiles() async throws {
        // Given
        let filesToDelete = (1...3).map { testDirectory.appendingPathComponent("delete\($0).txt") }
        for file in filesToDelete {
            try "Content".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When
        let operation = FileOperation.delete(files: filesToDelete, moveToTrash: false)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processedFiles.count, 3)
        for file in filesToDelete {
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }
    
    // MARK: - File Rename Tests
    
    func testRenameFile() async throws {
        // Given
        let originalFile = testDirectory.appendingPathComponent("original.txt")
        let newName = "renamed.txt"
        try "Content to rename".write(to: originalFile, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.rename(file: originalFile, newName: newName)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalFile.path))
        
        let renamedFile = testDirectory.appendingPathComponent(newName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamedFile.path))
        XCTAssertEqual(result.processedFiles.first, renamedFile)
    }
    
    // MARK: - File Search Tests
    
    func testSearchByExtension() async throws {
        // Given
        let searchDir = testDirectory.appendingPathComponent("search")
        try FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
        
        let testFiles = ["doc1.pdf", "doc2.pdf", "image.jpg", "text.txt"]
        for filename in testFiles {
            let file = searchDir.appendingPathComponent(filename)
            try "Content".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When
        let criteria = SearchCriteria(directory: searchDir, fileExtension: "pdf", recursive: false)
        let operation = FileOperation.search(criteria: criteria)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processedFiles.count, 2)
        XCTAssertTrue(result.processedFiles.allSatisfy { $0.pathExtension == "pdf" })
    }
    
    func testSearchByName() async throws {
        // Given
        let searchDir = testDirectory.appendingPathComponent("search")
        try FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
        
        let testFiles = ["report_2023.pdf", "report_2024.pdf", "summary.txt"]
        for filename in testFiles {
            let file = searchDir.appendingPathComponent(filename)
            try "Content".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When
        let criteria = SearchCriteria(directory: searchDir, namePattern: "report", recursive: false)
        let operation = FileOperation.search(criteria: criteria)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processedFiles.count, 2)
        XCTAssertTrue(result.processedFiles.allSatisfy { $0.lastPathComponent.contains("report") })
    }
    
    // MARK: - File Organization Tests
    
    func testOrganizeByType() async throws {
        // Given
        let organizeDir = testDirectory.appendingPathComponent("organize")
        try FileManager.default.createDirectory(at: organizeDir, withIntermediateDirectories: true)
        
        let testFiles = ["doc.pdf", "image.jpg", "text.txt", "sheet.xlsx"]
        for filename in testFiles {
            let file = organizeDir.appendingPathComponent(filename)
            try "Content".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When
        let operation = FileOperation.organize(directory: organizeDir, strategy: .byType)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        
        let documentsDir = organizeDir.appendingPathComponent("Documents")
        let imagesDir = organizeDir.appendingPathComponent("Images")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentsDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagesDir.path))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentsDir.appendingPathComponent("doc.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagesDir.appendingPathComponent("image.jpg").path))
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressTracking() async throws {
        // Given
        let sourceFiles = (1...5).map { testDirectory.appendingPathComponent("source\($0).txt") }
        let destinationDir = testDirectory.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        for (index, sourceFile) in sourceFiles.enumerated() {
            try "Content \(index)".write(to: sourceFile, atomically: true, encoding: .utf8)
        }
        
        var progressUpdates: [Double] = []
        
        // When
        let operations = sourceFiles.map { sourceFile in
            FileOperation.copy(
                source: sourceFile,
                destination: destinationDir.appendingPathComponent(sourceFile.lastPathComponent)
            )
        }
        
        for operation in operations {
            let result = try await fileSystemService.executeOperation(operation) { progress in
                progressUpdates.append(progress)
            }
            XCTAssertTrue(result.success)
        }
        
        // Then
        XCTAssertFalse(progressUpdates.isEmpty)
        XCTAssertTrue(progressUpdates.contains(1.0)) // Should reach 100% for each operation
    }
    
    // MARK: - Undo Functionality Tests
    
    func testUndoFileMove() async throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("undo_source.txt")
        let destinationFile = testDirectory.appendingPathComponent("undo_destination.txt")
        let testContent = "Content for undo test"
        
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.move(source: sourceFile, destination: destinationFile)
        let result = try await fileSystemService.executeOperation(operation)
        
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.undoAction)
        
        // Execute undo
        result.undoAction?()
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationFile.path))
        
        let restoredContent = try String(contentsOf: sourceFile, encoding: .utf8)
        XCTAssertEqual(restoredContent, testContent)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleInsufficientDiskSpace() async throws {
        // This test would require mocking disk space checks
        // For now, we'll test the error handling structure
        
        // Given
        let sourceFile = testDirectory.appendingPathComponent("large_file.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        
        // Create a file
        try "Content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Mock insufficient disk space
        mockPermissionManager.simulateInsufficientDiskSpace = true
        
        // When
        let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
        let result = try await fileSystemService.executeOperation(operation)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errors.contains { error in
            if case .insufficientDiskSpace = error {
                return true
            }
            return false
        })
    }
    
    // MARK: - Performance Tests
    
    func testFileOperationPerformance() {
        measure {
            let sourceFile = testDirectory.appendingPathComponent("perf_source.txt")
            let destinationFile = testDirectory.appendingPathComponent("perf_destination.txt")
            
            try! "Performance test content".write(to: sourceFile, atomically: true, encoding: .utf8)
            
            let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
            _ = try! await fileSystemService.executeOperation(operation)
        }
    }
}

// MARK: - Mock Classes

class MockPermissionManager: PermissionManagerProtocol {
    var hasFileSystemAccess = true
    var simulateInsufficientDiskSpace = false
    
    func checkFileSystemAccess() -> Bool {
        return hasFileSystemAccess
    }
    
    func checkDiskSpace(for operation: FileOperation) throws {
        if simulateInsufficientDiskSpace {
            throw FileOperationError.insufficientDiskSpace(required: 1000, available: 500)
        }
    }
    
    func requestFileSystemAccess() async -> Bool {
        hasFileSystemAccess = true
        return true
    }
}