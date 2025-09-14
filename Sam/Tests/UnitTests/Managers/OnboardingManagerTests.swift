import XCTest
@testable import Sam

@MainActor
final class OnboardingManagerTests: XCTestCase {
    var onboardingManager: OnboardingManager!
    
    override func setUp() {
        super.setUp()
        onboardingManager = OnboardingManager()
        // Reset onboarding state for testing
        onboardingManager.resetOnboarding()
    }
    
    override func tearDown() {
        onboardingManager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(onboardingManager.currentStep, .welcome)
        XCTAssertFalse(onboardingManager.isCompleted)
        XCTAssertTrue(onboardingManager.shouldShowOnboarding)
    }
    
    func testStepNavigation() {
        // Test going forward
        onboardingManager.goNext()
        XCTAssertEqual(onboardingManager.currentStep, .features)
        
        onboardingManager.goNext()
        XCTAssertEqual(onboardingManager.currentStep, .permissions)
        
        // Test going back
        onboardingManager.goBack()
        XCTAssertEqual(onboardingManager.currentStep, .features)
        
        onboardingManager.goBack()
        XCTAssertEqual(onboardingManager.currentStep, .welcome)
        
        // Test can't go back from first step
        XCTAssertFalse(onboardingManager.canGoBack)
        onboardingManager.goBack()
        XCTAssertEqual(onboardingManager.currentStep, .welcome)
    }
    
    func testProgressCalculation() {
        XCTAssertEqual(onboardingManager.progress, 0.2) // 1/5 steps
        
        onboardingManager.goNext()
        XCTAssertEqual(onboardingManager.progress, 0.4) // 2/5 steps
        
        onboardingManager.goNext()
        XCTAssertEqual(onboardingManager.progress, 0.6) // 3/5 steps
        
        onboardingManager.goNext()
        XCTAssertEqual(onboardingManager.progress, 0.8) // 4/5 steps
        
        onboardingManager.goNext()
        XCTAssertEqual(onboardingManager.progress, 1.0) // 5/5 steps
        XCTAssertTrue(onboardingManager.isLastStep)
    }
    
    func testOnboardingCompletion() {
        // Navigate to last step
        onboardingManager.goToStep(.examples)
        XCTAssertTrue(onboardingManager.isLastStep)
        
        // Complete onboarding
        onboardingManager.completeOnboarding()
        XCTAssertTrue(onboardingManager.isCompleted)
        XCTAssertFalse(onboardingManager.shouldShowOnboarding)
    }
    
    func testOnboardingReset() {
        // Complete onboarding first
        onboardingManager.completeOnboarding()
        XCTAssertTrue(onboardingManager.isCompleted)
        
        // Reset onboarding
        onboardingManager.resetOnboarding()
        XCTAssertFalse(onboardingManager.isCompleted)
        XCTAssertEqual(onboardingManager.currentStep, .welcome)
        XCTAssertTrue(onboardingManager.shouldShowOnboarding)
    }
    
    func testDirectStepNavigation() {
        onboardingManager.goToStep(.permissions)
        XCTAssertEqual(onboardingManager.currentStep, .permissions)
        
        onboardingManager.goToStep(.apiSetup)
        XCTAssertEqual(onboardingManager.currentStep, .apiSetup)
        
        onboardingManager.goToStep(.welcome)
        XCTAssertEqual(onboardingManager.currentStep, .welcome)
    }
}

@MainActor
final class HelpManagerTests: XCTestCase {
    var helpManager: HelpManager!
    
    override func setUp() {
        super.setUp()
        helpManager = HelpManager()
    }
    
    override func tearDown() {
        helpManager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(helpManager.showingOnboarding)
        XCTAssertFalse(helpManager.showingCommandPalette)
        XCTAssertFalse(helpManager.showingKeyboardShortcuts)
        XCTAssertTrue(helpManager.searchResults.isEmpty)
    }
    
    func testShowMethods() {
        helpManager.showOnboarding()
        XCTAssertTrue(helpManager.showingOnboarding)
        
        helpManager.showCommandPalette()
        XCTAssertTrue(helpManager.showingCommandPalette)
        
        helpManager.showKeyboardShortcuts()
        XCTAssertTrue(helpManager.showingKeyboardShortcuts)
    }
    
    func testSearchFunctionality() {
        let results = helpManager.search("file")
        XCTAssertFalse(results.isEmpty)
        
        // Should find file-related help content
        let fileResults = results.filter { $0.category == .fileOperations }
        XCTAssertFalse(fileResults.isEmpty)
        
        // Empty search should return empty results
        let emptyResults = helpManager.search("")
        XCTAssertTrue(emptyResults.isEmpty)
    }
    
    func testContextualHelp() {
        let fileOpHelp = helpManager.getContextualHelp(for: .fileOperation)
        XCTAssertFalse(fileOpHelp.isEmpty)
        
        let systemHelp = helpManager.getContextualHelp(for: .systemQuery)
        XCTAssertFalse(systemHelp.isEmpty)
        
        let appControlHelp = helpManager.getContextualHelp(for: .appControl)
        XCTAssertFalse(appControlHelp.isEmpty)
    }
}

@MainActor
final class CommandSuggestionManagerTests: XCTestCase {
    var suggestionManager: CommandSuggestionManager!
    
    override func setUp() {
        super.setUp()
        suggestionManager = CommandSuggestionManager()
    }
    
    override func tearDown() {
        suggestionManager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(suggestionManager.suggestedCommands.isEmpty)
        XCTAssertTrue(suggestionManager.recentCommands.isEmpty)
        XCTAssertTrue(suggestionManager.popularCommands.isEmpty)
    }
    
    func testCommandFiltering() {
        // Test category filtering
        let fileCommands = suggestionManager.getFilteredCommands(
            searchText: "",
            category: .fileOperations
        )
        XCTAssertFalse(fileCommands.isEmpty)
        XCTAssertTrue(fileCommands.allSatisfy { $0.category == .fileOperations })
        
        // Test search filtering
        let copyCommands = suggestionManager.getFilteredCommands(
            searchText: "copy",
            category: .all
        )
        XCTAssertFalse(copyCommands.isEmpty)
        XCTAssertTrue(copyCommands.allSatisfy { command in
            command.text.localizedCaseInsensitiveContains("copy") ||
            command.description.localizedCaseInsensitiveContains("copy") ||
            command.tags.contains { $0.localizedCaseInsensitiveContains("copy") }
        })
    }
    
    func testUsageTracking() {
        let command = suggestionManager.suggestedCommands.first!
        let initialUsageCount = command.usageCount
        
        suggestionManager.trackCommandUsage(command)
        
        // Should be added to recent commands
        XCTAssertEqual(suggestionManager.recentCommands.first?.text, command.text)
        
        // Usage count should be tracked in UserDefaults
        // (In a real implementation, we'd verify the updated command has higher usage count)
    }
    
    func testContextualSuggestions() {
        let suggestions = suggestionManager.getSuggestionsForContext("file copy")
        XCTAssertFalse(suggestions.isEmpty)
        
        // Should return relevant suggestions for file operations
        let relevantSuggestions = suggestions.filter { suggestion in
            suggestion.text.localizedCaseInsensitiveContains("file") ||
            suggestion.text.localizedCaseInsensitiveContains("copy")
        }
        XCTAssertFalse(relevantSuggestions.isEmpty)
    }
}