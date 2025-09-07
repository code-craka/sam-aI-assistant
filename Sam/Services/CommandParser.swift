import Foundation
import NaturalLanguage

// MARK: - Command Parser
class CommandParser: ObservableObject {
    
    // MARK: - Properties
    private let nlProcessor = NLLanguageRecognizer()
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .nameType])
    
    // Common app name mappings
    private let appNameMappings: [String: String] = [
        "mail": "com.apple.mail",
        "email": "com.apple.mail",
        "safari": "com.apple.Safari",
        "browser": "com.apple.Safari",
        "finder": "com.apple.finder",
        "files": "com.apple.finder",
        "calendar": "com.apple.iCal",
        "notes": "com.apple.Notes",
        "messages": "com.apple.MobileSMS",
        "text": "com.apple.MobileSMS",
        "photos": "com.apple.Photos",
        "music": "com.apple.Music",
        "itunes": "com.apple.Music",
        "preview": "com.apple.Preview",
        "textedit": "com.apple.TextEdit",
        "terminal": "com.apple.Terminal",
        "xcode": "com.apple.dt.Xcode",
        "photoshop": "com.adobe.Photoshop",
        "figma": "com.figma.Desktop",
        "sketch": "com.bohemiancoding.sketch3",
        "slack": "com.tinyspeck.slackmacgap",
        "discord": "com.hnc.Discord",
        "zoom": "us.zoom.xos"
    ]
    
    // Command patterns for different actions
    private let commandPatterns: [String: [String]] = [
        "launch": ["open", "launch", "start", "run"],
        "quit": ["quit", "close", "exit", "stop"],
        "create": ["create", "new", "make"],
        "send": ["send", "compose", "write"],
        "bookmark": ["bookmark", "save", "add to bookmarks"],
        "search": ["search", "find", "look for"],
        "play": ["play", "start playing"],
        "pause": ["pause", "stop playing"]
    ]
    
    // MARK: - Public Methods
    
    /// Parse natural language command into structured format
    func parseCommand(_ input: String) -> ParsedCommand {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract app name
        let targetApp = extractTargetApp(from: normalizedInput)
        
        // Extract action
        let action = extractAction(from: normalizedInput)
        
        // Extract parameters
        let parameters = extractParameters(from: normalizedInput, action: action)
        
        // Determine task type
        let taskType = determineTaskType(action: action, parameters: parameters)
        
        // Calculate confidence
        let confidence = calculateConfidence(
            input: normalizedInput,
            action: action,
            targetApp: targetApp,
            parameters: parameters
        )
        
        // Determine if confirmation is required
        let requiresConfirmation = determineConfirmationRequirement(
            action: action,
            parameters: parameters
        )
        
        return ParsedCommand(
            originalText: input,
            intent: taskType,
            parameters: parameters,
            confidence: confidence,
            requiresConfirmation: requiresConfirmation,
            targetApplication: targetApp
        )
    }
    
    /// Extract app-specific commands from natural language
    func extractAppCommands(_ input: String, for bundleId: String) -> [String: String] {
        var commands: [String: String] = [:]
        let normalizedInput = input.lowercased()
        
        // App-specific command extraction
        switch bundleId {
        case "com.apple.mail":
            commands = extractMailCommands(from: normalizedInput)
        case "com.apple.Safari":
            commands = extractSafariCommands(from: normalizedInput)
        case "com.apple.iCal":
            commands = extractCalendarCommands(from: normalizedInput)
        case "com.apple.finder":
            commands = extractFinderCommands(from: normalizedInput)
        default:
            commands = extractGenericCommands(from: normalizedInput)
        }
        
        return commands
    }
    
    // MARK: - Private Methods
    
    private func extractTargetApp(from input: String) -> String? {
        // Check for explicit app mentions
        for (keyword, bundleId) in appNameMappings {
            if input.contains(keyword) {
                return bundleId
            }
        }
        
        // Use NLP to find app names
        tagger.string = input
        let range = input.startIndex..<input.endIndex
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        
        var detectedApp: String?
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if tag == .organizationName || tag == .personalName {
                let token = String(input[tokenRange]).lowercased()
                if let bundleId = appNameMappings[token] {
                    detectedApp = bundleId
                    return false
                }
            }
            return true
        }
        
        return detectedApp
    }
    
    private func extractAction(from input: String) -> String {
        for (action, patterns) in commandPatterns {
            for pattern in patterns {
                if input.contains(pattern) {
                    return action
                }
            }
        }
        
        // Default action based on context
        if input.contains("to ") || input.contains("about ") {
            return "send"
        } else if input.contains("new ") || input.contains("create ") {
            return "create"
        } else {
            return "launch"
        }
    }
    
    private func extractParameters(from input: String, action: String) -> [String: String] {
        var parameters: [String: String] = [:]
        
        // Extract email addresses
        let emailRegex = try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)
        let emailMatches = emailRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if !emailMatches.isEmpty {
            let emailMatch = emailMatches.first!
            let email = String(input[Range(emailMatch.range, in: input)!])
            parameters["email"] = email
        }
        
        // Extract URLs
        let urlRegex = try! NSRegularExpression(pattern: #"https?://[^\s]+"#)
        let urlMatches = urlRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if !urlMatches.isEmpty {
            let urlMatch = urlMatches.first!
            let url = String(input[Range(urlMatch.range, in: input)!])
            parameters["url"] = url
        }
        
        // Extract quoted strings (subjects, titles, etc.)
        let quotedRegex = try! NSRegularExpression(pattern: #""([^"]+)""#)
        let quotedMatches = quotedRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if !quotedMatches.isEmpty {
            let quotedMatch = quotedMatches.first!
            let quoted = String(input[Range(quotedMatch.range(at: 1), in: input)!])
            parameters["subject"] = quoted
        }
        
        // Extract file paths
        let fileRegex = try! NSRegularExpression(pattern: #"[~/][^\s]+"#)
        let fileMatches = fileRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if !fileMatches.isEmpty {
            let fileMatch = fileMatches.first!
            let filePath = String(input[Range(fileMatch.range, in: input)!])
            parameters["file"] = filePath
        }
        
        // Extract time/date expressions
        if input.contains("at ") || input.contains("on ") {
            let timeRegex = try! NSRegularExpression(pattern: #"(?:at|on)\s+([^,\n]+)"#)
            let timeMatches = timeRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
            if !timeMatches.isEmpty {
                let timeMatch = timeMatches.first!
                let timeString = String(input[Range(timeMatch.range(at: 1), in: input)!])
                parameters["time"] = timeString.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return parameters
    }
    
    private func determineTaskType(action: String, parameters: [String: String]) -> TaskType {
        switch action {
        case "launch", "quit":
            return .appControl
        case "send":
            return parameters["email"] != nil ? .appControl : .textProcessing
        case "create":
            return .appControl
        case "bookmark":
            return .appControl
        case "search":
            return .webQuery
        case "play", "pause":
            return .appControl
        default:
            return .appControl
        }
    }
    
    private func calculateConfidence(
        input: String,
        action: String,
        targetApp: String?,
        parameters: [String: String]
    ) -> Double {
        var confidence: Double = 0.5
        
        // Boost confidence if we detected a target app
        if targetApp != nil {
            confidence += 0.3
        }
        
        // Boost confidence if we found relevant parameters
        if !parameters.isEmpty {
            confidence += 0.2
        }
        
        // Boost confidence for clear action words
        if commandPatterns.values.flatMap({ $0 }).contains(where: { input.contains($0) }) {
            confidence += 0.2
        }
        
        return min(confidence, 1.0)
    }
    
    private func determineConfirmationRequirement(
        action: String,
        parameters: [String: String]
    ) -> Bool {
        // Actions that typically require confirmation
        let dangerousActions = ["quit", "delete", "remove"]
        return dangerousActions.contains(action)
    }
    
    // MARK: - App-Specific Command Extraction
    
    private func extractMailCommands(from input: String) -> [String: String] {
        var commands: [String: String] = [:]
        
        // Extract recipient
        if let emailMatch = input.range(of: #"to\s+([^\s@]+@[^\s]+)"#, options: .regularExpression) {
            let email = String(input[emailMatch]).replacingOccurrences(of: "to ", with: "")
            commands["to"] = email
        }
        
        // Extract subject
        if let subjectMatch = input.range(of: #"about\s+(.+?)(?:\s+with|$)"#, options: .regularExpression) {
            let subject = String(input[subjectMatch]).replacingOccurrences(of: "about ", with: "")
            commands["subject"] = subject
        }
        
        return commands
    }
    
    private func extractSafariCommands(from input: String) -> [String: String] {
        var commands: [String: String] = [:]
        
        // Extract URL
        let urlRegex = try! NSRegularExpression(pattern: #"(?:go to|open|visit)\s+([^\s]+)"#)
        let matches = urlRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if let match = matches.first {
            let url = String(input[Range(match.range(at: 1), in: input)!])
            commands["url"] = url.hasPrefix("http") ? url : "https://\(url)"
        }
        
        return commands
    }
    
    private func extractCalendarCommands(from input: String) -> [String: String] {
        var commands: [String: String] = [:]
        
        // Extract event title
        if let titleMatch = input.range(of: #"(?:create|add|schedule)\s+(?:event\s+)?(.+?)\s+(?:at|on|for)"#, options: .regularExpression) {
            let title = String(input[titleMatch])
                .replacingOccurrences(of: #"(?:create|add|schedule)\s+(?:event\s+)?"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            commands["title"] = title
        }
        
        return commands
    }
    
    private func extractFinderCommands(from input: String) -> [String: String] {
        var commands: [String: String] = [:]
        
        // Extract folder path
        if let pathMatch = input.range(of: #"(?:open|show|navigate to)\s+([~/][^\s]*)"#, options: .regularExpression) {
            let path = String(input[pathMatch])
                .replacingOccurrences(of: #"(?:open|show|navigate to)\s+"#, with: "", options: .regularExpression)
            commands["path"] = path
        }
        
        return commands
    }
    
    private func extractGenericCommands(from input: String) -> [String: String] {
        var commands: [String: String] = [:]
        
        // Extract file names
        let fileRegex = try! NSRegularExpression(pattern: #"([^\s]+\.[a-zA-Z]{2,4})"#)
        let matches = fileRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        if let match = matches.first {
            let fileName = String(input[Range(match.range, in: input)!])
            commands["file"] = fileName
        }
        
        return commands
    }
}