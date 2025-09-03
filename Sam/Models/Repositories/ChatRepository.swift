import CoreData
import Foundation
import OSLog
import Combine

/// Repository for managing chat messages and conversations
class ChatRepository: ObservableObject {
    private let persistenceController: PersistenceController
    private let logger = Logger(subsystem: "com.sam.assistant", category: "ChatRepository")
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Conversation Management
    
    /// Create a new conversation
    func createConversation(title: String = "New Conversation") async throws -> Conversation {
        return try await persistenceController.performBackgroundTask { context in
            let conversation = Conversation.createConversation(title: title, in: context)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Created new conversation: \(conversation.id)")
            return conversation
        }
    }
    
    /// Get all conversations
    func getAllConversations() async throws -> [Conversation] {
        return try await persistenceController.performBackgroundTask { context in
            let request = Conversation.recentConversationsRequest(limit: 100)
            return try context.fetch(request)
        }
    }
    
    /// Get recent conversations
    func getRecentConversations(limit: Int = 20) async throws -> [Conversation] {
        return try await persistenceController.performBackgroundTask { context in
            let request = Conversation.recentConversationsRequest(limit: limit)
            return try context.fetch(request)
        }
    }
    
    /// Get active conversations (within last 24 hours)
    func getActiveConversations() async throws -> [Conversation] {
        return try await persistenceController.performBackgroundTask { context in
            let request = Conversation.activeConversationsRequest
            return try context.fetch(request)
        }
    }
    
    /// Search conversations by title
    func searchConversations(term: String) async throws -> [Conversation] {
        return try await persistenceController.performBackgroundTask { context in
            let request = Conversation.searchRequest(term: term)
            return try context.fetch(request)
        }
    }
    
