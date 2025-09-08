import Foundation

// MARK: - AI Models
enum AIModel: String, CaseIterable, Codable {
    case gpt4 = "gpt-4"
    case gpt4Turbo = "gpt-4-turbo-preview"
    case gpt35Turbo = "gpt-3.5-turbo"
    
    var displayName: String {
        switch self {
        case .gpt4: return "GPT-4"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .gpt4: return AIConstants.gpt4MaxTokens
        case .gpt4Turbo: return AIConstants.gpt4TurboMaxTokens
        case .gpt35Turbo: return AIConstants.gpt35TurboMaxTokens
        }
    }
    
    var costPerToken: Double {
        switch self {
        case .gpt4: return AIConstants.gpt4CostPerToken
        case .gpt4Turbo: return AIConstants.gpt4TurboCostPerToken
        case .gpt35Turbo: return AIConstants.gpt35TurboCostPerToken
        }
    }
    
    var isRecommended: Bool {
        return self == .gpt4Turbo
    }
}

// MARK: - Message Role
enum MessageRole: String, Codable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case function = "function"
}

// MARK: - API Message
struct APIMessage: Codable {
    let role: MessageRole
    let content: String?
    let name: String?
    let functionCall: FunctionCall?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case functionCall = "function_call"
    }
    
    init(role: MessageRole, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
        self.functionCall = nil
    }
    
    init(role: MessageRole, functionCall: FunctionCall, name: String? = nil) {
        self.role = role
        self.content = nil
        self.name = name
        self.functionCall = functionCall
    }
}

// MARK: - Function Call
struct FunctionCall: Codable {
    let name: String
    let arguments: String
}

// MARK: - Function Definition
struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: FunctionParameters
}

// MARK: - Function Parameters
struct FunctionParameters: Codable {
    let type: String
    let properties: [String: PropertyDefinition]
    let required: [String]?
    
    init(type: String = "object", properties: [String: PropertyDefinition], required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

// MARK: - Property Definition
indirect enum PropertyDefinition: Codable {
    case simple(type: String, description: String, enumValues: [String]?)
    case array(type: String, description: String, items: PropertyDefinition)
    case object(type: String, description: String, properties: [String: PropertyDefinition])
    
    var type: String {
        switch self {
        case .simple(let type, _, _), .array(let type, _, _), .object(let type, _, _):
            return type
        }
    }
    
    var description: String {
        switch self {
        case .simple(_, let description, _), .array(_, let description, _), .object(_, let description, _):
            return description
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
        case items
        case properties
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let description = try container.decode(String.self, forKey: .description)
        
        if type == "array" {
            let items = try container.decode(PropertyDefinition.self, forKey: .items)
            self = .array(type: type, description: description, items: items)
        } else if type == "object" {
            let properties = try container.decodeIfPresent([String: PropertyDefinition].self, forKey: .properties) ?? [:]
            self = .object(type: type, description: description, properties: properties)
        } else {
            let enumValues = try container.decodeIfPresent([String].self, forKey: .enumValues)
            self = .simple(type: type, description: description, enumValues: enumValues)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .simple(let type, let description, let enumValues):
            try container.encode(type, forKey: .type)
            try container.encode(description, forKey: .description)
            try container.encodeIfPresent(enumValues, forKey: .enumValues)
        case .array(let type, let description, let items):
            try container.encode(type, forKey: .type)
            try container.encode(description, forKey: .description)
            try container.encode(items, forKey: .items)
        case .object(let type, let description, let properties):
            try container.encode(type, forKey: .type)
            try container.encode(description, forKey: .description)
            try container.encode(properties, forKey: .properties)
        }
    }
}

// MARK: - Completion Request
struct CompletionRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Float?
    let maxTokens: Int?
    let topP: Float?
    let frequencyPenalty: Float?
    let presencePenalty: Float?
    let stop: [String]?
    let stream: Bool?
    let functions: [FunctionDefinition]?
    let functionCall: String?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case stop
        case stream
        case functions
        case functionCall = "function_call"
    }
    
    init(
        model: String,
        messages: [APIMessage],
        temperature: Float? = nil,
        maxTokens: Int? = nil,
        topP: Float? = nil,
        frequencyPenalty: Float? = nil,
        presencePenalty: Float? = nil,
        stop: [String]? = nil,
        stream: Bool? = nil,
        functions: [FunctionDefinition]? = nil,
        functionCall: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stop = stop
        self.stream = stream
        self.functions = functions
        self.functionCall = functionCall
    }
}

// MARK: - Completion Response
struct CompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: APIMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Stream Chunk
struct StreamChunk: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Codable {
        let role: MessageRole?
        let content: String?
        let functionCall: FunctionCall?
        
        enum CodingKeys: String, CodingKey {
            case role
            case content
            case functionCall = "function_call"
        }
    }
}

// MARK: - Connection Status
enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

// MARK: - AI Service Error
enum AIServiceError: LocalizedError {
    case invalidResponse
    case functionCallFailed(String)
    case contextTooLarge
    case modelNotAvailable(String)
    case rateLimitExceeded
    case insufficientCredits
    case networkTimeout
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .functionCallFailed(let function):
            return "Function call failed: \(function)"
        case .contextTooLarge:
            return "Context is too large for the selected model"
        case .modelNotAvailable(let model):
            return "Model not available: \(model)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .insufficientCredits:
            return "Insufficient API credits"
        case .networkTimeout:
            return "Network request timed out"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidResponse:
            return "Please try again or contact support"
        case .functionCallFailed:
            return "Check the function parameters and try again"
        case .contextTooLarge:
            return "Try reducing the conversation history or input size"
        case .modelNotAvailable:
            return "Select a different model in settings"
        case .rateLimitExceeded:
            return "Wait a moment before making another request"
        case .insufficientCredits:
            return "Add credits to your OpenAI account"
        case .networkTimeout:
            return "Check your internet connection and try again"
        case .authenticationFailed:
            return "Verify your API key in settings"
        }
    }
}