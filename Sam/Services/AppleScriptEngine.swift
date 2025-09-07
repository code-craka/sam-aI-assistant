import Foundation
import OSAKit

/// AppleScript engine for advanced app automation
/// Provides dynamic script generation, compilation, caching, and execution
class AppleScriptEngine: ObservableObject {
    
    // MARK: - Types
    
    enum ScriptError: LocalizedError {
        case compilationFailed(String)
        case executionFailed(String)
        case permissionDenied
        case scriptNotFound(String)
        case invalidTemplate(String)
        
        var errorDescription: String? {
            switch self {
            case .compilationFailed(let message):
                return "AppleScript compilation failed: \(message)"
            case .executionFailed(let message):
                return "AppleScript execution failed: \(message)"
            case .permissionDenied:
                return "Permission denied for automation. Please enable in System Preferences > Security & Privacy > Privacy > Automation"
            case .scriptNotFound(let name):
                return "Script template not found: \(name)"
            case .invalidTemplate(let message):
                return "Invalid script template: \(message)"
            }
        }
    }
    
    struct ScriptResult {
        let success: Bool
        let output: String?
        let error: String?
        let executionTime: TimeInterval
    }
    
    struct CompiledScript {
        let script: OSAScript
        let source: String
        let compiledAt: Date
        let cacheKey: String
    }
    
    // MARK: - Properties
    
    private let scriptCache = NSCache<NSString, CompiledScript>()
    private let templateManager = ScriptTemplateManager()
    private let permissionManager = AutomationPermissionManager()
    
    @Published var isExecuting = false
    @Published var lastExecutionTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init() {
        setupCache()
        loadTemplates()
    }
    
    // MARK: - Public Methods
    
    /// Execute AppleScript with dynamic generation
    func executeScript(
        _ scriptSource: String,
        parameters: [String: Any] = [:],
        useCache: Bool = true
    ) async throws -> ScriptResult {
        let startTime = Date()
        
        do {
            // Check permissions
            try await checkAutomationPermissions()
            
            // Generate cache key
            let cacheKey = generateCacheKey(scriptSource, parameters: parameters)
            
            // Try to get compiled script from cache
            var compiledScript: CompiledScript?
            if useCache {
                compiledScript = scriptCache.object(forKey: cacheKey as NSString)
            }
            
            // Compile if not cached
            if compiledScript == nil {
                let processedSource = try processScriptTemplate(scriptSource, parameters: parameters)
                let script = try compileScript(processedSource)
                
                compiledScript = CompiledScript(
                    script: script,
                    source: processedSource,
                    compiledAt: Date(),
                    cacheKey: cacheKey
                )
                
                if useCache {
                    scriptCache.setObject(compiledScript!, forKey: cacheKey as NSString)
                }
            }
            
            // Execute script
            await MainActor.run {
                isExecuting = true
            }
            
            let result = try await executeCompiledScript(compiledScript!)
            let executionTime = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                isExecuting = false
                lastExecutionTime = executionTime
            }
            
            return ScriptResult(
                success: result.error == nil,
                output: result.output,
                error: result.error,
                executionTime: executionTime
            )
            
        } catch {
            await MainActor.run {
                isExecuting = false
            }
            throw error
        }
    }
    
    /// Execute script from template
    func executeTemplate(
        _ templateName: String,
        parameters: [String: Any] = [:]
    ) async throws -> ScriptResult {
        guard let template = templateManager.getTemplate(templateName) else {
            throw ScriptError.scriptNotFound(templateName)
        }
        
        return try await executeScript(template.source, parameters: parameters)
    }
    
    /// Generate script from natural language description
    func generateScript(
        for description: String,
        targetApp: String? = nil
    ) async throws -> String {
        return try await templateManager.generateFromDescription(description, targetApp: targetApp)
    }
    
    /// Clear script cache
    func clearCache() {
        scriptCache.removeAllObjects()
    }
    
    /// Get available templates
    func getAvailableTemplates() -> [ScriptTemplate] {
        return templateManager.getAllTemplates()
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        scriptCache.countLimit = 50
        scriptCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    private func loadTemplates() {
        templateManager.loadBuiltInTemplates()
    }
    
    private func checkAutomationPermissions() async throws {
        let hasPermission = await permissionManager.checkAutomationPermission()
        if !hasPermission {
            throw ScriptError.permissionDenied
        }
    }
    
    private func generateCacheKey(_ source: String, parameters: [String: Any]) -> String {
        let paramString = parameters.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "&")
        return "\(source.hashValue)_\(paramString.hashValue)"
    }
    
    private func processScriptTemplate(_ source: String, parameters: [String: Any]) throws -> String {
        var processedSource = source
        
        // Replace parameter placeholders
        for (key, value) in parameters {
            let placeholder = "{{\(key)}}"
            let stringValue = String(describing: value)
            processedSource = processedSource.replacingOccurrences(of: placeholder, with: stringValue)
        }
        
        // Validate processed script
        if processedSource.contains("{{") && processedSource.contains("}}") {
            throw ScriptError.invalidTemplate("Unresolved template parameters found")
        }
        
        return processedSource
    }
    
    private func compileScript(_ source: String) throws -> OSAScript {
        let script = OSAScript(source: source)
        
        var errorDict: NSDictionary?
        let compiled = script.compileAndReturnError(&errorDict)
        
        if !compiled, let error = errorDict {
            let errorMessage = error[OSAScriptErrorMessage] as? String ?? "Unknown compilation error"
            throw ScriptError.compilationFailed(errorMessage)
        }
        
        return script
    }
    
    private func executeCompiledScript(_ compiledScript: CompiledScript) async throws -> (output: String?, error: String?) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var errorDict: NSDictionary?
                let result = compiledScript.script.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    let errorMessage = error[OSAScriptErrorMessage] as? String ?? "Unknown execution error"
                    continuation.resume(returning: (output: nil, error: errorMessage))
                } else {
                    let output = result?.stringValue
                    continuation.resume(returning: (output: output, error: nil))
                }
            }
        }
    }
}