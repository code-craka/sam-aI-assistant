import XCTest
import Foundation
@testable import Sam

@MainActor
class MetadataExtractionServiceTests: XCTestCase {
    
    var metadataService: MetadataExtractionService!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        metadataService = MetadataExtractionService()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetadataExtractionTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }
    
    func testExtractBasicMetadata() async throws {
        // Create a test text file
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let testContent = "This is a test file for metadata extraction."
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Extract metadata
        let metadata = try await metadataService.extractMetadata(from: testFile)
        
        // Verify basic metadata
        XCTAssertNotNil(metadata.basicInfo)
        XCTAssertEqual(metadata.basicInfo.fileSize, Int64(testContent.utf8.count))
        XCTAssertTrue(metadata.basicInfo.permissions.isReadable)
        XCTAssertTrue(metadata.basicInfo.permissions.isWritable)
        
        // Text files should have document metadata
        XCTAssertNotNil(metadata.documentInfo)
        XCTAssertEqual(metadata.documentInfo?.wordCount, 9) // "This is a test file for metadata extraction."
        XCTAssertEqual(metadata.documentInfo?.characterCount, testContent.count)
    }
    
    func testExtractMetadataFromMultipleFiles() async throws {
        // Create multiple test files
        let files = [
            ("test1.txt", "First test file"),
            ("test2.txt", "Second test file with more content"),
            ("test3.txt", "Third file")
        ]
        
        var fileURLs: [URL] = []
        for (filename, content) in files {
            let fileURL = tempDirectory.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            fileURLs.append(fileURL)
        }
        
        // Extract metadata from all files
        let metadataMap = try await metadataService.extractMetadataFromFiles(fileURLs) { processed, total in
            // Progress callback - verify it's called
            XCTAssertLessThanOrEqual(processed, total)
        }
        
        // Verify all files were processed
        XCTAssertEqual(metadataMap.count, files.count)
        
        // Verify each file has metadata
        for fileURL in fileURLs {
            XCTAssertNotNil(metadataMap[fileURL])
            XCTAssertNotNil(metadataMap[fileURL]?.basicInfo)
            XCTAssertNotNil(metadataMap[fileURL]?.documentInfo)
        }
    }
    
    func testContentHashCalculation() async throws {
        // Create two identical files
        let content = "Identical content for hash testing"
        let file1 = tempDirectory.appendingPathComponent("identical1.txt")
        let file2 = tempDirectory.appendingPathComponent("identical2.txt")
        
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try content.write(to: file2, atomically: true, encoding: .utf8)
        
        // Extract metadata
        let metadata1 = try await metadataService.extractMetadata(from: file1)
        let metadata2 = try await metadataService.extractMetadata(from: file2)
        
        // Verify identical files have same hash
        XCTAssertNotNil(metadata1.contentHash)
        XCTAssertNotNil(metadata2.contentHash)
        XCTAssertEqual(metadata1.contentHash, metadata2.contentHash)
        
        // Create a different file
        let file3 = tempDirectory.appendingPathComponent("different.txt")
        try "Different content".write(to: file3, atomically: true, encoding: .utf8)
        
        let metadata3 = try await metadataService.extractMetadata(from: file3)
        
        // Verify different file has different hash
        XCTAssertNotEqual(metadata1.contentHash, metadata3.contentHash)
    }
    
    func testUnsupportedFileFormat() async throws {
        // Create a file with unsupported format for image metadata
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "Not an image".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Extract metadata - should not throw but image info should be nil
        let metadata = try await metadataService.extractMetadata(from: testFile)
        
        XCTAssertNotNil(metadata.basicInfo)
        XCTAssertNil(metadata.imageInfo)
        XCTAssertNil(metadata.videoInfo)
        XCTAssertNil(metadata.audioInfo)
        XCTAssertNotNil(metadata.documentInfo) // Text files should have document info
    }
    
    func testFileNotAccessible() async throws {
        // Try to extract metadata from non-existent file
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.txt")
        
        do {
            _ = try await metadataService.extractMetadata(from: nonExistentFile)
            XCTFail("Should have thrown an error for non-existent file")
        } catch {
            // Expected to throw an error
            XCTAssertTrue(error is CocoaError || error is MetadataExtractionError)
        }
    }
    
    func testDocumentMetadataExtraction() async throws {
        // Create a text file with specific content
        let testFile = tempDirectory.appendingPathComponent("document.txt")
        let content = """
        This is a test document.
        It has multiple lines and words.
        We can count words and characters.
        """
        try content.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Extract metadata
        let metadata = try await metadataService.extractMetadata(from: testFile)
        
        // Verify document metadata
        XCTAssertNotNil(metadata.documentInfo)
        XCTAssertEqual(metadata.documentInfo?.title, "document") // Filename without extension
        XCTAssertNotNil(metadata.documentInfo?.wordCount)
        XCTAssertNotNil(metadata.documentInfo?.characterCount)
        XCTAssertEqual(metadata.documentInfo?.characterCount, content.count)
        
        // Word count should be reasonable (around 15 words)
        let wordCount = metadata.documentInfo?.wordCount ?? 0
        XCTAssertGreaterThan(wordCount, 10)
        XCTAssertLessThan(wordCount, 20)
    }
}