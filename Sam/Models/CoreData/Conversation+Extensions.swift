import CoreData
import Foundation

// MARK: - Conversation Extensions
extension Conversation {
    
    /// Computed property for messages array (sorted by timestamp)
    var sortedMessages: [ChatMessage] {
        let messagesSet = messages as? Set<ChatMessage> ?? []
        return messagesSet.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Get the last message in the conversation
    var lastMessage: ChatMessage? {
        return sortedMessages.last
    }
    
    /// Get the first message in the conversation
    var firstMessage: ChatMessage? {
        return sortedMessages.first
    }
    
    /// Formatted creation date
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Formatted last message date
    var formattedLastMessageAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastMessageAt)
    }
    
    /// Formatted total cost
    var formattedTotalCost: String {
        return String(format: "$%.4f", totalCost)
    }
    
    /// Check if conversation is active (has messages in last 24 hours)
    var isActive: Bool {
        return lastMessageAt.timeIntervalSinceNow > -86400 // 24 hours
    }
    
    /// Get conversation duration
    var duration: TimeInterval {
        return lastMessageAt.timeIntervalSince(createdAt)
    }
    
    /// Formatted duration
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
    
    /// Generate automatic title based on first user message
    func generateTitle() -> String {
        guard let firstUserMessage = sortedMessages.first(where: { $0.isUserMessage }) else {
            return "New Conversation"
        }
        
        let content = firstUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.count <= 50 {
            return content
        } else {
            return String(content.prefix(47)) + "..."
        }
    }
    
    /// Update conversation statistics
    func updateStatistics() {
        let allMessages = sortedMessages
        messageCount = Int32(allMessages.count)
        totalTokens = allMessages.reduce(0) { $0 + $1.tokens }
        totalCost = allMessages.reduce(0) { $0 + $1.cost }
        
        if let lastMsg = allMessages.last {
            lastMessageAt = lastMsg.timestamp
        }
        
        // Auto-generate title if it's still "New Conversation"
        if title == "New Conversation" || title.isEmpty {
            title = generateTitle()
        }
    }
    
    /// Add a message to the conversation
    func addMessage(_ message: ChatMessage) {
        message.conversation = self
        updateStatistics()
    }
    
    /// Validation before saving
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateConversation()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateConversation()
    }
    
    private func validateConversation() throws {
        // Validate title is not empty
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ConversationValidationError.emptyTitle
        }
        
        // Validate dates
        if lastMessageAt < createdAt {
            throw ConversationValidationError.invalidDateOrder
        }
        
        // Validate counts are not negative
        if messageCount < 0 {
            throw ConversationValidationError.negativeMessageCount
        }
        
        if totalTokens < 0 {
            throw ConversationValidationError.negativeTotalTokens
        }
        
        if totalCost < 0 {
            throw ConversationValidationError.negativeTotalCost
        }
    }
}

// MARK: - Fetch Requests
extension Conversation {
    
    /// Fetch request for recent conversations
    static func recentConversationsRequest(limit: Int = 20) -> NSFetchRequest<Conversation> {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    /// Fetch request for active conversations (within last 24 hours)
    static var activeConversationsRequest: NSFetchRequest<Conversation> {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        let yesterday = Date().addingTimeInterval(-86400)
        request.predicate = NSPredicate(format: "lastMessageAt >= %@", yesterday as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)]
        return request
    }
    
    /// Fetch request for conversations by date range
    static func conversationsRequest(from startDate: Date, to endDate: Date) -> NSFetchRequest<Conversation> {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: false)]
        return request
    }
    
    /// Fetch request for conversations with search term
    static func searchRequest(term: String) -> NSFetchRequest<Conversation> {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", term)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)]
        return request
    }
}

// MARK: - Convenience Initializers
extension Conversation {
    
    /// Create a new conversation
    static func createConversation(
        title: String = "New Conversation",
        in context: NSManagedObjectContext
    ) -> Conversation {
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
}

// MARK: - Conversation Validation Errors
enum ConversationValidationError: LocalizedError {
    case emptyTitle
    case invalidDateOrder
    case negativeMessageCount
    case negativeTotalTokens
    case negativeTotalCost
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Conversation title cannot be empty"
        case .invalidDateOrder:
            return "Last message date cannot be before creation date"
        case .negativeMessageCount:
            return "Message count cannot be negative"
        case .negativeTotalTokens:
            return "Total tokens cannot be negative"
        case .negativeTotalCost:
            return "Total cost cannot be negative"
        }
    }
}