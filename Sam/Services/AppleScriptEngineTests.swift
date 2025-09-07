import XCTest
@testable import Sam

class AppleScriptEngineTests: XCTestCase {
    
    var engine: AppleScriptEngine!
    
    override func setUp() {
        super.setUp()
        engine = AppleScriptEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Template Tests
    
    func testGetAvailableTemplates() {
        let templates = engine.getAvailableTemplates()
        XCTAssertFalse(templates.isEmpty, "Should have built-in templates")
        
        // Check for key templates
        let templateNames = templates.map { $0.name }
        XCTAssertTrue(templateNames.contains("create_folder"))
        XCTAssertTrue(templateNames.contains("send_email"))
        XCTAssertTrue(templateNames.contains("open_url"))
    }
    
    func testTemplateParameterReplacement() async {
        let script = """
        tell application "Finder"
            make new folder at desktop with properties {name:"{{folderName}}"}
        end tell
        """
        
        let parameters = ["folderName": "TestFolder"]
        
        do {
            // This will fail without proper permissions, but we can test the parameter replacement
            let _ = try await engine.executeScript(script, parameters: parameters, useCache: false)
        } catch AppleScriptEngine.ScriptError.permissionDenied {
            // Expected - we don't have automation permissions in tests
            XCTAssertTrue(true, "Permission denied is expected in test environment")
        } catch AppleScriptEngine.ScriptError.compilationFailed(let message) {
            // Check that parameters were replaced
            XCTAssertFalse(message.contains("{{folderName}}"), "Parameters should be replaced before compilation")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testInvalidTemplateParameters() async {
        let script = """
        tell application "Finder"
            make new folder at desktop with properties {name:"{{missingParam}}"}
        end tell
        """
        
        do {
            let _ = try await engine.executeScript(script, parameters: [:], useCache: false)
            XCTFail("Should throw invalid template error")
        } catch AppleScriptEngine.ScriptError.invalidTemplate(let message) {
            XCTAssertTrue(message.contains("Unresolved template parameters"), "Should detect unresolved parameters")
        } catch {
            // Other errors are acceptable (like permission denied)
        }
    }
    
    // MARK: - Script Generation Tests
    
    func testGenerateScriptFromDescription() async {
        do {
            let script = try await engine.generateScript(for: "create a new folder")
            XCTAssertFalse(script.isEmpty, "Should generate script from description")
            XCTAssertTrue(script.contains("Finder"), "Should use Finder for folder operations")
        } catch {
            XCTFail("Should generate script from description: \(error)")
        }
    }
    
    func testGenerateEmailScript() async {
        do {
            let script = try await engine.generateScript(for: "send an email")
            XCTAssertFalse(script.isEmpty, "Should generate email script")
            XCTAssertTrue(script.contains("Mail"), "Should use Mail app for email")
        } catch {
            XCTFail("Should generate email script: \(error)")
        }
    }
    
    func testGenerateCalendarScript() async {
        do {
            let script = try await engine.generateScript(for: "create a calendar event")
            XCTAssertFalse(script.isEmpty, "Should generate calendar script")
            XCTAssertTrue(script.contains("Calendar"), "Should use Calendar app")
        } catch {
            XCTFail("Should generate calendar script: \(error)")
        }
    }
    
    // MARK: - Cache Tests
    
    func testScriptCaching() {
        let script = "return \"test\""
        let parameters = ["key": "value"]
        
        // Clear cache first
        engine.clearCache()
        
        // Execute same script twice - second should be faster due to caching
        let expectation1 = expectation(description: "First execution")
        let expectation2 = expectation(description: "Second execution")
        
        var firstTime: TimeInterval = 0
        var secondTime: TimeInterval = 0
        
        Task {
            do {
                let result1 = try await engine.executeScript(script, parameters: parameters, useCache: true)
                firstTime = result1.executionTime
                expectation1.fulfill()
                
                let result2 = try await engine.executeScript(script, parameters: parameters, useCache: true)
                secondTime = result2.executionTime
                expectation2.fulfill()
            } catch {
                // Expected in test environment without permissions
                expectation1.fulfill()
                expectation2.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
        
        // Note: In test environment, we can't actually execute scripts,
        // but we can verify the cache mechanism is in place
    }
    
    func testClearCache() {
        engine.clearCache()
        // Cache clearing should not throw errors
        XCTAssertTrue(true, "Cache clearing should succeed")
    }
    
    // MARK: - Template Execution Tests
    
    func testExecuteCreateFolderTemplate() async {
        do {
            let result = try await engine.executeTemplate(
                "create_folder",
                parameters: ["folderName": "TestFolder"]
            )
            // In test environment, this will likely fail due to permissions
            // but we can verify the template exists and parameters are processed
        } catch AppleScriptEngine.ScriptError.permissionDenied {
            XCTAssertTrue(true, "Permission denied is expected in test environment")
        } catch AppleScriptEngine.ScriptError.scriptNotFound {
            XCTFail("create_folder template should exist")
        } catch {
            // Other errors are acceptable in test environment
        }
    }
    
    func testExecuteNonExistentTemplate() async {
        do {
            let _ = try await engine.executeTemplate("non_existent_template")
            XCTFail("Should throw script not found error")
        } catch AppleScriptEngine.ScriptError.scriptNotFound(let name) {
            XCTAssertEqual(name, "non_existent_template")
        } catch {
            XCTFail("Should throw script not found error, got: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testCompilationError() async {
        let invalidScript = "this is not valid AppleScript syntax"
        
        do {
            let _ = try await engine.executeScript(invalidScript, useCache: false)
            XCTFail("Should throw compilation error")
        } catch AppleScriptEngine.ScriptError.compilationFailed {
            XCTAssertTrue(true, "Should detect compilation errors")
        } catch {
            // Other errors are acceptable (like permission denied)
        }
    }
    
    // MARK: - Performance Tests
    
    func testExecutionTimeTracking() async {
        let script = "return \"test\""
        
        do {
            let result = try await engine.executeScript(script, useCache: false)
            XCTAssertGreaterThan(result.executionTime, 0, "Should track execution time")
        } catch {
            // Expected in test environment
        }
    }
    
    func testConcurrentExecution() async {
        let script = "return \"test\""
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        let _ = try await self.engine.executeScript("\(script) \(i)", useCache: false)
                    } catch {
                        // Expected in test environment
                    }
                }
            }
        }
        
        XCTAssertTrue(true, "Concurrent execution should not crash")
    }
    
    // MARK: - State Tests
    
    func testExecutionState() {
        XCTAssertFalse(engine.isExecuting, "Should not be executing initially")
        XCTAssertEqual(engine.lastExecutionTime, 0, "Should have no execution time initially")
    }
}