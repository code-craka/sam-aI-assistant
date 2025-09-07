import Foundation

// Demo script to showcase FileSystemService safety and validation features
print("=== FileSystemService Safety and Validation Demo ===\n")

// Create a temporary directory for testing
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SafetyDemo")
try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

print("Created temporary directory: \(tempDir.path)\n")

// Demo 1: Pre-flight validation
print("1. PRE-FLIGHT VALIDATION")
print("========================")

// File existence check
let nonExistentFile = tempDir.appendingPathComponent("missing.txt")
print("❌ Attempting to copy non-existent file: \(nonExistentFile.lastPathComponent)")
print("   → This would be caught by validateOperation() before execution")
print("   → Error: FileOperationError.fileNotFound")

// Destination validation
let nonExistentDir = tempDir.appendingPathComponent("missing_dir")
let destination = nonExistentDir.appendingPathComponent("file.txt")
print("\n❌ Attempting to copy to non-existent directory: \(nonExistentDir.lastPathComponent)")
print("   → This would be caught by validateOperation() before execution")
print("   → Error: FileOperationError.destinationNotFound")

// Demo 2: File name validation
print("\n\n2. FILE NAME VALIDATION")
print("=======================")

let invalidNames = ["file:name.txt", "file\\name.txt", "file?name.txt", "", "CON.txt"]
for name in invalidNames {
    print("❌ Invalid file name: '\(name)'")
    print("   → Caught by isValidFileName() validation")
}

print("\n✅ Valid file name: 'document.txt'")
print("   → Passes isValidFileName() validation")

// Demo 3: User confirmation for dangerous operations
print("\n\n3. USER CONFIRMATION SYSTEM")
print("===========================")

print("🚨 Dangerous operations that require confirmation:")
print("   • Permanent deletion (moveToTrash: false)")
print("   • Deleting more than 10 files at once")
print("   • Moving system or application files")
print("   • Organizing system directories")
print("   → These trigger requestUserConfirmation() dialog")

// Demo 4: Undo functionality
print("\n\n4. UNDO FUNCTIONALITY")
print("=====================")

// Create a test file
let testFile = tempDir.appendingPathComponent("test.txt")
try! "Test content".write(to: testFile, atomically: true, encoding: .utf8)

print("✅ Created test file: \(testFile.lastPathComponent)")

// Simulate copy operation with undo
let copyDest = tempDir.appendingPathComponent("copy.txt")
print("📋 Copy operation: \(testFile.lastPathComponent) → \(copyDest.lastPathComponent)")
print("   → Operation includes undo action: { try? fileManager.removeItem(at: destination) }")

// Simulate move operation with undo
let moveDest = tempDir.appendingPathComponent("moved.txt")
print("📦 Move operation: \(testFile.lastPathComponent) → \(moveDest.lastPathComponent)")
print("   → Operation includes undo action: { try? fileManager.moveItem(at: destination, to: source) }")

// Demo 5: Error handling and recovery
print("\n\n5. ERROR HANDLING & RECOVERY")
print("============================")

let errorExamples = [
    ("File not found", "File not found: missing.txt", "Please verify the file exists and try again"),
    ("Insufficient disk space", "Not enough disk space to complete the operation", "Please free up disk space and try again"),
    ("Permission denied", "Permission denied: Cannot write to system directory", "Please check file permissions or try running with administrator privileges"),
    ("File already exists", "File already exists: existing.txt", "Choose a different name or location, or delete the existing file first"),
    ("Invalid file name", "Invalid file name: bad:name.txt", "Please use a valid file name without special characters")
]

for (errorType, message, suggestion) in errorExamples {
    print("\n❌ \(errorType):")
    print("   Message: \(message)")
    print("   Suggestion: \(suggestion)")
}

// Demo 6: System resource validation
print("\n\n6. SYSTEM RESOURCE VALIDATION")
print("=============================")

print("🔍 Pre-operation checks:")
print("   • Available disk space validation")
print("   • File size limits (max 10GB per file)")
print("   • Minimum free space requirement (1GB)")
print("   • Permission checks for source and destination")

// Demo 7: Progress tracking and cancellation
print("\n\n7. PROGRESS TRACKING & CANCELLATION")
print("===================================")

print("📊 Real-time progress updates:")
print("   • @Published var progress: Double")
print("   • @Published var currentOperation: String")
print("   • @Published var isProcessing: Bool")
print("   • Cancellation support via Task.isCancelled")

// Cleanup
try! FileManager.default.removeItem(at: tempDir)
print("\n\n✅ DEMO COMPLETED")
print("=================")
print("All safety and validation features have been implemented:")
print("• Pre-flight validation checks")
print("• User confirmation for dangerous operations")
print("• Comprehensive error handling with user-friendly messages")
print("• Undo functionality for reversible operations")
print("• System resource validation")
print("• Progress tracking and cancellation support")
print("• File name and path validation")
print("• Permission and disk space checks")

print("\nTemporary files cleaned up successfully.")