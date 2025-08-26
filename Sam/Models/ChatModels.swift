import Foundation
import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isUserMessage: Bool
    let taskType: TaskType?
    let taskResult: TaskResult?
    let executionTime: TimeInterval
    let tokens: Int
    let cost: Double
    
    init(
        id: UUID = UUID(),
        content: String,
        timestamp: Date = Date(),
        isUserMessage: Bool,
        taskType: TaskType? = nil,
        taskResult: TaskResult? = nil,
        executionTime: TimeInterval = 0,
        tokens: Int = 0,
        cost: Double = 0
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
struct StreamingMessage {
    let id: UUID
    var content: String
    let isComplete: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), content: String = "", isComplete: Bool = false) {
        self.id = id
        self.content = content
        self.isComplete = isComplete
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