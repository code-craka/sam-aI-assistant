import Foundation

// MARK: - Simple FileSystem Service Test
/// A simple test to verify FileSystemService functionality
@MainActor
class FileSystemServiceSimpleTest {
    
    private let fileSystemService = FileSystemService()
    private let tempDirectory: URL
    
    init() {
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceTest")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        print("📁 Test directory: \(tempDirectory.path)")
    }
    
    deinit {
        // Clean up
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    /// Run basic tests
    func runTests() async {
        print("🧪 Starting FileSystemService Tests")
        
        var passedTests = 0
        var totalTests = 0
        
        // Test 1: File Creation and Copy
        totalTests += 1
        if await testFileCopy() {
            passedTests += 1
            print("✅ Test 1 PASSED: File Copy")
        } else {
            print("❌ Test 1 FAILED: File Copy")
        }
        
        // Test 2: File Search
        totalTests += 1
        if await testFileSearch() {
            passedTests += 1
            print("✅ Test 2 PASSED: File Search")
        } else {
            print("❌ Test 2 FAILED: File Search")
        }
        
        // Test 3: File Organization
        totalTests += 1
        if await testFileOrganization() {
            passedTests += 1
            print("✅ Test 3 PASSED: File Organization")
        } else {
            print("❌ Test 3 FAILED: File Organization")
        }
        
        // Test 4: Batch Operations
        totalTests += 1
        if await testBatchOperations() {
            passedTests += 1
            print("✅ Test 4 PASSED: Batch Operations")
        } else {
            print("❌ Test 4 FAILED: Batch Operations")
        }
        
        print("\n📊 Test Results: \(passedTests)/\(totalTests) tests passed")
        
        if passedTests == totalTests {
            print("🎉 All tests passed!")
        } else {
            print("⚠️  Some tests failed")
        }
    }
    
    // MARK: - Individual Tests
    
    private func testFileCopy() async -> Bool {
        do {
            // Create a test file
            let sourceFile = tempDirectory.appendingPathComponent("test.txt")
            let testContent = "This is a test file for copying"
            try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
            
            // Copy the file
            let destinationFile = tempDirectory.appendingPathComponent("test_copy.txt")
            let result = try await fileSystemService.executeOperation(
                .copy(source: sourceFile, destination: destinationFile)
            )
            
            // Verify the copy was successful
            guard result.success else { return false }
            guard FileManager.default.fileExists(atPath: destinationFile.path) else { return false }
            
            // Verify content is identical
            let copiedContent = try String(contentsOf: destinationFile)
            return copiedContent == testContent
            
        } catch {
            print("  Error in testFileCopy: \(error)")
            return false
        }
    }
    
    private func testFileSearch() async -> Bool {
        do {
            // Create test files with different extensions
            let testFiles = [
                ("document.txt", "Text document"),
                ("image.jpg", "JPEG image"),
                ("video.mp4", "MP4 video")
            ]
            
            for (fileName, content) in testFiles {
                let fileURL = tempDirectory.appendingPathComponent(fileName)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            // Search for .txt files
            let criteria = SearchCriteria(
                query: "",
                searchPaths: [tempDirectory],
                fileTypes: ["txt"],
                includeSubdirectories: false
            )
            
            let result = try await fileSystemService.executeOperation(.search(criteria: criteria))
            
            // Should find at least 2 .txt files (test.txt and document.txt)
            let txtFiles = result.processedFiles.filter { $0.pathExtension == "txt" }
            return result.success && txtFiles.count >= 2
            
        } catch {
            print("  Error in testFileSearch: \(error)")
            return false
        }
    }
    
    private func testFileOrganization() async -> Bool {
        do {
            // Create files of different types
            let testFiles = [
                ("photo.jpg", "JPEG photo"),
                ("song.mp3", "MP3 audio"),
                ("report.pdf", "PDF report")
            ]
            
            for (fileName, content) in testFiles {
                let fileURL = tempDirectory.appendingPathComponent(fileName)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            // Organize by type
            let result = try await fileSystemService.executeOperation(
                .organize(directory: tempDirectory, strategy: .byType)
            )
            
            // Check if organization was successful
            guard result.success else { return false }
            
            // Verify folders were created
            let expectedFolders = ["Images", "Audio", "Documents"]
            for folderName in expectedFolders {
                let folderURL = tempDirectory.appendingPathComponent(folderName)
                if FileManager.default.fileExists(atPath: folderURL.path) {
                    return true // At least one folder was created
                }
            }
            
            return false
            
        } catch {
            print("  Error in testFileOrganization: \(error)")
            return false
        }
    }
    
    private func testBatchOperations() async -> Bool {
        do {
            // Create files for batch operations
            let batchFiles = [
                ("batch1.txt", "Batch file 1"),
                ("batch2.txt", "Batch file 2")
            ]
            
            for (fileName, content) in batchFiles {
                let fileURL = tempDirectory.appendingPathComponent(fileName)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            // Create batch operations
            let operations: [FileOperation] = [
                .copy(
                    source: tempDirectory.appendingPathComponent("batch1.txt"),
                    destination: tempDirectory.appendingPathComponent("batch1_copy.txt")
                ),
                .rename(
                    file: tempDirectory.appendingPathComponent("batch2.txt"),
                    newName: "batch2_renamed.txt"
                )
            ]
            
            let result = try await fileSystemService.executeBatchOperations(operations)
            
            // Check if batch operations were successful
            return result.successfulOperations == 2 && result.failedOperations == 0
            
        } catch {
            print("  Error in testBatchOperations: \(error)")
            return false
        }
    }
}

// MARK: - Test Runner Function
func runFileSystemServiceTests() async {
    let test = await FileSystemServiceSimpleTest()
    await test.runTests()
}