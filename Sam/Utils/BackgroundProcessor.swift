import Foundation
import os.log

/// Background processing system for long-running tasks
@MainActor
class BackgroundProcessor: ObservableObject {
    static let shared = BackgroundProcessor()
    
    // MARK: - Published Properties
    @Published var activeTasks: [BackgroundTask] = []
    @Published var completedTasks: [BackgroundTask] = []
    @Published var isProcessing = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.sam.performance", category: "background")
    private let performanceTracker = PerformanceTracker.shared
    private let taskQueue = DispatchQueue(label: "com.sam.background", qos: .utility)
    private var taskStorage: [String: BackgroundTask] = [:]
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Task Management
    
    /// Submit a task for background processing
    func submitTask<T>(
        id: String? = nil,
        name: String,
        priority: TaskPriority = .normal,
        operation: @escaping () async throws -> T
    ) -> BackgroundTask {
        let taskId = id ?? UUID().uuidString
        
        let task = BackgroundTask(
            id: taskId,
            name: name,
            priority: priority,
            status: .queued,
            createdAt: Date()
        )
        
        taskStorage[taskId] = task
        activeTasks.append(task)
        
        // Execute the task
        Task {
            await executeTask(taskId, operation: operation)
        }
        
        logger.info("Submitted background task: \(name) with ID: \(taskId)")
        return task
    }
    
    /// Execute a background task
    private func executeTask<T>(_ taskId: String, operation: @escaping () async throws -> T) async {
        guard let task = taskStorage[taskId] else { return }
        
        await updateTaskStatus(taskId, status: .running)
        
        let operationId = "bg_task_\(taskId)"
        
        do {
            let result = try await performanceTracker.trackOperation(operationId, type: .backgroundTask) {
                return try await operation()
            }
            
            await completeTask(taskId, result: .success(result))
            
        } catch {
            await completeTask(taskId, result: .failure(error))
        }
    }
    
    /// Update task status
    private func updateTaskStatus(_ taskId: String, status: TaskStatus) async {
        guard var task = taskStorage[taskId] else { return }
        
        task.status = status
        task.updatedAt = Date()
        
        if status == .running {
            task.startedAt = Date()
        }
        
        taskStorage[taskId] = task
        
        // Update UI arrays
        if let index = activeTasks.firstIndex(where: { $0.id == taskId }) {
            activeTasks[index] = task
        }
    }
    
    /// Complete a task
    private func completeTask<T>(_ taskId: String, result: Result<T, Error>) async {
        guard var task = taskStorage[taskId] else { return }
        
        task.completedAt = Date()
        task.updatedAt = Date()
        
        switch result {
        case .success(let value):
            task.status = .completed
            task.result = value
            logger.info("Background task completed successfully: \(task.name)")
            
        case .failure(let error):
            task.status = .failed
            task.error = error
            logger.error("Background task failed: \(task.name) - \(error.localizedDescription)")
        }
        
        taskStorage[taskId] = task
        
        // Move from active to completed
        activeTasks.removeAll { $0.id == taskId }
        completedTasks.append(task)
        
        // Limit completed tasks history
        if completedTasks.count > 50 {
            completedTasks = Array(completedTasks.suffix(50))
        }
        
        // Post completion notification
        NotificationCenter.default.post(
            name: .backgroundTaskCompleted,
            object: task
        )
    }
    
    /// Cancel a background task
    func cancelTask(_ taskId: String) async {
        guard let task = taskStorage[taskId] else { return }
        
        if task.status == .running || task.status == .queued {
            await updateTaskStatus(taskId, status: .cancelled)
            activeTasks.removeAll { $0.id == taskId }
            completedTasks.append(task)
            
            logger.info("Cancelled background task: \(task.name)")
        }
    }
    
    /// Get task by ID
    func getTask(_ taskId: String) -> BackgroundTask? {
        return taskStorage[taskId]
    }
    
    /// Get tasks by status
    func getTasks(with status: TaskStatus) -> [BackgroundTask] {
        return Array(taskStorage.values.filter { $0.status == status })
    }
    
