//
//  test_workflow_compilation.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation

// Test compilation of workflow system components
@MainActor
func testWorkflowCompilation() async {
    print("🔧 Testing Workflow System Compilation")
    print("=====================================")
    
    // Test WorkflowModels
    print("✅ Testing WorkflowModels...")
    let step = WorkflowStep(
        name: "Test Step",
        type: .fileOperation,
        parameters: ["operation": "test"]
    )
    
    let condition = WorkflowCondition(
        type: .equals,
        variable: "test",
        value: "value"
    )
    
    let trigger = WorkflowTrigger(
        type: .manual,
        parameters: [:]
    )
    
    let workflow = WorkflowDefinition(
        name: "Test Workflow",
        description: "Test workflow for compilation",
        steps: [step],
        triggers: [trigger]
    )
    
    print("   Created workflow: \(workflow.name)")
    
    // Test WorkflowExecutor
    print("✅ Testing WorkflowExecutor...")
    let executor = WorkflowExecutor()
    print("   WorkflowExecutor initialized")
    
    // Test WorkflowScheduler
    print("✅ Testing WorkflowScheduler...")
    let scheduler = WorkflowScheduler()
    print("   WorkflowScheduler initialized")
    
    // Test WorkflowBuilder
    print("✅ Testing WorkflowBuilder...")
    let builder = WorkflowBuilder()
    print("   WorkflowBuilder initialized")
    
    // Test WorkflowManager
    print("✅ Testing WorkflowManager...")
    let manager = WorkflowManager()
    print("   WorkflowManager initialized")
    
    // Test workflow execution context
    print("✅ Testing WorkflowExecutionContext...")
    let context = WorkflowExecutionContext(workflowId: workflow.id)
    context.setVariable("test_var", value: "test_value")
    let retrievedValue = context.getVariable("test_var")
    print("   Variable set and retrieved: \(retrievedValue ?? "nil")")
    
    // Test workflow result
    print("✅ Testing WorkflowExecutionResult...")
    let stepResult = WorkflowStepResult(
        stepId: step.id,
        stepName: step.name,
        success: true,
        startTime: Date(),
        endTime: Date()
    )
    
    let workflowResult = WorkflowExecutionResult(
        executionId: UUID(),
        workflowId: workflow.id,
        success: true,
        startTime: Date(),
        endTime: Date(),
        duration: 1.0,
        completedSteps: 1,
        totalSteps: 1,
        error: nil,
        stepResults: [stepResult],
        variables: [:]
    )
    
    print("   WorkflowExecutionResult created: \(workflowResult.success)")
    
    // Test error types
    print("✅ Testing WorkflowError...")
    let error = WorkflowError.stepExecutionFailed(stepName: "test", error: NSError(domain: "test", code: -1))
    print("   WorkflowError created: \(error.localizedDescription)")
    
    // Test AnyCodable
    print("✅ Testing AnyCodable...")
    let codableValue = AnyCodable("test string")
    print("   AnyCodable created with value: \(codableValue.value)")
    
    print("\n🎉 All workflow components compiled successfully!")
}

// Run the test
Task { @MainActor in
    await testWorkflowCompilation()
}