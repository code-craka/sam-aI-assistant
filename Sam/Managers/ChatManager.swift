import Foundation
import SwiftUI
import Combine

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var currentConversation: Conversation?
    @Published var usageMetrics = UsageMetrics()
    
    private let taskManager = TaskManager()
    private let contextManager = ContextManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadConversationHistory()
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ content: String) async {
        let userMessage = ChatMessage(
            content: content,
            isUserMessage: true
        )
        
        messages.append(userMessage)
        isProcessing = true
        
        do {
            let response = try await processMessage(content)
            let assistantMessage = ChatMessage(
                content: response.output,
                isUserMessage: false,
                taskType: response.taskType,
                taskResult: response.taskResult,
                executionTime: response.executionTime,
                tokens: response.tokens,
                cost: response.cost
            )
            
            messages.append(assistantMessage)
            updateUsageMetrics(with: assistantMessage)
            
        } catch {
            let errorMessage = ChatMessage(
                content: "I encountered an error: \(error.localizedDescription)",
                isUserMessage: false,
                taskType: .help,
                executionTime: 0
            )
            messages.append(errorMessage)
        }
        
        isProcessing = false
        saveConversation()
    }
    
    func startNewConversation() {
        saveConversation()
        messages.removeAll()
        currentConversation = nil
    }
    
    func clearHistory() {
        messages.removeAll()
        currentConversation = nil
        // TODO: Clear from Core Data
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // TODO: Set up Combine bindings for real-time updates
    }
    
    private func loadConversationHistory() {
        // TODO: Load conversation history from Core Data
        // For now, add a welcome message
        if messages.isEmpty {
            let welcomeMessage = ChatMessage(
                content: "Hello! I'm Sam, your macOS AI assistant. I can help you with file operations, system queries, app control, and much more. What would you like me to help you with today?",
                isUserMessage: false,
                taskType: .help
            )
            messages.append(welcomeMessage)
        }
    }
    
    private func processMessage(_ content: String) async throws -> ProcessedMessageResult {
        let startTime = Date()
        
        // Get current context
        let context = await contextManager.getCurrentContext()
        
        // Process the message through task manager
        let result = try await taskManager.processTask(content, context: context)
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        return ProcessedMessageResult(
            output: result.output,
            taskType: result.taskType,
            taskResult: result,
            executionTime: executionTime,
            tokens: result.tokens ?? 0,
            cost: result.cost ?? 0.0
        )
    }
    
    private func updateUsageMetrics(with message: ChatMessage) {
        usageMetrics = UsageMetrics(
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
    
    private func saveConversation() {
        // TODO: Save conversation to Core Data
        guard !messages.isEmpty else { return }
        
        if currentConversation == nil {
            // Create new conversation
            let title = generateConversationTitle()
            currentConversation = Conversation(
                title: title,
                messageCount: messages.count,
                totalTokens: messages.reduce(0) { $0 + $1.tokens },
                totalCost: messages.reduce(0) { $0 + $1.cost }
            )
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
        export += "Messages: \(messages.count)\n\n"
        
        for message in messages {
            let sender = message.isUserMessage ? "User" : "Sam"
            let timestamp = formatter.string(from: message.timestamp)
            export += "[\(timestamp)] \(sender): \(message.content)\n\n"
        }
        
        return export
    }
    
    func getConversationSummary() -> String {
        let userMessages = messages.filter { $0.isUserMessage }.count
        let assistantMessages = messages.filter { !$0.isUserMessage }.count
        let totalTokens = messages.reduce(0) { $0 + $1.tokens }
        let totalCost = messages.reduce(0) { $0 + $1.cost }
        
        return """
        Conversation Summary:
        • \(userMessages) user messages
        • \(assistantMessages) assistant responses
        • \(totalTokens) tokens used
        • $\(String(format: "%.4f", totalCost)) total cost
        """
    }
}