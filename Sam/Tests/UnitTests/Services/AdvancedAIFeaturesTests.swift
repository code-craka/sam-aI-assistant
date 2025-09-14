import XCTest
@testable import Sam

class AdvancedAIFeaturesTests: XCTestCase {
    
    var conversationContextService: ConversationContextService!
    var userPatternLearning: UserPatternLearningService!
    var smartSuggestions: SmartSuggestionsService!
    var contextManager: ContextManager!
    
    override func setUp() {
        super.setUp()
        conversationContextService = ConversationContextService()
        userPatternLearning = UserPatternLearningService()
        contextManager = ContextManager()
        smartSuggestions = SmartSuggestionsService(
            userPatternLearning: userPatternLearning,
            conversationContext: conversationContextService,
            contextManager: contextManager
        )
    }
    
    override func tearDown() {
        conversationContextService = nil
        userPatternLearning = nil
        smartSuggestions = nil
        contextManager = nil
        super.tearDown()
    }
    
    // MARK: - Conversation Context Tests
    
    func testConversationContextUpdates() {
        let message = ChatModels.ChatMessage(
            content: "Open Safari and navigate to apple.com",
            isUserMessage: true,
            taskType: .appControl
        )
        
        conversationContextService.updateContext(with: message)
        
        XCTAssertFalse(conversationContextService.currentContext.activeEntities.isEmpty)
        XCTAssertEqual(conversationContextService.currentContext.messageHistory.count, 1)
    }
    
    func testFollowUpDetection() {
        let followUpMessage = "Also open that file"
        let regularMessage = "Open a new file"
        
        XCTAssertTrue(conversationContextService.isFollowUpMessage(followUpMessage))
        XCTAssertFalse(conversationContextService.isFollowUpMessage(regularMessage))
    }
    
    func testReferenceResolution() {
        // Add a file entity to context
        let fileMessage = ChatModels.ChatMessage(
            content: "Open /Users/test/document.pdf",
            isUserMessage: true,
            taskType: .fileOperation
        )
        conversationContextService.updateContext(with: fileMessage)
        
        // Test reference resolution
        let followUpContent = "Show information about it"
        let resolvedContent = conversationContextService.resolveReferences(in: followUpContent)
        
        XCTAssertTrue(resolvedContent.contains("/Users/test/document.pdf"))
    }
    
    // MARK: - User Pattern Learning Tests
    
    func testInteractionRecording() {
        let interaction = UserInteraction(
            command: "open Safari",
            taskType: .appControl,
            success: true
        )
        
        userPatternLearning.recordInteraction(interaction)
        
        XCTAssertFalse(userPatternLearning.learnedPatterns.isEmpty)
    }
    
    func testCommandFrequencyTracking() {
        // Record multiple interactions with the same command
        for _ in 0..<5 {
            let interaction = UserInteraction(
                command: "open Safari",
                taskType: .appControl,
                success: true
            )
            userPatternLearning.recordInteraction(interaction)
        }
        
        let completions = userPatternLearning.getCommandCompletions(for: "open")
        XCTAssertFalse(completions.isEmpty)
        
        let safariCompletion = completions.first { $0.command.contains("Safari") }
        XCTAssertNotNil(safariCompletion)
        XCTAssertEqual(safariCompletion?.frequency, 5)
    }
    
    func testPersonalizedSuggestions() {
        // Record some interactions to build patterns
        let interactions = [
            UserInteraction(command: "organize Downloads", taskType: .fileOperation),
            UserInteraction(command: "check battery", taskType: .systemQuery),
            UserInteraction(command: "open Xcode", taskType: .appControl)
        ]
        
        for interaction in interactions {
            userPatternLearning.recordInteraction(interaction)
        }
        
        let context = ConversationContextForAI(
            recentMessages: [],
            currentTopic: .fileManagement,
            activeEntities: [],
            taskContext: TaskContext(),
            systemContext: SystemContext(),
            userPreferences: UserPreferences()
        )
        
        let suggestions = userPatternLearning.getPersonalizedSuggestions(for: context)
        XCTAssertFalse(suggestions.isEmpty)
    }
    
