import Foundation
import Combine

// MARK: - Conversation Context Service
@MainActor
class ConversationContextService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentContext: ConversationContext = ConversationContext()
    @Published var contextualSuggestions: [ContextualSuggestion] = []
    @Published var followUpQuestions: [FollowUpQuestion] = []
    
    // MARK: - Private Properties
    private let maxContextMessages = 20
    private let maxContextFiles = 10
    private let maxContextApps = 5
    private var contextHistory: [ConversationContext] = []
    private let contextManager = ContextManager()
    
    // MARK: - Context Tracking
    
    /// Update conversation context with new message
    func updateContext(with message: ChatModels.ChatMessage, systemContext: SystemContext? = nil) {
        // Add message to context history
        currentContext.addMessage(message)
        
        // Update system context if provided
        if let systemContext = systemContext {
            currentContext.systemContext = systemContext
        }
        
        // Extract entities from message content
        let entities = extractEntities(from: message.content)
        currentContext.updateEntities(entities)
        
        // Update task context
        if let taskType = message.taskType {
            currentContext.updateTaskContext(taskType, result: message.taskResult)
        }
        
        // Generate contextual suggestions
        generateContextualSuggestions()
        
        // Generate follow-up questions
        generateFollowUpQuestions()
        
        // Maintain context history
        maintainContextHistory()
    }
    
    /// Get conversation context for AI processing
    func getContextForAI() -> ConversationContextForAI {
        return ConversationContextForAI(
            recentMessages: Array(currentContext.messageHistory.suffix(maxContextMessages)),
            currentTopic: currentContext.currentTopic,
            activeEntities: currentContext.activeEntities,
            taskContext: currentContext.taskContext,
            systemContext: currentContext.systemContext,
            userPreferences: currentContext.userPreferences
        )
    }
    
    /// Check if message is a follow-up to previous conversation
    func isFollowUpMessage(_ content: String) -> Bool {
        let followUpIndicators = [
            "also", "and", "then", "next", "after that", "additionally",
            "what about", "how about", "can you also", "please also",
            "it", "that", "this", "them", "those", "these"
        ]
        
        let lowercased = content.lowercased()
        return followUpIndicators.contains { lowercased.contains($0) }
    }
    
    /// Resolve references in follow-up messages
    func resolveReferences(in content: String) -> String {
        var resolvedContent = content
        
        // Replace pronouns with actual entities
        for entity in currentContext.activeEntities {
            resolvedContent = resolveEntityReferences(resolvedContent, entity: entity)
        }
        
        // Add context from recent tasks
        if let lastTask = currentContext.taskContext.lastTask {
            resolvedContent = addTaskContext(resolvedContent, lastTask: lastTask)
        }
        
        return resolvedContent
    }
    
    // MARK: - Private Methods
    
    private func extractEntities(from content: String) -> [ConversationEntity] {
        var entities: [ConversationEntity] = []
        
        // Extract file paths
        let filePathPattern = #"(?:\/[^\s\/]+)+\.[a-zA-Z0-9]+"#
        entities.append(contentsOf: extractMatches(content, pattern: filePathPattern, type: .file))
        
        // Extract application names
        let appPattern = #"\b(?:Safari|Finder|Mail|Calendar|Notes|TextEdit|Xcode|Terminal)\b"#
        entities.append(contentsOf: extractMatches(content, pattern: appPattern, type: .application))
        
        // Extract folder paths
        let folderPattern = #"(?:\/[^\s\/]+)+(?:\/|$)"#
        entities.append(contentsOf: extractMatches(content, pattern: folderPattern, type: .folder))
        
        // Extract URLs
        let urlPattern = #"https?:\/\/[^\s]+"#
        entities.append(contentsOf: extractMatches(content, pattern: urlPattern, type: .url))
        
        return entities
    }
    
    private func extractMatches(_ content: String, pattern: String, type: ConversationEntity.EntityType) -> [ConversationEntity] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            
            return matches.compactMap { match in
                guard let range = Range(match.range, in: content) else { return nil }
                let value = String(content[range])
                return ConversationEntity(type: type, value: value, confidence: 0.8)
            }
        } catch {
            return []
        }
    }
    
    private func generateContextualSuggestions() {
        var suggestions: [ContextualSuggestion] = []
        
        // Generate suggestions based on recent tasks
        if let lastTask = currentContext.taskContext.lastTask {
            suggestions.append(contentsOf: generateTaskBasedSuggestions(lastTask))
        }
        
        // Generate suggestions based on active entities
        for entity in currentContext.activeEntities.prefix(3) {
            suggestions.append(contentsOf: generateEntityBasedSuggestions(entity))
        }
        
        // Generate suggestions based on current topic
        if let topic = currentContext.currentTopic {
            suggestions.append(contentsOf: generateTopicBasedSuggestions(topic))
        }
        
        // Sort by relevance and limit
        contextualSuggestions = Array(suggestions.sorted { $0.relevance > $1.relevance }.prefix(5))
    }
    
    private func generateFollowUpQuestions() {
        var questions: [FollowUpQuestion] = []
        
        // Generate questions based on last assistant message
        if let lastAssistantMessage = currentContext.messageHistory.last(where: { !$0.isUserMessage }) {
            questions.append(contentsOf: generateQuestionsFromMessage(lastAssistantMessage))
        }
        
        // Generate questions based on task results
        if let lastTask = currentContext.taskContext.lastTask,
           let result = lastTask.result {
            questions.append(contentsOf: generateQuestionsFromTaskResult(result))
        }
        
        followUpQuestions = Array(questions.prefix(3))
    }
    
    private func generateTaskBasedSuggestions(_ task: TaskContext.TaskInfo) -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        switch task.type {
        case .fileOperation:
            suggestions.append(ContextualSuggestion(
                text: "Organize files by type",
                command: "organize files in current folder by type",
                relevance: 0.8,
                category: .fileManagement
            ))
            suggestions.append(ContextualSuggestion(
                text: "Show file details",
                command: "show details of recent files",
                relevance: 0.7,
                category: .fileManagement
            ))
            
        case .systemQuery:
            suggestions.append(ContextualSuggestion(
                text: "Check system performance",
                command: "show system performance metrics",
                relevance: 0.8,
                category: .systemInfo
            ))
            
        case .appControl:
            suggestions.append(ContextualSuggestion(
                text: "List running apps",
                command: "show all running applications",
                relevance: 0.7,
                category: .appControl
            ))
            
        default:
            break
        }
        
        return suggestions
    }
    
    private func generateEntityBasedSuggestions(_ entity: ConversationEntity) -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        switch entity.type {
        case .file:
            suggestions.append(ContextualSuggestion(
                text: "Open \(entity.displayName)",
                command: "open \(entity.value)",
                relevance: 0.9,
                category: .fileManagement
            ))
            suggestions.append(ContextualSuggestion(
                text: "Show file info",
                command: "show information about \(entity.value)",
                relevance: 0.8,
                category: .fileManagement
            ))
            
        case .application:
            suggestions.append(ContextualSuggestion(
                text: "Open \(entity.value)",
                command: "open \(entity.value)",
                relevance: 0.9,
                category: .appControl
            ))
            
        case .folder:
            suggestions.append(ContextualSuggestion(
                text: "List folder contents",
                command: "list files in \(entity.value)",
                relevance: 0.8,
                category: .fileManagement
            ))
            
        case .url:
            suggestions.append(ContextualSuggestion(
                text: "Open in Safari",
                command: "open \(entity.value) in Safari",
                relevance: 0.8,
                category: .webBrowsing
            ))
        }
        
        return suggestions
    }
    
    private func generateTopicBasedSuggestions(_ topic: ConversationTopic) -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        switch topic {
        case .fileManagement:
            suggestions.append(ContextualSuggestion(
                text: "Clean up Downloads",
                command: "organize and clean up Downloads folder",
                relevance: 0.7,
                category: .fileManagement
            ))
            
        case .systemMaintenance:
            suggestions.append(ContextualSuggestion(
                text: "Free up disk space",
                command: "help me free up disk space",
                relevance: 0.8,
                category: .systemInfo
            ))
            
        case .productivity:
            suggestions.append(ContextualSuggestion(
                text: "Create workflow",
                command: "help me create a workflow for this task",
                relevance: 0.7,
                category: .automation
            ))
            
        case .development:
            suggestions.append(ContextualSuggestion(
                text: "Open project in Xcode",
                command: "open current project in Xcode",
                relevance: 0.8,
                category: .appControl
            ))
        }
        
        return suggestions
    }
    
    private func generateQuestionsFromMessage(_ message: ChatModels.ChatMessage) -> [FollowUpQuestion] {
        var questions: [FollowUpQuestion] = []
        
        if let taskType = message.taskType {
            switch taskType {
            case .fileOperation:
                questions.append(FollowUpQuestion(
                    text: "Would you like me to organize more files?",
                    suggestedCommand: "organize files in another folder",
                    relevance: 0.8
                ))
                
            case .systemQuery:
                questions.append(FollowUpQuestion(
                    text: "Do you want to see more system details?",
                    suggestedCommand: "show detailed system information",
                    relevance: 0.7
                ))
                
            case .appControl:
                questions.append(FollowUpQuestion(
                    text: "Need help with any other applications?",
                    suggestedCommand: "help me with another app",
                    relevance: 0.6
                ))
                
            default:
                break
            }
        }
        
        return questions
    }
    
    private func generateQuestionsFromTaskResult(_ result: TaskResult) -> [FollowUpQuestion] {
        var questions: [FollowUpQuestion] = []
        
        if result.success {
            questions.append(FollowUpQuestion(
                text: "Would you like me to perform a similar task?",
                suggestedCommand: "do something similar",
                relevance: 0.7
            ))
        } else {
            questions.append(FollowUpQuestion(
                text: "Would you like me to try a different approach?",
                suggestedCommand: "try a different way",
                relevance: 0.8
            ))
        }
        
        return questions
    }
    
    private func resolveEntityReferences(_ content: String, entity: ConversationEntity) -> String {
        var resolved = content
        
        // Replace common pronouns with entity values
        let pronouns = ["it", "that", "this", "them", "those", "these"]
        
        for pronoun in pronouns {
            let pattern = "\\b\(pronoun)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                resolved = regex.stringByReplacingMatches(
                    in: resolved,
                    options: [],
                    range: NSRange(resolved.startIndex..., in: resolved),
                    withTemplate: entity.value
                )
            }
        }
        
        return resolved
    }
    
    private func addTaskContext(_ content: String, lastTask: TaskContext.TaskInfo) -> String {
        // If the content seems incomplete, add context from the last task
        if content.count < 20 && lastTask.parameters.count > 0 {
            let contextInfo = lastTask.parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "\(content) (context: \(contextInfo))"
        }
        
        return content
    }
    
    private func maintainContextHistory() {
        // Keep a history of contexts for pattern analysis
        contextHistory.append(currentContext)
        
        // Limit history size
        if contextHistory.count > 50 {
            contextHistory = Array(contextHistory.suffix(50))
        }
        
        // Update current topic based on recent activity
        updateCurrentTopic()
    }
    
    private func updateCurrentTopic() {
        let recentTaskTypes = currentContext.messageHistory.suffix(5).compactMap { $0.taskType }
        
        if recentTaskTypes.filter({ $0 == .fileOperation }).count >= 2 {
            currentContext.currentTopic = .fileManagement
        } else if recentTaskTypes.filter({ $0 == .systemQuery }).count >= 2 {
            currentContext.currentTopic = .systemMaintenance
        } else if recentTaskTypes.contains(.automation) {
            currentContext.currentTopic = .productivity
        } else if recentTaskTypes.contains(.appControl) && 
                  currentContext.activeEntities.contains(where: { $0.value.contains("Xcode") || $0.value.contains("Terminal") }) {
            currentContext.currentTopic = .development
        }
    }
}

