import XCTest
import Foundation
@testable import Sam

final class FileSystemIntegrationTests: XCTestCase {
    var fileSystemService: FileSystemService!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        fileSystemService = FileSystemService()
        
        // Create temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SamFileSystemTests_\(UUID().uuidString)")
        
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
        // Clean up test directory
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        fileSystemService = nil
        super.tearDown()
    }
    
    // MARK: - File Copy Operations
    
    func testFileCopyOperation() async throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("source.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        let testContent = "Test file content for copy operation"
        
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
        let result = try await fileSystemService.executeFileOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        
        let copiedContent = try String(contentsOf: destinationFile, encoding: .utf8)
        XCTAssertEqual(copiedContent, testContent)
        XCTAssertEqual(result.processedFiles.count, 1)
        XCTAssertEqual(result.processedFiles.first, destinationFile)
    }
    
    func testBatchFileCopy() async throws {
        // Given
        let sourceFiles = (1...5).map { testDirectory.appendingPathComponent("source\($0).txt") }
        let destinationDir = testDirectory.appendingPathComponent("destination")
        
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        for (index, sourceFile) in sourceFiles.enumerated() {
            try "Content \(index + 1)".write(to: sourceFile, atomically: true, encoding: .utf8)
        }
        
        // When
        let operations = sourceFiles.map { sourceFile in
            FileOperation.copy(
                source: sourceFile,
                destination: destinationDir.appendingPathComponent(sourceFile.lastPathComponent)
            )
        }
        
        let results = try await withThrowingTaskGroup(of: TaskResult.self) { group in
            for operation in operations {
                group.addTask {
                    try await self.fileSystemService.executeFileOperation(operation)
                }
            }
            
            var results: [TaskResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        // Then
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0.success })
        
        for sourceFile in sourceFiles {
            let destinationFile = destinationDir.appendingPathComponent(sourceFile.lastPathComponent)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        }
    }
    
    // MARK: - File Move Operations
    
    func testFileMoveOperation() async throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("move_source.txt")
        let destinationFile = testDirectory.appendingPathComponent("move_destination.txt")
        let testContent = "Content to be moved"
        
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When
        let operation = FileOperation.move(source: sourceFile, destination: destinationFile)
        let result = try await fileSystemService.executeFileOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        
        let movedContent = try String(contentsOf: destinationFile, encoding: .utf8)
        XCTAssertEqual(movedContent, testContent)
    }
    
    // MARK: - File Search Operations
    
    func testFileSearch() async throws {
        // Given
        let searchDir = testDirectory.appendingPathComponent("search_test")
        try FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
        
        let testFiles = [
            ("document.pdf", "PDF content"),
            ("image.jpg", "JPEG data"),
            ("text.txt", "Plain text content"),
            ("report.pdf", "Another PDF document")
        ]
        
        for (filename, content) in testFiles {
            let file = searchDir.appendingPathComponent(filename)
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When
        let searchCriteria = SearchCriteria(
            directory: searchDir,
            fileExtension: "pdf",
            recursive: true
        )
        let operation = FileOperation.search(criteria: searchCriteria)
        let result = try await fileSystemService.executeFileOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.processedFiles.count, 2) // Two PDF files
        XCTAssertTrue(result.processedFiles.contains { $0.lastPathComponent == "document.pdf" })
        XCTAssertTrue(result.processedFiles.contains { $0.lastPathComponent == "report.pdf" })
    }
    
    // MARK: - File Organization Operations
    
    func testFileOrganization() async throws {
        // Given
        let organizeDir = testDirectory.appendingPathComponent("organize_test")
        try FileManager.default.createDirectory(at: organizeDir, withIntermediateDirectories: true)
        
        let testFiles = [
            "document.pdf",
            "image.jpg",
            "photo.png",
            "text.txt",
            "spreadsheet.xlsx"
        ]
        
        for filename in testFiles {
            let file = organizeDir.appendingPathComponent(filename)
            try "Content".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When
        let operation = FileOperation.organize(
            directory: organizeDir,
            strategy: .byType
        )
        let result = try await fileSystemService.executeFileOperation(operation)
        
        // Then
        XCTAssertTrue(result.success)
        
        // Check that type-based folders were created
        let documentsDir = organizeDir.appendingPathComponent("Documents")
        let imagesDir = organizeDir.appendingPathComponent("Images")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentsDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagesDir.path))
        
        // Check that files were moved to appropriate folders
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentsDir.appendingPathComponent("document.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagesDir.appendingPathComponent("image.jpg").path))
    }
    
    // MARK: - Error Handling Tests
    
    func testFileOperationWithInsufficientPermissions() async throws {
        // Given
        let restrictedFile = URL(fileURLWithPath: "/System/Library/Kernels/kernel")
        let destinationFile = testDirectory.appendingPathComponent("kernel_copy")
        
        // When
        let operation = FileOperation.copy(source: restrictedFile, destination: destinationFile)
        let result = try await fileSystemService.executeFileOperation(operation)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errors.contains { error in
            if case .insufficientPermissions = error {
                return true
            }
            return false
        })
    }
    
    func testFileOperationWithNonExistentSource() async throws {
        // Given
        let nonExistentFile = testDirectory.appendingPathComponent("does_not_exist.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        
        // When
        let operation = FileOperation.copy(source: nonExistentFile, destination: destinationFile)
        let result = try await fileSystemService.executeFileOperation(operation)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errors.contains { error in
            if case .fileNotFound = error {
                return true
            }
            return false
        })
    }
    
    // MARK: - Performance Tests
    
    func testLargeFileOperation() async throws {
        // Given
        let largeFile = testDirectory.appendingPathComponent("large_file.txt")
        let destinationFile = testDirectory.appendingPathComponent("large_file_copy.txt")
        
        // Create a 10MB file
        let largeContent = String(repeating: "A", count: 10 * 1024 * 1024)
        try largeContent.write(to: largeFile, atomically: true, encoding: .utf8)
        
        // When
        let startTime = Date()
        let operation = FileOperation.copy(source: largeFile, destination: destinationFile)
        let result = try await fileSystemService.executeFileOperation(operation)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertLessThan(executionTime, 10.0, "Large file copy took too long")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        
        // Verify file size
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationFile.path)
        let fileSize = attributes[.size] as? Int64
        XCTAssertEqual(fileSize, Int64(largeContent.count))
    }
    
    func testConcurrentFileOperations() async throws {
        // Given
        let sourceFiles = (1...10).map { testDirectory.appendingPathComponent("concurrent_source\($0).txt") }
        let destinationFiles = (1...10).map { testDirectory.appendingPathComponent("concurrent_dest\($0).txt") }
        
        for (index, sourceFile) in sourceFiles.enumerated() {
            try "Content \(index + 1)".write(to: sourceFile, atomically: true, encoding: .utf8)
        }
        
        // When
        let startTime = Date()
        let operations = zip(sourceFiles, destinationFiles).map { source, destination in
            FileOperation.copy(source: source, destination: destination)
        }
        
        let results = try await withThrowingTaskGroup(of: TaskResult.self) { group in
            for operation in operations {
                group.addTask {
                    try await self.fileSystemService.executeFileOperation(operation)
                }
            }
            
            var results: [TaskResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, 10)
        XCTAssertTrue(results.allSatisfy { $0.success })
        XCTAssertLessThan(executionTime, 5.0, "Concurrent operations took too long")
        
        for destinationFile in destinationFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
        }
    }
}