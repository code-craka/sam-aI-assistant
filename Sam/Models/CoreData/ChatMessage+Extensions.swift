import CoreData
import Foundation

// MARK: - ChatMessage Extensions
extension ChatMessage {
    
    /// Computed property for task type enum
    var taskTypeEnum: TaskType {
        get {
            guard let taskType = taskType else { return .unknown }
            return TaskType(rawValue: taskType) ?? .unknown
        }
        set {
            taskType = newValue.rawValue
        }
    }
    
    /// Computed property for parsed task result
    var parsedTaskResult: TaskResult? {
        get {
            guard let taskResult = taskResult,
                  let data = taskResult.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(TaskResult.self, from: data)
        }
        set {
            if let result = newValue,
               let data = try? JSONEncoder().encode(result) {
                taskResult = String(data: data, encoding: .utf8)
            } else {
                taskResult = nil
            }
        }
    }
    
    /// Formatted timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Formatted cost for display
    var formattedCost: String {
        return String(format: "$%.4f", cost)
    }
    
    /// Check if message is recent (within last 5 minutes)
    var isRecent: Bool {
        return timestamp.timeIntervalSinceNow > -300
    }
    
    /// Message preview (first 100 characters)
    var preview: String {
        return String(content.prefix(100))
    }
    
    /// Validation before saving
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateMessage()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateMessage()
    }
    
    private func validateMessage() throws {
        // Validate content is not empty
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyContent
        }
        
        // Validate cost is not negative
        if cost < 0 {
            throw ValidationError.negativeCost
        }
        
        // Validate execution time is not negative
        if executionTime < 0 {
            throw ValidationError.negativeExecutionTime
        }
        
        // Validate tokens is not negative
        if tokens < 0 {
            throw ValidationError.negativeTokens
        }
    }
}

// MARK: - Fetch Requests
extension ChatMessage {
    
    /// Fetch request for messages in a specific conversation
    static func fetchRequest(for conversation: Conversation) -> NSFetchRequest<ChatMessage> {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "conversation == %@", conversation)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: true)]
        return request
    }
    
    /// Fetch request for recent messages
    static func recentMessagesRequest(limit: Int = 50) -> NSFetchRequest<ChatMessage> {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    /// Fetch request for messages by task type
    static func fetchRequest(taskType: TaskType) -> NSFetchRequest<ChatMessage> {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "taskType == %@", taskType.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        return request
    }
    
    /// Fetch request for user messages only
    static var userMessagesRequest: NSFetchRequest<ChatMessage> {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "isUserMessage == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        return request
    }
    
    /// Fetch request for assistant messages only
    static var assistantMessagesRequest: NSFetchRequest<ChatMessage> {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "isUserMessage == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        return request
    }
}

// MARK: - Convenience Initializers
extension ChatMessage {
    
    /// Create a user message
    static func createUserMessage(
        content: String,
        in context: NSManagedObjectContext,
        conversation: Conversation? = nil
    ) -> ChatMessage {
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = content
        message.timestamp = Date()
        message.isUserMessage = true
        message.executionTime = 0
        message.tokens = 0
        message.cost = 0
        message.conversation = conversation
        return message
    }
    
    /// Create an assistant message
    static func createAssistantMessage(
        content: String,
        taskType: TaskType? = nil,
        taskResult: TaskResult? = nil,
        executionTime: TimeInterval = 0,
        tokens: Int = 0,
        cost: Double = 0,
        in context: NSManagedObjectContext,
        conversation: Conversation? = nil
    ) -> ChatMessage {
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = content
        message.timestamp = Date()
        message.isUserMessage = false
        message.taskTypeEnum = taskType ?? .unknown
        message.parsedTaskResult = taskResult
        message.executionTime = executionTime
        message.tokens = Int32(tokens)
        message.cost = cost
        message.conversation = conversation
        return message
    }
}

// MARK: - Validation Errors
enum ValidationError: LocalizedError {
    case emptyContent
    case negativeCost
    case negativeExecutionTime
    case negativeTokens
    
    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Message content cannot be empty"
        case .negativeCost:
            return "Cost cannot be negative"
        case .negativeExecutionTime:
            return "Execution time cannot be negative"
        case .negativeTokens:
            return "Token count cannot be negative"
        }
    }
}