import Foundation

// MARK: - FileSystem Service Demo
/// Demonstrates the FileSystemService functionality
@MainActor
class FileSystemServiceDemo {
    
    private let fileSystemService = FileSystemService()
    private let tempDirectory: URL
    
    init() {
        // Create a temporary directory for demo
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceDemo")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }
    
    deinit {
        // Clean up
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    /// Run all demo operations
    func runDemo() async {
        print("🚀 Starting FileSystemService Demo")
        print("📁 Demo directory: \(tempDirectory.path)")
        
        do {
            // Create test files
            await createTestFiles()
            
            // Demo file operations
            await demoCopyOperation()
            await demoMoveOperation()
            await demoRenameOperation()
            await demoSearchOperation()
            await demoOrganizationOperation()
            await demoBatchOperations()
            
            print("✅ All demo operations completed successfully!")
            
        } catch {
            print("❌ Demo failed with error: \(error)")
        }
    }
    
    // MARK: - Demo Operations
    
    private func createTestFiles() async {
        print("\n📝 Creating test files...")
        
        let testFiles = [
            ("document.txt", "This is a text document"),
            ("image.jpg", "JPEG image data"),
            ("video.mp4", "MP4 video data"),
            ("archive.zip", "ZIP archive data"),
            ("presentation.pdf", "PDF presentation data"),
            ("spreadsheet.xlsx", "Excel spreadsheet data")
        ]
        
        for (fileName, content) in testFiles {
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            try! content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("  ✓ Created: \(fileName)")
        }
    }
    
    private func demoCopyOperation() async {
        print("\n📋 Demo: Copy Operation")
        
        do {
            let sourceFile = tempDirectory.appendingPathComponent("document.txt")
            let destinationFile = tempDirectory.appendingPathComponent("document_copy.txt")
            
            let result = try await fileSystemService.executeOperation(
                .copy(source: sourceFile, destination: destinationFile)
            )
            
            print("  ✓ \(result.summary)")
            print("  ⏱️ Execution time: \(String(format: "%.3f", result.executionTime))s")
            
        } catch {
            print("  ❌ Copy operation failed: \(error)")
        }
    }
    
    private func demoMoveOperation() async {
        print("\n🚚 Demo: Move Operation")
        
        do {
            let sourceFile = tempDirectory.appendingPathComponent("document_copy.txt")
            let destinationFile = tempDirectory.appendingPathComponent("moved_document.txt")
            
            let result = try await fileSystemService.executeOperation(
                .move(source: sourceFile, destination: destinationFile)
            )
            
            print("  ✓ \(result.summary)")
            print("  ⏱️ Execution time: \(String(format: "%.3f", result.executionTime))s")
            
        } catch {
            print("  ❌ Move operation failed: \(error)")
        }
    }
    
    private func demoRenameOperation() async {
        print("\n✏️ Demo: Rename Operation")
        
        do {
            let fileToRename = tempDirectory.appendingPathComponent("moved_document.txt")
            let newName = "final_document.txt"
            
            let result = try await fileSystemService.executeOperation(
                .rename(file: fileToRename, newName: newName)
            )
            
            print("  ✓ \(result.summary)")
            print("  ⏱️ Execution time: \(String(format: "%.3f", result.executionTime))s")
            
        } catch {
            print("  ❌ Rename operation failed: \(error)")
        }
    }
    
    private func demoSearchOperation() async {
        print("\n🔍 Demo: Search Operation")
        
        do {
            let criteria = SearchCriteria(
                query: "document",
                searchPaths: [tempDirectory],
                includeSubdirectories: true
            )
            
            let result = try await fileSystemService.executeOperation(.search(criteria: criteria))
            
            print("  ✓ \(result.summary)")
            print("  📄 Found files:")
            for fileURL in result.processedFiles {
                print("    - \(fileURL.lastPathComponent)")
            }
            
        } catch {
            print("  ❌ Search operation failed: \(error)")
        }
    }
    
    private func demoOrganizationOperation() async {
        print("\n📂 Demo: Organization by Type")
        
        do {
            let result = try await fileSystemService.executeOperation(
                .organize(directory: tempDirectory, strategy: .byType)
            )
            
            print("  ✓ \(result.summary)")
            print("  📁 Created folders:")
            
            // List created folders
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            
            for item in contents {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    let folderContents = try FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)
                    print("    - \(item.lastPathComponent) (\(folderContents.count) files)")
                }
            }
            
        } catch {
            print("  ❌ Organization operation failed: \(error)")
        }
    }
    
    private func demoBatchOperations() async {
        print("\n📦 Demo: Batch Operations")
        
        do {
            // Create some new files for batch operations
            let batchFiles = [
                ("batch1.txt", "Batch file 1"),
                ("batch2.txt", "Batch file 2"),
                ("batch3.txt", "Batch file 3")
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
                .copy(
                    source: tempDirectory.appendingPathComponent("batch2.txt"),
                    destination: tempDirectory.appendingPathComponent("batch2_copy.txt")
                ),
                .rename(
                    file: tempDirectory.appendingPathComponent("batch3.txt"),
                    newName: "batch3_renamed.txt"
                )
            ]
            
            let result = try await fileSystemService.executeBatchOperations(operations)
            
            print("  ✓ \(result.summary)")
            print("  📊 Success rate: \(String(format: "%.1f", result.successRate * 100))%")
            
        } catch {
            print("  ❌ Batch operations failed: \(error)")
        }
    }
}

// MARK: - Demo Runner
/// Run the FileSystemService demo
func runFileSystemServiceDemo() async {
    let demo = await FileSystemServiceDemo()
    await demo.runDemo()
}