    // MARK: - Smart Suggestions Tests
    
    func testCommandCompletions() async {
        let completions = smartSuggestions.getCommandCompletions(for: "open")
        XCTAssertFalse(completions.isEmpty)
        
        // Should include template-based completions
        let openCompletion = completions.first { $0.command.hasPrefix("open") }
        XCTAssertNotNil(openCompletion)
    }
    
    func testContextAwareSuggestions() async {
        let context = ConversationContextForAI(
            recentMessages: [
                ChatModels.ChatMessage(
                    content: "Show system information",
                    isUserMessage: false,
                    taskType: .systemQuery
                )
            ],
            currentTopic: .systemMaintenance,
            activeEntities: [],
            taskContext: TaskContext(),
            systemContext: SystemContext(),
            userPreferences: UserPreferences()
        )
        
        await smartSuggestions.generateSuggestions(context: context)
        XCTAssertFalse(smartSuggestions.currentSuggestions.isEmpty)
    }
    
    func testQuickActions() {
        let quickActions = smartSuggestions.getQuickActions()
        XCTAssertFalse(quickActions.isEmpty)
        
        // Should include common actions
        let systemStatusAction = quickActions.first { $0.text.contains("system") }
        XCTAssertNotNil(systemStatusAction)
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndContextFlow() async {
        // Simulate a conversation flow
        let userMessage1 = ChatModels.ChatMessage(
            content: "Open the Downloads folder",
            isUserMessage: true,
            taskType: .fileOperation
        )
        
        conversationContextService.updateContext(with: userMessage1)
        
        // Record interaction for learning
        let interaction1 = UserInteraction(
            command: "open Downloads folder",
            taskType: .fileOperation,
            success: true
        )
        userPatternLearning.recordInteraction(interaction1)
        
        // Generate suggestions based on context
        let context = conversationContextService.getContextForAI()
        await smartSuggestions.generateSuggestions(context: context)
        
        // Verify we have contextual suggestions
        XCTAssertFalse(smartSuggestions.currentSuggestions.isEmpty)
        XCTAssertFalse(conversationContextService.contextualSuggestions.isEmpty)
        
        // Test follow-up message
        let followUpMessage = "Also organize the files in it"
        XCTAssertTrue(conversationContextService.isFollowUpMessage(followUpMessage))
        
        let resolvedContent = conversationContextService.resolveReferences(in: followUpMessage)
        XCTAssertNotEqual(followUpMessage, resolvedContent)
    }
    
    func testLearningDisabled() {
        userPatternLearning.isLearningEnabled = false
        
        let interaction = UserInteraction(
            command: "test command",
            taskType: .textProcessing
        )
        
        userPatternLearning.recordInteraction(interaction)
        
        // Should not record when learning is disabled
        XCTAssertTrue(userPatternLearning.learnedPatterns.isEmpty)
    }
    
    func testPatternReset() {
        // Add some patterns
        let interaction = UserInteraction(
            command: "test command",
            taskType: .textProcessing
        )
        userPatternLearning.recordInteraction(interaction)
        
        XCTAssertFalse(userPatternLearning.learnedPatterns.isEmpty)
        
        // Reset learning
        userPatternLearning.resetLearning()
        
        XCTAssertTrue(userPatternLearning.learnedPatterns.isEmpty)
    }
}

// MARK: - Performance Tests

extension AdvancedAIFeaturesTests {
    
    func testSuggestionGenerationPerformance() {
        measure {
            let context = ConversationContextForAI(
                recentMessages: [],
                currentTopic: .fileManagement,
                activeEntities: [],
                taskContext: TaskContext(),
                systemContext: SystemContext(),
                userPreferences: UserPreferences()
            )
            
            Task {
                await smartSuggestions.generateSuggestions(context: context)
            }
        }
    }
    
    func testPatternLearningPerformance() {
        measure {
            for i in 0..<100 {
                let interaction = UserInteraction(
                    command: "test command \(i)",
                    taskType: .textProcessing
                )
                userPatternLearning.recordInteraction(interaction)
            }
        }
    }
}