import Foundation
import Combine

// MARK: - User Pattern Learning Service
@MainActor
class UserPatternLearningService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var learnedPatterns: [UserPattern] = []
    @Published var personalizedSuggestions: [PersonalizedSuggestion] = []
    @Published var userPreferences: UserPreferences = UserPreferences()
    @Published var isLearningEnabled: Bool = true
    
    // MARK: - Private Properties
    private var interactionHistory: [UserInteraction] = []
    private var commandFrequency: [String: Int] = [:]
    private var taskSequences: [TaskSequence] = []
    private var timeBasedPatterns: [TimeBasedPattern] = []
    private let maxHistorySize = 1000
    private let minPatternOccurrences = 3
    
    // MARK: - Initialization
    init() {
        loadStoredPatterns()
        setupPeriodicAnalysis()
    }
    
    // MARK: - Public Methods
    
    /// Record user interaction for pattern learning
    func recordInteraction(_ interaction: UserInteraction) {
        guard isLearningEnabled else { return }
        
        interactionHistory.append(interaction)
        updateCommandFrequency(interaction.command)
        updateTaskSequences(interaction)
        updateTimeBasedPatterns(interaction)
        
        // Maintain history size
        if interactionHistory.count > maxHistorySize {
            interactionHistory = Array(interactionHistory.suffix(maxHistorySize))
        }
        
        // Trigger pattern analysis
        analyzePatterns()
        generatePersonalizedSuggestions()
        savePatterns()
    }
    
    /// Get personalized suggestions based on current context
    func getPersonalizedSuggestions(for context: ConversationContextForAI) -> [PersonalizedSuggestion] {
        var suggestions: [PersonalizedSuggestion] = []
        
        // Time-based suggestions
        suggestions.append(contentsOf: getTimeBasedSuggestions())
        
        // Frequency-based suggestions
        suggestions.append(contentsOf: getFrequencyBasedSuggestions())
        
        // Context-aware suggestions
        suggestions.append(contentsOf: getContextAwareSuggestions(context))
        
        // Sequence-based suggestions
        suggestions.append(contentsOf: getSequenceBasedSuggestions(context))
        
        // Sort by relevance and return top suggestions
        return Array(suggestions.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(5))
    }
    
    /// Get command completion suggestions
    func getCommandCompletions(for partialCommand: String) -> [CommandCompletion] {
        var completions: [CommandCompletion] = []
        
        // Frequency-based completions
        for (command, frequency) in commandFrequency {
            if command.lowercased().hasPrefix(partialCommand.lowercased()) {
                let score = calculateCompletionScore(command: command, frequency: frequency, partial: partialCommand)
                completions.append(CommandCompletion(
                    command: command,
                    score: score,
                    frequency: frequency,
                    lastUsed: getLastUsedDate(for: command)
                ))
            }
        }
        
        // Pattern-based completions
        completions.append(contentsOf: getPatternBasedCompletions(partialCommand))
        
        return Array(completions.sorted { $0.score > $1.score }.prefix(10))
    }
    
    /// Update user preferences based on interactions
    func updateUserPreferences(_ preferences: UserPreferences) {
        userPreferences = preferences
        savePatterns()
    }
    
    /// Get user's preferred apps for specific tasks
    func getPreferredApp(for taskType: TaskType) -> String? {
        return userPreferences.preferredApps[taskType.rawValue]
    }
    
    /// Get user's common working directories
    func getCommonDirectories() -> [String] {
        return userPreferences.workingDirectories
    }
    
    /// Reset all learned patterns
    func resetLearning() {
        interactionHistory.removeAll()
        commandFrequency.removeAll()
        taskSequences.removeAll()
        timeBasedPatterns.removeAll()
        learnedPatterns.removeAll()
        personalizedSuggestions.removeAll()
        userPreferences = UserPreferences()
        savePatterns()
    }
    
    // MARK: - Private Methods
    
    private func updateCommandFrequency(_ command: String) {
        let normalizedCommand = normalizeCommand(command)
        commandFrequency[normalizedCommand, default: 0] += 1
    }
    
    private func updateTaskSequences(_ interaction: UserInteraction) {
        // Look for task sequences in recent interactions
        let recentInteractions = Array(interactionHistory.suffix(5))
        
        if recentInteractions.count >= 2 {
            let sequence = TaskSequence(
                tasks: recentInteractions.map { $0.taskType },
                frequency: 1,
                lastOccurrence: Date(),
                averageTimeBetween: calculateAverageTimeBetween(recentInteractions)
            )
            
            // Check if this sequence already exists
            if let existingIndex = taskSequences.firstIndex(where: { $0.isEquivalent(to: sequence) }) {
                taskSequences[existingIndex].frequency += 1
                taskSequences[existingIndex].lastOccurrence = Date()
            } else {
                taskSequences.append(sequence)
            }
        }
    }
    
    private func updateTimeBasedPatterns(_ interaction: UserInteraction) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: interaction.timestamp)
        let dayOfWeek = calendar.component(.weekday, from: interaction.timestamp)
        
        let timePattern = TimeBasedPattern(
            taskType: interaction.taskType,
            hour: hour,
            dayOfWeek: dayOfWeek,
            frequency: 1
        )
        
        if let existingIndex = timeBasedPatterns.firstIndex(where: { $0.isEquivalent(to: timePattern) }) {
            timeBasedPatterns[existingIndex].frequency += 1
        } else {
            timeBasedPatterns.append(timePattern)
        }
    }
    
    private func analyzePatterns() {
        var patterns: [UserPattern] = []
        
        // Analyze command frequency patterns
        patterns.append(contentsOf: analyzeCommandFrequencyPatterns())
        
        // Analyze time-based patterns
        patterns.append(contentsOf: analyzeTimeBasedPatterns())
        
        // Analyze task sequence patterns
        patterns.append(contentsOf: analyzeTaskSequencePatterns())
        
        // Analyze directory usage patterns
        patterns.append(contentsOf: analyzeDirectoryPatterns())
        
        learnedPatterns = patterns
    }
    
    private func analyzeCommandFrequencyPatterns() -> [UserPattern] {
        var patterns: [UserPattern] = []
        
        let sortedCommands = commandFrequency.sorted { $0.value > $1.value }
        let topCommands = Array(sortedCommands.prefix(10))
        
        for (command, frequency) in topCommands {
            if frequency >= minPatternOccurrences {
                patterns.append(UserPattern(
                    type: .frequentCommand,
                    description: "Frequently uses: \(command)",
                    confidence: min(1.0, Double(frequency) / 20.0),
                    metadata: ["command": command, "frequency": "\(frequency)"]
                ))
            }
        }
        
        return patterns
    }
    
    private func analyzeTimeBasedPatterns() -> [UserPattern] {
        var patterns: [UserPattern] = []
        
        // Group by hour and task type
        let hourlyPatterns = Dictionary(grouping: timeBasedPatterns) { "\($0.hour)-\($0.taskType.rawValue)" }
        
        for (key, patternGroup) in hourlyPatterns {
            let totalFrequency = patternGroup.reduce(0) { $0 + $1.frequency }
            if totalFrequency >= minPatternOccurrences {
                let components = key.split(separator: "-")
                if components.count == 2 {
                    patterns.append(UserPattern(
                        type: .timeBasedUsage,
                        description: "Often performs \(components[1]) tasks at \(components[0]):00",
                        confidence: min(1.0, Double(totalFrequency) / 10.0),
                        metadata: ["hour": String(components[0]), "taskType": String(components[1])]
                    ))
                }
            }
        }
        
        return patterns
    }
    
    private func analyzeTaskSequencePatterns() -> [UserPattern] {
        var patterns: [UserPattern] = []
        
        for sequence in taskSequences {
            if sequence.frequency >= minPatternOccurrences {
                let taskNames = sequence.tasks.map { $0.displayName }.joined(separator: " → ")
                patterns.append(UserPattern(
                    type: .taskSequence,
                    description: "Common workflow: \(taskNames)",
                    confidence: min(1.0, Double(sequence.frequency) / 5.0),
                    metadata: [
                        "sequence": sequence.tasks.map { $0.rawValue }.joined(separator: ","),
                        "frequency": "\(sequence.frequency)"
                    ]
                ))
            }
        }
        
        return patterns
    }
    
    private func analyzeDirectoryPatterns() -> [UserPattern] {
        var patterns: [UserPattern] = []
        
        let directoryUsage = Dictionary(grouping: interactionHistory.compactMap { $0.workingDirectory }) { $0 }
        
        for (directory, occurrences) in directoryUsage {
            if occurrences.count >= minPatternOccurrences {
                patterns.append(UserPattern(
                    type: .directoryUsage,
                    description: "Frequently works in: \(URL(fileURLWithPath: directory).lastPathComponent)",
                    confidence: min(1.0, Double(occurrences.count) / 15.0),
                    metadata: ["directory": directory, "usage": "\(occurrences.count)"]
                ))
            }
        }
        
        return patterns
    }
    
    private func generatePersonalizedSuggestions() {
        var suggestions: [PersonalizedSuggestion] = []
        
        // Generate suggestions from learned patterns
        for pattern in learnedPatterns {
            suggestions.append(contentsOf: generateSuggestionsFromPattern(pattern))
        }
        
        personalizedSuggestions = Array(suggestions.prefix(10))
    }
    
    private func generateSuggestionsFromPattern(_ pattern: UserPattern) -> [PersonalizedSuggestion] {
        var suggestions: [PersonalizedSuggestion] = []
        
        switch pattern.type {
        case .frequentCommand:
            if let command = pattern.metadata["command"] {
                suggestions.append(PersonalizedSuggestion(
                    text: "Quick access: \(command)",
                    command: command,
                    relevanceScore: pattern.confidence,
                    reason: "You use this command frequently"
                ))
            }
            
        case .timeBasedUsage:
            if let hour = pattern.metadata["hour"],
               let taskType = pattern.metadata["taskType"] {
                suggestions.append(PersonalizedSuggestion(
                    text: "It's \(hour):00 - time for \(taskType) tasks?",
                    command: "help me with \(taskType) tasks",
                    relevanceScore: pattern.confidence * 0.8,
                    reason: "You often do \(taskType) tasks at this time"
                ))
            }
            
        case .taskSequence:
            if let sequence = pattern.metadata["sequence"] {
                let tasks = sequence.split(separator: ",")
                if tasks.count > 1 {
                    suggestions.append(PersonalizedSuggestion(
                        text: "Continue workflow: \(tasks.last ?? "")",
                        command: "help me with \(tasks.last ?? "")",
                        relevanceScore: pattern.confidence * 0.9,
                        reason: "This follows your usual workflow pattern"
                    ))
                }
            }
            
        case .directoryUsage:
            if let directory = pattern.metadata["directory"] {
                suggestions.append(PersonalizedSuggestion(
                    text: "Work in \(URL(fileURLWithPath: directory).lastPathComponent)",
                    command: "navigate to \(directory)",
                    relevanceScore: pattern.confidence * 0.7,
                    reason: "You frequently work in this directory"
                ))
            }
        }
        
        return suggestions
    }
    
    private func getTimeBasedSuggestions() -> [PersonalizedSuggestion] {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let currentDayOfWeek = calendar.component(.weekday, from: Date())
        
        return timeBasedPatterns
            .filter { $0.hour == currentHour && $0.dayOfWeek == currentDayOfWeek && $0.frequency >= 2 }
            .map { pattern in
                PersonalizedSuggestion(
                    text: "Time for \(pattern.taskType.displayName)?",
                    command: "help me with \(pattern.taskType.rawValue)",
                    relevanceScore: min(1.0, Double(pattern.frequency) / 5.0),
                    reason: "You often do this at this time"
                )
            }
    }
    
    private func getFrequencyBasedSuggestions() -> [PersonalizedSuggestion] {
        let topCommands = commandFrequency.sorted { $0.value > $1.value }.prefix(3)
        
        return topCommands.map { command, frequency in
            PersonalizedSuggestion(
                text: command,
                command: command,
                relevanceScore: min(1.0, Double(frequency) / 10.0),
                reason: "One of your most used commands"
            )
        }
    }
    
    private func getContextAwareSuggestions(_ context: ConversationContextForAI) -> [PersonalizedSuggestion] {
        var suggestions: [PersonalizedSuggestion] = []
        
        // Suggest based on current topic
        if let topic = context.currentTopic {
            let relatedPatterns = learnedPatterns.filter { pattern in
                pattern.metadata.values.contains { value in
                    value.lowercased().contains(topic.rawValue.lowercased())
                }
            }
            
            for pattern in relatedPatterns.prefix(2) {
                if let command = pattern.metadata["command"] {
                    suggestions.append(PersonalizedSuggestion(
                        text: "Related: \(command)",
                        command: command,
                        relevanceScore: pattern.confidence * 0.8,
                        reason: "Related to current topic"
                    ))
                }
            }
        }
        
        return suggestions
    }
    
    private func getSequenceBasedSuggestions(_ context: ConversationContextForAI) -> [PersonalizedSuggestion] {
        guard let lastMessage = context.recentMessages.last,
              let lastTaskType = lastMessage.taskType else { return [] }
        
        // Find sequences that start with the last task type
        let relevantSequences = taskSequences.filter { sequence in
            sequence.tasks.first == lastTaskType && sequence.tasks.count > 1
        }
        
        return relevantSequences.prefix(2).map { sequence in
            let nextTask = sequence.tasks[1]
            return PersonalizedSuggestion(
                text: "Next: \(nextTask.displayName)",
                command: "help me with \(nextTask.rawValue)",
                relevanceScore: min(1.0, Double(sequence.frequency) / 3.0),
                reason: "Part of your usual workflow"
            )
        }
    }
    
    private func getPatternBasedCompletions(_ partialCommand: String) -> [CommandCompletion] {
        var completions: [CommandCompletion] = []
        
        // Look for patterns in learned commands
        for pattern in learnedPatterns {
            if pattern.type == .frequentCommand,
               let command = pattern.metadata["command"],
               command.lowercased().contains(partialCommand.lowercased()) {
                
                let frequency = Int(pattern.metadata["frequency"] ?? "0") ?? 0
                completions.append(CommandCompletion(
                    command: command,
                    score: pattern.confidence,
                    frequency: frequency,
                    lastUsed: Date()
                ))
            }
        }
        
        return completions
    }
    
    private func calculateCompletionScore(command: String, frequency: Int, partial: String) -> Double {
        let lengthRatio = Double(partial.count) / Double(command.count)
        let frequencyScore = min(1.0, Double(frequency) / 10.0)
        let recencyScore = getRecencyScore(for: command)
        
        return (lengthRatio * 0.3) + (frequencyScore * 0.5) + (recencyScore * 0.2)
    }
    
    private func getRecencyScore(for command: String) -> Double {
        guard let lastInteraction = interactionHistory.last(where: { normalizeCommand($0.command) == normalizeCommand(command) }) else {
            return 0.0
        }
        
        let daysSinceLastUse = Date().timeIntervalSince(lastInteraction.timestamp) / (24 * 60 * 60)
        return max(0.0, 1.0 - (daysSinceLastUse / 30.0)) // Decay over 30 days
    }
    
    private func getLastUsedDate(for command: String) -> Date {
        return interactionHistory.last(where: { normalizeCommand($0.command) == normalizeCommand(command) })?.timestamp ?? Date.distantPast
    }
    
    private func normalizeCommand(_ command: String) -> String {
        return command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func calculateAverageTimeBetween(_ interactions: [UserInteraction]) -> TimeInterval {
        guard interactions.count > 1 else { return 0 }
        
        var totalTime: TimeInterval = 0
        for i in 1..<interactions.count {
            totalTime += interactions[i].timestamp.timeIntervalSince(interactions[i-1].timestamp)
        }
        
        return totalTime / Double(interactions.count - 1)
    }
    
    private func setupPeriodicAnalysis() {
        // Analyze patterns every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.analyzePatterns()
                self?.generatePersonalizedSuggestions()
            }
        }
    }
    
    private func loadStoredPatterns() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "UserPatterns"),
           let patterns = try? JSONDecoder().decode([UserPattern].self, from: data) {
            learnedPatterns = patterns
        }
        
        if let data = UserDefaults.standard.data(forKey: "CommandFrequency"),
           let frequency = try? JSONDecoder().decode([String: Int].self, from: data) {
            commandFrequency = frequency
        }
        
        if let data = UserDefaults.standard.data(forKey: "UserPreferences"),
           let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            userPreferences = preferences
        }
    }
    
    private func savePatterns() {
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(learnedPatterns) {
            UserDefaults.standard.set(data, forKey: "UserPatterns")
        }
        
        if let data = try? JSONEncoder().encode(commandFrequency) {
            UserDefaults.standard.set(data, forKey: "CommandFrequency")
        }
        
        if let data = try? JSONEncoder().encode(userPreferences) {
            UserDefaults.standard.set(data, forKey: "UserPreferences")
        }
    }
}