// MARK: - Supporting Types

struct ConversationContext {
    var messageHistory: [ChatModels.ChatMessage] = []
    var activeEntities: [ConversationEntity] = []
    var taskContext: TaskContext = TaskContext()
    var systemContext: SystemContext = SystemContext()
    var userPreferences: UserPreferences = UserPreferences()
    var currentTopic: ConversationTopic?
    var sessionStartTime: Date = Date()
    
    mutating func addMessage(_ message: ChatModels.ChatMessage) {
        messageHistory.append(message)
        
        // Limit message history
        if messageHistory.count > 50 {
            messageHistory = Array(messageHistory.suffix(50))
        }
    }
    
    mutating func updateEntities(_ entities: [ConversationEntity]) {
        // Add new entities and update existing ones
        for entity in entities {
            if let existingIndex = activeEntities.firstIndex(where: { $0.value == entity.value }) {
                activeEntities[existingIndex].updateRelevance()
            } else {
                activeEntities.append(entity)
            }
        }
        
        // Remove old entities and sort by relevance
        activeEntities = activeEntities
            .filter { $0.isRelevant }
            .sorted { $0.relevance > $1.relevance }
        
        // Limit active entities
        if activeEntities.count > 10 {
            activeEntities = Array(activeEntities.prefix(10))
        }
    }
    
