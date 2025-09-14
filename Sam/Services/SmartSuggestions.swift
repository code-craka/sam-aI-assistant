import Combine
import Foundation

// MARK: - Smart Suggestions Service
@MainActor
class SmartSuggestionsService: ObservableObject {

    // MARK: - Published Properties
    @Published var currentSuggestions: [SmartSuggestion] = []
    @Published var commandCompletions: [CommandCompletion] = []
    @Published var isGeneratingSuggestions: Bool = false

    // MARK: - Private Properties
    private let userPatternLearning: UserPatternLearningService
    private let conversationContext: ConversationContextService
    private let contextManager: ContextManager
    private var suggestionCache: [String: [SmartSuggestion]] = [:]
    private let maxSuggestions = 8
    private let cacheExpiryTime: TimeInterval = 300  // 5 minutes

    // Built-in command templates
    private let commandTemplates: [CommandTemplate] = [
        CommandTemplate(
            pattern: "open *", description: "Open application or file", category: .appControl),
        CommandTemplate(
            pattern: "find *", description: "Search for files", category: .fileOperation),
        CommandTemplate(
            pattern: "copy * to *", description: "Copy files to location", category: .fileOperation),
        CommandTemplate(
            pattern: "move * to *", description: "Move files to location", category: .fileOperation),
        CommandTemplate(
            pattern: "delete *", description: "Delete files or folders", category: .fileOperation),
        CommandTemplate(
            pattern: "show * info", description: "Display file information", category: .systemQuery),
        CommandTemplate(
            pattern: "create folder *", description: "Create new folder", category: .fileOperation),
        CommandTemplate(
            pattern: "compress *", description: "Create archive", category: .fileOperation),
        CommandTemplate(
            pattern: "extract *", description: "Extract archive", category: .fileOperation),
        CommandTemplate(
            pattern: "search web for *", description: "Web search", category: .webQuery),
        CommandTemplate(
            pattern: "calculate *", description: "Perform calculation", category: .calculation),
        CommandTemplate(
            pattern: "remind me to *", description: "Create reminder", category: .automation),
        CommandTemplate(
            pattern: "schedule * at *", description: "Schedule task", category: .automation),
        CommandTemplate(pattern: "backup *", description: "Backup files", category: .fileOperation),
        CommandTemplate(
            pattern: "organize * by *", description: "Organize files", category: .fileOperation),
    ]

    // MARK: - Initialization
    init(
        userPatternLearning: UserPatternLearningService,
        conversationContext: ConversationContextService, contextManager: ContextManager
    ) {
        self.userPatternLearning = userPatternLearning
        self.conversationContext = conversationContext
        self.contextManager = contextManager

        setupObservers()
    }

    // MARK: - Public Methods

    /// Generate smart suggestions based on current context
    func generateSuggestions(for input: String = "", context: ConversationContextForAI? = nil) async
    {
        isGeneratingSuggestions = true

        // Check cache first
        let cacheKey = createCacheKey(input: input, context: context)
        if let cachedSuggestions = getCachedSuggestions(for: cacheKey) {
            currentSuggestions = cachedSuggestions
            isGeneratingSuggestions = false
            return
        }

        var suggestions: [SmartSuggestion] = []

        // Get context-aware suggestions
        if let context = context {
            suggestions.append(contentsOf: await generateContextAwareSuggestions(context))
        }

        // Get personalized suggestions from user patterns
        let personalizedSuggestions = userPatternLearning.getPersonalizedSuggestions(
            for: context ?? getDefaultContext()
        )
        suggestions.append(contentsOf: personalizedSuggestions.map { convertToSmartSuggestion($0) })

        // Get template-based suggestions
        suggestions.append(contentsOf: generateTemplateSuggestions(for: input))

        // Get contextual suggestions from conversation
        suggestions.append(
            contentsOf: conversationContext.contextualSuggestions.map {
                convertToSmartSuggestion($0)
            })

        // Get system-aware suggestions
        suggestions.append(contentsOf: await generateSystemAwareSuggestions())

        // Sort by relevance and limit
        let finalSuggestions = Array(
            suggestions
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .prefix(maxSuggestions))

        // Cache the results
        cacheSuggestions(finalSuggestions, for: cacheKey)

        currentSuggestions = finalSuggestions
        isGeneratingSuggestions = false
    }