// MARK: - Supporting Types

struct UserInteraction {
    let id: UUID
    let command: String
    let taskType: TaskType
    let timestamp: Date
    let success: Bool
    let executionTime: TimeInterval
    let workingDirectory: String?
    let context: [String: String]
    
    init(command: String, taskType: TaskType, success: Bool = true, executionTime: TimeInterval = 0, workingDirectory: String? = nil, context: [String: String] = [:]) {
        self.id = UUID()
        self.command = command
        self.taskType = taskType
        self.timestamp = Date()
        self.success = success
        self.executionTime = executionTime
        self.workingDirectory = workingDirectory
        self.context = context
    }
}

struct UserPattern: Codable {
    enum PatternType: String, Codable {
        case frequentCommand
        case timeBasedUsage
        case taskSequence
        case directoryUsage
    }
    
    let type: PatternType
    let description: String
    let confidence: Double
    let metadata: [String: String]
    let discoveredAt: Date
    
    init(type: PatternType, description: String, confidence: Double, metadata: [String: String]) {
        self.type = type
        self.description = description
        self.confidence = confidence
        self.metadata = metadata
        self.discoveredAt = Date()
    }
}

struct PersonalizedSuggestion {
    let text: String
    let command: String
    let relevanceScore: Double
    let reason: String
    let timestamp: Date
    
    init(text: String, command: String, relevanceScore: Double, reason: String) {
        self.text = text
        self.command = command
        self.relevanceScore = relevanceScore
        self.reason = reason
        self.timestamp = Date()
    }
}

struct CommandCompletion {
    let command: String
    let score: Double
    let frequency: Int
    let lastUsed: Date
}

struct TaskSequence {
    let tasks: [TaskType]
    var frequency: Int
    var lastOccurrence: Date
    let averageTimeBetween: TimeInterval
    
    func isEquivalent(to other: TaskSequence) -> Bool {
        return tasks == other.tasks
    }
}

struct TimeBasedPattern {
    let taskType: TaskType
    let hour: Int
    let dayOfWeek: Int
    var frequency: Int
    
    func isEquivalent(to other: TimeBasedPattern) -> Bool {
        return taskType == other.taskType && hour == other.hour && dayOfWeek == other.dayOfWeek
    }
}
