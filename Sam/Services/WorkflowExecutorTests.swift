//
//  WorkflowExecutorTests.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import XCTest
@testable import Sam

@MainActor
class WorkflowExecutorTests: XCTestCase {
    var workflowExecutor: WorkflowExecutor!
    var mockFileSystemService: MockFileSystemService!
    var mockAppIntegrationManager: MockAppIntegrationManager!
    var mockSystemService: MockSystemService!
    var mockTaskRouter: MockTaskRouter!
    
    override func setUp() {
        super.setUp()
        mockFileSystemService = MockFileSystemService()
        mockAppIntegrationManager = MockAppIntegrationManager()
        mockSystemService = MockSystemService()
        mockTaskRouter = MockTaskRouter()
        
        workflowExecutor = WorkflowExecutor(
            fileSystemService: mockFileSystemService,
            appIntegrationManager: mockAppIntegrationManager,
            systemService: mockSystemService,
            taskRouter: mockTaskRouter
        )
    }
    
    override func tearDown() {
        workflowExecutor = nil
        mockFileSystemService = nil
        mockAppIntegrationManager = nil
        mockSystemService = nil
        mockTaskRouter = nil
        super.tearDown()
    }
    
    func testSimpleWorkflowExecution() async throws {
        // Given
        let workflow = createTestWorkflow()
        
        // When
        let result = try await workflowExecutor.executeWorkflow(workflow)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.completedSteps, workflow.steps.count)
        XCTAssertEqual(result.stepResults.count, workflow.steps.count)
        XCTAssertNil(result.error)
    }
    
    func testWorkflowWithFailingStep() async throws {
        // Given
        let workflow = createWorkflowWithFailingStep()
        
        // When
        do {
            _ = try await workflowExecutor.executeWorkflow(workflow)
            XCTFail("Expected workflow to fail")
        } catch {
            // Then
            XCTAssertTrue(error is WorkflowError)
        }
    }
    
    func testWorkflowWithConditionalStep() async throws {
        // Given
        let workflow = createWorkflowWithCondition()
        
        // When
        let result = try await workflowExecutor.executeWorkflow(workflow)
        
        // Then
        XCTAssertTrue(result.success)
        // The conditional step should be skipped
        XCTAssertEqual(result.stepResults.filter { $0.success }.count, 1)
    }
    
    func testWorkflowWithRetry() async throws {
        // Given
        let workflow = createWorkflowWithRetry()
        mockFileSystemService.shouldFailOnce = true
        
        // When
        let result = try await workflowExecutor.executeWorkflow(workflow)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stepResults.first?.retryCount, 1)
    }
    
    func testWorkflowVariableExpansion() async throws {
        // Given
        let workflow = createWorkflowWithVariables()
        
        // When
        let result = try await workflowExecutor.executeWorkflow(workflow)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.variables.keys.contains("test_variable"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestWorkflow() -> WorkflowDefinition {
        let steps = [
            WorkflowStep(
                name: "Test notification",
                type: .notification,
                parameters: [
                    "title": "Test",
                    "message": "This is a test notification"
                ]
            ),
            WorkflowStep(
                name: "Test delay",
                type: .delay,
                parameters: [
                    "duration": 0.1
                ]
            )
        ]
        
        return WorkflowDefinition(
            name: "Test Workflow",
            description: "A simple test workflow",
            steps: steps
        )
    }
    
    private func createWorkflowWithFailingStep() -> WorkflowDefinition {
        let steps = [
            WorkflowStep(
                name: "Failing file operation",
                type: .fileOperation,
                parameters: [
                    "operation": "invalid_operation"
                ],
                continueOnError: false
            )
        ]
        
        return WorkflowDefinition(
            name: "Failing Workflow",
            description: "A workflow that should fail",
            steps: steps
        )
    }
    
    private func createWorkflowWithCondition() -> WorkflowDefinition {
        let condition = WorkflowCondition(
            type: .equals,
            variable: "test_var",
            value: "expected_value"
        )
        
        let steps = [
            WorkflowStep(
                name: "Conditional step",
                type: .notification,
                parameters: [
                    "title": "Conditional",
                    "message": "This should be skipped"
                ],
                condition: condition
            ),
            WorkflowStep(
                name: "Always executed step",
                type: .notification,
                parameters: [
                    "title": "Always",
                    "message": "This should always execute"
                ]
            )
        ]
        
        return WorkflowDefinition(
            name: "Conditional Workflow",
            description: "A workflow with conditional steps",
            steps: steps
        )
    }
    
    private func createWorkflowWithRetry() -> WorkflowDefinition {
        let steps = [
            WorkflowStep(
                name: "Retryable file operation",
                type: .fileOperation,
                parameters: [
                    "operation": "copy",
                    "source": "/test/source.txt",
                    "destination": "/test/dest.txt"
                ],
                retryCount: 2
            )
        ]
        
        return WorkflowDefinition(
            name: "Retry Workflow",
            description: "A workflow with retry logic",
            steps: steps
        )
    }
    
    private func createWorkflowWithVariables() -> WorkflowDefinition {
        let steps = [
            WorkflowStep(
                name: "Set variable step",
                type: .textProcessing,
                parameters: [
                    "text": "Hello World",
                    "operation": "uppercase",
                    "outputVariable": "test_variable"
                ]
            )
        ]
        
        return WorkflowDefinition(
            name: "Variable Workflow",
            description: "A workflow that uses variables",
            steps: steps,
            variables: ["initial_var": AnyCodable("initial_value")]
        )
    }
}

// MARK: - Mock Services

class MockFileSystemService: FileSystemService {
    var shouldFailOnce = false
    private var hasFailedOnce = false
    
    override func executeOperation(_ operation: FileSystemService.FileOperation) async throws -> FileSystemService.OperationResult {
        if shouldFailOnce && !hasFailedOnce {
            hasFailedOnce = true
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
        
        return FileSystemService.OperationResult(
            success: true,
            processedFiles: [],
            errors: [],
            summary: "Mock operation completed",
            undoAction: nil
        )
    }
}

class MockAppIntegrationManager: AppIntegrationManager {
    override func executeCommand(_ command: String, targetApp: String?) async throws -> CommandResult {
        return CommandResult(
            success: true,
            output: "Mock command executed: \(command)",
            executionTime: 0.1,
            affectedResources: []
        )
    }
}

class MockSystemService: SystemService {
    override func handleQuery(_ query: String) async throws -> String {
        return "Mock system response for: \(query)"
    }
    
    override func isAppRunning(_ appName: String) async -> Bool {
        return appName == "TestApp"
    }
}

class MockTaskRouter: TaskRouter {
    override func routeTask(_ input: String) async throws -> TaskResult {
        return TaskResult(
            success: true,
            output: "Mock task result",
            executionTime: 0.1,
            affectedFiles: nil,
            undoAction: nil,
            followUpSuggestions: []
        )
    }
}