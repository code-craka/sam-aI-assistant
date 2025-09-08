import Foundation
import SwiftUI

// Workflow Automation Demo for Sam macOS AI Assistant
// This demonstrates the complete workflow system implementation

@MainActor
class WorkflowDemo {
    private let workflowManager = WorkflowManager()

    func runDemo() async {
        print("🚀 Starting Workflow Automation Demo")
        print("====================================")

        do {
            // 1. Create a workflow from natural language description
            print("\n📝 Creating workflow from description...")
            let workflow = try await workflowManager.createWorkflow(from: """
                Create a daily cleanup workflow that:
                1. Organizes the Downloads folder
                2. Empties the trash
                3. Shows a completion notification
            """)

            print("✅ Workflow created: \(workflow.name)")
            print("   Steps: \(workflow.steps.count)")
            print("   Estimated duration: \(workflow.estimatedDuration)s")

            // 2. Add an additional step
            print("\n➕ Adding additional step...")
            let updatedWorkflow = try await workflowManager.addStepToWorkflow(
                workflow,
                stepDescription: "Wait 5 seconds before showing notification"
            )

            print("✅ Step added successfully")
            print("   Total steps: \(updatedWorkflow.steps.count)")

            // 3. Validate the workflow
            print("\n🔍 Validating workflow...")
            let validationErrors = workflowManager.validateWorkflow(updatedWorkflow)

            if validationErrors.isEmpty {
                print("✅ Workflow validation passed")
            } else {
                print("⚠️  Validation errors found:")
                for error in validationErrors {
                    print("   - \(error.localizedDescription)")
                }
            }

            // 4. Schedule the workflow
            print("\n⏰ Scheduling workflow...")
            let schedule = RecurringSchedule(
                frequency: .days,
                interval: 1, // Daily
                startDate: Date(),
                endDate: nil,
                daysOfWeek: nil,
                daysOfMonth: nil
            )
            
            let trigger = WorkflowTrigger.recurring(schedule)
            
            try workflowManager.scheduleWorkflow(updatedWorkflow, trigger: trigger)
            print("✅ Workflow scheduled for daily execution")            // 5. Execute the workflow
            print("\n▶️  Executing workflow...")
            try await workflowManager.executeWorkflow(updatedWorkflow)
            print("✅ Workflow execution completed")

            print("\n🎉 Demo completed successfully!")
            print("   - Workflow created from natural language")
            print("   - Steps added dynamically")
            print("   - Validation performed")
            print("   - Scheduling configured")
            print("   - Execution completed")

        } catch {
            print("❌ Demo failed: \(error.localizedDescription)")
        }
    }
}

// Run the demo
let demo = WorkflowDemo()
Task {
    await demo.runDemo()
}
