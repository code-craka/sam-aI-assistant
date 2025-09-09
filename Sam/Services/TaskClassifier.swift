import Foundation
import NaturalLanguage

/// Local natural language processing service for task classification
/// Provides keyword-based classification with confidence scoring and parameter extraction
class TaskClassifier: ObservableObject {
    
    // MARK: - Properties
    
    private let nlTagger: NLTagger
    private let confidenceThreshold: Double = 0.7
    private let performanceTracker = PerformanceTracker.shared
    
    // MARK: - Classification Patterns
    
    private struct ClassificationPattern {
        let keywords: [String]
        let taskType: TaskType
        let weight: Double
        let parameterExtractors: [ParameterExtractor]
        let complexity: TaskComplexity
        let requiresConfirmation: Bool
        
        init(
            keywords: [String],
            taskType: TaskType,
            weight: Double = 1.0,
            parameterExtractors: [ParameterExtractor] = [],
            complexity: TaskComplexity = .simple,
            requiresConfirmation: Bool = false
        ) {
            self.keywords = keywords
            self.taskType = taskType
            self.weight = weight
            self.parameterExtractors = parameterExtractors
            self.complexity = complexity
            self.requiresConfirmation = requiresConfirmation
        }
    }
    
    private struct ParameterExtractor {
        let name: String
        let pattern: NSRegularExpression
        let transform: ((String) -> String)?
        
        init(name: String, pattern: String, transform: ((String) -> String)? = nil) {
            self.name = name
            self.pattern = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            self.transform = transform
        }
    }
    
    // MARK: - Classification Patterns Database
    
