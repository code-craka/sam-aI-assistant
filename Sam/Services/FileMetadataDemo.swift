import Foundation
import SwiftUI

/// Demo class to showcase file metadata extraction and smart organization features
@MainActor
class FileMetadataDemo: ObservableObject {
    
    @Published var isRunning = false
    @Published var output: [String] = []
    @Published var progress: Double = 0.0
    
    private let fileSystemService = FileSystemService()
    
    func runDemo() async {
        isRunning = true
        output.removeAll()
        progress = 0.0
        
        await addOutput("🚀 Starting File Metadata and Smart Organization Demo")
        await addOutput("=" * 50)
        
        do {
            // Create demo directory structure
            let demoDir = try await createDemoFiles()
            await addOutput("📁 Created demo files in: \(demoDir.lastPathComponent)")
            progress = 0.2
            
            // Demo 1: Extract metadata from files
            await addOutput("\n📊 Demo 1: Extracting File Metadata")
            await addOutput("-" * 30)
            try await demoMetadataExtraction(in: demoDir)
            progress = 0.4
            
            // Demo 2: Detect duplicates
            await addOutput("\n🔍 Demo 2: Detecting Duplicate Files")
            await addOutput("-" * 30)
            try await demoDuplicateDetection(in: demoDir)
            progress = 0.6
            
            // Demo 3: Smart organization
            await addOutput("\n🗂️ Demo 3: Smart File Organization")
            await addOutput("-" * 30)
            try await demoSmartOrganization(in: demoDir)
            progress = 0.8
            
            // Demo 4: Enhanced search with metadata
            await addOutput("\n🔎 Demo 4: Enhanced Search with Metadata")
            await addOutput("-" * 30)
            try await demoEnhancedSearch(in: demoDir)
            progress = 1.0
            
            await addOutput("\n✅ Demo completed successfully!")
            
            // Cleanup
            try? FileManager.default.removeItem(at: demoDir)
            await addOutput("🧹 Cleaned up demo files")
            
        } catch {
            await addOutput("❌ Demo failed: \(error.localizedDescription)")
        }
        
        isRunning = false
    }
    
    private func createDemoFiles() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileMetadataDemo_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Create various file types for testing
        let files = [
            // Text documents
            ("document1.txt", "This is a sample document with some text content for testing metadata extraction."),
            ("document2.txt", "Another document with different content but similar structure for duplicate testing."),
            ("readme.md", "# Project README\n\nThis is a markdown file with **formatting** and content."),
            
            // Duplicate files
            ("original.txt", "This content will be duplicated in multiple files to test duplicate detection."),
            ("copy1.txt", "This content will be duplicated in multiple files to test duplicate detection."),
            ("copy2.txt", "This content will be duplicated in multiple files to test duplicate detection."),
            
            // Different sizes
            ("small.txt", "Small"),
            ("medium.txt", String(repeating: "Medium sized content. ", count: 50)),
            ("large.txt", String(repeating: "Large file content with lots of repeated text. ", count: 200)),
            
            // Different dates (we'll modify these after creation)
            ("old_file.txt", "This file will be made to appear old"),
            ("new_file.txt", "This file will be kept as new")
        ]
        
        for (filename, content) in files {
            let fileURL = tempDir.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        // Create subdirectories with files
        let subDir1 = tempDir.appendingPathComponent("Photos")
        let subDir2 = tempDir.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: subDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)
        
        // Add files to subdirectories
        try "Photo metadata would go here".write(
            to: subDir1.appendingPathComponent("photo1.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "Important document content".write(
            to: subDir2.appendingPathComponent("important.txt"),
            atomically: true,
            encoding: .utf8
        )
        
        // Modify file dates to simulate old files
        let oldDate = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        let oldFileURL = tempDir.appendingPathComponent("old_file.txt")
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFileURL.path)
        