    /// Get command completions for partial input
    func getCommandCompletions(for input: String) -> [CommandCompletion] {
        guard !input.isEmpty else { return [] }

        var completions: [CommandCompletion] = []

        // Get completions from user patterns
        completions.append(contentsOf: userPatternLearning.getCommandCompletions(for: input))

        // Get template-based completions
        completions.append(contentsOf: getTemplateCompletions(for: input))

        // Get context-aware completions
        completions.append(contentsOf: getContextCompletions(for: input))

        // Sort and limit
        let finalCompletions = Array(
            completions
                .sorted { $0.score > $1.score }
                .prefix(10))

        commandCompletions = finalCompletions
        return finalCompletions
    }

    /// Get quick action suggestions
    func getQuickActions() -> [SmartSuggestion] {
        var actions: [SmartSuggestion] = []

        // System status actions
        actions.append(
            SmartSuggestion(
                text: "Check system status",
                command: "show system information",
                relevanceScore: 0.8,
                category: .systemQuery,
                reason: "Quick system overview"
            ))

        // File management actions
        actions.append(
            SmartSuggestion(
                text: "Clean Downloads folder",
                command: "organize Downloads folder",
                relevanceScore: 0.7,
                category: .fileOperation,
                reason: "Common maintenance task"
            ))

        // Productivity actions
        actions.append(
            SmartSuggestion(
                text: "Show recent files",
                command: "list recent files",
                relevanceScore: 0.6,
                category: .fileOperation,
                reason: "Access recent work"
            ))

        return actions
    }