    private lazy var classificationPatterns: [ClassificationPattern] = [
        // File Operations
        ClassificationPattern(
            keywords: ["copy", "move", "delete", "rename", "organize", "find", "search", "create folder", "mkdir"],
            taskType: .fileOperation,
            weight: 1.2,
            parameterExtractors: [
                ParameterExtractor(name: "source", pattern: #"(?:copy|move|rename)\s+(?:file\s+)?["\']?([^"'\s]+(?:\.[a-zA-Z0-9]+)?)["\']?"#),
                ParameterExtractor(name: "destination", pattern: #"(?:to|into|in)\s+["\']?([^"'\s]+)["\']?"#),
                ParameterExtractor(name: "filename", pattern: #"(?:create|find|search)\s+(?:file\s+)?["\']?([^"'\s]+(?:\.[a-zA-Z0-9]+)?)["\']?"#),
                ParameterExtractor(name: "extension", pattern: #"(?:find|search).*?\.([a-zA-Z0-9]+)"#),
                ParameterExtractor(name: "directory", pattern: #"(?:in|from)\s+["\']?([^"'\s]+)["\']?"#)
            ],
            complexity: .simple,
            requiresConfirmation: true
        ),
        
        // System Queries
        ClassificationPattern(
            keywords: ["battery", "storage", "memory", "disk space", "cpu", "network", "wifi", "system info", "running apps"],
            taskType: .systemQuery,
            weight: 1.1,
            parameterExtractors: [
                ParameterExtractor(name: "queryType", pattern: #"(battery|storage|memory|disk|cpu|network|wifi|system)"#),
                ParameterExtractor(name: "unit", pattern: #"(percentage|percent|gb|mb|kb|bytes)"#)
            ],
            complexity: .simple
        ),
        
        // App Control
        ClassificationPattern(
            keywords: ["open", "launch", "start", "close", "quit", "switch to", "activate", "minimize", "maximize"],
            taskType: .appControl,
            weight: 1.0,
            parameterExtractors: [
                ParameterExtractor(name: "appName", pattern: #"(?:open|launch|start|close|quit|switch to|activate)\s+([a-zA-Z\s]+?)(?:\s|$)"#) { appName in
                    return appName.trimmingCharacters(in: .whitespacesAndNewlines)
                },
                ParameterExtractor(name: "action", pattern: #"(open|launch|start|close|quit|minimize|maximize|activate)"#)
            ],
            complexity: .simple
        ),
        
        // Text Processing
        ClassificationPattern(
            keywords: ["summarize", "translate", "format", "convert", "extract", "analyze", "count words", "spell check"],
            taskType: .textProcessing,
            weight: 0.9,
            parameterExtractors: [
                ParameterExtractor(name: "action", pattern: #"(summarize|translate|format|convert|extract|analyze|count|spell check)"#),
                ParameterExtractor(name: "language", pattern: #"(?:to|in)\s+([a-zA-Z]+)"#),
                ParameterExtractor(name: "format", pattern: #"(?:to|as)\s+(pdf|docx|txt|html|markdown)"#)
            ],
            complexity: .moderate
        ),
        
        // Calculations
        ClassificationPattern(
            keywords: ["calculate", "compute", "math", "add", "subtract", "multiply", "divide", "percentage", "convert units"],
            taskType: .calculation,
            weight: 1.0,
            parameterExtractors: [
                ParameterExtractor(name: "expression", pattern: #"calculate\s+(.+)"#),
                ParameterExtractor(name: "operation", pattern: #"(add|subtract|multiply|divide|percentage|convert)"#),
                ParameterExtractor(name: "numbers", pattern: #"(\d+(?:\.\d+)?)"#)
            ],
            complexity: .simple
        ),
        
        // Web Queries
        ClassificationPattern(
            keywords: ["search", "google", "browse", "website", "url", "bookmark", "web"],
            taskType: .webQuery,
            weight: 0.8,
            parameterExtractors: [
                ParameterExtractor(name: "query", pattern: #"(?:search|google)\s+(?:for\s+)?(.+)"#),
                ParameterExtractor(name: "url", pattern: #"(https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,})"#),
                ParameterExtractor(name: "action", pattern: #"(search|browse|bookmark|open)"#)
            ],
            complexity: .simple
        ),
        
        // Automation/Workflows
        ClassificationPattern(
            keywords: ["workflow", "automate", "schedule", "repeat", "batch", "script", "macro"],
            taskType: .automation,
            weight: 0.9,
            parameterExtractors: [
                ParameterExtractor(name: "action", pattern: #"(create|run|schedule|automate)"#),
                ParameterExtractor(name: "frequency", pattern: #"(daily|weekly|monthly|hourly|every\s+\d+)"#)
            ],
            complexity: .complex,
            requiresConfirmation: true
        ),
        
        // Settings
        ClassificationPattern(
            keywords: ["settings", "preferences", "configure", "setup", "change", "adjust", "volume", "brightness"],
            taskType: .settings,
            weight: 1.0,
            parameterExtractors: [
                ParameterExtractor(name: "setting", pattern: #"(volume|brightness|theme|language|notifications)"#),
                ParameterExtractor(name: "value", pattern: #"(?:to|at)\s+(\d+%?|\w+)"#)
            ],
            complexity: .simple
        ),
        
        // Help
        ClassificationPattern(
            keywords: ["help", "how to", "tutorial", "guide", "explain", "what is", "show me"],
            taskType: .help,
            weight: 0.7,
            parameterExtractors: [
                ParameterExtractor(name: "topic", pattern: #"(?:help with|how to|explain|what is|show me)\s+(.+)"#)
            ],
            complexity: .simple
        )
    ]
    
    // MARK: - Initialization
    
    init() {
        self.nlTagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .nameType])
    }
    
    // MARK: - Public Methods
    
    /// Classifies user input and extracts parameters
    /// - Parameter input: The user's natural language input
    /// - Returns: Classification result with confidence score and extracted parameters
    func classify(_ input: String) async -> TaskClassificationResult {
        let operationId = "classify_\(UUID().uuidString.prefix(8))"
        
        return await performanceTracker.trackOperation(operationId, type: .taskClassification) {
            return await performClassification(input)
        }
    }
    
    /// Internal method to perform the actual classification
    private func performClassification(_ input: String) async -> TaskClassificationResult {
        let normalizedInput = normalizeInput(input)
        
        // Calculate scores for each task type
        var scores: [TaskType: Double] = [:]
        var bestPattern: ClassificationPattern?
        var extractedParameters: [String: String] = [:]
        
        for pattern in classificationPatterns {
            let score = calculateScore(for: pattern, input: normalizedInput)
            
            if score > 0 {
                scores[pattern.taskType] = max(scores[pattern.taskType] ?? 0, score)
                
                // Keep track of the best matching pattern for parameter extraction
                if bestPattern == nil || score > calculateScore(for: bestPattern!, input: normalizedInput) {
                    bestPattern = pattern
                }
            }
        }
        
        // Find the highest scoring task type
        guard let (taskType, confidence) = scores.max(by: { $0.value < $1.value }) else {
            return TaskClassificationResult(
                taskType: .unknown,
                confidence: 0.0,
                parameters: [:],
                complexity: .simple,
                processingRoute: .cloud,
                requiresConfirmation: false,
                estimatedDuration: 1.0
            )
        }
        
        // Extract parameters using the best matching pattern
        if let pattern = bestPattern {
            extractedParameters = extractParameters(from: input, using: pattern.parameterExtractors)
        }
        
        // Enhance with NLP analysis
        let nlpEnhancedResult = enhanceWithNLP(
            input: input,
            taskType: taskType,
            confidence: confidence,
            parameters: extractedParameters,
            pattern: bestPattern
        )
        
        return nlpEnhancedResult
    }
    
    // MARK: - Private Methods
    
    private func normalizeInput(_ input: String) -> String {
        return input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
    
    private func calculateScore(for pattern: ClassificationPattern, input: String) -> Double {
        var score: Double = 0
        let words = input.components(separatedBy: .whitespacesAndNewlines)
        
        for keyword in pattern.keywords {
            let keywordWords = keyword.components(separatedBy: " ")
            
            if keywordWords.count == 1 {
                // Single word keyword
                if words.contains(keyword) {
                    score += pattern.weight
                }
            } else {
                // Multi-word keyword - check for phrase match
                if input.contains(keyword) {
                    score += pattern.weight * 1.5 // Bonus for phrase matches
                }
            }
        }
        
        // Normalize score by number of keywords to prevent bias toward patterns with many keywords
        return score / Double(pattern.keywords.count)
    }
    
    private func extractParameters(from input: String, using extractors: [ParameterExtractor]) -> [String: String] {
        var parameters: [String: String] = [:]
        
        for extractor in extractors {
            let matches = extractor.pattern.matches(
                in: input,
                options: [],
                range: NSRange(location: 0, length: input.utf16.count)
            )
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: input) {
                        var value = String(input[swiftRange])
                        
                        // Apply transformation if provided
                        if let transform = extractor.transform {
                            value = transform(value)
                        }
                        
                        parameters[extractor.name] = value
                        break // Take first match for each parameter
                    }
                }
            }
        }
        
        return parameters
    }
    
    private func enhanceWithNLP(
        input: String,
        taskType: TaskType,
        confidence: Double,
        parameters: [String: String],
        pattern: ClassificationPattern?
    ) -> TaskClassificationResult {
        
        // Use NaturalLanguage framework for additional analysis
        nlTagger.string = input
        
        // Extract named entities (file paths, app names, etc.)
        var enhancedParameters = parameters
        
        nlTagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entity = String(input[range])
                
                switch tag {
                case .personalName:
                    if enhancedParameters["contact"] == nil {
                        enhancedParameters["contact"] = entity
                    }
                case .placeName:
                    if enhancedParameters["location"] == nil {
                        enhancedParameters["location"] = entity
                    }
                case .organizationName:
                    if enhancedParameters["organization"] == nil {
                        enhancedParameters["organization"] = entity
                    }
                default:
                    break
                }
            }
            return true
        }
        
        // Detect file paths and URLs that might have been missed
        enhancedParameters = enhanceFilePathDetection(input: input, parameters: enhancedParameters)
        enhancedParameters = enhanceAppNameDetection(input: input, parameters: enhancedParameters)
        
        // Determine processing route based on confidence and complexity
        let processingRoute: ProcessingRoute
        if confidence >= confidenceThreshold {
            processingRoute = pattern?.complexity.processingRoute ?? .local
        } else {
            processingRoute = .cloud
        }
        
        // Estimate duration based on task type and complexity
        let estimatedDuration = estimateDuration(for: taskType, complexity: pattern?.complexity ?? .simple)
        
        return TaskClassificationResult(
            taskType: taskType,
            confidence: confidence,
            parameters: enhancedParameters,
            complexity: pattern?.complexity ?? .simple,
            processingRoute: processingRoute,
            requiresConfirmation: pattern?.requiresConfirmation ?? false,
            estimatedDuration: estimatedDuration
        )
    }
    
    private func enhanceFilePathDetection(input: String, parameters: [String: String]) -> [String: String] {
        var enhanced = parameters
        
        // Enhanced file path detection
        let filePathPattern = #"(?:[~/]?(?:[a-zA-Z0-9._-]+/)*[a-zA-Z0-9._-]+(?:\.[a-zA-Z0-9]+)?)"#
        let regex = try! NSRegularExpression(pattern: filePathPattern, options: [])
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        
        for match in matches {
            if let range = Range(match.range, in: input) {
                let path = String(input[range])
                
                // Determine if this looks like a source or destination
                let beforePath = String(input[..<range.lowerBound]).lowercased()
                
                if beforePath.contains("to ") || beforePath.contains("into ") {
                    if enhanced["destination"] == nil {
                        enhanced["destination"] = path
                    }
                } else if beforePath.contains("from ") || enhanced["source"] == nil {
                    enhanced["source"] = path
                }
            }
        }
        
        return enhanced
    }
    
    private func enhanceAppNameDetection(input: String, parameters: [String: String]) -> [String: String] {
        var enhanced = parameters
        
        // Common macOS app names
        let commonApps = [
            "safari", "chrome", "firefox", "mail", "calendar", "notes", "finder", "terminal",
            "xcode", "vscode", "photoshop", "illustrator", "sketch", "figma", "slack",
            "discord", "spotify", "music", "photos", "preview", "textedit", "pages",
            "numbers", "keynote", "system preferences", "activity monitor"
        ]
        
        let inputLower = input.lowercased()
        
        for app in commonApps {
            if inputLower.contains(app) && enhanced["appName"] == nil {
                enhanced["appName"] = app
                break
            }
        }
        
        return enhanced
    }
    
    private func estimateDuration(for taskType: TaskType, complexity: TaskComplexity) -> TimeInterval {
        let baseTime: TimeInterval
        
        switch taskType {
        case .systemQuery, .calculation, .help:
            baseTime = 0.5
        case .fileOperation, .appControl, .settings:
            baseTime = 1.0
        case .textProcessing, .webQuery:
            baseTime = 2.0
        case .automation:
            baseTime = 5.0
        case .unknown:
            baseTime = 1.0
        }
        
        let complexityMultiplier: Double
        switch complexity {
        case .simple: complexityMultiplier = 1.0
        case .moderate: complexityMultiplier = 2.0
        case .complex: complexityMultiplier = 4.0
        case .advanced: complexityMultiplier = 8.0
        }
        
        return baseTime * complexityMultiplier
    }
}

// MARK: - Extensions

extension TaskClassifier {
    
    /// Quick classification for simple patterns (used for performance optimization)
    func quickClassify(_ input: String) -> TaskClassificationResult? {
        let normalizedInput = normalizeInput(input)
        
        // Quick keyword matching for obvious cases
        if normalizedInput.contains("battery") || normalizedInput.contains("storage") {
            return TaskClassificationResult(
                taskType: .systemQuery,
                confidence: 0.9,
                parameters: ["queryType": normalizedInput.contains("battery") ? "battery" : "storage"],
                complexity: .simple,
                processingRoute: .local
            )
        }
        
        if normalizedInput.hasPrefix("open ") || normalizedInput.hasPrefix("launch ") {
            let appName = String(normalizedInput.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return TaskClassificationResult(
                taskType: .appControl,
                confidence: 0.85,
                parameters: ["appName": appName, "action": "open"],
                complexity: .simple,
                processingRoute: .local
            )
        }
        
        return nil
    }
    
    /// Get confidence threshold for determining local vs cloud processing
    var localProcessingThreshold: Double {
        return confidenceThreshold
    }
    
    /// Check if classification result should be processed locally
    func shouldProcessLocally(_ result: TaskClassificationResult) -> Bool {
        return result.confidence >= confidenceThreshold && result.complexity == .simple
    }
    
    /// Get processing route recommendation based on classification
    func recommendProcessingRoute(for result: TaskClassificationResult) -> ProcessingRoute {
        if result.confidence >= confidenceThreshold {
            return result.complexity.processingRoute
        } else {
            return .cloud
        }
    }
}