    mutating func updateTaskContext(_ taskType: TaskType, result: TaskResult?) {
        taskContext.addTask(TaskContext.TaskInfo(
            type: taskType,
            timestamp: Date(),
            result: result,
            parameters: [:]
        ))
    }
}

struct ConversationEntity {
    enum EntityType {
        case file
        case folder
        case application
        case url
        case person
        case date
        case number
    }
    
    let type: EntityType
    let value: String
    var relevance: Double
    let firstMentioned: Date
    var lastMentioned: Date
    
    init(type: EntityType, value: String, confidence: Double) {
        self.type = type
        self.value = value
        self.relevance = confidence
        self.firstMentioned = Date()
        self.lastMentioned = Date()
    }
    
    var displayName: String {
        switch type {
        case .file, .folder:
            return URL(fileURLWithPath: value).lastPathComponent
        default:
            return value
        }
    }
    
    var isRelevant: Bool {
        let timeSinceLastMention = Date().timeIntervalSince(lastMentioned)
        return timeSinceLastMention < 3600 && relevance > 0.3 // Relevant for 1 hour
    }
    
    mutating func updateRelevance() {
        lastMentioned = Date()
        relevance = min(1.0, relevance + 0.1) // Increase relevance when mentioned again
    }
}

struct TaskContext {
    struct TaskInfo {
        let type: TaskType
        let timestamp: Date
        let result: TaskResult?
        let parameters: [String: String]
    }
    
