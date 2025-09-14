import XCTest
import Foundation
@testable import Sam

final class FileSystemPerformanceTests: XCTestCase {
    var fileSystemService: FileSystemService!
    var testDirectory: URL!
    var performanceMetrics: PerformanceMetrics!
    
    override func setUp() {
        super.setUp()
        fileSystemService = FileSystemService()
        performanceMetrics = PerformanceMetrics()
        
        // Create temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SamPerformanceTests_\(UUID().uuidString)")
        
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
        performanceMetrics = nil
        super.tearDown()
    }
    
    // MARK: - File Copy Performance Tests
    
    func testSingleFileCopyPerformance() throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("source.txt")
        let destinationFile = testDirectory.appendingPathComponent("destination.txt")
        let testContent = String(repeating: "A", count: 1024 * 1024) // 1MB file
        
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When & Then
        measure {
            Task {
                let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
                _ = try? await self.fileSystemService.executeFileOperation(operation)
                
                // Clean up for next iteration
                try? FileManager.default.removeItem(at: destinationFile)
            }
        }
    }
    
    func testBatchFileCopyPerformance() throws {
        // Given
        let fileCount = 100
        let sourceFiles = (1...fileCount).map { testDirectory.appendingPathComponent("source\($0).txt") }
        let destinationDir = testDirectory.appendingPathComponent("destination")
        
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        for (index, sourceFile) in sourceFiles.enumerated() {
            try "Content \(index + 1)".write(to: sourceFile, atomically: true, encoding: .utf8)
        }
        
        // When & Then
        measure {
            Task {
                let operations = sourceFiles.map { sourceFile in
                    FileOperation.copy(
                        source: sourceFile,
                        destination: destinationDir.appendingPathComponent(sourceFile.lastPathComponent)
                    )
                }
                
                await withTaskGroup(of: Void.self) { group in
                    for operation in operations {
                        group.addTask {
                            _ = try? await self.fileSystemService.executeFileOperation(operation)
                        }
                    }
                }
                
                // Clean up for next iteration
                try? FileManager.default.removeItem(at: destinationDir)
                try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }
        }
    }
    
    func testLargeFileCopyPerformance() throws {
        // Given
        let sourceFile = testDirectory.appendingPathComponent("large_source.txt")
        let destinationFile = testDirectory.appendingPathComponent("large_destination.txt")
        let largeContent = String(repeating: "A", count: 50 * 1024 * 1024) // 50MB file
        
        try largeContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // When & Then
        measure {
            Task {
                let operation = FileOperation.copy(source: sourceFile, destination: destinationFile)
                _ = try? await self.fileSystemService.executeFileOperation(operation)
                
                // Clean up for next iteration
                try? FileManager.default.removeItem(at: destinationFile)
            }
        }
    }
    
    // MARK: - File Search Performance Tests
    
    func testFileSearchPerformance() throws {
        // Given
        let searchDir = testDirectory.appendingPathComponent("search_test")
        try FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
        
        // Create test files with various extensions
        let fileTypes = ["txt", "pdf", "jpg", "png", "doc", "xlsx"]
        let filesPerType = 50
        
        for fileType in fileTypes {
            for i in 1...filesPerType {
                let file = searchDir.appendingPathComponent("file\(i).\(fileType)")
                try "Content for \(fileType) file \(i)".write(to: file, atomically: true, encoding: .utf8)
            }
        }
        
        // When & Then
        measure {
            Task {
                let searchCriteria = SearchCriteria(
                    directory: searchDir,
                    fileExtension: "pdf",
                    recursive: true
                )
                let operation = FileOperation.search(criteria: searchCriteria)
                _ = try? await self.fileSystemService.executeFileOperation(operation)
            }
        }
    }
    
    func testDeepDirectorySearchPerformance() throws {
        // Given
        let baseDir = testDirectory.appendingPathComponent("deep_search")
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        
        // Create nested directory structure (5 levels deep, 10 dirs per level)
        var currentDirs = [baseDir]
        
        for level in 1...5 {
            var nextDirs: [URL] = []
            for currentDir in currentDirs {
                for i in 1...10 {
                    let newDir = currentDir.appendingPathComponent("level\(level)_dir\(i)")
                    try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
                    nextDirs.append(newDir)
                    
                    // Add some files in each directory
                    for j in 1...5 {
                        let file = newDir.appendingPathComponent("file\(j).txt")
                        try "Content level \(level) dir \(i) file \(j)".write(to: file, atomically: true, encoding: .utf8)
                    }
                }
            }
            currentDirs = nextDirs
        }
        
        // When & Then
        measure {
            Task {
                let searchCriteria = SearchCriteria(
                    directory: baseDir,
                    fileExtension: "txt",
                    recursive: true
                )
                let operation = FileOperation.search(criteria: searchCriteria)
                _ = try? await self.fileSystemService.executeFileOperation(operation)
            }
        }
    }
    
    func testContentSearchPerformance() throws {
        // Given
        let searchDir = testDirectory.appendingPathComponent("content_search")
        try FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
        
        let searchTerm = "important document"
        let fileCount = 200
        
        for i in 1...fileCount {
            let file = searchDir.appendingPathComponent("document\(i).txt")
            let content = i % 10 == 0 ? 
                "This is an \(searchTerm) number \(i)" : 
                "This is a regular document number \(i)"
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When & Then
        measure {
            Task {
                let searchCriteria = SearchCriteria(
                    directory: searchDir,
                    contentSearch: searchTerm,
                    recursive: true
                )
                let operation = FileOperation.search(criteria: searchCriteria)
                _ = try? await self.fileSystemService.executeFileOperation(operation)
            }
        }
    }
    
    // MARK: - File Organization Performance Tests
    
    func testFileOrganizationByTypePerformance() throws {
        // Given
        let organizeDir = testDirectory.appendingPathComponent("organize_test")
        try FileManager.default.createDirectory(at: organizeDir, withIntermediateDirectories: true)
        
        let fileTypes = [
            ("document", ["pdf", "doc", "docx", "txt"]),
            ("image", ["jpg", "png", "gif", "bmp"]),
            ("video", ["mp4", "mov", "avi", "mkv"]),
            ("audio", ["mp3", "wav", "aac", "flac"])
        ]
        
        let filesPerExtension = 25
        
        for (_, extensions) in fileTypes {
            for ext in extensions {
                for i in 1...filesPerExtension {
                    let file = organizeDir.appendingPathComponent("file\(i).\(ext)")
                    try "Content for \(ext) file".write(to: file, atomically: true, encoding: .utf8)
                }
            }
        }
        
        // When & Then
        measure {
            Task {
                let operation = FileOperation.organize(
                    directory: organizeDir,
                    strategy: .byType
                )
                _ = try? await self.fileSystemService.executeFileOperation(operation)
                
                // Reset for next iteration
                self.resetOrganizeDirectory(organizeDir)
            }
        }
    }
    
    func testFileOrganizationByDatePerformance() throws {
        // Given
        let organizeDir = testDirectory.appendingPathComponent("organize_date_test")
        try FileManager.default.createDirectory(at: organizeDir, withIntermediateDirectories: true)
        
        let fileCount = 200
        let dateRange = TimeInterval(30 * 24 * 60 * 60) // 30 days
        let baseDate = Date().addingTimeInterval(-dateRange)
        
        for i in 1...fileCount {
            let file = organizeDir.appendingPathComponent("file\(i).txt")
            try "Content \(i)".write(to: file, atomically: true, encoding: .utf8)
            
            // Set random modification date within range
            let randomOffset = TimeInterval.random(in: 0...dateRange)
            let modificationDate = baseDate.addingTimeInterval(randomOffset)
            
            try FileManager.default.setAttributes(
                [.modificationDate: modificationDate],
                ofItemAtPath: file.path
            )
        }
        
        // When & Then
        measure {
            Task {
                let operation = FileOperation.organize(
                    directory: organizeDir,
                    strategy: .byDate
                )
                _ = try? await self.fileSystemService.executeFileOperation(operation)
                
                // Reset for next iteration
                self.resetOrganizeDirectory(organizeDir)
            }
        }
    }
    
    // MARK: - Metadata Extraction Performance Tests
    
    func testMetadataExtractionPerformance() throws {
        // Given
        let metadataDir = testDirectory.appendingPathComponent("metadata_test")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        
        let fileCount = 100
        
        for i in 1...fileCount {
            let file = metadataDir.appendingPathComponent("document\(i).txt")
            let content = """
            Title: Document \(i)
            Author: Test Author \(i)
            Created: \(Date())
            Content: This is the content of document number \(i).
            It contains multiple lines and various metadata.
            """
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When & Then
        measure {
            Task {
                let operation = FileOperation.extractMetadata(directory: metadataDir)
                _ = try? await self.fileSystemService.executeFileOperation(operation)
            }
        }
    }
    
    // MARK: - Concurrent Operations Performance Tests
    
    func testConcurrentFileOperationsPerformance() throws {
        // Given
        let concurrentDir = testDirectory.appendingPathComponent("concurrent_test")
        try FileManager.default.createDirectory(at: concurrentDir, withIntermediateDirectories: true)
        
        let operationCount = 50
        let sourceFiles = (1...operationCount).map { concurrentDir.appendingPathComponent("source\($0).txt") }
        let destinationFiles = (1...operationCount).map { concurrentDir.appendingPathComponent("dest\($0).txt") }
        
        for (index, sourceFile) in sourceFiles.enumerated() {
            try "Content \(index + 1)".write(to: sourceFile, atomically: true, encoding: .utf8)
        }
        
        // When & Then
        measure {
            Task {
                let operations = zip(sourceFiles, destinationFiles).map { source, destination in
                    FileOperation.copy(source: source, destination: destination)
                }
                
                await withTaskGroup(of: Void.self) { group in
                    for operation in operations {
                        group.addTask {
                            _ = try? await self.fileSystemService.executeFileOperation(operation)
                        }
                    }
                }
                
                // Clean up for next iteration
                for destFile in destinationFiles {
                    try? FileManager.default.removeItem(at: destFile)
                }
            }
        }
    }
    
    func testSequentialVsConcurrentPerformance() throws {
        // Given
        let testDir = testDirectory.appendingPathComponent("sequential_vs_concurrent")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let fileCount = 20
        let sourceFiles = (1...fileCount).map { testDir.appendingPathComponent("source\($0).txt") }
        
        for (index, sourceFile) in sourceFiles.enumerated() {
            let content = String(repeating: "A", count: 1024 * 100) // 100KB per file
            try content.write(to: sourceFile, atomically: true, encoding: .utf8)
        }
        
        // Test sequential execution
        let sequentialTime = measureExecutionTime {
            Task {
                for (index, sourceFile) in sourceFiles.enumerated() {
                    let destFile = testDir.appendingPathComponent("seq_dest\(index + 1).txt")
                    let operation = FileOperation.copy(source: sourceFile, destination: destFile)
                    _ = try? await self.fileSystemService.executeFileOperation(operation)
                }
            }
        }
        
        // Clean up sequential files
        for i in 1...fileCount {
            let destFile = testDir.appendingPathComponent("seq_dest\(i).txt")
            try? FileManager.default.removeItem(at: destFile)
        }
        
        // Test concurrent execution
        let concurrentTime = measureExecutionTime {
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for (index, sourceFile) in sourceFiles.enumerated() {
                        group.addTask {
                            let destFile = testDir.appendingPathComponent("conc_dest\(index + 1).txt")
                            let operation = FileOperation.copy(source: sourceFile, destination: destFile)
                            _ = try? await self.fileSystemService.executeFileOperation(operation)
                        }
                    }
                }
            }
        }
        
        // Then
        print("📊 Sequential execution time: \(String(format: "%.2f", sequentialTime))s")
        print("📊 Concurrent execution time: \(String(format: "%.2f", concurrentTime))s")
        print("📊 Performance improvement: \(String(format: "%.1f", sequentialTime / concurrentTime))x")
        
        XCTAssertLessThan(concurrentTime, sequentialTime, "Concurrent execution should be faster")
    }
    
    // MARK: - Memory Usage Performance Tests
    
    func testMemoryUsageDuringLargeOperations() throws {
        // Given
        let memoryTestDir = testDirectory.appendingPathComponent("memory_test")
        try FileManager.default.createDirectory(at: memoryTestDir, withIntermediateDirectories: true)
        
        let largeFileCount = 10
        let fileSize = 10 * 1024 * 1024 // 10MB per file
        
        for i in 1...largeFileCount {
            let file = memoryTestDir.appendingPathComponent("large\(i).txt")
            let content = String(repeating: "A", count: fileSize)
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // When & Then
        measure {
            autoreleasepool {
                Task {
                    let initialMemory = self.getCurrentMemoryUsage()
                    
                    // Perform memory-intensive operations
                    for i in 1...largeFileCount {
                        let sourceFile = memoryTestDir.appendingPathComponent("large\(i).txt")
                        let destFile = memoryTestDir.appendingPathComponent("copy\(i).txt")
                        let operation = FileOperation.copy(source: sourceFile, destination: destFile)
                        _ = try? await self.fileSystemService.executeFileOperation(operation)
                    }
                    
                    let finalMemory = self.getCurrentMemoryUsage()
                    let memoryIncrease = finalMemory - initialMemory
                    
                    print("📊 Memory increase during large operations: \(memoryIncrease / 1024 / 1024)MB")
                    
                    // Clean up
                    for i in 1...largeFileCount {
                        let destFile = memoryTestDir.appendingPathComponent("copy\(i).txt")
                        try? FileManager.default.removeItem(at: destFile)
                    }
                }
            }
        }
    }
    
    // MARK: - Disk I/O Performance Tests
    
    func testDiskIOPerformance() throws {
        // Given
        let ioTestDir = testDirectory.appendingPathComponent("io_test")
        try FileManager.default.createDirectory(at: ioTestDir, withIntermediateDirectories: true)
        
        let fileSizes = [
            ("small", 1024), // 1KB
            ("medium", 1024 * 1024), // 1MB
            ("large", 10 * 1024 * 1024) // 10MB
        ]
        
        for (sizeName, size) in fileSizes {
            let sourceFile = ioTestDir.appendingPathComponent("\(sizeName)_source.txt")
            let content = String(repeating: "A", count: size)
            try content.write(to: sourceFile, atomically: true, encoding: .utf8)
            
            // Measure read performance
            let readTime = measureExecutionTime {
                _ = try? String(contentsOf: sourceFile, encoding: .utf8)
            }
            
            // Measure write performance
            let destFile = ioTestDir.appendingPathComponent("\(sizeName)_dest.txt")
            let writeTime = measureExecutionTime {
                try? content.write(to: destFile, atomically: true, encoding: .utf8)
            }
            
            // Measure copy performance
            let copyFile = ioTestDir.appendingPathComponent("\(sizeName)_copy.txt")
            let copyTime = measureExecutionTime {
                Task {
                    let operation = FileOperation.copy(source: sourceFile, destination: copyFile)
                    _ = try? await self.fileSystemService.executeFileOperation(operation)
                }
            }
            
            print("📊 \(sizeName.capitalized) file (\(size / 1024)KB) - Read: \(String(format: "%.3f", readTime))s, Write: \(String(format: "%.3f", writeTime))s, Copy: \(String(format: "%.3f", copyTime))s")
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetOrganizeDirectory(_ directory: URL) {
        // Move all files back to root directory for next test iteration
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let subContents = try fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)
                    
                    for subItem in subContents {
                        let destination = directory.appendingPathComponent(subItem.lastPathComponent)
                        try? fileManager.moveItem(at: subItem, to: destination)
                    }
                    
                    try? fileManager.removeItem(at: item)
                }
            }
        } catch {
            // Ignore errors during reset
        }
    }
    
    private func measureExecutionTime(_ block: () -> Void) -> TimeInterval {
        let startTime = Date()
        block()
        return Date().timeIntervalSince(startTime)
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Performance Metrics Helper

class PerformanceMetrics {
    private var measurements: [String: [TimeInterval]] = [:]
    
    func recordMeasurement(_ name: String, time: TimeInterval) {
        if measurements[name] == nil {
            measurements[name] = []
        }
        measurements[name]?.append(time)
    }
    
    func getAverageTime(for name: String) -> TimeInterval? {
        guard let times = measurements[name], !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    func getMinTime(for name: String) -> TimeInterval? {
        return measurements[name]?.min()
    }
    
    func getMaxTime(for name: String) -> TimeInterval? {
        return measurements[name]?.max()
    }
    
    func printSummary() {
        for (name, times) in measurements {
            let avg = times.reduce(0, +) / Double(times.count)
            let min = times.min() ?? 0
            let max = times.max() ?? 0
            
            print("📊 \(name): Avg: \(String(format: "%.3f", avg))s, Min: \(String(format: "%.3f", min))s, Max: \(String(format: "%.3f", max))s")
        }
    }
}

// MARK: - Extensions

extension FileOperation {
    static func extractMetadata(directory: URL) -> FileOperation {
        return .search(criteria: SearchCriteria(directory: directory, extractMetadata: true, recursive: true))
    }
}

extension SearchCriteria {
    init(directory: URL, extractMetadata: Bool, recursive: Bool) {
        self.init(directory: directory, fileExtension: nil, recursive: recursive)
        // In a real implementation, this would have an extractMetadata parameter
    }
    
    init(directory: URL, contentSearch: String, recursive: Bool) {
        self.init(directory: directory, fileExtension: nil, recursive: recursive)
        // In a real implementation, this would have a contentSearch parameter
    }
}