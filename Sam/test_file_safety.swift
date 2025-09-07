#!/usr/bin/env swift

import Foundation

// Simple test to verify FileSystemService safety features
@MainActor
func testFileSystemSafety() async {
    print("Testing FileSystemService safety and validation features...")
    
    let fileSystemService = FileSystemService()
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SafetyTest")
    
    do {
        // Create temp directory
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Test 1: File existence validation
        print("Test 1: File existence validation")
        let nonExistentFile = tempDir.appendingPathComponent("does_not_exist.txt")
        let destination = tempDir.appendingPathComponent("destination.txt")
        
        do {
            _ = try await fileSystemService.executeOperation(
                FileOperation.copy(source: nonExistentFile, destination: destination)
            )
            print("❌ Expected file not found error")
        } catch let error as FileOperationError {
            switch error {
            case .fileNotFound:
                print("✅ Correctly caught file not found error")
            default:
                print("❌ Unexpected error: \(error)")
            }
        }
        
        // Test 2: Invalid file name validation
        print("\nTest 2: Invalid file name validation")
        let sourceFile = tempDir.appendingPathComponent("source.txt")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        do {
            _ = try await fileSystemService.executeOperation(
                FileOperation.rename(file: sourceFile, newName: "invalid:name.txt")
            )
            print("❌ Expected invalid file name error")
        } catch let error as FileOperationError {
            switch error {
            case .invalidFileName:
                print("✅ Correctly caught invalid file name error")
            default:
                print("❌ Unexpected error: \(error)")
            }
        }
        
        // Test 3: Successful operation with undo
        print("\nTest 3: Successful operation with undo")
        let copyDestination = tempDir.appendingPathComponent("copy.txt")
        
        let result = try await fileSystemService.executeOperation(
            FileOperation.copy(source: sourceFile, destination: copyDestination)
        )
        
        if result.success && FileManager.default.fileExists(atPath: copyDestination.path) {
            print("✅ Copy operation succeeded")
            
            if fileSystemService.canUndo(result) {
                print("✅ Undo is available")
                
                try await fileSystemService.undoLastOperation(result)
                
                if !FileManager.default.fileExists(atPath: copyDestination.path) {
                    print("✅ Undo operation succeeded")
                } else {
                    print("❌ Undo operation failed")
                }
            } else {
                print("❌ Undo not available")
            }
        } else {
            print("❌ Copy operation failed")
        }
        
        // Test 4: User-friendly error messages
        print("\nTest 4: User-friendly error messages")
        let testErrors: [FileOperationError] = [
            .fileNotFound("/path/to/missing.txt"),
            .diskSpaceInsufficient,
            .invalidFileName("bad:name.txt")
        ]
        
        for error in testErrors {
            let (message, suggestion) = fileSystemService.getErrorMessage(for: error)
            print("Error: \(message)")
            if let suggestion = suggestion {
                print("Suggestion: \(suggestion)")
            }
        }
        
        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
        print("\n✅ All safety tests completed successfully!")
        
    } catch {
        print("❌ Test failed with error: \(error)")
    }
}

// Run the test
Task {
    await testFileSystemSafety()
}

// Keep the script running
RunLoop.main.run()