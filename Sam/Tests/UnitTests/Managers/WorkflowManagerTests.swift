import XCTest
import Combine
@testable import Sam

@MainActor
final class WorkflowManagerTests: XCTestCase {
    var workflowManager: WorkflowManager!
    var mockWorkflowExecutor: MockWorkflowExecutor!
    var mockWorkflowBuilder: MockWorkflowBuilder!
    var mockRepository: MockWorkflowRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockWorkflowExecutor = MockWorkflowExecutor()
        mockWorkflowBuilder = MockWorkflowBuilder()
        mockRepository = MockWorkflowRepository()
        workflowManager = WorkflowManager(
            executor: mockWorkflowExecutor,
            builder: mockWorkflowBuilder,
            repository: mockRepository
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        workflowManager = nil
        mockWorkflowExecutor = nil
        mockWorkflowBuilder = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Workflow Creation Tests
    
    func testCreateWorkflowFromDescription() async throws {
        // Given
        let description = "Copy all PDF files from Downloads to Documents, then organize by date"
        let expectedWorkflow = Workflow(
            id: UUID(),
            name: "Organize PDFs",
            description: description,
            steps: [
                WorkflowStep(id: UUID(), type: .fileOperation, parameters: ["action": "copy"], continueOnError: false, retryCount: 0),
                WorkflowStep(id: UUID(), type: .fileOperation, parameters: ["action": "organize"], continueOnError: false, retryCount: 0)
            ],
            createdAt: Date(),
            lastExecuted: nil,
            executionCount: 0,
            isEnabled: true
        )
        mockWorkflowBuilder.mockWorkflow = expectedWorkflow
        
        // When
        let workflow = try await workflowManager.createWorkflow(from: description)
        
        // Then
        XCTAssertEqual(workflow.name, "Organize PDFs")
        XCTAssertEqual(workflow.steps.count, 2)
        XCTAssertTrue(mockWorkflowBuilder.buildFromDescriptionCalled)
        XCTAssertTrue(mockRepository.saveWorkflowCalled)
    }
    
    func testCreateWorkflowWithSteps() async throws {
        // Given
        let steps = [
            WorkflowStep(id: UUID(), type: .fileOperation, parameters: ["action": "copy"], continueOnError: false, retryCount: 0),
            WorkflowStep(id: UUID(), type: .systemCommand, parameters: ["command": "cleanup"], continueOnError: true, retryCount: 1)
        ]
        
        // When
        let workflow = try await workflowManager.createWorkflow(
            name: "Test Workflow",
            description: "Test workflow description",
            steps: steps
        )
        
        // Then
        XCTAssertEqual(workflow.name, "Test Workflow")
        XCTAssertEqual(workflow.steps.count, 2)
        XCTAssertTrue(workflow.isEnabled)
        XCTAssertTrue(mockRepository.saveWorkflowCalled)
    }
    
    // MARK: - Workflow Execution Tests
    
    func testExecuteWorkflow() async throws {
        // Given
        let workflow = createTestWorkflow()
        mockWorkflowExecutor.mockResult = WorkflowExecutionResult(
            workflowId: workflow.id,
            success: true,
            executedSteps: 2,
            totalSteps: 2,
            executionTime: 1.5,
            results: ["Step 1 completed", "Step 2 completed"],
            errors: []
        )
        
        var executionUpdates: [WorkflowExecutionUpdate] = []
        workflowManager.executionUpdates
            .sink { update in
                executionUpdates.append(update)
            }
            .store(in: &cancellables)
        
        // When
        let result = try await workflowManager.executeWorkflow(workflow)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.executedSteps, 2)
        XCTAssertTrue(mockWorkflowExecutor.executeWorkflowCalled)
        XCTAssertTrue(mockRepository.updateWorkflowCalled)
        XCTAssertFalse(executionUpdates.isEmpty)
    }
    
