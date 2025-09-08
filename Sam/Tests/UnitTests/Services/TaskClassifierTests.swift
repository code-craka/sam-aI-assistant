import XCTest
import NaturalLanguage
@testable import Sam

final class TaskClassifierTests: XCTestCase {
    var taskClassifier: TaskClassifier!
    
    override func setUp() {
        super.setUp()
        taskClassifier = TaskClassifier()
    }
    
    override func tearDown() {
        taskClassifier = nil
        super.tearDown()
    }
    
    // MARK: - File Operation Classification Tests
    
    func testFileOperationClassification() async throws {
        let testCases = [
            ("copy file.txt to Desktop", TaskType.fileOperation, ["operation": "copy", "source": "file.txt", "destination": "Desktop"]),
            ("move report.pdf from Downloads to Documents", TaskType.fileOperation, ["operation": "move", "source": "Downloads/report.pdf", "destination": "Documents"]),
            ("delete old files in Downloads", TaskType.fileOperation, ["operation": "delete", "location": "Downloads"]),
            ("rename document.txt to final_report.txt", TaskType.fileOperation, ["operation": "rename", "source": "document.txt", "target": "final_report.txt"])
        ]
        
        for (input, expectedType, expectedParams) in testCases {
            let result = try await taskClassifier.classify(input)
            
            XCTAssertEqual(result.taskType, expectedType, "Failed for input: \(input)")
            XCTAssertGreaterThan(result.confidence, 0.7, "Low confidence for: \(input)")
            
            for (key, expectedValue) in expectedParams {
                XCTAssertNotNil(result.parameters[key], "Missing parameter \(key) for: \(input)")
            }
        }
    }
    
    // MARK: - System Query Classification Tests
    
    func testSystemQueryClassification() async throws {
        let testCases = [
            ("what's my battery level?", "battery"),
            ("how much storage space do I have?", "storage"),
            ("what's my memory usage?", "memory"),
            ("show me running applications", "apps"),
            ("what's my network status?", "network")
        ]
        
        for (input, expectedQueryType) in testCases {
            let result = try await taskClassifier.classify(input)
            
            XCTAssertEqual(result.taskType, .systemQuery, "Failed for input: \(input)")
            XCTAssertGreaterThan(result.confidence, 0.7, "Low confidence for: \(input)")
            XCTAssertEqual(result.parameters["queryType"] as? String, expectedQueryType, "Wrong query type for: \(input)")
        }
    }
    
    // MARK: - App Control Classification Tests
    
    func testAppControlClassification() async throws {
        let testCases = [
            ("open Safari", "Safari", "open"),
            ("quit Finder", "Finder", "quit"),
            ("launch Terminal", "Terminal", "launch"),
            ("close all Safari windows", "Safari", "close")
        ]
        
        for (input, expectedApp, expectedAction) in testCases {
            let result = try await taskClassifier.classify(input)
            
            XCTAssertEqual(result.taskType, .appControl, "Failed for input: \(input)")
            XCTAssertGreaterThan(result.confidence, 0.7, "Low confidence for: \(input)")
            XCTAssertEqual(result.parameters["app"] as? String, expectedApp, "Wrong app for: \(input)")
            XCTAssertEqual(result.parameters["action"] as? String, expectedAction, "Wrong action for: \(input)")
        }
    }
    
    // MARK: - Text Processing Classification Tests
    
    func testTextProcessingClassification() async throws {
        let testCases = [
            "summarize this document",
            "translate this text to Spanish",
            "check grammar in my essay",
            "format this code snippet"
        ]
        
        for input in testCases {
            let result = try await taskClassifier.classify(input)
            
            XCTAssertEqual(result.taskType, .textProcessing, "Failed for input: \(input)")
            XCTAssertGreaterThan(result.confidence, 0.6, "Low confidence for: \(input)")
        }
    }
    
    // MARK: - Confidence Scoring Tests
    
    func testConfidenceScoring() async throws {
        // High confidence cases
        let highConfidenceCases = [
            "copy file.txt to Desktop",
            "what's my battery level?",
            "open Safari"
        ]
        
        for input in highConfidenceCases {
            let result = try await taskClassifier.classify(input)
            XCTAssertGreaterThan(result.confidence, 0.8, "Expected high confidence for: \(input)")
        }
        
        // Low confidence cases
        let lowConfidenceCases = [
            "do something with that thing",
            "help me with stuff",
            "make it better"
        ]
        
        for input in lowConfidenceCases {
            let result = try await taskClassifier.classify(input)
            XCTAssertLessThan(result.confidence, 0.7, "Expected low confidence for: \(input)")
            XCTAssertTrue(result.requiresCloudProcessing, "Should require cloud processing for: \(input)")
        }
    }
    
    // MARK: - Parameter Extraction Tests
    
    func testParameterExtraction() async throws {
        // File path extraction
        let filePathInput = "copy ~/Documents/report.pdf to /Users/john/Desktop/"
        let fileResult = try await taskClassifier.classify(filePathInput)
        
        XCTAssertNotNil(fileResult.parameters["source"])
        XCTAssertNotNil(fileResult.parameters["destination"])
        
        // App name extraction with variations
        let appInputs = [
            ("open Google Chrome", "Google Chrome"),
            ("launch VS Code", "VS Code"),
            ("quit Microsoft Word", "Microsoft Word")
        ]
        
        for (input, expectedApp) in appInputs {
            let result = try await taskClassifier.classify(input)
            XCTAssertEqual(result.parameters["app"] as? String, expectedApp, "Failed app extraction for: \(input)")
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testEdgeCases() async throws {
        // Empty input
        let emptyResult = try await taskClassifier.classify("")
        XCTAssertEqual(emptyResult.taskType, .help)
        XCTAssertLessThan(emptyResult.confidence, 0.5)
        
        // Very long input
        let longInput = String(repeating: "copy file ", count: 100)
        let longResult = try await taskClassifier.classify(longInput)
        XCTAssertEqual(longResult.taskType, .fileOperation)
        
        // Mixed language input (if supported)
        let mixedInput = "copy archivo.txt to Desktop"
        let mixedResult = try await taskClassifier.classify(mixedInput)
        XCTAssertEqual(mixedResult.taskType, .fileOperation)
    }
    
    // MARK: - Performance Tests
    
    func testClassificationPerformance() {
        let inputs = [
            "copy file.txt to Desktop",
            "what's my battery level?",
            "open Safari",
            "summarize this document"
        ]
        
        measure {
            for input in inputs {
                _ = taskClassifier.classifyLocally(input)
            }
        }
    }
    
    func testBatchClassificationPerformance() async throws {
        let inputs = Array(repeating: "copy file.txt to Desktop", count: 100)
        
        let startTime = Date()
        for input in inputs {
            _ = try await taskClassifier.classify(input)
        }
        let executionTime = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(executionTime, 5.0, "Batch classification took too long")
    }
}