        return tempDir
    }
    
    private func demoMetadataExtraction(in directory: URL) async throws {
        // Get all files in directory
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return resourceValues?.isRegularFile == true
        }
        
        await addOutput("Found \(files.count) files to analyze")
        
        // Extract metadata from a few sample files
        let sampleFiles = Array(files.prefix(3))
        
        for file in sampleFiles {
            do {
                let metadata = try await fileSystemService.extractFileMetadata(from: file)
                
                await addOutput("📄 \(file.lastPathComponent):")
                await addOutput("   Size: \(ByteCountFormatter.string(fromByteCount: metadata.basicInfo.fileSize, countStyle: .file))")
                await addOutput("   Type: \(metadata.basicInfo.contentType ?? "Unknown")")
                await addOutput("   Readable: \(metadata.basicInfo.permissions.isReadable ? "✅" : "❌")")
                await addOutput("   Hash: \(metadata.contentHash?.prefix(8) ?? "N/A")...")
                
                if let docInfo = metadata.documentInfo {
                    await addOutput("   Words: \(docInfo.wordCount ?? 0)")
                    await addOutput("   Characters: \(docInfo.characterCount ?? 0)")
                }
                
            } catch {
                await addOutput("   ❌ Failed to extract metadata: \(error.localizedDescription)")
            }
        }
    }
    
    private func demoDuplicateDetection(in directory: URL) async throws {
        let result = try await fileSystemService.detectDuplicates(
            in: [directory],
            methods: [.contentHash, .nameAndSize]
        )
        
        await addOutput("Scanned \(result.scannedFiles) files")
        await addOutput("Found \(result.duplicateGroups.count) duplicate groups")
        await addOutput("Total duplicates: \(result.totalDuplicates)")
        await addOutput("Potential space savings: \(result.formattedSavings)")
        await addOutput("Scan time: \(String(format: "%.2f", result.scanTime)) seconds")
        
        // Show details of duplicate groups
        for (index, group) in result.duplicateGroups.enumerated() {
            await addOutput("\n📋 Group \(index + 1) (\(group.duplicateType)):")
            await addOutput("   Original: \(group.originalFile?.name ?? "Unknown")")
            await addOutput("   Duplicates: \(group.duplicateFiles.map { $0.name }.joined(separator: ", "))")
            await addOutput("   Total size: \(ByteCountFormatter.string(fromByteCount: group.totalSize, countStyle: .file))")
        }
        
        // Demonstrate duplicate removal (but don't actually remove in demo)
        if !result.duplicateGroups.isEmpty {
            await addOutput("\n🗑️ Would remove \(result.totalDuplicates) duplicate files")
            await addOutput("   (Not actually removing in demo)")
        }
    }
    
    private func demoSmartOrganization(in directory: URL) async throws {
        // Create custom organization rules for demo
        let customRules = [
            SmartOrganizationRule(
                name: "Large Files",
                condition: .fileLargerThan(1000), // Files larger than 1KB
                targetFolder: "Large Files",
                priority: 10
            ),
            SmartOrganizationRule(
                name: "Old Files",
                condition: .fileOlderThan(Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()),
                targetFolder: "Archive",
                priority: 9
            ),
            SmartOrganizationRule(
                name: "Markdown Files",
                condition: .fileType("md"),
                targetFolder: "Documentation",
                priority: 8
            ),
            SmartOrganizationRule(
                name: "Text Documents",
                condition: .fileType("txt"),
                targetFolder: "Text Files",
                priority: 7
            )
        ]
        
        await addOutput("Applying \(customRules.count) organization rules:")
        for rule in customRules {
            await addOutput("  • \(rule.name) (priority: \(rule.priority))")
        }
        
        // Note: In a real demo, we would actually organize files
        // For this demo, we'll simulate the organization
        await addOutput("\n📁 Organization simulation:")
        await addOutput("   Would create folders: Large Files, Archive, Documentation, Text Files")
        await addOutput("   Would move files based on size, age, and type")
        await addOutput("   (Not actually moving files in demo to preserve structure)")
        
        // Show what would happen
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return resourceValues?.isRegularFile == true
        }
        
        var ruleMatches: [String: [String]] = [:]
        
        for file in files {
            let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
            let size = Int64(resourceValues.fileSize ?? 0)
            
            for rule in customRules {
                var matches = false
                
                switch rule.condition {
                case .fileLargerThan(let threshold):
                    matches = size > threshold
                case .fileOlderThan:
                    matches = file.lastPathComponent == "old_file.txt"
                case .fileType(let type):
                    matches = file.pathExtension.lowercased() == type.lowercased()
                default:
                    matches = false
                }
                
                if matches {
                    ruleMatches[rule.name, default: []].append(file.lastPathComponent)
                    break // First matching rule wins
                }
            }
        }
        
        for (ruleName, matchedFiles) in ruleMatches {
            await addOutput("   \(ruleName): \(matchedFiles.joined(separator: ", "))")
        }
    }
    
    private func demoEnhancedSearch(in directory: URL) async throws {
        // Demonstrate enhanced search with metadata
        let searchCriteria = SearchCriteria(
            query: "document",
            searchPaths: [directory],
            includeSubdirectories: true,
            searchContent: true,
            sortBy: .size
        )
        
        await addOutput("Searching for '\(searchCriteria.query)' with metadata enhancement...")
        
        let result = try await fileSystemService.searchFilesWithMetadata(criteria: searchCriteria)
        
        await addOutput("Found \(result.totalFound) files matching search criteria")
        await addOutput("Search time: \(String(format: "%.3f", result.searchTime)) seconds")
        
        // Show enhanced results with metadata
        for file in result.files.prefix(5) { // Show first 5 results
            await addOutput("\n📄 \(file.name):")
            await addOutput("   Size: \(file.formattedSize)")
            await addOutput("   Modified: \(DateFormatter.localizedString(from: file.dateModified, dateStyle: .short, timeStyle: .short))")
            
            if let metadata = file.metadata {
                await addOutput("   Hash: \(metadata.contentHash?.prefix(8) ?? "N/A")...")
                
                if let docInfo = metadata.documentInfo {
                    await addOutput("   Words: \(docInfo.wordCount ?? 0)")
                    if let language = docInfo.language {
                        await addOutput("   Language: \(language)")
                    }
                }
            }
        }
    }
    
    private func addOutput(_ message: String) async {
        await MainActor.run {
            output.append(message)
        }
    }
}

// Helper extension for string repetition
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}