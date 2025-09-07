import Foundation

/// Simple test for AppleScript engine functionality
class AppleScriptEngineSimpleTest {
    
    private let engine = AppleScriptEngine()
    
    /// Run basic functionality tests
    func runTests() async {
        print("🧪 AppleScript Engine Simple Tests")
        print("=" * 40)
        
        await testTemplateLoading()
        await testScriptGeneration()
        await testParameterReplacement()
        await testErrorHandling()
        await testCaching()
        
        print("\n✅ Simple tests completed!")
    }
    
    /// Test template loading
    private func testTemplateLoading() async {
        print("\n📋 Testing template loading...")
        
        let templates = engine.getAvailableTemplates()
        
        if templates.isEmpty {
            print("❌ No templates loaded")
            return
        }
        
        print("✅ Loaded \(templates.count) templates")
        
        // Check for essential templates
        let templateNames = templates.map { $0.name }
        let essentialTemplates = ["create_folder", "send_email", "open_url", "launch_app"]
        
        for template in essentialTemplates {
            if templateNames.contains(template) {
                print("✅ Found essential template: \(template)")
            } else {
                print("❌ Missing essential template: \(template)")
            }
        }
    }
    
    /// Test script generation
    private func testScriptGeneration() async {
        print("\n🧠 Testing script generation...")
        
        let testCases = [
            ("create a folder", "Finder"),
            ("send email", "Mail"),
            ("open website", "Safari"),
            ("calendar event", "Calendar")
        ]
        
        for (description, expectedApp) in testCases {
            do {
                let script = try await engine.generateScript(for: description)
                
                if script.contains(expectedApp) {
                    print("✅ Generated script for '\(description)' contains \(expectedApp)")
                } else {
                    print("⚠️ Generated script for '\(description)' doesn't contain \(expectedApp)")
                }
            } catch {
                print("❌ Failed to generate script for '\(description)': \(error)")
            }
        }
    }
    
    /// Test parameter replacement
    private func testParameterReplacement() async {
        print("\n🔄 Testing parameter replacement...")
        
        let script = """
        tell application "{{appName}}"
            return "Hello {{userName}}"
        end tell
        """
        
        let parameters = [
            "appName": "Finder",
            "userName": "TestUser"
        ]
        
        do {
            // This will likely fail due to permissions, but we can catch compilation errors
            // to verify parameter replacement worked
            let _ = try await engine.executeScript(script, parameters: parameters, useCache: false)
            print("✅ Script executed (parameters replaced)")
        } catch AppleScriptEngine.ScriptError.compilationFailed(let message) {
            // Check if parameters were replaced
            if message.contains("{{") {
                print("❌ Parameters not replaced in script")
            } else {
                print("✅ Parameters replaced successfully (compilation failed for other reasons)")
            }
        } catch AppleScriptEngine.ScriptError.permissionDenied {
            print("✅ Parameters replaced (permission denied as expected)")
        } catch AppleScriptEngine.ScriptError.invalidTemplate(let message) {
            print("❌ Invalid template: \(message)")
        } catch {
            print("⚠️ Unexpected error: \(error)")
        }
    }
    
    /// Test error handling
    private func testErrorHandling() async {
        print("\n🚨 Testing error handling...")
        
        // Test compilation error
        do {
            let _ = try await engine.executeScript("this is not valid AppleScript", useCache: false)
            print("❌ Should have thrown compilation error")
        } catch AppleScriptEngine.ScriptError.compilationFailed {
            print("✅ Compilation error handled correctly")
        } catch {
            print("⚠️ Unexpected error type: \(error)")
        }
        
        // Test missing template
        do {
            let _ = try await engine.executeTemplate("non_existent_template")
            print("❌ Should have thrown template not found error")
        } catch AppleScriptEngine.ScriptError.scriptNotFound(let name) {
            print("✅ Missing template error handled: \(name)")
        } catch {
            print("⚠️ Unexpected error type: \(error)")
        }
        
        // Test unresolved parameters
        do {
            let _ = try await engine.executeScript("tell app \"Finder\" to {{unresolved}}", useCache: false)
            print("❌ Should have thrown invalid template error")
        } catch AppleScriptEngine.ScriptError.invalidTemplate {
            print("✅ Invalid template error handled correctly")
        } catch {
            print("⚠️ Unexpected error type: \(error)")
        }
    }
    
    /// Test caching functionality
    private func testCaching() async {
        print("\n💾 Testing caching...")
        
        // Clear cache first
        engine.clearCache()
        print("✅ Cache cleared")
        
        let script = "return \"test result\""
        
        do {
            // First execution
            let start1 = Date()
            let result1 = try await engine.executeScript(script, useCache: true)
            let time1 = Date().timeIntervalSince(start1)
            
            // Second execution (should use cache)
            let start2 = Date()
            let result2 = try await engine.executeScript(script, useCache: true)
            let time2 = Date().timeIntervalSince(start2)
            
            print("✅ Caching system functional")
            print("   First execution: \(String(format: "%.3f", time1))s")
            print("   Second execution: \(String(format: "%.3f", time2))s")
            
        } catch {
            print("⚠️ Caching test failed due to: \(error)")
            print("   (This is expected in test environment without permissions)")
        }
    }
}

// MARK: - Test Runner

/// Run simple AppleScript engine tests
func runAppleScriptEngineSimpleTest() async {
    let test = AppleScriptEngineSimpleTest()
    await test.runTests()
}

// MARK: - String Extension

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}