    // MARK: - Batch Operations
    
    /// Submit multiple related tasks
    func submitBatchTasks<T>(
        name: String,
        tasks: [(String, () async throws -> T)],
        priority: TaskPriority = .normal
    ) -> [BackgroundTask] {
        let batchId = UUID().uuidString
        var submittedTasks: [BackgroundTask] = []
        
        for (taskName, operation) in tasks {
            let taskId = "\(batchId)_\(submittedTasks.count)"
            let task = submitTask(
                id: taskId,
                name: "\(name) - \(taskName)",
                priority: priority,
                operation: operation
            )
            submittedTasks.append(task)
        }
        
        logger.info("Submitted batch of \(tasks.count) tasks: \(name)")
        return submittedTasks
    }
    
    // MARK: - Resource Management
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .memoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() async {
        logger.warning("Memory warning received, cleaning up background tasks")
        
        // Cancel low priority queued tasks
        let lowPriorityTasks = activeTasks.filter { 
            $0.priority == .low && $0.status == .queued 
        }
        
        for task in lowPriorityTasks {
            await cancelTask(task.id)
        }
        
        // Clear old completed tasks
        if completedTasks.count > 20 {
            completedTasks = Array(completedTasks.suffix(20))
        }
    }
    
    // MARK: - Statistics
    
    func getProcessingStatistics() -> ProcessingStatistics {
        let allTasks = Array(taskStorage.values)
        
        return ProcessingStatistics(
            totalTasks: allTasks.count,
            activeTasks: activeTasks.count,
            completedTasks: completedTasks.filter { $0.status == .completed }.count,
            failedTasks: completedTasks.filter { $0.status == .failed }.count,
            cancelledTasks: completedTasks.filter { $0.status == .cancelled }.count,
            averageExecutionTime: calculateAverageExecutionTime(),
            tasksByPriority: getTasksByPriority()
        )
    }
    
    private func calculateAverageExecutionTime() -> TimeInterval {
        let completedTasks = Array(taskStorage.values).filter { 
            $0.status == .completed && $0.startedAt != nil && $0.completedAt != nil 
        }
        
        guard !completedTasks.isEmpty else { return 0 }
        
        let totalTime = completedTasks.compactMap { task in
            guard let start = task.startedAt, let end = task.completedAt else { return nil }
            return end.timeIntervalSince(start)
        }.reduce(0, +)
        
        return totalTime / Double(completedTasks.count)
    }
    
    private func getTasksByPriority() -> [TaskPriority: Int] {
        var counts: [TaskPriority: Int] = [:]
        for task in taskStorage.values {
            counts[task.priority, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Supporting Types

struct BackgroundTask: Identifiable, Equatable {
    let id: String
    let name: String
    let priority: TaskPriority
    var status: TaskStatus
    let createdAt: Date
    var updatedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var result: Any?
    var error: Error?
    
    init(id: String, name: String, priority: TaskPriority, status: TaskStatus, createdAt: Date) {
        self.id = id
        self.name = name
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
    
    static func == (lhs: BackgroundTask, rhs: BackgroundTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    var duration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }
    
    var isActive: Bool {
        return status == .queued || status == .running
    }
}

enum TaskStatus: String, CaseIterable {
    case queued = "queued"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

enum TaskPriority: String, CaseIterable, Comparable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        let order: [TaskPriority] = [.low, .normal, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

struct ProcessingStatistics {
    let totalTasks: Int
    let activeTasks: Int
    let completedTasks: Int
    let failedTasks: Int
    let cancelledTasks: Int
    let averageExecutionTime: TimeInterval
    let tasksByPriority: [TaskPriority: Int]
}

// MARK: - Notifications

extension Notification.Name {
    static let backgroundTaskCompleted = Notification.Name("com.sam.backgroundTaskCompleted")
    static let backgroundTaskFailed = Notification.Name("com.sam.backgroundTaskFailed")
}