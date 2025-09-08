import Foundation
import CoreData

// MARK: - Core Data Entity Stubs
// These are minimal stubs to resolve compilation errors
// In a real implementation, these would be generated from Core Data model

class Conversation: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var createdAt: Date
    @NSManaged var lastMessageAt: Date
    @NSManaged var messageCount: Int32
    @NSManaged var totalTokens: Int32
    @NSManaged var totalCost: Double
    @NSManaged var messages: NSSet?
    
    var sortedMessages: [ChatMessage] {
        let messageArray = messages?.allObjects as? [ChatMessage] ?? []
        return messageArray.sorted { $0.timestamp < $1.timestamp }
    }
    
    func addMessage(_ message: ChatMessage) {
        let messages = self.mutableSetValue(forKey: "messages")
        messages.add(message)
        updateStatistics()
    }
    
    func updateStatistics() {
        messageCount = Int32(sortedMessages.count)
        totalTokens = Int32(sortedMessages.reduce(0) { $0 + Int($1.tokens) })
        totalCost = sortedMessages.reduce(0) { $0 + $1.cost }
        if let lastMessage = sortedMessages.last {
            lastMessageAt = lastMessage.timestamp
        }
    }
    
    static func createConversation(title: String, in context: NSManagedObjectContext) -> Conversation {
        let conversation = Conversation(context: context)
        conversation.id = UUID()
        conversation.title = title
        conversation.createdAt = Date()
        conversation.lastMessageAt = Date()
        conversation.messageCount = 0
        conversation.totalTokens = 0
        conversation.totalCost = 0
        return conversation
    }
    
    static func recentConversationsRequest(limit: Int) -> NSFetchRequest<Conversation> {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    static var activeConversationsRequest: NSFetchRequest<Conversation> {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        let dayAgo = Date().addingTimeInterval(-86400)
        request.predicate = NSPredicate(format: "lastMessageAt >= %@", dayAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)]
        return request
    }
    
    static func searchRequest(term: String) -> NSFetchRequest<Conversation> {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", term)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)]
        return request
    }
}

class ChatMessage: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var content: String
    @NSManaged var timestamp: Date
    @NSManaged var isUserMessage: Bool
    @NSManaged var taskType: String?
    @NSManaged var taskResultData: Data?
    @NSManaged var executionTime: TimeInterval
    @NSManaged var tokens: Int32
    @NSManaged var cost: Double
    @NSManaged var conversation: Conversation?
    
    var taskTypeEnum: TaskType {
        guard let taskType = taskType else { return .unknown }
        return TaskType(rawValue: taskType) ?? .unknown
    }
    
    var parsedTaskResult: TaskResult? {
        guard let data = taskResultData else { return nil }
        return try? JSONDecoder().decode(TaskResult.self, from: data)
    }
    
    static func createUserMessage(
        content: String,
        in context: NSManagedObjectContext,
        conversation: Conversation
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
    
    static func createAssistantMessage(
        content: String,
        taskType: TaskType? = nil,
        taskResult: TaskResult? = nil,
        executionTime: TimeInterval = 0,
        tokens: Int = 0,
        cost: Double = 0,
        in context: NSManagedObjectContext,
        conversation: Conversation
    ) -> ChatMessage {
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = content
        message.timestamp = Date()
        message.isUserMessage = false
        message.taskType = taskType?.rawValue
        message.executionTime = executionTime
        message.tokens = Int32(tokens)
        message.cost = cost
        message.conversation = conversation
        
        if let taskResult = taskResult {
            message.taskResultData = try? JSONEncoder().encode(taskResult)
        }
        
        return message
    }
    
    static func recentMessagesRequest(limit: Int) -> NSFetchRequest<ChatMessage> {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    static func fetchRequest(taskType: TaskType) -> NSFetchRequest<ChatMessage> {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "taskType == %@", taskType.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        return request
    }
}

// MARK: - Persistence Controller Stub
class PersistenceController {
    static let shared = PersistenceController()
    
    private init() {}
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        // Stub implementation
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func saveBackground(_ context: NSManagedObjectContext) throws {
        // Stub implementation
        if context.hasChanges {
            try context.save()
        }
    }
    
    func cleanupOldData() async throws {
        // Stub implementation
    }
}