    func testExecuteWorkflowWithErrors() async throws {
        // Given
        let workflow = createTestWorkflow()
        mockWorkflowExecutor.mockResult = WorkflowExecutionResult(
            workflowId: workflow.id,
            success: false,
            executedSteps: 1,
            totalSteps: 2,
            executionTime: 0.8,
            results: ["Step 1 completed"],
            errors: [WorkflowError.stepExecutionFailed("Step 2 failed")]
        )
        
        // When
        let result = try await workflowManager.executeWorkflow(workflow)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.executedSteps, 1)
        XCTAssertEqual(result.errors.count, 1)
    }
    
    func testCancelWorkflowExecution() async throws {
        // Given
        let workflow = createTestWorkflow()
        mockWorkflowExecutor.shouldDelay = true
        
        // When
        let executionTask = Task {
            try await workflowManager.executeWorkflow(workflow)
        }
        
        // Small delay to let execution start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        workflowManager.cancelExecution(workflow.id)
        
        // Then
        do {
            _ = try await executionTask.value
            XCTFail("Expected execution to be cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError || error is WorkflowError)
        }
    }
    
    // MARK: - Workflow Management Tests
    
    func testLoadWorkflows() async throws {
        // Given
        let mockWorkflows = [
            createTestWorkflow(name: "Workflow 1"),
            createTestWorkflow(name: "Workflow 2"),
            createTestWorkflow(name: "Workflow 3")
        ]
        mockRepository.mockWorkflows = mockWorkflows
        
        // When
        let workflows = try await workflowManager.loadWorkflows()
        
        // Then
        XCTAssertEqual(workflows.count, 3)
        XCTAssertTrue(mockRepository.loadWorkflowsCalled)
    }
    
    func testUpdateWorkflow() async throws {
        // Given
        var workflow = createTestWorkflow()
        workflow.name = "Updated Workflow"
        workflow.description = "Updated description"
        
        // When
        try await workflowManager.updateWorkflow(workflow)
        
        // Then
        XCTAssertTrue(mockRepository.updateWorkflowCalled)
        XCTAssertEqual(mockRepository.lastUpdatedWorkflow?.name, "Updated Workflow")
    }
    
    func testDeleteWorkflow() async throws {
        // Given
        let workflow = createTestWorkflow()
        
        // When
        try await workflowManager.deleteWorkflow(workflow.id)
        
        // Then
        XCTAssertTrue(mockRepository.deleteWorkflowCalled)
        XCTAssertEqual(mockRepository.lastDeletedWorkflowId, workflow.id)
    }
    
    // MARK: - Workflow Validation Tests
    
    func testValidateWorkflow() async throws {
        // Given
        let validWorkflow = createTestWorkflow()
        let invalidWorkflow = Workflow(
            id: UUID(),
            name: "", // Invalid: empty name
            description: "Test",
            steps: [], // Invalid: no steps
            createdAt: Date(),
            lastExecuted: nil,
            executionCount: 0,
            isEnabled: true
        )
        
        // When & Then
        XCTAssertNoThrow(try workflowManager.validateWorkflow(validWorkflow))
        XCTAssertThrowsError(try workflowManager.validateWorkflow(invalidWorkflow))
    }
    
    func testValidateWorkflowSteps() async throws {
        // Given
        let validStep = WorkflowStep(
            id: UUID(),
            type: .fileOperation,
            parameters: ["action": "copy", "source": "/path/to/file"],
            continueOnError: false,
            retryCount: 0
        )
        
        let invalidStep = WorkflowStep(
            id: UUID(),
            type: .fileOperation,
            parameters: [:], // Invalid: missing required parameters
            continueOnError: false,
            retryCount: 0
        )
        
        // When & Then
        XCTAssertNoThrow(try workflowManager.validateStep(validStep))
        XCTAssertThrowsError(try workflowManager.validateStep(invalidStep))
    }
    
    // MARK: - Workflow Scheduling Tests
    
    func testScheduleWorkflow() async throws {
        // Given
        let workflow = createTestWorkflow()
        let schedule = WorkflowSchedule(
            workflowId: workflow.id,
            type: .daily,
            time: DateComponents(hour: 9, minute: 0),
            isEnabled: true
        )
        
        // When
        try await workflowManager.scheduleWorkflow(workflow.id, schedule: schedule)
        
        // Then
        XCTAssertTrue(mockRepository.saveScheduleCalled)
        XCTAssertEqual(mockRepository.lastSavedSchedule?.workflowId, workflow.id)
    }
    
    func testUnscheduleWorkflow() async throws {
        // Given
        let workflow = createTestWorkflow()
        
        // When
        try await workflowManager.unscheduleWorkflow(workflow.id)
        
        // Then
        XCTAssertTrue(mockRepository.deleteScheduleCalled)
        XCTAssertEqual(mockRepository.lastDeletedScheduleWorkflowId, workflow.id)
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentWorkflowExecution() async throws {
        // Given
        let workflows = (1...5).map { createTestWorkflow(name: "Workflow \($0)") }
        mockWorkflowExecutor.mockResult = WorkflowExecutionResult(
            workflowId: UUID(),
            success: true,
            executedSteps: 1,
            totalSteps: 1,
            executionTime: 0.5,
            results: ["Completed"],
            errors: []
        )
        
        // When
        let startTime = Date()
        let results = try await withThrowingTaskGroup(of: WorkflowExecutionResult.self) { group in
            for workflow in workflows {
                group.addTask {
                    try await self.workflowManager.executeWorkflow(workflow)
                }
            }
            
            var results: [WorkflowExecutionResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0.success })
        XCTAssertLessThan(executionTime, 5.0, "Concurrent workflow execution took too long")
    }
    
    func testWorkflowExecutionPerformance() async throws {
        // Given
        let workflow = createTestWorkflow()
        
        // When & Then
        await measureAsync {
            _ = try? await self.workflowManager.executeWorkflow(workflow)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestWorkflow(name: String = "Test Workflow") -> Workflow {
        return Workflow(
            id: UUID(),
            name: name,
            description: "Test workflow description",
            steps: [
                WorkflowStep(id: UUID(), type: .fileOperation, parameters: ["action": "copy"], continueOnError: false, retryCount: 0),
                WorkflowStep(id: UUID(), type: .systemCommand, parameters: ["command": "cleanup"], continueOnError: true, retryCount: 1)
            ],
            createdAt: Date(),
            lastExecuted: nil,
            executionCount: 0,
            isEnabled: true
        )
    }
}

// MARK: - Mock Classes

class MockWorkflowExecutor: WorkflowExecutorProtocol {
    var mockResult: WorkflowExecutionResult?
    var shouldDelay = false
    var executeWorkflowCalled = false
    
    func executeWorkflow(_ workflow: Workflow) async throws -> WorkflowExecutionResult {
        executeWorkflowCalled = true
        
        if shouldDelay {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        return mockResult ?? WorkflowExecutionResult(
            workflowId: workflow.id,
            success: true,
            executedSteps: workflow.steps.count,
            totalSteps: workflow.steps.count,
            executionTime: 1.0,
            results: ["Mock execution completed"],
            errors: []
        )
    }
    
    func cancelExecution(_ workflowId: UUID) {
        // Mock cancellation
    }
}

class MockWorkflowBuilder: WorkflowBuilderProtocol {
    var mockWorkflow: Workflow?
    var buildFromDescriptionCalled = false
    
    func buildWorkflow(from description: String) async throws -> Workflow {
        buildFromDescriptionCalled = true
        return mockWorkflow ?? Workflow(
            id: UUID(),
            name: "Mock Workflow",
            description: description,
            steps: [],
            createdAt: Date(),
            lastExecuted: nil,
            executionCount: 0,
            isEnabled: true
        )
    }
}

class MockWorkflowRepository: WorkflowRepositoryProtocol {
    var mockWorkflows: [Workflow] = []
    var saveWorkflowCalled = false
    var loadWorkflowsCalled = false
    var updateWorkflowCalled = false
    var deleteWorkflowCalled = false
    var saveScheduleCalled = false
    var deleteScheduleCalled = false
    
    var lastUpdatedWorkflow: Workflow?
    var lastDeletedWorkflowId: UUID?
    var lastSavedSchedule: WorkflowSchedule?
    var lastDeletedScheduleWorkflowId: UUID?
    
    func saveWorkflow(_ workflow: Workflow) async throws {
        saveWorkflowCalled = true
        mockWorkflows.append(workflow)
    }
    
    func loadWorkflows() async throws -> [Workflow] {
        loadWorkflowsCalled = true
        return mockWorkflows
    }
    
    func updateWorkflow(_ workflow: Workflow) async throws {
        updateWorkflowCalled = true
        lastUpdatedWorkflow = workflow
    }
    
    func deleteWorkflow(_ id: UUID) async throws {
        deleteWorkflowCalled = true
        lastDeletedWorkflowId = id
        mockWorkflows.removeAll { $0.id == id }
    }
    
    func saveSchedule(_ schedule: WorkflowSchedule) async throws {
        saveScheduleCalled = true
        lastSavedSchedule = schedule
    }
    
    func deleteSchedule(for workflowId: UUID) async throws {
        deleteScheduleCalled = true
        lastDeletedScheduleWorkflowId = workflowId
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