import XCTest
import Foundation
@testable import Sam

@MainActor
class DuplicateDetectionServiceTests: XCTestCase {
    
    var duplicateService: DuplicateDetectionService!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        duplicateService = DuplicateDetectionService()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DuplicateDetectionTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }
    
    func testDetectExactDuplicates() async throws {
        // Create identical files
        let content = "This is identical content for duplicate testing"
        let file1 = tempDirectory.appendingPathComponent("original.txt")
        let file2 = tempDirectory.appendingPathComponent("duplicate1.txt")
        let file3 = tempDirectory.appendingPathComponent("duplicate2.txt")
        
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try content.write(to: file2, atomically: true, encoding: .utf8)
        try content.write(to: file3, atomically: true, encoding: .utf8)
        
        // Create a different file
        let file4 = tempDirectory.appendingPathComponent("different.txt")
        try "Different content".write(to: file4, atomically: true, encoding: .utf8)
        
        // Detect duplicates using content hash
        let result = try await duplicateService.detectDuplicates(
            in: [tempDirectory],
            methods: [.contentHash]
        ) { progress, operation in
            XCTAssertGreaterThanOrEqual(progress, 0.0)
            XCTAssertLessThanOrEqual(progress, 1.0)
        }
        
        // Verify results
        XCTAssertEqual(result.duplicateGroups.count, 1)
        XCTAssertEqual(result.totalDuplicates, 2) // 3 identical files = 2 duplicates
        XCTAssertEqual(result.scannedFiles, 4)
        
        let duplicateGroup = result.duplicateGroups.first!
        XCTAssertEqual(duplicateGroup.files.count, 3)
        XCTAssertEqual(duplicateGroup.duplicateType, .exactMatch)
        XCTAssertNotNil(duplicateGroup.originalFile)
        XCTAssertEqual(duplicateGroup.duplicateFiles.count, 2)
    }
    
    func testDetectNameAndSizeDuplicates() async throws {
        // Create files with same name and size but different content
        let content1 = "Content with exactly 50 characters for testing!!"
        let content2 = "Different content but same length for testing!!"
        
        XCTAssertEqual(content1.count, content2.count) // Ensure same size
        
        let file1 = tempDirectory.appendingPathComponent("samename.txt")
        let file2 = tempDirectory.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: file2, withIntermediateDirectories: true)
        let file2Path = file2.appendingPathComponent("samename.txt")
        
        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2Path, atomically: true, encoding: .utf8)
        
        // Detect duplicates using name and size
        let result = try await duplicateService.detectDuplicates(
            in: [tempDirectory],
            methods: [.nameAndSize]
        ) { _, _ in }
        
        // Should find name/size duplicates
        XCTAssertEqual(result.duplicateGroups.count, 1)
        XCTAssertEqual(result.totalDuplicates, 1)
        
        let duplicateGroup = result.duplicateGroups.first!
        XCTAssertEqual(duplicateGroup.files.count, 2)
        XCTAssertEqual(duplicateGroup.duplicateType, .nameMatch)
    }
    
    func testDetectSizeOnlyDuplicates() async throws {
        // Create files with same size but different names and content
        let size = 25
        let content1 = String(repeating: "a", count: size)
        let content2 = String(repeating: "b", count: size)
        
        let file1 = tempDirectory.appendingPathComponent("file1.txt")
        let file2 = tempDirectory.appendingPathComponent("file2.txt")
        
        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2, atomically: true, encoding: .utf8)
        
        // Detect duplicates using size only
        let result = try await duplicateService.detectDuplicates(
            in: [tempDirectory],
            methods: [.sizeOnly]
        ) { _, _ in }
        
        // Should find size duplicates
        XCTAssertEqual(result.duplicateGroups.count, 1)
        XCTAssertEqual(result.totalDuplicates, 1)
        
        let duplicateGroup = result.duplicateGroups.first!
        XCTAssertEqual(duplicateGroup.files.count, 2)
        XCTAssertEqual(duplicateGroup.duplicateType, .sizeMatch)
    }
    
    func testRemoveDuplicatesKeepOldest() async throws {
        // Create files with different modification dates
        let content = "Duplicate content"
        let file1 = tempDirectory.appendingPathComponent("oldest.txt")
        let file2 = tempDirectory.appendingPathComponent("newer.txt")
        let file3 = tempDirectory.appendingPathComponent("newest.txt")
        
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try content.write(to: file2, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 100_000_000)
        try content.write(to: file3, atomically: true, encoding: .utf8)
        
        // First detect duplicates
        let detectResult = try await duplicateService.detectDuplicates(
            in: [tempDirectory],
            methods: [.contentHash]
        ) { _, _ in }
        
        XCTAssertEqual(detectResult.duplicateGroups.count, 1)
        
        // Remove duplicates keeping oldest
        let removeResult = try await duplicateService.removeDuplicates(
            from: detectResult.duplicateGroups,
            keepStrategy: .oldest
        )
        
        // Verify removal results
        XCTAssertEqual(removeResult.removedFiles.count, 2) // Should remove 2 newer files
        XCTAssertTrue(removeResult.errors.isEmpty)
        XCTAssertGreaterThan(removeResult.spaceSaved, 0)
        
        // Verify oldest file still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1.path))
        
        // Note: Files are moved to trash, so they might still exist in trash
        // We can't easily test if they're actually in trash without system APIs
    }
    
    func testRemoveDuplicatesKeepNewest() async throws {
        // Create files with different modification dates
        let content = "Duplicate content for newest test"
        let file1 = tempDirectory.appendingPathComponent("old.txt")
        let file2 = tempDirectory.appendingPathComponent("new.txt")
        
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try content.write(to: file2, atomically: true, encoding: .utf8)
        
        // Detect and remove duplicates
        let detectResult = try await duplicateService.detectDuplicates(
            in: [tempDirectory],
            methods: [.contentHash]
        ) { _, _ in }
        
        let removeResult = try await duplicateService.removeDuplicates(
            from: detectResult.duplicateGroups,
            keepStrategy: .newest
        )
        
        // Should remove 1 file (the older one)
        XCTAssertEqual(removeResult.removedFiles.count, 1)
        XCTAssertTrue(removeResult.errors.isEmpty)
        
        // Verify newer file still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path))
    }
    
    func testNoDuplicatesFound() async throws {
        // Create unique files
        let files = [
            ("unique1.txt", "First unique content"),
            ("unique2.txt", "Second unique content"),
            ("unique3.txt", "Third unique content")
        ]
        
        for (filename, content) in files {
            let fileURL = tempDirectory.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        // Detect duplicates
        let result = try await duplicateService.detectDuplicates(
            in: [tempDirectory],
            methods: [.contentHash, .nameAndSize]
        ) { _, _ in }
        
        // Should find no duplicates
        XCTAssertEqual(result.duplicateGroups.count, 0)
        XCTAssertEqual(result.totalDuplicates, 0)
        XCTAssertEqual(result.potentialSpaceSavings, 0)
        XCTAssertEqual(result.scannedFiles, 3)
    }
    
    func testEmptyDirectory() async throws {
        // Create empty subdirectory
        let emptyDir = tempDirectory.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        
        // Detect duplicates in empty directory
        let result = try await duplicateService.detectDuplicates(
            in: [emptyDir],
            methods: [.contentHash]
        ) { _, _ in }
        
        // Should handle empty directory gracefully
        XCTAssertEqual(result.duplicateGroups.count, 0)
        XCTAssertEqual(result.totalDuplicates, 0)
        XCTAssertEqual(result.scannedFiles, 0)
    }
    
    func testMultipleDirectories() async throws {
        // Create files in multiple directories
        let dir1 = tempDirectory.appendingPathComponent("dir1")
        let dir2 = tempDirectory.appendingPathComponent("dir2")
        
        try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)
        
        let content = "Shared content across directories"
        try content.write(to: dir1.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try content.write(to: dir2.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        
        // Detect duplicates across multiple directories
        let result = try await duplicateService.detectDuplicates(
            in: [dir1, dir2],
            methods: [.contentHash]
        ) { _, _ in }
        
        // Should find duplicates across directories
        XCTAssertEqual(result.duplicateGroups.count, 1)
        XCTAssertEqual(result.totalDuplicates, 1)
        XCTAssertEqual(result.scannedFiles, 2)
    }
}