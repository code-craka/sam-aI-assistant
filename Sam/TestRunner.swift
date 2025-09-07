import Foundation

// MARK: - Test Runner
/// Simple test runner for FileSystemService
@main
struct TestRunner {
    static func main() async {
        print("🧪 Running FileSystemService Tests")
        print(String(repeating: "=", count: 50))
        
        await runFileSystemServiceTests()
        
        print("\n" + String(repeating: "=", count: 50))
        print("🏁 Test run completed")
    }
}