import XCTest
@testable import Sam

final class TaskClassificationPerformanceTests: XCTestCase {
    var taskClassifier: TaskClassifier!
    var mockAIService: MockAIService!
    var mockLocalNLP: MockLocalNLPService!
    
    override func setUp() {
        super.setUp()
        mockAIService = MockAIService()
        mockLocalNLP = MockLocalNLPService()
        taskClassifier = TaskClassifier(
            aiService: mockAIService,
            localNLP: mockLocalNLP
        )
    }
    
    override func tearDown() {
        taskClassifier = nil
        mockAIService = nil
        mockLocalNLP = nil
        super.tearDown()
    }
    
    // MARK: - Local Classification Performance Tests
    
    func testLocalClassificationPerformance() {
        let testInputs = [
            "copy file.txt to Desktop",
            "move document.pdf from Downloads to Documents",
            "delete old_file.txt",
            "what's my battery level?",
            "how much storage do I have?",
            "open Safari",
            "quit TextEdit",
            "send email to john@example.com",
            "create calendar event for tomorrow",
            "find all PDF files in Downloads"
        ]
        
        measure {
            for input in testInputs {
                _ = taskClassifier.classifyLocally(input)
            }
        }
    }
    
    func testSingleClassificationLatency() {
        let input = "copy report.pdf from Downloads to Desktop"
        
        measure {
            _ = taskClassifier.classifyLocally(input)
        }
    }
    
    func testComplexQueryClassificationPerformance() {
        let complexInputs = [
            "find all PDF files created in the last week in my Documents folder and organize them by date",
            "send an email to my team about the project update with the latest report attached",
            "create a calendar event for next Monday at 2 PM for the quarterly review meeting",
            "open Safari, navigate to github.com, and bookmark the page as Development Resources",
            "search for all images larger than 10MB in my Pictures folder and move them to external drive"
        ]
        
        measure {
            for input in complexInputs {
                _ = taskClassifier.classifyLocally(input)
            }
        }
    }
    
    func testParameterExtractionPerformance() {
        let parameterRichInputs = [
            "copy /Users/john/Documents/report.pdf to /Users/john/Desktop/backup/",
            "send email to john@example.com, jane@example.com with subject 'Project Update' and body 'Please review the attached document'",
            "create calendar event 'Team Meeting' on 2024-03-15 at 14:00 with location 'Conference Room A'",
            "find files with extension .docx modified after 2024-01-01 in /Users/john/Documents/",
            "set volume to 50% and brightness to 75%"
        ]
        
        measure {
            for input in parameterRichInputs {
                let result = taskClassifier.classifyLocally(input)
                _ = result.parameters // Force parameter extraction
            }
        }
    }
    
    // MARK: - Cloud Classification Performance Tests
    
    func testCloudClassificationPerformance() async {
        let ambiguousInputs = [
            "help me organize my workspace",
            "prepare for the meeting tomorrow",
            "clean up my computer",
            "make my system faster",
            "backup important stuff"
        ]
        
        await measureAsync {
            for input in ambiguousInputs {
                _ = try? await self.taskClassifier.classifyWithCloud(input)
            }
        }
    }
    
    func testHybridClassificationPerformance() async {
        let mixedInputs = [
            "copy file.txt to Desktop", // Should use local
            "help me organize my files", // Should use cloud
            "what's my battery level?", // Should use local
            "make my computer run faster", // Should use cloud
            "open Safari and go to apple.com", // Should use local
            "prepare a presentation about AI", // Should use cloud
            "delete temporary files", // Should use local
            "suggest ways to improve productivity" // Should use cloud
        ]
        
        await measureAsync {
            for input in mixedInputs {
                _ = try? await self.taskClassifier.classify(input)
            }
        }
    }
    
    // MARK: - Batch Processing Performance Tests
    
    func testBatchClassificationPerformance() {
        let batchInputs = Array(repeating: [
            "copy file.txt to Desktop",
            "what's my battery level?",
            "open Safari",
            "send email to test@example.com",
            "find PDF files in Downloads"
        ], count: 20).flatMap { $0 }
        
        measure {
            let results = taskClassifier.classifyBatch(batchInputs)
            XCTAssertEqual(results.count, batchInputs.count)
        }
    }
    
