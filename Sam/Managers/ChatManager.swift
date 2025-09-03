import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatModels.ChatMessage] = []
    @Published var isProcessing = false
    @Published var currentConversation: Conversation?
    @Published var usageMetrics = ChatModels.UsageMetrics()
    @Published var streamingMessage: ChatModels.StreamingMessage?
    @Published var typingIndicator = ChatModels.TypingIndicator()
    @Published var processingProgress: Double = 0.0
    @Published var conversationHistory: [ChatModels.Conversation] = []
    @Published var isLoadingHistory = false
    
    private let taskManager = TaskManager()
    private let contextManager = ContextManager()
    private let chatRepository = ChatRepository()
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Message threading support
    private var messageThreads: [UUID: [ChatModels.ChatMessage]] = [:]
    private var currentThreadId: UUID?
    
    init() {
        setupBindings()
        Task {
            await loadConversationHistory()
            await loadRecentConversations()
        }
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ content: String, threadId: UUID? = nil) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Ensure we have a current conversation
        if currentConversation == nil {
            await createNewConversation()
        }
        
        guard let conversation = currentConversation else {
            print("Failed to create or load conversation")
            return
        }
        
        isProcessing = true
        
        do {
            // Create user message using repository
            let userMessage = try await chatRepository.addUserMessage(
                content: content,
                to: conversation
            )
            
            let userSwiftUIMessage = convertToSwiftUIMessage(userMessage)
            messages.append(userSwiftUIMessage)
            
            // Handle message threading
            if let threadId = threadId {
                addMessageToThread(userSwiftUIMessage, threadId: threadId)
            }
            
            // Start streaming response
            await startStreamingResponse()
            
            // Process the message
            let response = try await processMessage(content)
            
            // Complete streaming and create final assistant message
            await completeStreamingResponse(with: response)
            
        } catch {
            await handleMessageError(error)
        }
        
        isProcessing = false
        await updateConversationStatistics()
    }
    
    func sendMessageWithStreaming(_ content: String, threadId: UUID? = nil) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Start streaming response
                    await startStreamingResponse()
                    
                    // Simulate streaming with character-by-character animation
                    let response = try await processMessage(content)
                    await streamResponse(response.output, continuation: continuation)
                    
                    // Complete streaming
                    await completeStreamingResponse(with: response)
                    continuation.finish()
                } catch {
                    await handleStreamingError(error)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func editMessage(_ messageId: UUID, newContent: String) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        var message = messages[index]
        message.edit(newContent: newContent)
        messages[index] = message
        
        // Update in Core Data if it's a persisted message
        if let conversation = currentConversation {
            do {
                try await chatRepository.updateMessage(messageId, content: newContent, in: conversation)
            } catch {
                print("Failed to update message in Core Data: \(error)")
            }
        }
    }
    
    func deleteMessage(_ messageId: UUID) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        var message = messages[index]
        message.delete()
        messages[index] = message
        
        // Update in Core Data if it's a persisted message
        if let conversation = currentConversation {
            do {
                try await chatRepository.deleteMessage(messageId, in: conversation)
            } catch {
                print("Failed to delete message in Core Data: \(error)")
            }
        }
    }
    
    func startEditingMessage(_ messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].startEditing()
    }
    
    func cancelEditingMessage(_ messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].cancelEditing()
    }
    
    func startNewConversation() async {
        await saveConversation()
        messages.removeAll()
        messageThreads.removeAll()
        currentThreadId = nil
        currentConversation = nil
        await createNewConversation()
        await loadRecentConversations()
    }
    
    func loadConversation(_ conversation: ChatModels.Conversation) async {
        await saveConversation()
        
        do {
            // Find the Core Data conversation
            if let coreDataConversation = try await chatRepository.getConversation(id: conversation.id) {
                currentConversation = coreDataConversation
                
                // Load messages for this conversation
                let conversationMessages = try await chatRepository.getMessages(for: coreDataConversation)
                messages = conversationMessages.map { convertToSwiftUIMessage($0) }
                
                // Rebuild message threads
                rebuildMessageThreads()
            }
        } catch {
            print("Failed to load conversation: \(error)")
        }
    }
    
    func deleteConversation(_ conversation: ChatModels.Conversation) async {
        do {
            if let coreDataConversation = try await chatRepository.getConversation(id: conversation.id) {
                try await chatRepository.deleteConversation(coreDataConversation)
                
                // If this was the current conversation, start a new one
                if currentConversation?.id == conversation.id {
                    await startNewConversation()
                }
                
                await loadRecentConversations()
            }
        } catch {
            print("Failed to delete conversation: \(error)")
        }
    }
    
    func clearHistory() async {
        do {
            let allConversations = try await chatRepository.getAllConversations()
            for conversation in allConversations {
                try await chatRepository.deleteConversation(conversation)
            }
            
            messages.removeAll()
            conversationHistory.removeAll()
            messageThreads.removeAll()
            currentThreadId = nil
            currentConversation = nil
            
            await createNewConversation()
        } catch {
            print("Failed to clear history: \(error)")
        }
    }
    
    // MARK: - Message Threading
    
    func startNewThread() -> UUID {
        let threadId = UUID()
        messageThreads[threadId] = []
        currentThreadId = threadId
        return threadId
    }
    
    func getMessagesInThread(_ threadId: UUID) -> [ChatModels.ChatMessage] {
        return messageThreads[threadId] ?? []
    }
    
    func getAllThreads() -> [UUID: [ChatModels.ChatMessage]] {
        return messageThreads
    }
    
    // MARK: - Conversation Management
    
    func getConversationContext(messageLimit: Int = 10) -> ChatModels.ChatContext {
        let recentMessages = Array(messages.suffix(messageLimit))
        let systemInfo = contextManager.getSystemInfo()
        let currentDirectory = contextManager.getCurrentDirectory()
        let recentFiles = contextManager.getRecentFiles()
        let activeApps = contextManager.getActiveApplications()
        
        return ChatModels.ChatContext(
            systemInfo: systemInfo,
            currentDirectory: currentDirectory,
            recentFiles: recentFiles,
            activeApplications: activeApps,
            conversationHistory: recentMessages
        )
    }
    
    func searchMessages(_ query: String) -> [ChatModels.ChatMessage] {
        return messages.filter { message in
            message.content.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getMessagesByTaskType(_ taskType: TaskType) -> [ChatModels.ChatMessage] {
        return messages.filter { $0.taskType == taskType }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Set up Combine bindings for real-time updates
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshConversationData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadConversationHistory() async {
        isLoadingHistory = true
        
        do {
            // Try to load the most recent conversation
            let recentConversations = try await chatRepository.getRecentConversations(limit: 1)
            
            if let conversation = recentConversations.first {
                currentConversation = conversation
                
                // Load messages for this conversation
                let conversationMessages = try await chatRepository.getMessages(for: conversation)
                messages = conversationMessages.map { convertToSwiftUIMessage($0) }
                
                // Rebuild message threads
                rebuildMessageThreads()
            }
            
            // If no conversation exists, create a new one with welcome message
            if currentConversation == nil {
                await createNewConversation()
            }
            
        } catch {
            print("Failed to load conversation history: \(error)")
            await createNewConversation()
        }
        
        isLoadingHistory = false
    }
    
    private func loadRecentConversations() async {
        do {
            let conversations = try await chatRepository.getRecentConversations(limit: 20)
            conversationHistory = conversations.map { conversation in
                ChatModels.Conversation(
                    id: conversation.id,
                    title: conversation.title,
                    createdAt: conversation.createdAt,
                    lastMessageAt: conversation.lastMessageAt,
                    messageCount: Int(conversation.messageCount),
                    totalTokens: Int(conversation.totalTokens),
                    totalCost: conversation.totalCost
                )
            }
        } catch {
            print("Failed to load recent conversations: \(error)")
        }
    }
    
    private func createNewConversation() async {
        do {
            let conversation = try await chatRepository.createConversation(title: "New Conversation")
            currentConversation = conversation
            
            // Add welcome message
            let welcomeMessage = try await chatRepository.addAssistantMessage(
                content: "Hello! I'm Sam, your macOS AI assistant. I can help you with file operations, system queries, app control, and much more. What would you like me to help you with today?",
                taskType: .help,
                to: conversation
            )
            
            messages = [convertToSwiftUIMessage(welcomeMessage)]
            
        } catch {
            print("Failed to create new conversation: \(error)")
            // Fallback to in-memory welcome message
            let welcomeMessage = ChatModels.ChatMessage(
                content: "Hello! I'm Sam, your macOS AI assistant. I can help you with file operations, system queries, app control, and much more. What would you like me to help you with today?",
                isUserMessage: false,
                taskType: .help
            )
            messages = [welcomeMessage]
        }
    }
    
    private func startStreamingResponse() async {
        typingIndicator = ChatModels.TypingIndicator(isVisible: true, message: "Sam is thinking...")
        streamingMessage = ChatModels.StreamingMessage(
            id: UUID(),
            content: "",
            isComplete: false,
            streamingState: .preparing
        )
        processingProgress = 0.0
    }
    
    private func streamResponse(_ response: String, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        guard var streaming = streamingMessage else { return }
        
        streaming.streamingState = .streaming
        streamingMessage = streaming
        typingIndicator = ChatModels.TypingIndicator(isVisible: false)
        
        // Character-by-character streaming animation
        let characters = Array(response)
        let totalCharacters = characters.count
        
        for (index, character) in characters.enumerated() {
            streaming.content.append(character)
            streaming.progress = Double(index + 1) / Double(totalCharacters)
            streamingMessage = streaming
            
            // Emit the current content
            continuation.yield(streaming.content)
            
            // Add slight delay for animation effect
            try? await Task.sleep(nanoseconds: 15_000_000) // 15ms delay
        }
        
        streaming.setProcessing()
        streamingMessage = streaming
    }
    
    private func handleStreamingError(_ error: Error) async {
        typingIndicator = ChatModels.TypingIndicator(isVisible: false)
        
        if var streaming = streamingMessage {
            streaming.setError(error.localizedDescription)
            streamingMessage = streaming
        }
        
        processingProgress = 0.0
    }
    
    private func completeStreamingResponse(with response: ProcessedMessageResult) async {
        if var streaming = streamingMessage {
            streaming.complete()
            streamingMessage = streaming
            
            // Brief delay to show completion state
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        streamingMessage = nil
        typingIndicator = ChatModels.TypingIndicator(isVisible: false)
        processingProgress = 0.0
        
        guard let conversation = currentConversation else { return }
        
        do {
            // Create assistant message using repository
            let assistantMessage = try await chatRepository.addAssistantMessage(
                content: response.output,
                taskType: response.taskType,
                taskResult: response.taskResult,
                executionTime: response.executionTime,
                tokens: response.tokens,
                cost: response.cost,
                to: conversation
            )
            
            let assistantSwiftUIMessage = convertToSwiftUIMessage(assistantMessage)
            messages.append(assistantSwiftUIMessage)
            updateUsageMetrics(with: assistantSwiftUIMessage)
            
            // Add to current thread if active
            if let threadId = currentThreadId {
                addMessageToThread(assistantSwiftUIMessage, threadId: threadId)
            }
            
        } catch {
            print("Failed to create assistant message: \(error)")
        }
    }
    
    private func handleMessageError(_ error: Error) async {
        await handleStreamingError(error)
        
        guard let conversation = currentConversation else { return }
        
        do {
            let errorMessage = try await chatRepository.addAssistantMessage(
                content: "I encountered an error: \(error.localizedDescription)",
                taskType: .help,
                to: conversation
            )
            
            messages.append(convertToSwiftUIMessage(errorMessage))
            
        } catch {
            print("Failed to create error message: \(error)")
            // Fallback to in-memory error message
            let errorMessage = ChatModels.ChatMessage(
                content: "I encountered an error: \(error.localizedDescription)",
                isUserMessage: false,
                taskType: .help
            )
            messages.append(errorMessage)
        }
    }
    
    private func addMessageToThread(_ message: ChatModels.ChatMessage, threadId: UUID) {
        if messageThreads[threadId] == nil {
            messageThreads[threadId] = []
        }
        messageThreads[threadId]?.append(message)
    }
    
    private func rebuildMessageThreads() {
        messageThreads.removeAll()
        // For now, put all messages in a single thread
        // This can be enhanced later with actual thread detection logic
        if !messages.isEmpty {
            let mainThreadId = UUID()
            messageThreads[mainThreadId] = messages
            currentThreadId = mainThreadId
        }
    }
    
    private func refreshConversationData() async {
        await loadRecentConversations()
        
        // Refresh current conversation if needed
        if let conversation = currentConversation {
            do {
                let updatedMessages = try await chatRepository.getMessages(for: conversation)
                let newMessages = updatedMessages.map { convertToSwiftUIMessage($0) }
                
                // Only update if there are new messages
                if newMessages.count != messages.count {
                    messages = newMessages
                    rebuildMessageThreads()
                }
            } catch {
                print("Failed to refresh conversation data: \(error)")
            }
        }
    }
    
    private func updateConversationStatistics() async {
        guard let conversation = currentConversation else { return }
        
        do {
            try await chatRepository.updateConversation(conversation)
        } catch {
            print("Failed to update conversation statistics: \(error)")
        }
    }
    
    private func processMessage(_ content: String) async throws -> ProcessedMessageResult {
        let startTime = Date()
        
        // Get current context with conversation history
        let context = getConversationContext()
        
        // Process the message through task manager
        let result = try await taskManager.processTask(content, context: context)
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Infer task type from the task manager's classification
        let taskType = inferTaskType(from: content, result: result)
        
        // For now, we'll use placeholder values for tokens and cost
        // These will be implemented when AI service integration is added
        return ProcessedMessageResult(
            output: result.output,
            taskType: taskType,
            taskResult: result,
            executionTime: executionTime,
            tokens: estimateTokens(content: content, output: result.output),
            cost: calculateCost(tokens: estimateTokens(content: content, output: result.output))
        )
    }
    
    private func inferTaskType(from input: String, result: TaskResult) -> TaskType {
        // Simple heuristic-based task type inference
        let lowercased = input.lowercased()
        
        if lowercased.contains("copy") || lowercased.contains("move") || lowercased.contains("delete") || lowercased.contains("file") {
            return .fileOperation
        } else if lowercased.contains("battery") || lowercased.contains("storage") || lowercased.contains("memory") {
            return .systemQuery
        } else if lowercased.contains("open") || lowercased.contains("app") || lowercased.contains("safari") {
            return .appControl
        } else if lowercased.contains("help") || lowercased.contains("what") || lowercased.contains("how") {
            return .help
        } else if lowercased.contains("calculate") || lowercased.contains("math") {
            return .calculation
        } else if lowercased.contains("search") || lowercased.contains("google") {
            return .webQuery
        } else if lowercased.contains("workflow") || lowercased.contains("automate") {
            return .automation
        } else if lowercased.contains("setting") || lowercased.contains("preference") {
            return .settings
        }
        
        return .textProcessing // Default for complex queries
    }
    
    private func estimateTokens(content: String, output: String) -> Int {
        // Simple token estimation (roughly 4 characters per token)
        let totalChars = content.count + output.count
        return max(1, totalChars / 4)
    }
    
    private func calculateCost(tokens: Int) -> Double {
        // Placeholder cost calculation (will be updated with actual AI service integration)
        return Double(tokens) * 0.00001 // Rough estimate
    }
    
    private func updateUsageMetrics(with message: ChatModels.ChatMessage) {
        usageMetrics = ChatModels.UsageMetrics(
            totalMessages: usageMetrics.totalMessages + 1,
            totalTokens: usageMetrics.totalTokens + message.tokens,
            totalCost: usageMetrics.totalCost + message.cost,
            averageResponseTime: calculateAverageResponseTime(),
            successfulTasks: usageMetrics.successfulTasks + (message.taskResult?.success == true ? 1 : 0),
            failedTasks: usageMetrics.failedTasks + (message.taskResult?.success == false ? 1 : 0)
        )
    }
    
    private func calculateAverageResponseTime() -> TimeInterval {
        let responseTimes = messages
            .filter { !$0.isUserMessage && $0.executionTime > 0 }
            .map { $0.executionTime }
        
        guard !responseTimes.isEmpty else { return 0 }
        return responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    private func saveConversation() async {
        guard let conversation = currentConversation else { return }
        
        do {
            try await chatRepository.updateConversation(conversation)
        } catch {
            print("Failed to save conversation: \(error)")
        }
    }
    
    private func generateConversationTitle() -> String {
        // Generate a title based on the first user message
        let firstUserMessage = messages.first { $0.isUserMessage }
        let content = firstUserMessage?.content ?? "New Conversation"
        
        // Truncate to reasonable length
        if content.count > 50 {
            return String(content.prefix(47)) + "..."
        }
        return content
    }
    
    // MARK: - Helper Methods
    
    private func convertToSwiftUIMessage(_ coreDataMessage: ChatMessage) -> ChatModels.ChatMessage {
        return ChatModels.ChatMessage(
            id: coreDataMessage.id,
            content: coreDataMessage.content,
            timestamp: coreDataMessage.timestamp,
            isUserMessage: coreDataMessage.isUserMessage,
            taskType: coreDataMessage.taskTypeEnum,
            taskResult: coreDataMessage.parsedTaskResult,
            executionTime: coreDataMessage.executionTime,
            tokens: Int(coreDataMessage.tokens),
            cost: coreDataMessage.cost
        )
    }
    

}

// MARK: - Supporting Types

struct ProcessedMessageResult {
    let output: String
    let taskType: TaskType?
    let taskResult: TaskResult?
    let executionTime: TimeInterval
    let tokens: Int
    let cost: Double
}

// MARK: - Extensions

extension ChatManager {
    func exportConversation() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var export = "Sam AI Assistant Conversation Export\n"
        export += "Generated: \(formatter.string(from: Date()))\n"
        export += "Messages: \(messages.count)\n"
        
        if let conversation = currentConversation {
            export += "Conversation: \(conversation.title)\n"
            export += "Created: \(formatter.string(from: conversation.createdAt))\n"
        }
        
        export += "\n"
        
        for message in messages {
            let sender = message.isUserMessage ? "User" : "Sam"
            let timestamp = formatter.string(from: message.timestamp)
            export += "[\(timestamp)] \(sender): \(message.content)\n"
            
            if let taskType = message.taskType {
                export += "  Task Type: \(taskType.displayName)\n"
            }
            
            if message.executionTime > 0 {
                export += "  Execution Time: \(String(format: "%.2f", message.executionTime))s\n"
            }
            
            export += "\n"
        }
        
        return export
    }
    
    func exportConversationAsJSON() -> String? {
        let exportData = ConversationExport(
            conversation: currentConversation.map { conversation in
                ConversationExport.ConversationInfo(
                    id: conversation.id,
                    title: conversation.title,
                    createdAt: conversation.createdAt,
                    messageCount: Int(conversation.messageCount)
                )
            },
            messages: messages.map { message in
                ConversationExport.MessageInfo(
                    id: message.id,
                    content: message.content,
                    timestamp: message.timestamp,
                    isUserMessage: message.isUserMessage,
                    taskType: message.taskType?.rawValue,
                    executionTime: message.executionTime,
                    tokens: message.tokens,
                    cost: message.cost
                )
            },
            exportedAt: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(exportData)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to export conversation as JSON: \(error)")
            return nil
        }
    }
    
    func getConversationSummary() -> String {
        let userMessages = messages.filter { $0.isUserMessage }.count
        let assistantMessages = messages.filter { !$0.isUserMessage }.count
        let totalTokens = messages.reduce(0) { $0 + $1.tokens }
        let totalCost = messages.reduce(0) { $0 + $1.cost }
        
        let taskTypeDistribution = Dictionary(grouping: messages.compactMap { $0.taskType }) { $0 }
            .mapValues { $0.count }
        
        var summary = """
        Conversation Summary:
        • \(userMessages) user messages
        • \(assistantMessages) assistant responses
        • \(totalTokens) tokens used
        • $\(String(format: "%.4f", totalCost)) total cost
        """
        
        if !taskTypeDistribution.isEmpty {
            summary += "\n\nTask Distribution:"
            for (taskType, count) in taskTypeDistribution.sorted(by: { $0.value > $1.value }) {
                summary += "\n• \(taskType.displayName): \(count)"
            }
        }
        
        return summary
    }
    
    func getConversationStatistics() async -> ChatStatistics? {
        do {
            return try await chatRepository.getChatStatistics()
        } catch {
            print("Failed to get conversation statistics: \(error)")
            return nil
        }
    }
    
    func searchConversations(_ query: String) async -> [ChatModels.Conversation] {
        do {
            let conversations = try await chatRepository.searchConversations(term: query)
            return conversations.map { conversation in
                ChatModels.Conversation(
                    id: conversation.id,
                    title: conversation.title,
                    createdAt: conversation.createdAt,
                    lastMessageAt: conversation.lastMessageAt,
                    messageCount: Int(conversation.messageCount),
                    totalTokens: Int(conversation.totalTokens),
                    totalCost: conversation.totalCost
                )
            }
        } catch {
            print("Failed to search conversations: \(error)")
            return []
        }
    }
}

// MARK: - Supporting Types for Export

struct ConversationExport: Codable {
    struct ConversationInfo: Codable {
        let id: UUID
        let title: String
        let createdAt: Date
        let messageCount: Int
    }
    
    struct MessageInfo: Codable {
        let id: UUID
        let content: String
        let timestamp: Date
        let isUserMessage: Bool
        let taskType: String?
        let executionTime: TimeInterval
        let tokens: Int
        let cost: Double
    }
    
    let conversation: ConversationInfo?
    let messages: [MessageInfo]
    let exportedAt: Date
}