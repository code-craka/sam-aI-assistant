import Foundation
import SwiftUI

// MARK: - Chat Models Namespace
enum ChatModels {
    // MARK: - Chat Message Model
    struct ChatMessage: Identifiable, Codable {
        let id: UUID
        var content: String
        let timestamp: Date
        let isUserMessage: Bool
        let taskType: TaskType?
        let taskResult: TaskResult?
        let executionTime: TimeInterval
        let tokens: Int
        let cost: Double
        var messageState: MessageState
        var editedAt: Date?
        var originalContent: String?
        
        init(
            id: UUID = UUID(),
            content: String,
            timestamp: Date = Date(),
            isUserMessage: Bool,
            taskType: TaskType? = nil,
            taskResult: TaskResult? = nil,
            executionTime: TimeInterval = 0,
            tokens: Int = 0,
            cost: Double = 0,
            messageState: MessageState = .normal
        ) {
            self.id = id
            self.content = content
            self.timestamp = timestamp
            self.isUserMessage = isUserMessage
            self.taskType = taskType
            self.taskResult = taskResult
            self.executionTime = executionTime
            self.tokens = tokens
            self.cost = cost
            self.messageState = messageState
        }
        
        mutating func edit(newContent: String) {
            if originalContent == nil {
                originalContent = content
            }
            content = newContent
            editedAt = Date()
            messageState = .normal
        }
        
        mutating func delete() {
            messageState = .deleted
        }
        
        mutating func startEditing() {
            messageState = .editing
        }
        
        mutating func cancelEditing() {
            if let original = originalContent {
                content = original
                originalContent = nil
                editedAt = nil
            }
            messageState = .normal
        }
        
        var isEdited: Bool {
            return editedAt != nil
        }
        
        var isDeleted: Bool {
            return messageState == .deleted
        }
    }

    // MARK: - Conversation Model
    struct Conversation: Identifiable, Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let lastMessageAt: Date
    let messageCount: Int
    let totalTokens: Int
    let totalCost: Double
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        lastMessageAt: Date = Date(),
        messageCount: Int = 0,
        totalTokens: Int = 0,
        totalCost: Double = 0
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
        self.totalTokens = totalTokens
        self.totalCost = totalCost
    }
    }

    // MARK: - Chat Context
    struct ChatContext {
    let systemInfo: SystemInfo?
    let currentDirectory: URL?
    let recentFiles: [URL]
    let activeApplications: [String]
    let conversationHistory: [ChatMessage]
    
    init(
        systemInfo: SystemInfo? = nil,
        currentDirectory: URL? = nil,
        recentFiles: [URL] = [],
        activeApplications: [String] = [],
        conversationHistory: [ChatMessage] = []
    ) {
        self.systemInfo = systemInfo
        self.currentDirectory = currentDirectory
        self.recentFiles = recentFiles
        self.activeApplications = activeApplications
        self.conversationHistory = conversationHistory
    }
    }

    // MARK: - Message Streaming
    struct StreamingMessage: Identifiable {
        let id: UUID
        var content: String
        var isComplete: Bool
        let timestamp: Date
        var streamingState: StreamingState
        var progress: Double
        var estimatedTimeRemaining: TimeInterval?
        
        enum StreamingState {
            case preparing
            case streaming
            case processing
            case completing
            case complete
            case error(String)
        }
        
        init(
            id: UUID = UUID(),
            content: String = "",
            isComplete: Bool = false,
            streamingState: StreamingState = .preparing,
            progress: Double = 0.0
        ) {
            self.id = id
            self.content = content
            self.isComplete = isComplete
            self.timestamp = Date()
            self.streamingState = streamingState
            self.progress = progress
        }
        
        mutating func updateContent(_ newContent: String) {
            self.content = newContent
            self.streamingState = .streaming
        }
        
        mutating func setProcessing() {
            self.streamingState = .processing
        }
        
        mutating func complete() {
            self.isComplete = true
            self.streamingState = .complete
            self.progress = 1.0
        }
        
        mutating func setError(_ error: String) {
            self.streamingState = .error(error)
            self.isComplete = true
        }
    }
    
    // MARK: - Message State
    enum MessageState: Codable {
        case normal
        case editing
        case deleting
        case deleted
    }
    
    // MARK: - Typing Indicator
    struct TypingIndicator {
        let isVisible: Bool
        let message: String
        let timestamp: Date
        
        init(isVisible: Bool = false, message: String = "Sam is thinking...") {
            self.isVisible = isVisible
            self.message = message
            self.timestamp = Date()
        }
    }

    // MARK: - Usage Metrics
    struct UsageMetrics: Codable {
    let totalMessages: Int
    let totalTokens: Int
    let totalCost: Double
    let averageResponseTime: TimeInterval
    let successfulTasks: Int
    let failedTasks: Int
    
    init(
        totalMessages: Int = 0,
        totalTokens: Int = 0,
        totalCost: Double = 0,
        averageResponseTime: TimeInterval = 0,
        successfulTasks: Int = 0,
        failedTasks: Int = 0
    ) {
        self.totalMessages = totalMessages
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.averageResponseTime = averageResponseTime
        self.successfulTasks = successfulTasks
        self.failedTasks = failedTasks
    }
    }
}