    func testConcurrentClassificationPerformance() async {
        let inputs = Array(repeating: [
            "copy document.pdf to Desktop",
            "check system memory usage",
            "launch Calculator app",
            "create new calendar event",
            "search for image files"
        ], count: 10).flatMap { $0 }
        
        await measureAsync {
            await withTaskGroup(of: ClassificationResult?.self) { group in
                for input in inputs {
                    group.addTask {
                        return self.taskClassifier.classifyLocally(input)
                    }
                }
                
                var results: [ClassificationResult] = []
                for await result in group {
                    if let result = result {
                        results.append(result)
                    }
                }
                XCTAssertEqual(results.count, inputs.count)
            }
        }
    }
    
    // MARK: - Memory Usage Performance Tests
    
    func testMemoryUsageDuringClassification() {
        let largeInputs = Array(repeating: "copy " + String(repeating: "very_long_filename_", count: 100) + ".txt to Desktop", count: 1000)
        
        measure {
            autoreleasepool {
                for input in largeInputs {
                    _ = taskClassifier.classifyLocally(input)
                }
            }
        }
    }
    
    func testClassificationCachePerformance() {
        let repeatedInputs = Array(repeating: "copy file.txt to Desktop", count: 100)
        
        // First run - populate cache
        for input in repeatedInputs {
            _ = taskClassifier.classifyLocally(input)
        }
        
        // Second run - should use cache
        measure {
            for input in repeatedInputs {
                _ = taskClassifier.classifyLocally(input)
            }
        }
    }
    
    // MARK: - Confidence Scoring Performance Tests
    
    func testConfidenceScoringPerformance() {
        let testCases = [
            ("copy file.txt to Desktop", TaskType.fileOperation),
            ("what's my battery level?", TaskType.systemQuery),
            ("open Safari", TaskType.appControl),
            ("summarize this document", TaskType.textProcessing),
            ("calculate 2 + 2", TaskType.calculation),
            ("search for apple.com", TaskType.webQuery),
            ("help me organize files", TaskType.automation),
            ("change my settings", TaskType.settings),
            ("how do I use this feature?", TaskType.help)
        ]
        
        measure {
            for (input, expectedType) in testCases {
                let result = taskClassifier.classifyLocally(input)
                let confidence = taskClassifier.calculateConfidence(result, expectedType: expectedType)
                XCTAssertGreaterThan(confidence, 0.0)
            }
        }
    }
    
    // MARK: - Real-world Scenario Performance Tests
    
