//
//  WorkflowBuilder.swift
//  Sam
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import NaturalLanguage

@MainActor
class WorkflowBuilder: ObservableObject {
    @Published var isBuilding = false
    @Published var buildProgress: Double = 0.0
    
    private let taskClassifier: TaskClassifier
    private let aiService: AIService
    private let nlProcessor = NLTagger(tagSchemes: [.tokenType, .nameType])
    
    init() {
        self.taskClassifier = TaskClassifier()
        self.aiService = AIService()
    }
    
    // MARK: - Public Methods
    
    func buildWorkflowFromDescription(_ description: String, name: String? = nil) async throws -> WorkflowDefinition {
        isBuilding = true
        buildProgress = 0.0
        
        defer {
            isBuilding = false
            buildProgress = 0.0
        }
        
        // Step 1: Parse the description into individual steps
        buildProgress = 0.2
        let stepDescriptions = try await parseStepDescriptions(description)
        
        // Step 2: Convert each step description into workflow steps
        buildProgress = 0.4
        var workflowSteps: [WorkflowStepDefinition] = []
        
        for (index, stepDescription) in stepDescriptions.enumerated() {
            let step = try await buildWorkflowStep(stepDescription, index: index)
            workflowSteps.append(step)
            buildProgress = 0.4 + (0.4 * Double(index + 1) / Double(stepDescriptions.count))
        }
        
        // Step 3: Identify variables and dependencies
        buildProgress = 0.8
        let variables = extractVariables(from: stepDescriptions)
        let optimizedSteps = optimizeSteps(workflowSteps)
        
        // Step 4: Create workflow definition
        buildProgress = 0.9
        let workflowName = name ?? generateWorkflowName(from: description)
        let workflow = WorkflowDefinition(
            name: workflowName,
            description: description,
            steps: optimizedSteps,
            variables: variables,
            tags: extractTags(from: description)
        )
        
        buildProgress = 1.0
        return workflow
    }
    
    func buildWorkflowFromTemplate(_ template: WorkflowTemplate, parameters: [String: Any]) async throws -> WorkflowDefinition {
        isBuilding = true
        buildProgress = 0.0
        
        defer {
            isBuilding = false
            buildProgress = 0.0
        }
        
        // Replace template variables with actual parameters
        buildProgress = 0.3
        let expandedSteps = template.steps.map { step in
            expandTemplateStep(step, parameters: parameters)
        }
        
        buildProgress = 0.6
        let expandedVariables = template.variables.merging(parameters.mapValues { AnyCodable($0) }) { _, new in new }
        
        buildProgress = 0.9
        let workflow = WorkflowDefinition(
            name: template.name,
            description: expandTemplate(template.description, parameters: parameters),
            steps: expandedSteps,
            variables: expandedVariables,
            triggers: template.triggers,
            tags: template.tags
        )
        
        buildProgress = 1.0
        return workflow
    }
    
    func validateWorkflow(_ workflow: WorkflowDefinition) async throws -> WorkflowValidationResult {
        var issues: [WorkflowValidationIssue] = []
        var warnings: [WorkflowValidationWarning] = []
        
        // Validate steps
        for (index, step) in workflow.steps.enumerated() {
            let stepIssues = validateStep(step, index: index, workflow: workflow)
            issues.append(contentsOf: stepIssues)
        }
        
        // Check for circular dependencies
        if hasCircularDependencies(workflow) {
            issues.append(WorkflowValidationIssue(
                type: .circularDependency,
                message: "Workflow contains circular dependencies",
                stepIndex: nil
            ))
        }
        
        // Check for unreachable steps
        let unreachableSteps = findUnreachableSteps(workflow)
        for stepIndex in unreachableSteps {
            warnings.append(WorkflowValidationWarning(
                type: .unreachableStep,
                message: "Step \(stepIndex + 1) may be unreachable",
                stepIndex: stepIndex
            ))
        }
        
        return WorkflowValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    func optimizeWorkflow(_ workflow: WorkflowDefinition) async throws -> WorkflowDefinition {
        var optimizedSteps = workflow.steps
        
        // Remove redundant steps
        optimizedSteps = removeRedundantSteps(optimizedSteps)
        
        // Reorder steps for better performance
        optimizedSteps = reorderStepsForPerformance(optimizedSteps)
        
        // Merge compatible steps
        optimizedSteps = mergeCompatibleSteps(optimizedSteps)
        
        return WorkflowDefinition(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description,
            steps: optimizedSteps,
            variables: workflow.variables,
            triggers: workflow.triggers,
            isEnabled: workflow.isEnabled,
            createdAt: workflow.createdAt,
            modifiedAt: Date(),
            version: workflow.version + 1,
            tags: workflow.tags
        )
    }
    
    // MARK: - Private Methods
    
    private func parseStepDescriptions(_ description: String) async throws -> [String] {
        // Use AI to break down the description into individual steps
        let messages = [
            ChatModels.ChatMessage(
                content: """
                Break down the following workflow description into individual, actionable steps. 
                Each step should be a single action that can be executed independently.
                Return the steps as a numbered list, one step per line.
                
                Description: \(description)
                """,
                isUserMessage: true
            )
        ]
        
        let response = try await aiService.generateCompletion(messages: messages)
        let responseText = response.choices.first?.message.content ?? ""
        
        // Parse the response into individual steps
        let lines = responseText.components(separatedBy: CharacterSet.newlines)
        let steps = lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            // Remove numbering and extract the step description
            if let range = trimmed.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                return String(trimmed[range.upperBound...])
            }
            return trimmed.isEmpty ? nil : trimmed
        }
        
