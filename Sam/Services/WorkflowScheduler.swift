//
//  WorkflowScheduler.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import Combine
import UserNotifications

@MainActor
class WorkflowScheduler: ObservableObject {
    @Published var scheduledWorkflows: [ScheduledWorkflow] = []
    @Published var activeTriggers: [ActiveTrigger] = []
    @Published var isMonitoring = false
    
    private let workflowExecutor: WorkflowExecutor
    private let fileSystemMonitor = FileSystemMonitor()
    private let systemEventMonitor = SystemEventMonitor()
    private let hotkeyManager = HotkeyManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]
    
    init(workflowExecutor: WorkflowExecutor = WorkflowExecutor()) {
        self.workflowExecutor = workflowExecutor
        setupMonitoring()
    }
    
    // MARK: - Public Methods
    
    func scheduleWorkflow(_ workflow: WorkflowDefinition) {
        for trigger in workflow.triggers where trigger.isEnabled {
            switch trigger.type {
            case .scheduled:
                scheduleTimedWorkflow(workflow, trigger: trigger)
            case .fileChanged:
                setupFileWatcher(workflow, trigger: trigger)
            case .appLaunched:
                setupAppLaunchWatcher(workflow, trigger: trigger)
            case .systemEvent:
                setupSystemEventWatcher(workflow, trigger: trigger)
            case .hotkey:
                setupHotkeyTrigger(workflow, trigger: trigger)
            case .webhook:
                setupWebhookTrigger(workflow, trigger: trigger)
            case .manual:
                // Manual triggers don't need scheduling
                break
            }
        }
    }
    
    func unscheduleWorkflow(_ workflowId: UUID) {
        // Cancel scheduled tasks
        scheduledTasks[workflowId]?.cancel()
        scheduledTasks.removeValue(forKey: workflowId)
        
        // Remove from scheduled workflows
        scheduledWorkflows.removeAll { $0.workflowId == workflowId }
        
        // Remove active triggers
        activeTriggers.removeAll { $0.workflowId == workflowId }
        
        // Clean up monitors
        fileSystemMonitor.removeWatchers(for: workflowId)
        systemEventMonitor.removeWatchers(for: workflowId)
        hotkeyManager.removeHotkeys(for: workflowId)
    }
    
    func executeWorkflowManually(_ workflow: WorkflowDefinition) async throws -> WorkflowExecutionResult {
        return try await workflowExecutor.executeWorkflow(workflow)
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        fileSystemMonitor.startMonitoring()
        systemEventMonitor.startMonitoring()
        hotkeyManager.startListening()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        fileSystemMonitor.stopMonitoring()
        systemEventMonitor.stopMonitoring()
        hotkeyManager.stopListening()
        
        // Cancel all scheduled tasks
        for task in scheduledTasks.values {
            task.cancel()
        }
        scheduledTasks.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // File system monitoring
        fileSystemMonitor.fileChangedPublisher
            .sink { [weak self] event in
                Task { @MainActor in
                    await self?.handleFileSystemEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // System event monitoring
        systemEventMonitor.eventPublisher
            .sink { [weak self] event in
                Task { @MainActor in
                    await self?.handleSystemEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // Hotkey monitoring
        hotkeyManager.hotkeyPressedPublisher
            .sink { [weak self] hotkeyId in
                Task { @MainActor in
                    await self?.handleHotkeyPressed(hotkeyId)
                }
            }
            .store(in: &cancellables)
    }
    
    private func scheduleTimedWorkflow(_ workflow: WorkflowDefinition, trigger: WorkflowTrigger) {
        guard let schedule = trigger.parameters["schedule"]?.value as? String else { return }
        
        let scheduledWorkflow = ScheduledWorkflow(
            id: UUID(),
            workflowId: workflow.id,
            workflowName: workflow.name,
            triggerId: trigger.id,
            schedule: schedule,
            nextExecution: calculateNextExecution(schedule),
            isEnabled: true
        )
        
        scheduledWorkflows.append(scheduledWorkflow)
        
        // Create scheduled task
        let task = Task {
            while !Task.isCancelled {
                let nextExecution = calculateNextExecution(schedule)
                let delay = nextExecution.timeIntervalSinceNow
                
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                if !Task.isCancelled {
                    do {
                        _ = try await workflowExecutor.executeWorkflow(workflow)
                        await logTriggerExecution(trigger.id, success: true)
                    } catch {
                        await logTriggerExecution(trigger.id, success: false, error: error)
                    }
                }
            }
        }
        
        scheduledTasks[workflow.id] = task
    }
    
    private func setupFileWatcher(_ workflow: WorkflowDefinition, trigger: WorkflowTrigger) {
        guard let path = trigger.parameters["path"]?.value as? String else { return }
        
        let activeTrigger = ActiveTrigger(
            id: UUID(),
            workflowId: workflow.id,
            workflowName: workflow.name,
            triggerId: trigger.id,
            type: trigger.type,
            parameters: trigger.parameters,
            isActive: true
        )
        
        activeTriggers.append(activeTrigger)
        fileSystemMonitor.addWatcher(for: workflow.id, path: path, trigger: trigger)
    }
    
    private func setupAppLaunchWatcher(_ workflow: WorkflowDefinition, trigger: WorkflowTrigger) {
        guard let appName = trigger.parameters["appName"]?.value as? String else { return }
        
        let activeTrigger = ActiveTrigger(
            id: UUID(),
            workflowId: workflow.id,
            workflowName: workflow.name,
            triggerId: trigger.id,
            type: trigger.type,
            parameters: trigger.parameters,
            isActive: true
        )
        
        activeTriggers.append(activeTrigger)
        systemEventMonitor.addAppLaunchWatcher(for: workflow.id, appName: appName, trigger: trigger)
    }
    
    private func setupSystemEventWatcher(_ workflow: WorkflowDefinition, trigger: WorkflowTrigger) {
        guard let eventType = trigger.parameters["eventType"]?.value as? String else { return }
        
        let activeTrigger = ActiveTrigger(
            id: UUID(),
            workflowId: workflow.id,
            workflowName: workflow.name,
            triggerId: trigger.id,
            type: trigger.type,
            parameters: trigger.parameters,
            isActive: true
        )
        
        activeTriggers.append(activeTrigger)
        systemEventMonitor.addEventWatcher(for: workflow.id, eventType: eventType, trigger: trigger)
    }
    
    private func setupHotkeyTrigger(_ workflow: WorkflowDefinition, trigger: WorkflowTrigger) {
        guard let keyCombo = trigger.parameters["keyCombo"]?.value as? String else { return }
        
        let activeTrigger = ActiveTrigger(
            id: UUID(),
            workflowId: workflow.id,
            workflowName: workflow.name,
            triggerId: trigger.id,
            type: trigger.type,
            parameters: trigger.parameters,
            isActive: true
        )
        
        activeTriggers.append(activeTrigger)
        hotkeyManager.registerHotkey(for: workflow.id, keyCombo: keyCombo, trigger: trigger)
    }
    
    private func setupWebhookTrigger(_ workflow: WorkflowDefinition, trigger: WorkflowTrigger) {
        // Webhook triggers would be handled by a separate web server component
        // For now, we'll just create an active trigger entry
        let activeTrigger = ActiveTrigger(
            id: UUID(),
            workflowId: workflow.id,
            workflowName: workflow.name,
            triggerId: trigger.id,
            type: trigger.type,
            parameters: trigger.parameters,
            isActive: true
        )
        
        activeTriggers.append(activeTrigger)
    }
    
    // MARK: - Event Handlers
    
    private func handleFileSystemEvent(_ event: FileSystemEvent) async {
        let matchingTriggers = activeTriggers.filter { trigger in
            trigger.type == .fileChanged &&
            trigger.parameters["path"]?.value as? String == event.path
        }
        
        for trigger in matchingTriggers {
            await executeTriggeredWorkflow(trigger.workflowId, triggerId: trigger.triggerId)
        }
    }
    
    private func handleSystemEvent(_ event: SystemEvent) async {
        let matchingTriggers = activeTriggers.filter { trigger in
            (trigger.type == .appLaunched && trigger.parameters["appName"]?.value as? String == event.appName) ||
            (trigger.type == .systemEvent && trigger.parameters["eventType"]?.value as? String == event.type)
        }
        
        for trigger in matchingTriggers {
            await executeTriggeredWorkflow(trigger.workflowId, triggerId: trigger.triggerId)
        }
    }
    
    private func handleHotkeyPressed(_ hotkeyId: UUID) async {
        let matchingTriggers = activeTriggers.filter { trigger in
            trigger.type == .hotkey && trigger.workflowId == hotkeyId
        }
        
        for trigger in matchingTriggers {
            await executeTriggeredWorkflow(trigger.workflowId, triggerId: trigger.triggerId)
        }
    }
    
    private func executeTriggeredWorkflow(_ workflowId: UUID, triggerId: UUID) async {
        // In a real implementation, we would load the workflow from storage
        // For now, we'll create a placeholder
        print("Executing workflow \(workflowId) triggered by \(triggerId)")
        
        await logTriggerExecution(triggerId, success: true)
    }
    
    private func logTriggerExecution(_ triggerId: UUID, success: Bool, error: Error? = nil) async {
        // Log trigger execution for monitoring and debugging
        let logEntry = TriggerExecutionLog(
            triggerId: triggerId,
            executionTime: Date(),
            success: success,
            error: error?.localizedDescription
        )
        
        print("Trigger execution: \(logEntry)")
    }
    
    private func calculateNextExecution(_ schedule: String) -> Date {
        // Parse cron-like schedule format
        // For now, return a simple future date
        return Date().addingTimeInterval(3600) // 1 hour from now
    }
}

// MARK: - Supporting Types

struct ScheduledWorkflow: Identifiable {
    let id: UUID
    let workflowId: UUID
    let workflowName: String
    let triggerId: UUID
    let schedule: String
    let nextExecution: Date
    let isEnabled: Bool
}

struct ActiveTrigger: Identifiable {
    let id: UUID
    let workflowId: UUID
    let workflowName: String
    let triggerId: UUID
    let type: WorkflowTrigger.TriggerType
    let parameters: [String: AnyCodable]
    let isActive: Bool
}

struct TriggerExecutionLog {
    let triggerId: UUID
    let executionTime: Date
    let success: Bool
    let error: String?
}

struct FileSystemEvent {
    let path: String
    let eventType: String
    let timestamp: Date
}

struct SystemEvent {
    let type: String
    let appName: String?
    let timestamp: Date
}

// MARK: - Monitor Classes (Placeholder implementations)

class FileSystemMonitor {
    let fileChangedPublisher = PassthroughSubject<FileSystemEvent, Never>()
    private var watchers: [UUID: String] = [:]
    
    func startMonitoring() {
        // Start file system monitoring
    }
    
    func stopMonitoring() {
        // Stop file system monitoring
    }
    
    func addWatcher(for workflowId: UUID, path: String, trigger: WorkflowTrigger) {
        watchers[workflowId] = path
    }
    
    func removeWatchers(for workflowId: UUID) {
        watchers.removeValue(forKey: workflowId)
    }
}

class SystemEventMonitor {
    let eventPublisher = PassthroughSubject<SystemEvent, Never>()
    private var appWatchers: [UUID: String] = [:]
    private var eventWatchers: [UUID: String] = [:]
    
    func startMonitoring() {
        // Start system event monitoring
    }
    
    func stopMonitoring() {
        // Stop system event monitoring
    }
    
    func addAppLaunchWatcher(for workflowId: UUID, appName: String, trigger: WorkflowTrigger) {
        appWatchers[workflowId] = appName
    }
    
    func addEventWatcher(for workflowId: UUID, eventType: String, trigger: WorkflowTrigger) {
        eventWatchers[workflowId] = eventType
    }
    
    func removeWatchers(for workflowId: UUID) {
        appWatchers.removeValue(forKey: workflowId)
        eventWatchers.removeValue(forKey: workflowId)
    }
}

class HotkeyManager {
    let hotkeyPressedPublisher = PassthroughSubject<UUID, Never>()
    private var hotkeys: [UUID: String] = [:]
    
    func startListening() {
        // Start hotkey listening
    }
    
    func stopListening() {
        // Stop hotkey listening
    }
    
    func registerHotkey(for workflowId: UUID, keyCombo: String, trigger: WorkflowTrigger) {
        hotkeys[workflowId] = keyCombo
    }
    
    func removeHotkeys(for workflowId: UUID) {
        hotkeys.removeValue(forKey: workflowId)
    }
}