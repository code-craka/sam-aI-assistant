//
//  WorkflowDemo.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation

@MainActor
class WorkflowDemo {
    private let workflowManager = WorkflowManager()
    
    func runDemo() async {
        print("🔄 Starting Workflow System Demo")
        print("================================")
        
        await demoBasicWorkflowCreation()
        await demoWorkflowFromDescription()
        await demoWorkflowExecution()
        await demoWorkflowScheduling()
        await demoWorkflowTemplates()
        
        print("\n✅ Workflow Demo Complete!")
    }
    
    // MARK: - Demo Methods
    
    private func demoBasicWorkflowCreation() async {
        print("\n📝 Demo 1: Basic Workflow Creation")
        print("----------------------------------")
        
        // Create a simple workflow manually
        let steps = [
            WorkflowStep(
                name: "Create backup folder",
                type: .fileOperation,
                parameters: [
                    "operation": "create_directory",
                    "path": "~/Desktop/Backup_\(Date().timeIntervalSince1970)"
                ]
            ),
            WorkflowStep(
                name: "Copy important files",
                type: .fileOperation,
                parameters: [
                    "operation": "copy",
                    "source": "~/Documents/Important",
                    "destination": "~/Desktop/Backup_\(Date().timeIntervalSince1970)/Important"
                ]
            ),
            WorkflowStep(
                name: "Send completion notification",
                type: .notification,
                parameters: [
                    "title": "Backup Complete",
                    "message": "Your important files have been backed up successfully"
                ]
            )
        ]
        
        let workflow = WorkflowDefinition(
            name: "Quick Backup",
            description: "Backup important files to Desktop",
            steps: steps,
            tags: ["backup", "files", "safety"]
        )
        
        do {
            try await workflowManager.saveWorkflow(workflow)
            print("✅ Created workflow: \(workflow.name)")
            print("   Steps: \(workflow.steps.count)")
            print("   Tags: \(workflow.tags.joined(separator: ", "))")
        } catch {
            print("❌ Failed to create workflow: \(error)")
        }
    }
    
    private func demoWorkflowFromDescription() async {
        print("\n🤖 Demo 2: Workflow from Natural Language")
        print("------------------------------------------")
        
        let description = """
        Every morning at 9 AM, clean up my Downloads folder by organizing files by type,
        then delete any files older than 30 days, and finally send me a notification
        with the cleanup summary.
        """
        
        do {
            let workflow = try await workflowManager.createWorkflowFromDescription(
                description,
                name: "Morning Cleanup"
            )
            
            print("✅ Created workflow from description:")
            print("   Name: \(workflow.name)")
            print("   Description: \(workflow.description)")
            print("   Steps: \(workflow.steps.count)")
            
            for (index, step) in workflow.steps.enumerated() {
                print("   \(index + 1). \(step.name) (\(step.type.rawValue))")
            }
        } catch {
            print("❌ Failed to create workflow from description: \(error)")
        }
    }
    
    private func demoWorkflowExecution() async {
        print("\n▶️ Demo 3: Workflow Execution")
        print("-----------------------------")
        
        // Create a simple test workflow
        let testSteps = [
            WorkflowStep(
                name: "Test notification",
                type: .notification,
                parameters: [
                    "title": "Workflow Test",
                    "message": "Testing workflow execution system"
                ]
            ),
            WorkflowStep(
                name: "Short delay",
                type: .delay,
                parameters: [
                    "duration": 1.0
                ]
            ),
            WorkflowStep(
                name: "Text processing test",
                type: .textProcessing,
                parameters: [
                    "text": "hello world",
                    "operation": "uppercase",
                    "outputVariable": "processed_text"
                ]
            )
        ]
        
        let testWorkflow = WorkflowDefinition(
            name: "Execution Test",
            description: "Test workflow execution",
            steps: testSteps
        )
        
        do {
            print("🚀 Executing test workflow...")
            let startTime = Date()
            
            let result = try await workflowManager.executeWorkflowManually(testWorkflow)
            
            let duration = Date().timeIntervalSince(startTime)
            
            print("✅ Workflow execution completed:")
            print("   Success: \(result.success)")
            print("   Duration: \(String(format: "%.2f", duration))s")
            print("   Completed Steps: \(result.completedSteps)/\(result.totalSteps)")
            print("   Variables: \(result.variables.keys.joined(separator: ", "))")
            
            if !result.stepResults.isEmpty {
                print("   Step Results:")
                for stepResult in result.stepResults {
                    let status = stepResult.success ? "✅" : "❌"
                    print("     \(status) \(stepResult.stepName) (\(String(format: "%.2f", stepResult.duration))s)")
                }
            }
        } catch {
            print("❌ Workflow execution failed: \(error)")
        }
    }
    
    private func demoWorkflowScheduling() async {
        print("\n⏰ Demo 4: Workflow Scheduling")
        print("------------------------------")
        
        // Create a workflow with triggers
        let triggers = [
            WorkflowTrigger(
                type: .scheduled,
                parameters: [
                    "schedule": "0 9 * * *" // Daily at 9 AM
                ]
            ),
            WorkflowTrigger(
                type: .fileChanged,
                parameters: [
                    "path": "~/Downloads"
                ]
            )
        ]
        
        let scheduledWorkflow = WorkflowDefinition(
            name: "Auto Organizer",
            description: "Automatically organize files when Downloads folder changes",
            steps: [
                WorkflowStep(
                    name: "Organize Downloads",
                    type: .fileOperation,
                    parameters: [
                        "operation": "organize",
                        "path": "~/Downloads",
                        "strategy": "by_type"
                    ]
                )
            ],
            triggers: triggers
        )
        
        do {
            try await workflowManager.saveWorkflow(scheduledWorkflow)
            try workflowManager.scheduleWorkflow(scheduledWorkflow.id)
            
            print("✅ Scheduled workflow: \(scheduledWorkflow.name)")
            print("   Triggers:")
            for trigger in triggers {
                print("     - \(trigger.type.rawValue)")
            }
            
            // Start monitoring
            workflowManager.startMonitoring()
            print("   Monitoring started")
            
        } catch {
            print("❌ Failed to schedule workflow: \(error)")
        }
    }
    
    private func demoWorkflowTemplates() async {
        print("\n📋 Demo 5: Workflow Templates")
        print("-----------------------------")
        
        // Use a built-in template
        let template = WorkflowManager.builtInTemplates.first!
        let parameters: [String: Any] = [
            "project_path": "~/Projects/MyApp",
            "backup_path": "/Volumes/Backup",
            "project_name": "MyApp",
            "date": DateFormatter().string(from: Date())
        ]
        
        do {
            let workflow = try await workflowManager.createWorkflowFromTemplate(template, parameters: parameters)
            
            print("✅ Created workflow from template:")
            print("   Template: \(template.name)")
            print("   Generated Name: \(workflow.name)")
            print("   Steps: \(workflow.steps.count)")
            
            // Show parameter expansion
            for step in workflow.steps {
                if let source = step.parameters["source"]?.value as? String {
                    print("   Expanded parameter: \(source)")
                    break
                }
            }
        } catch {
            print("❌ Failed to create workflow from template: \(error)")
        }
    }
}

// MARK: - Demo Runner

extension WorkflowDemo {
    static func runDemoIfNeeded() {
        #if DEBUG
        Task { @MainActor in
            let demo = WorkflowDemo()
            await demo.runDemo()
        }
        #endif
    }
}