        return steps
    }
    
    private func buildWorkflowStep(_ description: String, index: Int) async throws -> WorkflowStepDefinition {
        // Classify the step to determine its type
        let classification = await taskClassifier.classify(description)
        
        let stepType: WorkflowStepType
        var parameters: [String: Any] = [:]
        
        switch classification.taskType {
        case .fileOperation:
            stepType = .fileOperation
            parameters = extractFileOperationParameters(description, classification: classification)
        case .appControl:
            stepType = .appControl
            parameters = extractAppControlParameters(description, classification: classification)
        case .systemQuery:
            stepType = .systemCommand
            parameters = extractSystemCommandParameters(description, classification: classification)
        case .textProcessing:
            stepType = .textProcessing
            parameters = extractTextProcessingParameters(description, classification: classification)
        default:
            stepType = .systemCommand
            parameters = ["command": description]
        }
        
        return WorkflowStepDefinition(
            name: "Step \(index + 1): \(description)",
            type: stepType,
            parameters: parameters,
            continueOnError: shouldContinueOnError(description),
            retryCount: determineRetryCount(stepType),
            timeout: determineTimeout(stepType)
        )
    }
    
    private func extractFileOperationParameters(_ description: String, classification: TaskClassificationResult) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // Extract operation type
        if description.lowercased().contains("copy") {
            parameters["operation"] = "copy"
        } else if description.lowercased().contains("move") {
            parameters["operation"] = "move"
        } else if description.lowercased().contains("delete") {
            parameters["operation"] = "delete"
        } else if description.lowercased().contains("rename") {
            parameters["operation"] = "rename"
        }
        
        // Extract file paths from classification parameters
        if let source = classification.parameters["source"] {
            parameters["source"] = source
        }
        if let destination = classification.parameters["destination"] {
            parameters["destination"] = destination
        }
        if let files = classification.parameters["files"] {
            parameters["files"] = files
        }
        
        return parameters
    }
    
    private func extractAppControlParameters(_ description: String, classification: TaskClassificationResult) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        parameters["command"] = description
        
        if let app = classification.parameters["app"] {
            parameters["app"] = app
        }
        
        // Extract specific app actions
        if description.lowercased().contains("open") {
            parameters["action"] = "open"
        } else if description.lowercased().contains("close") {
            parameters["action"] = "close"
        } else if description.lowercased().contains("send email") {
            parameters["action"] = "compose_email"
        } else if description.lowercased().contains("create event") {
            parameters["action"] = "create_calendar_event"
        }
        
        return parameters
    }
    
    private func extractSystemCommandParameters(_ description: String, classification: TaskClassificationResult) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        parameters["query"] = description
        
        // Extract query type
        if description.lowercased().contains("battery") {
            parameters["queryType"] = "battery"
        } else if description.lowercased().contains("storage") || description.lowercased().contains("disk") {
            parameters["queryType"] = "storage"
        } else if description.lowercased().contains("memory") || description.lowercased().contains("ram") {
            parameters["queryType"] = "memory"
        }
        
        return parameters
    }
    
    private func extractTextProcessingParameters(_ description: String, classification: TaskClassificationResult) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        if description.lowercased().contains("uppercase") {
            parameters["operation"] = "uppercase"
        } else if description.lowercased().contains("lowercase") {
            parameters["operation"] = "lowercase"
        } else if description.lowercased().contains("trim") {
            parameters["operation"] = "trim"
        } else if description.lowercased().contains("length") || description.lowercased().contains("count") {
            parameters["operation"] = "length"
        }
        
        // Extract text source
        if let text = classification.parameters["text"] {
            parameters["text"] = text
        }
        
        return parameters
    }
    
    private func extractVariables(from descriptions: [String]) -> [String: Any] {
        var variables: [String: Any] = [:]
        
        // Look for common variable patterns
        for description in descriptions {
            // Extract file paths that might be variables
            let pathPattern = #"[~/][^\s]+"#
            if let regex = try? NSRegularExpression(pattern: pathPattern) {
                let matches = regex.matches(in: description, range: NSRange(description.startIndex..., in: description))
                for match in matches {
                    if let range = Range(match.range, in: description) {
                        let path = String(description[range])
                        let variableName = "path_\(variables.count + 1)"
                        variables[variableName] = path
                    }
                }
            }
        }
        
        return variables
    }
    
    private func extractTags(from description: String) -> [String] {
        var tags: [String] = []
        
        // Extract tags based on content
        if description.lowercased().contains("file") {
            tags.append("file-management")
        }
        if description.lowercased().contains("email") || description.lowercased().contains("mail") {
            tags.append("email")
        }
        if description.lowercased().contains("calendar") || description.lowercased().contains("event") {
            tags.append("calendar")
        }
        if description.lowercased().contains("backup") {
            tags.append("backup")
        }
        if description.lowercased().contains("organize") {
            tags.append("organization")
        }
        
        return tags
    }
    
    private func generateWorkflowName(from description: String) -> String {
        // Generate a concise name from the description
        let words = description.components(separatedBy: .whitespacesAndNewlines)
        let significantWords = words.prefix(4).joined(separator: " ")
        return significantWords.capitalized
    }
    
    private func shouldContinueOnError(_ description: String) -> Bool {
        // Determine if the step should continue on error based on keywords
        let continueKeywords = ["optional", "if possible", "try to"]
        return continueKeywords.contains { description.lowercased().contains($0) }
    }
    
    private func determineRetryCount(_ stepType: WorkflowStepType) -> Int {
        switch stepType {
        case .fileOperation:
            return 2
        case .appControl:
            return 1
        case .systemCommand:
            return 1
        case .textProcessing:
            return 0
        default:
            return 1
        }
    }
    
    private func determineTimeout(_ stepType: WorkflowStepType) -> TimeInterval {
        switch stepType {
        case .fileOperation:
            return 60.0
        case .appControl:
            return 30.0
        case .systemCommand:
            return 15.0
        case .userInput:
            return 300.0 // 5 minutes for user input
        case .delay:
            return 3600.0 // 1 hour max delay
        default:
            return 30.0
        }
    }
    
    private func optimizeSteps(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        // Remove duplicate steps
        var optimizedSteps: [WorkflowStepDefinition] = []
        var seenSteps: Set<String> = []
        
        for step in steps {
            let stepKey = "\(step.type.rawValue)_\(step.parameters.keys.sorted().joined(separator: "_"))"
            if !seenSteps.contains(stepKey) {
                optimizedSteps.append(step)
                seenSteps.insert(stepKey)
            }
        }
        
        return optimizedSteps
    }
    
    // MARK: - Validation Methods
    
    private func validateStep(_ step: WorkflowStepDefinition, index: Int, workflow: WorkflowDefinition) -> [WorkflowValidationIssue] {
        var issues: [WorkflowValidationIssue] = []
        
        // Validate required parameters for each step type
        switch step.type {
        case .fileOperation:
            if step.parameters["operation"] == nil {
                issues.append(WorkflowValidationIssue(
                    type: .missingParameter,
                    message: "File operation step missing 'operation' parameter",
                    stepIndex: index
                ))
            }
        case .appControl:
            if step.parameters["command"] == nil {
                issues.append(WorkflowValidationIssue(
                    type: .missingParameter,
                    message: "App control step missing 'command' parameter",
                    stepIndex: index
                ))
            }
        case .delay:
            if step.parameters["duration"] == nil {
                issues.append(WorkflowValidationIssue(
                    type: .missingParameter,
                    message: "Delay step missing 'duration' parameter",
                    stepIndex: index
                ))
            }
        default:
            break
        }
        
        return issues
    }
    
    private func hasCircularDependencies(_ workflow: WorkflowDefinition) -> Bool {
        // Simple check for circular dependencies
        // In a more complex implementation, this would build a dependency graph
        return false
    }
    
    private func findUnreachableSteps(_ workflow: WorkflowDefinition) -> [Int] {
        // Find steps that might be unreachable due to conditions
        var unreachableSteps: [Int] = []
        
        for (index, step) in workflow.steps.enumerated() {
            if let condition = step.condition {
                // Check if condition can ever be true
                if isConditionAlwaysFalse(condition) {
                    unreachableSteps.append(index)
                }
            }
        }
        
        return unreachableSteps
    }
    
    private func isConditionAlwaysFalse(_ condition: WorkflowCondition) -> Bool {
        // Simple check for obviously false conditions
        switch condition.type {
        case .equals:
            if let value = condition.value.value as? String, value.isEmpty {
                return true
            }
        default:
            break
        }
        return false
    }
    
    // MARK: - Optimization Methods
    
    private func removeRedundantSteps(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        // Remove steps that have the same effect
        return steps // Placeholder implementation
    }
    
    private func reorderStepsForPerformance(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        // Reorder steps to minimize execution time
        return steps // Placeholder implementation
    }
    
    private func mergeCompatibleSteps(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        // Merge steps that can be executed together
        return steps // Placeholder implementation
    }
    
    // MARK: - Template Methods
    
    private func expandTemplateStep(_ step: WorkflowStepDefinition, parameters: [String: Any]) -> WorkflowStepDefinition {
        var expandedParameters = step.parameters
        
        for (key, value) in expandedParameters {
            if let stringValue = value.value as? String {
                expandedParameters[key] = AnyCodable(expandTemplate(stringValue, parameters: parameters))
            }
        }
        
        return WorkflowStepDefinition(
            id: step.id,
            name: expandTemplate(step.name, parameters: parameters),
            type: step.type,
            parameters: expandedParameters.mapValues { $0.value },
            continueOnError: step.continueOnError,
            retryCount: step.retryCount,
            timeout: step.timeout,
            condition: step.condition
        )
    }
    
    private func expandTemplate(_ template: String, parameters: [String: Any]) -> String {
        var result = template
        
        for (key, value) in parameters {
            result = result.replacingOccurrences(of: "{{\\(key)}}", with: "\(value)")
        }
        
        return result
    }
    
    // MARK: - Advanced Natural Language Processing
    
    /// Create workflow from complex natural language descriptions with context awareness
    func buildAdvancedWorkflowFromDescription(_ description: String, context: WorkflowContext? = nil) async throws -> WorkflowDefinition {
        isBuilding = true
        buildProgress = 0.0
        
        defer {
            isBuilding = false
            buildProgress = 0.0
        }
        
        // Step 1: Analyze the description for workflow patterns
        buildProgress = 0.1
        let workflowAnalysis = try await analyzeWorkflowDescription(description)
        
        // Step 2: Extract workflow metadata
        buildProgress = 0.2
        let metadata = extractWorkflowMetadata(description, analysis: workflowAnalysis)
        
        // Step 3: Generate workflow steps with AI assistance
        buildProgress = 0.3
        let steps = try await generateWorkflowSteps(description, analysis: workflowAnalysis, context: context)
        
        // Step 4: Optimize and validate workflow
        buildProgress = 0.7
        let optimizedSteps = optimizeWorkflowSteps(steps)
        let validatedSteps = try await validateAndFixSteps(optimizedSteps)
        
        // Step 5: Create final workflow definition
        buildProgress = 0.9
        let workflow = WorkflowDefinition(
            name: metadata.name,
            description: description,
            steps: validatedSteps,
            variables: metadata.variables,
            triggers: metadata.triggers,
            tags: metadata.tags
        )
        
        buildProgress = 1.0
        return workflow
    }
    
    /// Generate workflow templates from successful workflows
    func generateWorkflowTemplate(from workflow: WorkflowDefinition, templateName: String? = nil) -> WorkflowTemplate {
        let parameterizedSteps = parameterizeWorkflowSteps(workflow.steps)
        let templateVariables = extractTemplateVariables(from: parameterizedSteps)
        
        return WorkflowTemplate(
            name: templateName ?? "\(workflow.name) Template",
            description: "Template based on: \(workflow.description)",
            steps: parameterizedSteps,
            variables: templateVariables,
            triggers: workflow.triggers,
            tags: workflow.tags + ["template"]
        )
    }
    
    /// Share workflow as exportable template
    func exportWorkflowTemplate(_ template: WorkflowTemplate) throws -> Data {
        let exportData = WorkflowTemplateExport(
            template: template,
            version: "1.0",
            createdAt: Date(),
            compatibility: ["macOS 13.0+"]
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    /// Import workflow template from data
    func importWorkflowTemplate(from data: Data) throws -> WorkflowTemplate {
        let exportData = try JSONDecoder().decode(WorkflowTemplateExport.self, from: data)
        return exportData.template
    }
    
    // MARK: - Private Advanced Methods
    
    private func analyzeWorkflowDescription(_ description: String) async throws -> WorkflowAnalysis {
        let messages = [
            ChatModels.ChatMessage(
                content: """
                Analyze the following workflow description and identify:
                1. The main goal/purpose
                2. Sequential vs parallel steps
                3. Conditional logic
                4. Variables and parameters
                5. Error handling requirements
                6. Estimated complexity
                
                Description: \(description)
                
                Respond in JSON format with the analysis.
                """,
                isUserMessage: true
            )
        ]
        
        let response = try await aiService.generateCompletion(messages: messages)
        let responseText = response.choices.first?.message.content ?? "{}"
        
        guard let data = responseText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback to basic analysis
            return WorkflowAnalysis(
                purpose: extractPurpose(from: description),
                complexity: .moderate,
                hasConditionalLogic: description.lowercased().contains("if") || description.lowercased().contains("when"),
                hasParallelSteps: description.lowercased().contains("simultaneously") || description.lowercased().contains("parallel"),
                estimatedSteps: estimateStepCount(from: description),
                requiredVariables: extractVariableNames(from: description)
            )
        }
        
        return WorkflowAnalysis(
            purpose: json["purpose"] as? String ?? "Automated workflow",
            complexity: TaskComplexity(rawValue: json["complexity"] as? String ?? "moderate") ?? .moderate,
            hasConditionalLogic: json["hasConditionalLogic"] as? Bool ?? false,
            hasParallelSteps: json["hasParallelSteps"] as? Bool ?? false,
            estimatedSteps: json["estimatedSteps"] as? Int ?? 3,
            requiredVariables: json["requiredVariables"] as? [String] ?? []
        )
    }
    
    private func extractWorkflowMetadata(_ description: String, analysis: WorkflowAnalysis) -> WorkflowMetadata {
        let name = generateWorkflowName(from: description)
        let variables = analysis.requiredVariables.reduce(into: [String: Any]()) { result, variable in
            result[variable] = ""
        }
        
        let triggers = inferTriggers(from: description)
        let tags = generateTags(from: description, analysis: analysis)
        
        return WorkflowMetadata(
            name: name,
            variables: variables,
            triggers: triggers,
            tags: tags
        )
    }
    
    private func generateWorkflowSteps(_ description: String, analysis: WorkflowAnalysis, context: WorkflowContext?) async throws -> [WorkflowStepDefinition] {
        let messages = [
            ChatModels.ChatMessage(
                content: """
                Create detailed workflow steps for the following description.
                Consider the analysis: \(analysis)
                
                Generate steps that are:
                1. Specific and actionable
                2. Properly sequenced
                3. Include error handling
                4. Have appropriate parameters
                
                Description: \(description)
                
                Return as a JSON array of step objects with: name, type, parameters, continueOnError, retryCount, timeout
                """,
                isUserMessage: true
            )
        ]
        
        let response = try await aiService.generateCompletion(messages: messages)
        let responseText = response.choices.first?.message.content ?? "[]"
        
        // Parse AI response and convert to WorkflowStepDefinition objects
        guard let data = responseText.data(using: .utf8),
              let stepsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Fallback to basic step generation
            return try await parseStepDescriptions(description).enumerated().map { index, stepDescription in
                return try await buildWorkflowStep(stepDescription, index: index)
            }
        }
        
        return stepsArray.enumerated().compactMap { index, stepData in
            guard let name = stepData["name"] as? String,
                  let typeString = stepData["type"] as? String,
                  let type = WorkflowStepType(rawValue: typeString) else {
                return nil
            }
            
            let parameters = stepData["parameters"] as? [String: Any] ?? [:]
            let continueOnError = stepData["continueOnError"] as? Bool ?? false
            let retryCount = stepData["retryCount"] as? Int ?? 0
            let timeout = stepData["timeout"] as? TimeInterval ?? 30.0
            
            return WorkflowStepDefinition(
                name: name,
                type: type,
                parameters: parameters,
                continueOnError: continueOnError,
                retryCount: retryCount,
                timeout: timeout
            )
        }
    }
    
    private func optimizeWorkflowSteps(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        var optimized = steps
        
        // Remove redundant steps
        optimized = removeRedundantSteps(optimized)
        
        // Merge compatible file operations
        optimized = mergeFileOperations(optimized)
        
        // Optimize step ordering
        optimized = optimizeStepOrdering(optimized)
        
        return optimized
    }
    
    private func validateAndFixSteps(_ steps: [WorkflowStepDefinition]) async throws -> [WorkflowStepDefinition] {
        var validatedSteps: [WorkflowStepDefinition] = []
        
        for step in steps {
            var validatedStep = step
            
            // Fix missing parameters
            validatedStep = fixMissingParameters(validatedStep)
            
            // Validate file paths
            validatedStep = validateFilePaths(validatedStep)
            
            // Set appropriate timeouts
            validatedStep = adjustTimeouts(validatedStep)
            
            validatedSteps.append(validatedStep)
        }
        
        return validatedSteps
    }
    
    private func parameterizeWorkflowSteps(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        return steps.map { step in
            var parameterizedStep = step
            var newParameters: [String: Any] = [:]
            
            for (key, value) in step.parameters {
                if let stringValue = value.value as? String {
                    // Convert specific values to template variables
                    let parameterizedValue = parameterizeValue(stringValue)
                    newParameters[key] = parameterizedValue
                } else {
                    newParameters[key] = value.value
                }
            }
            
            return WorkflowStepDefinition(
                id: parameterizedStep.id,
                name: parameterizedStep.name,
                type: parameterizedStep.type,
                parameters: newParameters,
                continueOnError: parameterizedStep.continueOnError,
                retryCount: parameterizedStep.retryCount,
                timeout: parameterizedStep.timeout,
                condition: parameterizedStep.condition
            )
        }
    }
    
    private func extractTemplateVariables(from steps: [WorkflowStepDefinition]) -> [String: AnyCodable] {
        var variables: [String: AnyCodable] = [:]
        
        for step in steps {
            for (_, value) in step.parameters {
                if let stringValue = value.value as? String {
                    let variableMatches = extractVariableReferences(from: stringValue)
                    for variable in variableMatches {
                        variables[variable] = AnyCodable("")
                    }
                }
            }
        }
        
        return variables
    }
    
    // MARK: - Helper Methods
    
    private func extractPurpose(from description: String) -> String {
        let sentences = description.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        return sentences.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "Automated workflow"
    }
    
    private func estimateStepCount(from description: String) -> Int {
        let keywords = ["then", "next", "after", "finally", "and", "also"]
        let count = keywords.reduce(0) { count, keyword in
            count + description.lowercased().components(separatedBy: keyword).count - 1
        }
        return max(1, count + 1)
    }
    
    private func extractVariableNames(from description: String) -> [String] {
        let pattern = #"\{([^}]+)\}"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: description, range: NSRange(description.startIndex..., in: description))
        
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: description) {
                return String(description[range])
            }
            return nil
        }
    }
    
    private func inferTriggers(from description: String) -> [WorkflowTrigger] {
        var triggers: [WorkflowTrigger] = []
        
        if description.lowercased().contains("daily") || description.lowercased().contains("every day") {
            triggers.append(WorkflowTrigger(
                type: .scheduled,
                parameters: ["schedule": "0 9 * * *"] // Daily at 9 AM
            ))
        }
        
        if description.lowercased().contains("when") && description.lowercased().contains("file") {
            triggers.append(WorkflowTrigger(
                type: .fileChanged,
                parameters: ["path": "~/Downloads"]
            ))
        }
        
        if triggers.isEmpty {
            triggers.append(WorkflowTrigger(type: .manual))
        }
        
        return triggers
    }
    
    private func generateTags(from description: String, analysis: WorkflowAnalysis) -> [String] {
        var tags: [String] = []
        
        // Add complexity tag
        tags.append(analysis.complexity.rawValue)
        
        // Add purpose-based tags
        if description.lowercased().contains("backup") {
            tags.append("backup")
        }
        if description.lowercased().contains("organize") || description.lowercased().contains("clean") {
            tags.append("organization")
        }
        if description.lowercased().contains("email") || description.lowercased().contains("mail") {
            tags.append("email")
        }
        if description.lowercased().contains("file") {
            tags.append("file-management")
        }
        
        return tags
    }
    
    private func mergeFileOperations(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        // Implementation for merging compatible file operations
        return steps
    }
    
    private func optimizeStepOrdering(_ steps: [WorkflowStepDefinition]) -> [WorkflowStepDefinition] {
        // Implementation for optimizing step order
        return steps
    }
    
    private func fixMissingParameters(_ step: WorkflowStepDefinition) -> WorkflowStepDefinition {
        var parameters = step.parameters
        
        switch step.type {
        case .fileOperation:
            if parameters["operation"] == nil {
                parameters["operation"] = AnyCodable("copy")
            }
        case .delay:
            if parameters["duration"] == nil {
                parameters["duration"] = AnyCodable(1.0)
            }
        default:
            break
        }
        
        return WorkflowStepDefinition(
            id: step.id,
            name: step.name,
            type: step.type,
            parameters: parameters.mapValues { $0.value },
            continueOnError: step.continueOnError,
            retryCount: step.retryCount,
            timeout: step.timeout,
            condition: step.condition
        )
    }
    
    private func validateFilePaths(_ step: WorkflowStepDefinition) -> WorkflowStepDefinition {
        // Implementation for validating and fixing file paths
        return step
    }
    
    private func adjustTimeouts(_ step: WorkflowStepDefinition) -> WorkflowStepDefinition {
        let adjustedTimeout = determineTimeout(step.type)
        
        return WorkflowStepDefinition(
            id: step.id,
            name: step.name,
            type: step.type,
            parameters: step.parameters.mapValues { $0.value },
            continueOnError: step.continueOnError,
            retryCount: step.retryCount,
            timeout: adjustedTimeout,
            condition: step.condition
        )
    }
    
    private func parameterizeValue(_ value: String) -> String {
        // Convert specific file paths to template variables
        if value.hasPrefix("/") || value.hasPrefix("~/") {
            return "{{file_path}}"
        }
        
        // Convert app names to template variables
        let commonApps = ["Safari", "Mail", "Calendar", "Finder"]
        for app in commonApps {
            if value.lowercased().contains(app.lowercased()) {
                return "{{app_name}}"
            }
        }
        
        return value
    }
    
    private func extractVariableReferences(from text: String) -> [String] {
        let pattern = #"\{\{([^}]+)\}\}"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
            return nil
        }
    }
    
    // MARK: - Built-in Workflow Templates
    
    static let builtInTemplates: [WorkflowTemplateCategory: [WorkflowTemplate]] = [
        .fileManagement: [
            WorkflowTemplate(
                name: "Smart File Organization",
                description: "Automatically organize files by type and date",
                steps: [
                    WorkflowStepDefinition(
                        name: "Scan directory for files",
                        type: .fileOperation,
                        parameters: [
                            "operation": "scan",
                            "path": "{{source_directory}}",
                            "recursive": true
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Create organization folders",
                        type: .fileOperation,
                        parameters: [
                            "operation": "create_folders",
                            "base_path": "{{source_directory}}",
                            "structure": "by_type_and_date"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Move files to organized folders",
                        type: .fileOperation,
                        parameters: [
                            "operation": "organize",
                            "strategy": "by_type_and_date",
                            "preserve_structure": false
                        ]
                    )
                ],
                variables: [
                    "source_directory": AnyCodable("~/Downloads")
                ],
                triggers: [
                    WorkflowTrigger(type: .manual)
                ],
                tags: ["organization", "file-management", "automation"]
            ),
            
            WorkflowTemplate(
                name: "Duplicate File Cleanup",
                description: "Find and remove duplicate files to save space",
                steps: [
                    WorkflowStepDefinition(
                        name: "Scan for duplicate files",
                        type: .fileOperation,
                        parameters: [
                            "operation": "find_duplicates",
                            "path": "{{scan_directory}}",
                            "method": "hash_comparison"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Review duplicates",
                        type: .userInput,
                        parameters: [
                            "prompt": "Review found duplicates before deletion",
                            "type": "confirmation_list"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Remove selected duplicates",
                        type: .fileOperation,
                        parameters: [
                            "operation": "delete",
                            "move_to_trash": true,
                            "confirm_each": false
                        ]
                    )
                ],
                variables: [
                    "scan_directory": AnyCodable("~/Documents")
                ],
                triggers: [
                    WorkflowTrigger(type: .manual)
                ],
                tags: ["cleanup", "duplicates", "storage"]
            )
        ],
        
        .backup: [
            WorkflowTemplate(
                name: "Incremental Project Backup",
                description: "Create incremental backups of project directories",
                steps: [
                    WorkflowStepDefinition(
                        name: "Check backup destination",
                        type: .fileOperation,
                        parameters: [
                            "operation": "check_space",
                            "path": "{{backup_destination}}",
                            "required_space": "{{project_size}}"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Create backup directory",
                        type: .fileOperation,
                        parameters: [
                            "operation": "create_directory",
                            "path": "{{backup_destination}}/{{project_name}}_{{timestamp}}"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Copy project files",
                        type: .fileOperation,
                        parameters: [
                            "operation": "copy",
                            "source": "{{project_path}}",
                            "destination": "{{backup_destination}}/{{project_name}}_{{timestamp}}",
                            "incremental": true,
                            "exclude_patterns": [".git", "node_modules", ".DS_Store"]
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Verify backup integrity",
                        type: .fileOperation,
                        parameters: [
                            "operation": "verify",
                            "source": "{{project_path}}",
                            "backup": "{{backup_destination}}/{{project_name}}_{{timestamp}}"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Send completion notification",
                        type: .notification,
                        parameters: [
                            "title": "Backup Complete",
                            "message": "{{project_name}} backed up successfully",
                            "sound": true
                        ]
                    )
                ],
                variables: [
                    "project_path": AnyCodable(""),
                    "project_name": AnyCodable(""),
                    "backup_destination": AnyCodable(""),
                    "project_size": AnyCodable("1GB"),
                    "timestamp": AnyCodable("{{current_timestamp}}")
                ],
                triggers: [
                    WorkflowTrigger(
                        type: .scheduled,
                        parameters: ["schedule": "0 18 * * 1-5"] // Weekdays at 6 PM
                    )
                ],
                tags: ["backup", "project", "incremental", "automated"]
            )
        ],
        
        .productivity: [
            WorkflowTemplate(
                name: "Daily Workspace Setup",
                description: "Set up your workspace for a productive day",
                steps: [
                    WorkflowStepDefinition(
                        name: "Open essential applications",
                        type: .appControl,
                        parameters: [
                            "action": "open_apps",
                            "apps": ["{{email_app}}", "{{calendar_app}}", "{{notes_app}}"]
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Check calendar for today",
                        type: .appControl,
                        parameters: [
                            "app": "{{calendar_app}}",
                            "action": "show_today"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Create daily notes file",
                        type: .fileOperation,
                        parameters: [
                            "operation": "create_file",
                            "path": "{{notes_directory}}/Daily_{{date}}.md",
                            "template": "daily_notes"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Set focus mode",
                        type: .systemCommand,
                        parameters: [
                            "command": "set_focus_mode",
                            "mode": "work",
                            "duration": "4 hours"
                        ]
                    )
                ],
                variables: [
                    "email_app": AnyCodable("Mail"),
                    "calendar_app": AnyCodable("Calendar"),
                    "notes_app": AnyCodable("Notes"),
                    "notes_directory": AnyCodable("~/Documents/Daily Notes"),
                    "date": AnyCodable("{{current_date}}")
                ],
                triggers: [
                    WorkflowTrigger(
                        type: .scheduled,
                        parameters: ["schedule": "0 9 * * 1-5"] // Weekdays at 9 AM
                    )
                ],
                tags: ["productivity", "daily", "workspace", "routine"]
            )
        ],
        
        .maintenance: [
            WorkflowTemplate(
                name: "System Maintenance",
                description: "Perform routine system maintenance tasks",
                steps: [
                    WorkflowStepDefinition(
                        name: "Clear system caches",
                        type: .systemCommand,
                        parameters: [
                            "command": "clear_caches",
                            "types": ["user", "system", "font"]
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Empty trash",
                        type: .fileOperation,
                        parameters: [
                            "operation": "empty_trash",
                            "secure": false
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Update applications",
                        type: .systemCommand,
                        parameters: [
                            "command": "check_updates",
                            "auto_install": false
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Run disk utility",
                        type: .systemCommand,
                        parameters: [
                            "command": "disk_utility",
                            "action": "first_aid",
                            "disk": "startup"
                        ]
                    ),
                    WorkflowStepDefinition(
                        name: "Generate maintenance report",
                        type: .fileOperation,
                        parameters: [
                            "operation": "create_report",
                            "path": "~/Desktop/Maintenance_Report_{{date}}.txt",
                            "include_stats": true
                        ]
                    )
                ],
                variables: [
                    "date": AnyCodable("{{current_date}}")
                ],
                triggers: [
                    WorkflowTrigger(
                        type: .scheduled,
                        parameters: ["schedule": "0 2 * * 0"] // Sundays at 2 AM
                    )
                ],
                tags: ["maintenance", "system", "cleanup", "automated"]
            )
        ]
    ]
    
    /// Get all built-in templates
    static func getAllBuiltInTemplates() -> [WorkflowTemplate] {
        return builtInTemplates.values.flatMap { $0 }
    }
    
    /// Get templates by category
    static func getTemplates(for category: WorkflowTemplateCategory) -> [WorkflowTemplate] {
        return builtInTemplates[category] ?? []
    }
    
    /// Search templates by name or description
    static func searchTemplates(_ query: String) -> [WorkflowTemplate] {
        let allTemplates = getAllBuiltInTemplates()
        let lowercaseQuery = query.lowercased()
        
        return allTemplates.filter { template in
            template.name.lowercased().contains(lowercaseQuery) ||
            template.description.lowercased().contains(lowercaseQuery) ||
            template.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
}

// MARK: - Supporting Types

struct WorkflowTemplate {
    let name: String
    let description: String
    let steps: [WorkflowStepDefinition]
    let variables: [String: AnyCodable]
    let triggers: [WorkflowTrigger]
    let tags: [String]
}

struct WorkflowValidationResult {
    let isValid: Bool
    let issues: [WorkflowValidationIssue]
    let warnings: [WorkflowValidationWarning]
}

struct WorkflowValidationIssue {
    enum IssueType {
        case missingParameter
        case invalidParameter
        case circularDependency
        case unreachableStep
        case invalidCondition
    }
    
    let type: IssueType
    let message: String
    let stepIndex: Int?
}

struct WorkflowValidationWarning {
    enum WarningType {
        case unreachableStep
        case longTimeout
        case highRetryCount
        case performanceImpact
    }
    
    let type: WarningType
    let message: String
    let stepIndex: Int?
}

// MARK: - Advanced Workflow Types

struct WorkflowAnalysis {
    let purpose: String
    let complexity: TaskComplexity
    let hasConditionalLogic: Bool
    let hasParallelSteps: Bool
    let estimatedSteps: Int
    let requiredVariables: [String]
}

struct WorkflowMetadata {
    let name: String
    let variables: [String: Any]
    let triggers: [WorkflowTrigger]
    let tags: [String]
}

struct WorkflowContext {
    let userPreferences: [String: Any]
    let availableApps: [String]
    let systemInfo: [String: Any]
    let recentFiles: [URL]
}

struct WorkflowTemplateExport: Codable {
    let template: WorkflowTemplate
    let version: String
    let createdAt: Date
    let compatibility: [String]
}

// MARK: - Workflow Template Categories

enum WorkflowTemplateCategory: String, CaseIterable {
    case fileManagement = "file_management"
    case productivity = "productivity"
    case automation = "automation"
    case backup = "backup"
    case organization = "organization"
    case communication = "communication"
    case development = "development"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .fileManagement: return "File Management"
        case .productivity: return "Productivity"
        case .automation: return "Automation"
        case .backup: return "Backup"
        case .organization: return "Organization"
        case .communication: return "Communication"
        case .development: return "Development"
        case .maintenance: return "Maintenance"
        }
    }
    
    var icon: String {
        switch self {
        case .fileManagement: return "folder"
        case .productivity: return "checkmark.circle"
        case .automation: return "gearshape.2"
        case .backup: return "externaldrive"
        case .organization: return "tray.2"
        case .communication: return "envelope"
        case .development: return "hammer"
        case .maintenance: return "wrench"
        }
    }
}