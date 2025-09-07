import Foundation
import AppKit

// MARK: - Mail Integration
class MailIntegration: AppIntegration {
    
    // MARK: - AppIntegration Protocol
    let bundleIdentifier = "com.apple.mail"
    let displayName = "Mail"
    
    var supportedCommands: [CommandDefinition] {
        return [
            CommandDefinition(
                name: "compose_email",
                description: "Compose a new email",
                parameters: [
                    CommandParameter(name: "to", type: .email, description: "Recipient email address"),
                    CommandParameter(name: "subject", type: .string, isRequired: false, description: "Email subject"),
                    CommandParameter(name: "body", type: .string, isRequired: false, description: "Email body")
                ],
                examples: [
                    "send email to john@example.com",
                    "compose email to team@company.com about meeting",
                    "send email to sarah@company.com about project update with message Hello Sarah, here's the update"
                ],
                integrationMethod: .urlScheme
            ),
            CommandDefinition(
                name: "search_emails",
                description: "Search for emails",
                parameters: [
                    CommandParameter(name: "query", type: .string, description: "Search query")
                ],
                examples: ["search emails for project update", "find emails from john", "look for messages about budget"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "check_new_mail",
                description: "Check for new mail",
                parameters: [],
                examples: ["check mail", "get new mail", "refresh inbox"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "create_mailbox",
                description: "Create a new mailbox",
                parameters: [
                    CommandParameter(name: "name", type: .string, description: "Mailbox name")
                ],
                examples: ["create mailbox for projects", "new folder called archive", "make mailbox client emails"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "reply_email",
                description: "Reply to the selected email",
                parameters: [],
                examples: ["reply to this email", "reply to selected message"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "forward_email",
                description: "Forward the selected email",
                parameters: [
                    CommandParameter(name: "to", type: .email, description: "Recipient email address")
                ],
                examples: ["forward this email to john@example.com", "forward to team@company.com"],
                integrationMethod: .appleScript
            )
        ]
    }
    
    let integrationMethods: [IntegrationMethod] = [.urlScheme, .appleScript, .accessibility]
    
    var isInstalled: Bool {
        return appDiscovery.isAppInstalled(bundleIdentifier: bundleIdentifier)
    }
    
    // MARK: - Properties
    private let appDiscovery: AppDiscoveryService
    private let urlSchemeHandler: URLSchemeHandler
    private let appleScriptEngine: AppleScriptEngine
    
    // MARK: - Initialization
    init(appDiscovery: AppDiscoveryService, urlSchemeHandler: URLSchemeHandler, appleScriptEngine: AppleScriptEngine) {
        self.appDiscovery = appDiscovery
        self.urlSchemeHandler = urlSchemeHandler
        self.appleScriptEngine = appleScriptEngine
    }
    
    // MARK: - AppIntegration Methods
    
    func canHandle(_ command: ParsedCommand) -> Bool {
        guard command.targetApplication == bundleIdentifier else { return false }
        
        switch command.intent {
        case .appControl:
            return true
        default:
            return false
        }
    }
    
    func execute(_ command: ParsedCommand) async throws -> CommandResult {
        let startTime = Date()
        
        let mailCommand = try identifyMailCommand(from: command)
        let result = try await executeMailCommand(mailCommand)
        
        let executionTime = Date().timeIntervalSince(startTime)
        return CommandResult(
            success: result.success,
            output: result.output,
            executionTime: executionTime,
            integrationMethod: result.integrationMethod,
            errorMessage: result.errorMessage,
            followUpActions: result.followUpActions
        )
    }
    
    func getCapabilities() -> AppCapabilities {
        return AppCapabilities(
            canLaunch: true,
            canQuit: true,
            canCreateDocuments: true,
            canOpenFiles: true,
            canSaveFiles: true,
            customCapabilities: [
                "canCompose": true,
                "canSend": true,
                "canSearch": true,
                "canManageMailboxes": true,
                "canCheckMail": true
            ]
        )
    }
    
    // MARK: - Private Methods
    
    // MARK: - Command Routing
    
    private enum MailCommand {
        case compose(recipient: String, subject: String, body: String)
        case search(query: String)
        case checkMail
        case createMailbox(name: String)
        case reply
        case forward(recipient: String)
    }
    
    private func identifyMailCommand(from command: ParsedCommand) throws -> MailCommand {
        let lowercaseCommand = command.originalText.lowercased()
        
        // Priority-based command identification
        if let email = command.parameters["email"] {
            let subject = command.parameters["subject"] ?? ""
            let body = command.parameters["body"] ?? ""
            return .compose(recipient: email, subject: subject, body: body)
        }
        
        if lowercaseCommand.contains("send") && lowercaseCommand.contains("email") {
            let (recipient, subject, body) = extractEmailComponents(from: command.originalText)
            return .compose(recipient: recipient, subject: subject, body: body)
        }
        
        if lowercaseCommand.contains("search") {
            let query = extractSearchQuery(from: command.originalText)
            return .search(query: query)
        }
        
        if lowercaseCommand.contains("check") || lowercaseCommand.contains("new mail") {
            return .checkMail
        }
        
        if lowercaseCommand.contains("create") && lowercaseCommand.contains("mailbox") {
            let name = extractMailboxName(from: command.originalText)
            return .createMailbox(name: name)
        }
        
        if lowercaseCommand.contains("reply") {
            return .reply
        }
        
        if lowercaseCommand.contains("forward") {
            let recipient = extractEmailAddress(from: command.originalText)
            return .forward(recipient: recipient)
        }
        
        throw AppIntegrationError.commandNotSupported(command.originalText)
    }
    
    private func executeMailCommand(_ mailCommand: MailCommand) async throws -> CommandResult {
        switch mailCommand {
        case .compose(let recipient, let subject, let body):
            return try await composeEmail(to: recipient, subject: subject, body: body)
        case .search(let query):
            return try await searchEmails(query: query)
        case .checkMail:
            return try await checkNewMail()
        case .createMailbox(let name):
            return try await createMailbox(name: name)
        case .reply:
            return try await replyToLastEmail()
        case .forward(let recipient):
            return try await forwardLastEmail(to: recipient)
        }
    }
    
    private func composeEmail(to recipient: String, subject: String = "", body: String = "") async throws -> CommandResult {
        try validateEmailAddress(recipient)
        
        // Build mailto URL
        var urlComponents = URLComponents()
        urlComponents.scheme = "mailto"
        urlComponents.path = recipient
        
        var queryItems: [URLQueryItem] = []
        if !subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if !body.isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let mailtoURL = urlComponents.url else {
            throw AppIntegrationError.invalidParameters(["Invalid email parameters"])
        }
        
        let success = try await urlSchemeHandler.openURL(mailtoURL)
        
        if success {
            return CommandResult(
                success: true,
                output: "Opened new email composition to \(recipient)",
                integrationMethod: .urlScheme,
                followUpActions: [
                    "You can now write your email in Mail",
                    "Press Cmd+Return to send when ready"
                ]
            )
        } else {
            throw AppIntegrationError.integrationMethodFailed(.urlScheme, "Failed to open Mail composer")
        }
    }
    
    private func searchEmails(query: String) async throws -> CommandResult {
        let sanitizedQuery = sanitizeAppleScriptString(query)
        let script = """
        tell application "Mail"
            activate
            set searchResults to (messages whose subject contains "\(sanitizedQuery)" or content contains "\(sanitizedQuery)")
            set resultCount to count of searchResults
            return "Found " & resultCount & " emails matching '\(sanitizedQuery)'"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["Check Mail to see the search results"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func checkNewMail() async throws -> CommandResult {
        let script = """
        tell application "Mail"
            activate
            check for new mail
            return "Checking for new mail..."
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Checking for new mail in all accounts",
                integrationMethod: .appleScript,
                followUpActions: ["New messages will appear in your inbox shortly"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func createMailbox(name: String) async throws -> CommandResult {
        try validateMailboxName(name)
        
        let sanitizedName = sanitizeAppleScriptString(name)
        let script = """
        tell application "Mail"
            activate
            make new mailbox with properties {name:"\(sanitizedName)"}
            return "Created mailbox '\(sanitizedName)'"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Created new mailbox '\(name)'",
                integrationMethod: .appleScript,
                followUpActions: ["You can now organize emails into this mailbox"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    // MARK: - Text Extraction Utilities
    
    private struct TextExtractor {
        static func extractUsingPatterns(_ patterns: [String], from input: String, defaultValue: String = "") -> String {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(input.startIndex..<input.endIndex, in: input)
                    if let match = regex.firstMatch(in: input, options: [], range: range) {
                        if let extractedRange = Range(match.range(at: 1), in: input) {
                            return String(input[extractedRange]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
            return defaultValue.isEmpty ? input : defaultValue
        }
    }
    
    private func extractSearchQuery(from input: String) -> String {
        let patterns = [
            "search (?:emails? )?for (.+)",
            "find (?:emails? )?(?:from )?(.+)",
            "look for (.+)"
        ]
        return TextExtractor.extractUsingPatterns(patterns, from: input)
    }
    
    private func extractMailboxName(from input: String) -> String {
        let patterns = [
            "create mailbox (?:for )?(.+)",
            "new (?:folder|mailbox) (?:called )?(.+)",
            "make (?:folder|mailbox) (.+)"
        ]
        return TextExtractor.extractUsingPatterns(patterns, from: input, defaultValue: "New Mailbox")
    }
    
    private struct EmailComponents {
        let recipient: String
        let subject: String
        let body: String
        
        init(recipient: String = "", subject: String = "", body: String = "") {
            self.recipient = recipient
            self.subject = subject
            self.body = body
        }
    }
    
    private func extractEmailComponents(from input: String) -> (recipient: String, subject: String, body: String) {
        let components = EmailComponents(
            recipient: extractEmailAddress(from: input),
            subject: extractSubject(from: input),
            body: extractBody(from: input)
        )
        return (components.recipient, components.subject, components.body)
    }
    
    private func extractSubject(from input: String) -> String {
        let patterns = [
            #"about\s+(.+?)(?:\s+with|$)"#,
            #"subject\s+(.+?)(?:\s+with|$)"#,
            #"regarding\s+(.+?)(?:\s+with|$)"#
        ]
        return TextExtractor.extractUsingPatterns(patterns, from: input)
    }
    
    private func extractBody(from input: String) -> String {
        let patterns = [#"with message\s+(.+)"#]
        return TextExtractor.extractUsingPatterns(patterns, from: input)
    }
    
    // MARK: - Security Utilities
    
    private func sanitizeAppleScriptString(_ input: String) -> String {
        // Escape quotes and backslashes to prevent AppleScript injection
        return input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    // MARK: - Input Validation
    
    private func validateEmailAddress(_ email: String) throws {
        guard !email.isEmpty else {
            throw AppIntegrationError.invalidParameters(["Email address cannot be empty"])
        }
        
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            throw AppIntegrationError.invalidParameters(["Invalid email address format: \(email)"])
        }
    }
    
    private func validateMailboxName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppIntegrationError.invalidParameters(["Mailbox name cannot be empty"])
        }
        
        guard name.count <= 100 else {
            throw AppIntegrationError.invalidParameters(["Mailbox name too long (max 100 characters)"])
        }
        
        // Check for invalid characters
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        guard name.rangeOfCharacter(from: invalidChars) == nil else {
            throw AppIntegrationError.invalidParameters(["Mailbox name contains invalid characters"])
        }
    }
    
    private func extractEmailAddress(from input: String) -> String {
        let emailPattern = #"([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"#
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range) {
                if let emailRange = Range(match.range(at: 1), in: input) {
                    return String(input[emailRange])
                }
            }
        }
        return ""
    }
    
    private func replyToLastEmail() async throws -> CommandResult {
        let script = """
        tell application "Mail"
            activate
            set selectedMessages to selection
            if (count of selectedMessages) > 0 then
                set theMessage to item 1 of selectedMessages
                reply theMessage
                return "Opened reply to: " & (subject of theMessage)
            else
                return "No email selected to reply to"
            end if
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["You can now compose your reply in Mail"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func forwardLastEmail(to recipient: String) async throws -> CommandResult {
        guard !recipient.isEmpty else {
            throw AppIntegrationError.invalidParameters(["Recipient email address is required for forwarding"])
        }
        
        try validateEmailAddress(recipient)
        
        let sanitizedRecipient = sanitizeAppleScriptString(recipient)
        let script = """
        tell application "Mail"
            activate
            set selectedMessages to selection
            if (count of selectedMessages) > 0 then
                set theMessage to item 1 of selectedMessages
                set forwardMessage to forward theMessage
                tell forwardMessage
                    make new to recipient at end of to recipients with properties {address:"\(sanitizedRecipient)"}
                end tell
                return "Forwarding email to \(sanitizedRecipient)"
            else
                return "No email selected to forward"
            end if
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["You can edit the forwarded message before sending"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
}