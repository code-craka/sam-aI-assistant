import Foundation
import Combine

// MARK: - AI Service
@MainActor
class AIService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentUsage = ChatModels.UsageMetrics()
    @Published var isStreaming = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    private let client: OpenAIClient
    private let costTracker: CostTracker
    private let contextManager: ContextManager
    private let rateLimiter: RateLimiter
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.client = OpenAIClient()
        self.costTracker = CostTracker()
        self.contextManager = ContextManager()
        self.rateLimiter = RateLimiter()
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Stream completion with real-time response
    func streamCompletion(
        messages: [ChatModels.ChatMessage],
        model: AIModel = .gpt4Turbo,
        functions: [FunctionDefinition]? = nil,
        temperature: Float = AIConstants.openAITemperature
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Check rate limits
                    try await rateLimiter.checkRateLimit()
                    
                    // Update streaming state
                    await MainActor.run {
                        self.isStreaming = true
                        self.connectionStatus = .connecting
                    }
                    
                    // Convert messages to API format
                    let apiMessages = messages.compactMap { convertToAPIMessage($0) }
                    
                    // Create request
                    let request = CompletionRequest(
                        model: model.rawValue,
                        messages: apiMessages,
                        temperature: temperature,
                        maxTokens: model.maxTokens,
                        stream: true,
                        functions: functions
                    )
                    
                    // Start streaming
                    let stream = try await client.streamCompletion(request: request)
                    
                    await MainActor.run {
                        self.connectionStatus = .connected
                    }
                    
                    var totalTokens = 0
                    var responseContent = ""
                    
                    for try await chunk in stream {
                        if let content = chunk.choices.first?.delta.content {
                            responseContent += content
                            continuation.yield(content)
                            
                            // Track tokens (approximate)
                            totalTokens += estimateTokens(content)
                        }
                        
                        // Handle function calls
                        if let functionCall = chunk.choices.first?.delta.functionCall {
                            try await handleFunctionCall(functionCall, continuation: continuation)
                        }
                    }
                    
                    // Update usage metrics
                    await updateUsageMetrics(
                        tokens: totalTokens,
                        cost: costTracker.calculateCost(tokens: totalTokens, model: model),
                        model: model
                    )
                    
                    continuation.finish()
                    
                } catch {
                    await MainActor.run {
                        self.connectionStatus = .error(error.localizedDescription)
                        self.isStreaming = false
                    }
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Generate single completion (non-streaming)
    func generateCompletion(
        messages: [ChatModels.ChatMessage],
        model: AIModel = .gpt4Turbo,
        functions: [FunctionDefinition]? = nil,
        temperature: Float = AIConstants.openAITemperature
    ) async throws -> CompletionResponse {
        
        try await rateLimiter.checkRateLimit()
        
        let apiMessages = messages.compactMap { convertToAPIMessage($0) }
        
        let request = CompletionRequest(
            model: model.rawValue,
            messages: apiMessages,
            temperature: temperature,
            maxTokens: model.maxTokens,
            stream: false,
            functions: functions
        )
        
        let response = try await client.generateCompletion(request: request)
        
        // Update usage metrics
        if let usage = response.usage {
            await updateUsageMetrics(
                tokens: usage.totalTokens,
                cost: costTracker.calculateCost(tokens: usage.totalTokens, model: model),
                model: model
            )
        }
        
        return response
    }
    
    /// Classify task with AI assistance
    func classifyTask(_ input: String) async throws -> TaskClassificationResult {
        let systemMessage = createTaskClassificationSystemMessage()
        let userMessage = APIMessage(role: .user, content: input)
        
        let request = CompletionRequest(
            model: AIModel.gpt35Turbo.rawValue,
            messages: [systemMessage, userMessage],
            temperature: 0.1,
            maxTokens: 500,
            functions: [createTaskClassificationFunction()]
        )
        
        let response = try await client.generateCompletion(request: request)
        
        guard let choice = response.choices.first,
              let functionCall = choice.message.functionCall,
              functionCall.name == "classify_task" else {
            throw AIServiceError.invalidResponse
        }
        
        return try parseTaskClassificationResult(functionCall.arguments)
    }
    
    /// Get current usage statistics
    func getUsageStatistics() -> ChatModels.UsageMetrics {
        return currentUsage
    }
    
    /// Reset usage statistics
    func resetUsageStatistics() {
        currentUsage = ChatModels.UsageMetrics()
        costTracker.reset()
    }
    
    /// Check if service is available
    func checkAvailability() async -> Bool {
        do {
            let testRequest = CompletionRequest(
                model: AIModel.gpt35Turbo.rawValue,
                messages: [APIMessage(role: .user, content: "test")],
                maxTokens: 1
            )
            _ = try await client.generateCompletion(request: testRequest)
            await MainActor.run {
                self.connectionStatus = .connected
            }
            return true
        } catch {
            await MainActor.run {
                self.connectionStatus = .error(error.localizedDescription)
            }
            return false
        }
    }
}

