import Foundation

// MARK: - OpenAI Client
class OpenAIClient {
    
    // MARK: - Properties
    private let session: URLSession
    private let baseURL: URL
    private var apiKey: String?
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AIConstants.openAITimeout
        config.timeoutIntervalForResource = AIConstants.openAITimeout * 2
        
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: AIConstants.openAIBaseURL)!
        self.apiKey = KeychainManager.shared.getAPIKey()
    }
    
    // MARK: - Public Methods
    
    /// Update API key from keychain
    func updateAPIKey() {
        self.apiKey = KeychainManager.shared.getAPIKey()
    }
    
    /// Generate completion (non-streaming)
    func generateCompletion(request: CompletionRequest) async throws -> CompletionResponse {
        guard let apiKey = apiKey else {
            throw OpenAIError.missingAPIKey
        }
        
        let url = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw OpenAIError.encodingError(error)
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded
            } else if httpResponse.statusCode >= 400 {
                throw OpenAIError.serverError(httpResponse.statusCode)
            }
            
            let completionResponse = try JSONDecoder().decode(CompletionResponse.self, from: data)
            return completionResponse
            
        } catch let error as OpenAIError {
            throw error
        } catch {
            throw OpenAIError.networkError(error)
        }
    }
    
    /// Stream completion with real-time response
    func streamCompletion(request: CompletionRequest) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        guard let apiKey = apiKey else {
            throw OpenAIError.missingAPIKey
        }
        
        let url = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var streamingRequest = request
        streamingRequest.stream = true
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(streamingRequest)
        } catch {
            throw OpenAIError.encodingError(error)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (asyncBytes, response) = try await session.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }
                    
                    if httpResponse.statusCode == 401 {
                        continuation.finish(throwing: OpenAIError.invalidAPIKey)
                        return
                    } else if httpResponse.statusCode == 429 {
                        continuation.finish(throwing: OpenAIError.rateLimitExceeded)
                        return
                    } else if httpResponse.statusCode >= 400 {
                        continuation.finish(throwing: OpenAIError.serverError(httpResponse.statusCode))
                        return
                    }
                    
                    var buffer = ""
                    
                    for try await byte in asyncBytes {
                        let character = Character(UnicodeScalar(byte)!)
                        buffer.append(character)
                        
                        if character == "\n" {
                            let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = ""
                            
                            if line.isEmpty { continue }
                            
                            if line == "data: [DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))
                                
                                if let data = jsonString.data(using: .utf8) {
                                    do {
                                        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
                                        continuation.yield(chunk)
                                    } catch {
                                        // Skip malformed chunks
                                        continue
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: OpenAIError.networkError(error))
                }
            }
        }
    }
}

// MARK: - OpenAI Error Types
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(Int)
    case networkError(Error)
    case encodingError(Error)
    case decodingError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Please add your API key in settings."
        case .invalidAPIKey:
            return "Invalid OpenAI API key. Please check your API key in settings."
        case .rateLimitExceeded:
            return "OpenAI rate limit exceeded. Please wait a moment and try again."
        case .serverError(let code):
            return "OpenAI server error (code: \(code)). Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Request encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Response decoding error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey, .invalidAPIKey:
            return "Please check your OpenAI API key in the settings panel."
        case .rateLimitExceeded:
            return "Wait a few moments before making another request."
        case .serverError, .networkError:
            return "Check your internet connection and try again."
        case .encodingError, .decodingError, .invalidResponse:
            return "This appears to be a technical issue. Please contact support if it persists."
        }
    }
}