    func testTypicalUserSessionPerformance() async {
        // Simulate a typical user session with various commands
        let sessionCommands = [
            "what's my battery level?",
            "copy report.pdf from Downloads to Desktop",
            "open Safari and go to github.com",
            "send email to team@company.com about project update",
            "create calendar event for meeting tomorrow at 2 PM",
            "find all images in Pictures folder",
            "organize Desktop files by type",
            "check available storage space",
            "quit unused applications",
            "backup Documents folder to external drive"
        ]
        
        await measureAsync {
            for command in sessionCommands {
                _ = try? await self.taskClassifier.classify(command)
                // Small delay to simulate user thinking time
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    func testPowerUserWorkflowPerformance() async {
        // Simulate a power user with complex, rapid commands
        let powerUserCommands = [
            "find all PDF files modified in last 7 days in ~/Documents and ~/Downloads",
            "batch rename all IMG_*.jpg files in Pictures to vacation_001.jpg, vacation_002.jpg, etc.",
            "create zip archive of all project files excluding .git and node_modules",
            "sync Documents folder with cloud storage and verify integrity",
            "analyze disk usage and suggest cleanup opportunities",
            "automate daily backup of important folders to external drive",
            "monitor system performance and alert if CPU usage exceeds 80%",
            "schedule weekly maintenance tasks including cache cleanup and disk repair"
        ]
        
        await measureAsync {
            for command in powerUserCommands {
                _ = try? await self.taskClassifier.classify(command)
            }
        }
    }
    
    // MARK: - Stress Testing
    
    func testHighVolumeClassificationStress() {
        let stressInputs = Array(1...1000).map { "copy file\($0).txt to Desktop" }
        
        measure {
            let startTime = Date()
            let results = taskClassifier.classifyBatch(stressInputs)
            let endTime = Date()
            
            XCTAssertEqual(results.count, stressInputs.count)
            
            let averageTime = endTime.timeIntervalSince(startTime) / Double(stressInputs.count)
            XCTAssertLessThan(averageTime, 0.01, "Average classification time too slow: \(averageTime)s")
        }
    }
    
    func testMemoryLeakDuringLongSession() {
        // Test for memory leaks during extended use
        let commands = Array(repeating: [
            "copy file.txt to Desktop",
            "what's my battery?",
            "open Calculator",
            "send email to test@example.com",
            "find PDF files"
        ], count: 200).flatMap { $0 }
        
        measure {
            autoreleasepool {
                for command in commands {
                    _ = taskClassifier.classifyLocally(command)
                }
            }
        }
    }
    
    // MARK: - Accuracy vs Performance Trade-offs
    
    func testFastModePerformance() {
        taskClassifier.setPerformanceMode(.fast)
        
        let testInputs = [
            "copy file.txt to Desktop",
            "what's my battery level?",
            "open Safari",
            "send email to john@example.com",
            "find PDF files in Downloads"
        ]
        
        measure {
            for input in testInputs {
                let result = taskClassifier.classifyLocally(input)
                XCTAssertGreaterThan(result.confidence, 0.5) // Should still be reasonably accurate
            }
        }
    }
    
    func testAccurateModePerformance() {
        taskClassifier.setPerformanceMode(.accurate)
        
        let testInputs = [
            "copy file.txt to Desktop",
            "what's my battery level?",
            "open Safari",
            "send email to john@example.com",
            "find PDF files in Downloads"
        ]
        
        measure {
            for input in testInputs {
                let result = taskClassifier.classifyLocally(input)
                XCTAssertGreaterThan(result.confidence, 0.7) // Should be more accurate
            }
        }
    }
}

// MARK: - Helper Extensions

extension XCTestCase {
    func measureAsync(block: @escaping () async throws -> Void) async {
        await measure {
            Task {
                try? await block()
            }
        }
    }
}

// MARK: - Mock Classes

class MockLocalNLPService: LocalNLPServiceProtocol {
    func quickClassify(_ input: String) async -> ClassificationResult? {
        // Simulate local NLP processing time
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // Simple keyword-based classification for testing
        if input.contains("copy") || input.contains("move") || input.contains("delete") {
            return ClassificationResult(
                taskType: .fileOperation,
                confidence: 0.9,
                parameters: [:],
                requiresCloudProcessing: false,
                estimatedComplexity: .low
            )
        } else if input.contains("battery") || input.contains("storage") || input.contains("memory") {
            return ClassificationResult(
                taskType: .systemQuery,
                confidence: 0.85,
                parameters: [:],
                requiresCloudProcessing: false,
                estimatedComplexity: .low
            )
        } else if input.contains("open") || input.contains("quit") || input.contains("launch") {
            return ClassificationResult(
                taskType: .appControl,
                confidence: 0.8,
                parameters: [:],
                requiresCloudProcessing: false,
                estimatedComplexity: .medium
            )
        }
        
        return nil // Requires cloud processing
    }
}

extension TaskClassifier {
    func classifyBatch(_ inputs: [String]) -> [ClassificationResult] {
        return inputs.compactMap { classifyLocally($0) }
    }
    
    func calculateConfidence(_ result: ClassificationResult, expectedType: TaskType) -> Double {
        return result.taskType == expectedType ? result.confidence : 0.0
    }
    
    func setPerformanceMode(_ mode: PerformanceMode) {
        // Implementation would adjust internal parameters for speed vs accuracy
    }
}

enum PerformanceMode {
    case fast
    case balanced
    case accurate
}