    /// Clear suggestion cache
    func clearCache() {
        suggestionCache.removeAll()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe context changes
        conversationContext.$currentContext
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.generateSuggestions()
                }
            }
            .store(in: &cancellables)

        // Clear cache periodically
        Timer.scheduledTimer(withTimeInterval: cacheExpiryTime, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.clearExpiredCache()
            }
        }
    }

    private func generateContextAwareSuggestions(_ context: ConversationContextForAI) async
        -> [SmartSuggestion]
    {
        var suggestions: [SmartSuggestion] = []

        // Suggestions based on recent messages
        if let lastMessage = context.recentMessages.last {
            suggestions.append(contentsOf: generateFollowUpSuggestions(for: lastMessage))
        }

        // Suggestions based on active entities
        for entity in context.activeEntities.prefix(3) {
            suggestions.append(contentsOf: generateEntitySuggestions(for: entity))
        }

        // Suggestions based on current topic
        if let topic = context.currentTopic {
            suggestions.append(contentsOf: generateTopicSuggestions(for: topic))
        }

        return suggestions
    }

    private func generateFollowUpSuggestions(for message: ChatModels.ChatMessage)
        -> [SmartSuggestion]
    {
        var suggestions: [SmartSuggestion] = []

        guard let taskType = message.taskType else { return suggestions }

        switch taskType {
        case .fileOperation:
            suggestions.append(
                SmartSuggestion(
                    text: "Show file details",
                    command: "show file information",
                    relevanceScore: 0.8,
                    category: .fileOperation,
                    reason: "Follow up to file operation"
                ))

        case .systemQuery:
            suggestions.append(
                SmartSuggestion(
                    text: "Show more system info",
                    command: "show detailed system information",
                    relevanceScore: 0.7,
                    category: .systemQuery,
                    reason: "Expand system query"
                ))

        case .appControl:
            suggestions.append(
                SmartSuggestion(
                    text: "List running apps",
                    command: "show running applications",
                    relevanceScore: 0.6,
                    category: .appControl,
                    reason: "Related to app control"
                ))

        default:
            break
        }

        return suggestions
    }

    private func generateEntitySuggestions(for entity: ConversationEntity) -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []

        switch entity.type {
        case .file:
            suggestions.append(
                SmartSuggestion(
                    text: "Open \(entity.displayName)",
                    command: "open \(entity.value)",
                    relevanceScore: 0.9,
                    category: .fileOperation,
                    reason: "Recently mentioned file"
                ))

        case .application:
            suggestions.append(
                SmartSuggestion(
                    text: "Launch \(entity.value)",
                    command: "open \(entity.value)",
                    relevanceScore: 0.8,
                    category: .appControl,
                    reason: "Recently mentioned app"
                ))

        case .folder:
            suggestions.append(
                SmartSuggestion(
                    text: "Browse \(entity.displayName)",
                    command: "open \(entity.value)",
                    relevanceScore: 0.7,
                    category: .fileOperation,
                    reason: "Recently mentioned folder"
                ))

        default:
            break
        }

        return suggestions
    }

    private func generateTopicSuggestions(for topic: ConversationTopic) -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []

        switch topic {
        case .fileManagement:
            suggestions.append(
                SmartSuggestion(
                    text: "Organize files by date",
                    command: "organize files by date modified",
                    relevanceScore: 0.7,
                    category: .fileOperation,
                    reason: "File management topic"
                ))

        case .systemMaintenance:
            suggestions.append(
                SmartSuggestion(
                    text: "Free up disk space",
                    command: "clean up disk space",
                    relevanceScore: 0.8,
                    category: .systemQuery,
                    reason: "System maintenance topic"
                ))

        case .productivity:
            suggestions.append(
                SmartSuggestion(
                    text: "Create workflow",
                    command: "help me create a workflow",
                    relevanceScore: 0.6,
                    category: .automation,
                    reason: "Productivity topic"
                ))

        default:
            break
        }

        return suggestions
    }

    private func generateTemplateSuggestions(for input: String) -> [SmartSuggestion] {
        guard !input.isEmpty else { return [] }

        var suggestions: [SmartSuggestion] = []
        let lowercasedInput = input.lowercased()

        for template in commandTemplates {
            let templateWords = template.pattern.lowercased().replacingOccurrences(
                of: "*", with: ""
            ).split(separator: " ")
            let inputWords = lowercasedInput.split(separator: " ")

            let matchScore = calculateMatchScore(
                templateWords: templateWords.map(String.init), inputWords: inputWords.map(String.init))

            if matchScore > 0.3 {
                suggestions.append(
                    SmartSuggestion(
                        text: template.description,
                        command: template.pattern,
                        relevanceScore: matchScore,
                        category: template.category,
                        reason: "Command template match"
                    ))
            }
        }

        return suggestions
    }

    private func generateSystemAwareSuggestions() async -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []

        // Get current system context
        let systemContext = contextManager.systemContext

        // Battery-based suggestions
        if let batteryLevel = systemContext.batteryLevel, batteryLevel < 0.2 {
            suggestions.append(
                SmartSuggestion(
                    text: "Enable low power mode",
                    command: "enable low power mode",
                    relevanceScore: 0.9,
                    category: .systemQuery,
                    reason: "Low battery detected"
                ))
        }

        // Storage-based suggestions
        let availableGB = Double(systemContext.availableStorage) / (1024 * 1024 * 1024)
        if availableGB < 5.0 {
            suggestions.append(
                SmartSuggestion(
                    text: "Clean up storage",
                    command: "free up disk space",
                    relevanceScore: 0.8,
                    category: .systemQuery,
                    reason: "Low storage space"
                ))
        }

        // Memory-based suggestions
        if systemContext.memoryUsage > 8.0 {
            suggestions.append(
                SmartSuggestion(
                    text: "Close unused apps",
                    command: "close unused applications",
                    relevanceScore: 0.7,
                    category: .appControl,
                    reason: "High memory usage"
                ))
        }

        return suggestions
    }

    private func getTemplateCompletions(for input: String) -> [CommandCompletion] {
        var completions: [CommandCompletion] = []

        for template in commandTemplates {
            let templateBase = template.pattern.replacingOccurrences(of: " *", with: "")
            if templateBase.lowercased().hasPrefix(input.lowercased()) {
                completions.append(
                    CommandCompletion(
                        command: templateBase,
                        score: 0.8,
                        frequency: 1,
                        lastUsed: Date()
                    ))
            }
        }

        return completions
    }

    private func getContextCompletions(for input: String) -> [CommandCompletion] {
        var completions: [CommandCompletion] = []

        // Get completions based on recent files
        let recentFiles = contextManager.getRecentFiles()
        for file in recentFiles.prefix(5) {
            let fileName = file.lastPathComponent
            if fileName.lowercased().contains(input.lowercased()) {
                completions.append(
                    CommandCompletion(
                        command: "open \(fileName)",
                        score: 0.6,
                        frequency: 1,
                        lastUsed: Date()
                    ))
            }
        }

        return completions
    }

    private func calculateMatchScore(templateWords: [String], inputWords: [String]) -> Double {
        guard !templateWords.isEmpty && !inputWords.isEmpty else { return 0.0 }

        var matches = 0
        for templateWord in templateWords {
            for inputWord in inputWords {
                if templateWord.hasPrefix(inputWord) || inputWord.hasPrefix(templateWord) {
                    matches += 1
                    break
                }
            }
        }

        return Double(matches) / Double(templateWords.count)
    }

    private func convertToSmartSuggestion(_ personalizedSuggestion: PersonalizedSuggestion)
        -> SmartSuggestion
    {
        return SmartSuggestion(
            text: personalizedSuggestion.text,
            command: personalizedSuggestion.command,
            relevanceScore: personalizedSuggestion.relevanceScore,
            category: .automation,  // Default category
            reason: personalizedSuggestion.reason
        )
    }

    private func convertToSmartSuggestion(_ contextualSuggestion: ContextualSuggestion)
        -> SmartSuggestion
    {
        return SmartSuggestion(
            text: contextualSuggestion.text,
            command: contextualSuggestion.command,
            relevanceScore: contextualSuggestion.relevance,
            category: mapContextualCategory(contextualSuggestion.category),
            reason: "Contextual suggestion"
        )
    }

    private func mapContextualCategory(_ category: ContextualSuggestion.Category)
        -> SmartSuggestion.Category
    {
        switch category {
        case .fileManagement:
            return .fileOperation
        case .systemInfo:
            return .systemQuery
        case .appControl:
            return .appControl
        case .automation:
            return .automation
        case .webBrowsing:
            return .webQuery
        }
    }

    private func getDefaultContext() -> ConversationContextForAI {
        return ConversationContextForAI(
            recentMessages: [],
            currentTopic: nil as ConversationTopic?,
            activeEntities: [],
            taskContext: TaskContext(),
            systemContext: contextManager.systemContext,
            userPreferences: userPatternLearning.userPreferences
        )
    }

    private func createCacheKey(input: String, context: ConversationContextForAI?) -> String {
        var key = input
        if let context = context {
            key += "_\(context.currentTopic?.rawValue ?? "")"
            key += "_\(context.activeEntities.count)"
        }
        return key
    }

    private func getCachedSuggestions(for key: String) -> [SmartSuggestion]? {
        return suggestionCache[key]
    }

    private func cacheSuggestions(_ suggestions: [SmartSuggestion], for key: String) {
        suggestionCache[key] = suggestions
    }

    private func clearExpiredCache() {
        // Simple cache clearing - in a real implementation, you'd track timestamps
        if suggestionCache.count > 50 {
            suggestionCache.removeAll()
        }
    }

    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Supporting Types

struct SmartSuggestion {
    enum Category {
        case fileOperation
        case systemQuery
        case appControl
        case automation
        case webQuery
        case calculation
        case textProcessing
    }

    let text: String
    let command: String
    let relevanceScore: Double
    let category: Category
    let reason: String
    let timestamp: Date

    init(text: String, command: String, relevanceScore: Double, category: Category, reason: String)
    {
        self.text = text
        self.command = command
        self.relevanceScore = relevanceScore
        self.category = category
        self.reason = reason
        self.timestamp = Date()
    }
}

struct CommandTemplate {
    let pattern: String
    let description: String
    let category: SmartSuggestion.Category
}