// MARK: - Private Methods
private extension AIService {
    
    func setupObservers() {
        // Observe API key changes
        NotificationCenter.default.publisher(for: .apiKeyUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.client.updateAPIKey()
                }
            }
            .store(in: &cancellables)
    }
    
    func convertToAPIMessage(_ message: ChatModels.ChatMessage) -> APIMessage? {
        guard !message.isDeleted else { return nil }
        
        let role: MessageRole = message.isUserMessage ? .user : .assistant
        return APIMessage(role: role, content: message.content)
    }
    
    func handleFunctionCall(
        _ functionCall: FunctionCall,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        // Handle function calls for structured task execution
        switch functionCall.name {
        case "execute_file_operation":
            let result = try await executeFunctionCall(functionCall)
            continuation.yield("Function executed: \(result)")
            
        case "get_system_info":
            let result = try await executeFunctionCall(functionCall)
            continuation.yield("System info: \(result)")
            
        case "control_application":
            let result = try await executeFunctionCall(functionCall)
            continuation.yield("App control: \(result)")
            
        default:
            continuation.yield("Unknown function: \(functionCall.name)")
        }
    }
    
    func executeFunctionCall(_ functionCall: FunctionCall) async throws -> String {
        // This would integrate with other services to execute the function
        // For now, return a placeholder
        return "Function \(functionCall.name) executed with arguments: \(functionCall.arguments)"
    }
    
    func updateUsageMetrics(tokens: Int, cost: Double, model: AIModel) async {
        await MainActor.run {
            self.currentUsage = ChatModels.UsageMetrics(
                totalMessages: self.currentUsage.totalMessages + 1,
                totalTokens: self.currentUsage.totalTokens + tokens,
                totalCost: self.currentUsage.totalCost + cost,
                averageResponseTime: self.currentUsage.averageResponseTime, // Would be calculated properly
                successfulTasks: self.currentUsage.successfulTasks + 1,
                failedTasks: self.currentUsage.failedTasks
            )
        }
        
        // Track in cost tracker
        await costTracker.trackUsage(tokens: tokens, cost: cost, model: model)
    }
    
    func estimateTokens(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return max(1, text.count / 4)
    }
    
    func createTaskClassificationSystemMessage() -> APIMessage {
        let systemPrompt = """
        You are a task classification system for a macOS AI assistant. Analyze user input and classify it into one of these categories:
        - file_operation: File/folder operations (copy, move, delete, organize, search)
        - system_query: System information requests (battery, memory, storage, network)
        - app_control: Application control (open, close, interact with apps)
        - text_processing: Text analysis, summarization, translation
        - calculation: Mathematical calculations or data analysis
        - web_query: Web searches or online information requests
        - automation: Multi-step workflows or complex task sequences
        - settings: App configuration or preference changes
        - help: Help requests or feature explanations
        
        Respond with confidence level (0.0-1.0), extracted parameters, and processing requirements.
        """
        
        return APIMessage(role: .system, content: systemPrompt)
    }
    
    func createTaskClassificationFunction() -> FunctionDefinition {
        return FunctionDefinition(
            name: "classify_task",
            description: "Classify user input into task categories",
            parameters: FunctionParameters(
                type: "object",
                properties: [
                    "task_type": PropertyDefinition(
                        type: "string",
                        description: "The classified task type",
                        enumValues: TaskType.allCases.map { $0.rawValue }
                    ),
                    "confidence": PropertyDefinition(
                        type: "number",
                        description: "Confidence level (0.0-1.0)"
                    ),
                    "parameters": PropertyDefinition(
                        type: "object",
                        description: "Extracted parameters from the input"
                    ),
                    "complexity": PropertyDefinition(
                        type: "string",
                        description: "Task complexity level",
                        enumValues: ["simple", "moderate", "complex", "advanced"]
                    ),
                    "requires_confirmation": PropertyDefinition(
                        type: "boolean",
                        description: "Whether the task requires user confirmation"
                    )
                ],
                required: ["task_type", "confidence", "complexity"]
            )
        )
    }
    
    func parseTaskClassificationResult(_ arguments: String) throws -> TaskClassificationResult {
        guard let data = arguments.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }
        
        guard let taskTypeString = json["task_type"] as? String,
              let taskType = TaskType(rawValue: taskTypeString),
              let confidence = json["confidence"] as? Double,
              let complexityString = json["complexity"] as? String,
              let complexity = TaskComplexity(rawValue: complexityString) else {
            throw AIServiceError.invalidResponse
        }
        
        let parameters = (json["parameters"] as? [String: Any])?.compactMapValues { "\($0)" } ?? [:]
        let requiresConfirmation = json["requires_confirmation"] as? Bool ?? false
        
        return TaskClassificationResult(
            taskType: taskType,
            confidence: confidence,
            parameters: parameters,
            complexity: complexity,
            processingRoute: complexity.processingRoute,
            requiresConfirmation: requiresConfirmation
        )
    }
}