    private var taskHistory: [TaskInfo] = []
    
    var lastTask: TaskInfo? {
        return taskHistory.last
    }
    
    var recentTasks: [TaskInfo] {
        return Array(taskHistory.suffix(5))
    }
    
    mutating func addTask(_ task: TaskInfo) {
        taskHistory.append(task)
        
        // Limit task history
        if taskHistory.count > 20 {
            taskHistory = Array(taskHistory.suffix(20))
        }
    }
}

enum ConversationTopic {
    case fileManagement
    case systemMaintenance
    case productivity
    case development
    case webBrowsing
    case communication
}

struct ContextualSuggestion {
    enum Category {
        case fileManagement
        case systemInfo
        case appControl
        case automation
        case webBrowsing
    }
    
    let text: String
    let command: String
    let relevance: Double
    let category: Category
}

struct FollowUpQuestion {
    let text: String
    let suggestedCommand: String
    let relevance: Double
}

struct ConversationContextForAI {
    let recentMessages: [ChatModels.ChatMessage]
    let currentTopic: ConversationTopic?
    let activeEntities: [ConversationEntity]
    let taskContext: TaskContext
    let systemContext: SystemContext
    let userPreferences: UserPreferences
}

struct UserPreferences {
    var preferredApps: [String: String] = [:]
    var commonTasks: [String] = []
    var workingDirectories: [String] = []
    var timeZone: TimeZone = TimeZone.current
}