    /// Get conversation by ID
    func getConversation(id: UUID) async throws -> Conversation? {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try context.fetch(request).first
        }
    }
    
    /// Update conversation
    func updateConversation(_ conversation: Conversation) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Refresh the object in this context
            let objectID = conversation.objectID
            guard let conversationInContext = try? context.existingObject(with: objectID) as? Conversation else {
                throw ChatRepositoryError.conversationNotFound
            }
            
            conversationInContext.updateStatistics()
            try self.persistenceController.saveBackground(context)
            self.logger.info("Updated conversation: \(conversationInContext.id)")
        }
    }
    
    /// Delete conversation
    func deleteConversation(_ conversation: Conversation) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = conversation.objectID
            guard let conversationInContext = try? context.existingObject(with: objectID) as? Conversation else {
                throw ChatRepositoryError.conversationNotFound
            }
            
            context.delete(conversationInContext)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Deleted conversation: \(conversation.id)")
        }
    }
    
    // MARK: - Message Management
    
    /// Add a user message to a conversation
    func addUserMessage(
        content: String,
        to conversation: Conversation
    ) async throws -> ChatMessage {
        return try await persistenceController.performBackgroundTask { context in
            let objectID = conversation.objectID
            guard let conversationInContext = try? context.existingObject(with: objectID) as? Conversation else {
                throw ChatRepositoryError.conversationNotFound
            }
            
            let message = ChatMessage.createUserMessage(
                content: content,
                in: context,
                conversation: conversationInContext
            )
            
            conversationInContext.addMessage(message)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Added user message to conversation: \(conversationInContext.id)")
            return message
        }
    }
    
    /// Add an assistant message to a conversation
    func addAssistantMessage(
        content: String,
        taskType: TaskType? = nil,
        taskResult: TaskResult? = nil,
        executionTime: TimeInterval = 0,
        tokens: Int = 0,
        cost: Double = 0,
        to conversation: Conversation
    ) async throws -> ChatMessage {
        return try await persistenceController.performBackgroundTask { context in
            let objectID = conversation.objectID
            guard let conversationInContext = try? context.existingObject(with: objectID) as? Conversation else {
                throw ChatRepositoryError.conversationNotFound
            }
            
            let message = ChatMessage.createAssistantMessage(
                content: content,
                taskType: taskType,
                taskResult: taskResult,
                executionTime: executionTime,
                tokens: tokens,
                cost: cost,
                in: context,
                conversation: conversationInContext
            )
            
            conversationInContext.addMessage(message)
            try self.persistenceController.saveBackground(context)
            self.logger.info("Added assistant message to conversation: \(conversationInContext.id)")
            return message
        }
    }
    
    /// Get messages for a conversation
    func getMessages(for conversation: Conversation) async throws -> [ChatMessage] {
        return try await persistenceController.performBackgroundTask { context in
            let objectID = conversation.objectID
            guard let conversationInContext = try? context.existingObject(with: objectID) as? Conversation else {
                throw ChatRepositoryError.conversationNotFound
            }
            
            return conversationInContext.sortedMessages
        }
    }
    
    /// Get recent messages across all conversations
    func getRecentMessages(limit: Int = 50) async throws -> [ChatMessage] {
        return try await persistenceController.performBackgroundTask { context in
            let request = ChatMessage.recentMessagesRequest(limit: limit)
            return try context.fetch(request)
        }
    }
    
    /// Get messages by task type
    func getMessages(taskType: TaskType) async throws -> [ChatMessage] {
        return try await persistenceController.performBackgroundTask { context in
            let request = ChatMessage.fetchRequest(taskType: taskType)
            return try context.fetch(request)
        }
    }
    
    /// Update message
    func updateMessage(_ message: ChatMessage) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = message.objectID
            guard let messageInContext = try? context.existingObject(with: objectID) as? ChatMessage else {
                throw ChatRepositoryError.messageNotFound
            }
            
            // Update conversation statistics if this message belongs to one
            messageInContext.conversation?.updateStatistics()
            
            try self.persistenceController.saveBackground(context)
            self.logger.info("Updated message: \(messageInContext.id)")
        }
    }
    
    /// Delete message
    func deleteMessage(_ message: ChatMessage) async throws {
        try await persistenceController.performBackgroundTask { context in
            let objectID = message.objectID
            guard let messageInContext = try? context.existingObject(with: objectID) as? ChatMessage else {
                throw ChatRepositoryError.messageNotFound
            }
            
            let conversation = messageInContext.conversation
            context.delete(messageInContext)
            
            // Update conversation statistics
            conversation?.updateStatistics()
            
            try self.persistenceController.saveBackground(context)
            self.logger.info("Deleted message: \(message.id)")
        }
    }
    
    /// Update message content by ID
    func updateMessage(_ messageId: UUID, content: String, in conversation: Conversation) async throws {
        try await persistenceController.performBackgroundTask { context in
            let conversationObjectID = conversation.objectID
            guard let conversationInContext = try? context.existingObject(with: conversationObjectID) as? Conversation else {
                throw ChatRepositoryError.conversationNotFound
            }
            
            // Find the message in the conversation
            guard let message = conversationInContext.sortedMessages.first(where: { $0.id == messageId }) else {
                throw ChatRepositoryError.messageNotFound
            }
            
            message.content = content
            
            try self.persistenceController.saveBackground(context)
            self.logger.info("Updated message content: \(messageId)")
        }
    }
    
    /// Delete message by ID
    func deleteMessage(_ messageId: UUID, in conversation: Conversation) async throws {
        try await persistenceController.performBackgroundTask { context in
            let conversationObjectID = conversation.objectID
            guard let conversationInContext = try? context.existingObject(with: conversationObjectID) as? Conversation else {
                throw ChatRepositoryError.conversationNotFound
            }
            
            // Find the message in the conversation
            guard let message = conversationInContext.sortedMessages.first(where: { $0.id == messageId }) else {
                throw ChatRepositoryError.messageNotFound
            }
            
            context.delete(message)
            conversationInContext.updateStatistics()
            
            try self.persistenceController.saveBackground(context)
            self.logger.info("Deleted message: \(messageId)")
        }
    }
    
    // MARK: - Statistics
    
    /// Get chat statistics
    func getChatStatistics() async throws -> ChatStatistics {
        return try await persistenceController.performBackgroundTask { context in
            // Total conversations
            let conversationRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            let totalConversations = try context.count(for: conversationRequest)
            
            // Total messages
            let messageRequest: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
            let totalMessages = try context.count(for: messageRequest)
            
            // Total tokens and cost
            let allMessages = try context.fetch(messageRequest)
            let totalTokens = allMessages.reduce(0) { $0 + Int($1.tokens) }
            let totalCost = allMessages.reduce(0) { $0 + $1.cost }
            
            // Average response time
            let assistantMessages = allMessages.filter { !$0.isUserMessage }
            let averageResponseTime = assistantMessages.isEmpty ? 0 :
                assistantMessages.reduce(0) { $0 + $1.executionTime } / Double(assistantMessages.count)
            
            // Task type distribution
            var taskTypeDistribution: [TaskType: Int] = [:]
            for message in assistantMessages {
                let taskType = message.taskTypeEnum
                taskTypeDistribution[taskType, default: 0] += 1
            }
            
            return ChatStatistics(
                totalConversations: totalConversations,
                totalMessages: totalMessages,
                totalTokens: totalTokens,
                totalCost: totalCost,
                averageResponseTime: averageResponseTime,
                taskTypeDistribution: taskTypeDistribution
            )
        }
    }
    
    // MARK: - Cleanup
    
    /// Delete old conversations based on user preferences
    func cleanupOldConversations() async throws {
        try await persistenceController.cleanupOldData()
    }
}

// MARK: - Chat Statistics
struct ChatStatistics {
    let totalConversations: Int
    let totalMessages: Int
    let totalTokens: Int
    let totalCost: Double
    let averageResponseTime: TimeInterval
    let taskTypeDistribution: [TaskType: Int]
    
    var formattedTotalCost: String {
        return String(format: "$%.4f", totalCost)
    }
    
    var formattedAverageResponseTime: String {
        return String(format: "%.2fs", averageResponseTime)
    }
}

// MARK: - Repository Errors
enum ChatRepositoryError: LocalizedError {
    case conversationNotFound
    case messageNotFound
    case invalidData
    case saveError(Error)
    
    var errorDescription: String? {
        switch self {
        case .conversationNotFound:
            return "Conversation not found"
        case .messageNotFound:
            return "Message not found"
        case .invalidData:
            return "Invalid data provided"
        case .saveError(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}