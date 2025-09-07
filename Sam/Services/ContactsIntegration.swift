import Foundation
import AppKit
import Contacts

// MARK: - Contacts Integration
class ContactsIntegration: AppIntegration {
    
    // MARK: - AppIntegration Protocol
    let bundleIdentifier = "com.apple.AddressBook"
    let displayName = "Contacts"
    
    var supportedCommands: [CommandDefinition] {
        return [
            CommandDefinition(
                name: "add_contact",
                description: "Add a new contact",
                parameters: [
                    CommandParameter(name: "name", type: .string, description: "Contact name"),
                    CommandParameter(name: "email", type: .email, isRequired: false, description: "Email address"),
                    CommandParameter(name: "phone", type: .string, isRequired: false, description: "Phone number")
                ],
                examples: [
                    "add contact John Smith",
                    "create contact Sarah Johnson with email sarah@company.com",
                    "add contact Mike Davis with phone 555-1234 and email mike@example.com"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "search_contact",
                description: "Search for a contact",
                parameters: [
                    CommandParameter(name: "query", type: .string, description: "Search query")
                ],
                examples: [
                    "find contact John",
                    "search for Sarah in contacts",
                    "look up contact with email john@company.com"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "get_contact_info",
                description: "Get contact information",
                parameters: [
                    CommandParameter(name: "name", type: .string, description: "Contact name")
                ],
                examples: [
                    "get info for John Smith",
                    "show contact details for Sarah",
                    "what's Mike's phone number"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "update_contact",
                description: "Update contact information",
                parameters: [
                    CommandParameter(name: "name", type: .string, description: "Contact name"),
                    CommandParameter(name: "field", type: .string, description: "Field to update"),
                    CommandParameter(name: "value", type: .string, description: "New value")
                ],
                examples: [
                    "update John Smith's email to john.smith@newcompany.com",
                    "change Sarah's phone number to 555-9876"
                ],
                integrationMethod: .appleScript
            )
        ]
    }
    
    let integrationMethods: [IntegrationMethod] = [.appleScript, .nativeSDK, .accessibility]
    
    var isInstalled: Bool {
        return appDiscovery.isAppInstalled(bundleIdentifier: bundleIdentifier)
    }
    
    // MARK: - Properties
    private let appDiscovery: AppDiscoveryService
    private let appleScriptEngine: AppleScriptEngine
    private let contactStore = CNContactStore()
    
    // MARK: - Initialization
    init(appDiscovery: AppDiscoveryService, appleScriptEngine: AppleScriptEngine) {
        self.appDiscovery = appDiscovery
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
        
        let result: CommandResult
        let lowercaseCommand = command.originalText.lowercased()
        
        if lowercaseCommand.contains("add") && lowercaseCommand.contains("contact") {
            let (name, email, phone) = extractContactDetails(from: command.originalText)
            result = try await addContact(name: name, email: email, phone: phone)
        } else if lowercaseCommand.contains("search") || lowercaseCommand.contains("find") {
            let query = extractSearchQuery(from: command.originalText)
            result = try await searchContact(query: query)
        } else if lowercaseCommand.contains("get") && lowercaseCommand.contains("info") {
            let name = extractContactName(from: command.originalText)
            result = try await getContactInfo(name: name)
        } else if lowercaseCommand.contains("update") || lowercaseCommand.contains("change") {
            let (name, field, value) = extractUpdateDetails(from: command.originalText)
            result = try await updateContact(name: name, field: field, value: value)
        } else {
            throw AppIntegrationError.commandNotSupported(command.originalText)
        }
        
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
            customCapabilities: [
                "canAddContact": true,
                "canSearchContact": true,
                "canUpdateContact": true,
                "canDeleteContact": true,
                "canAccessAddressBook": true
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func addContact(name: String, email: String?, phone: String?) async throws -> CommandResult {
        // First try using native Contacts framework
        if await requestContactsAccess() {
            return try await addContactNative(name: name, email: email, phone: phone)
        } else {
            // Fallback to AppleScript
            return try await addContactAppleScript(name: name, email: email, phone: phone)
        }
    }
    
    private func addContactNative(name: String, email: String?, phone: String?) async throws -> CommandResult {
        let contact = CNMutableContact()
        
        // Parse name
        let nameComponents = name.components(separatedBy: " ")
        if nameComponents.count >= 1 {
            contact.givenName = nameComponents[0]
        }
        if nameComponents.count >= 2 {
            contact.familyName = nameComponents[1...].joined(separator: " ")
        }
        
        // Add email if provided
        if let email = email {
            let emailAddress = CNLabeledValue(label: CNLabelWork, value: email as NSString)
            contact.emailAddresses = [emailAddress]
        }
        
        // Add phone if provided
        if let phone = phone {
            let phoneNumber = CNPhoneNumber(stringValue: phone)
            let phoneValue = CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneNumber)
            contact.phoneNumbers = [phoneValue]
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        
        do {
            try contactStore.execute(saveRequest)
            return CommandResult(
                success: true,
                output: "Successfully added contact: \(name)",
                integrationMethod: .nativeSDK,
                followUpActions: ["You can view and edit the contact in the Contacts app"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.nativeSDK, error.localizedDescription)
        }
    }
    
    private func addContactAppleScript(name: String, email: String?, phone: String?) async throws -> CommandResult {
        var script = """
        tell application "Contacts"
            activate
            set newContact to make new person with properties {name:"\(name)"}
        """
        
        if let email = email {
            script += """
                make new email at end of emails of newContact with properties {label:"work", value:"\(email)"}
            """
        }
        
        if let phone = phone {
            script += """
                make new phone at end of phones of newContact with properties {label:"main", value:"\(phone)"}
            """
        }
        
        script += """
            save
            return "Added contact: " & name of newContact
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["You can view and edit the contact in the Contacts app"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func searchContact(query: String) async throws -> CommandResult {
        let script = """
        tell application "Contacts"
            activate
            set searchResults to (every person whose name contains "\(query)" or company contains "\(query)")
            set resultCount to count of searchResults
            if resultCount > 0 then
                set resultNames to {}
                repeat with aPerson in searchResults
                    set end of resultNames to name of aPerson
                end repeat
                return "Found " & resultCount & " contact(s): " & (resultNames as string)
            else
                return "No contacts found matching '\(query)'"
            end if
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["Check the Contacts app to see full details"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func getContactInfo(name: String) async throws -> CommandResult {
        let script = """
        tell application "Contacts"
            activate
            set matchingContacts to (every person whose name contains "\(name)")
            if (count of matchingContacts) > 0 then
                set theContact to item 1 of matchingContacts
                set contactInfo to "Name: " & name of theContact
                
                if (count of emails of theContact) > 0 then
                    set contactInfo to contactInfo & ", Email: " & value of item 1 of emails of theContact
                end if
                
                if (count of phones of theContact) > 0 then
                    set contactInfo to contactInfo & ", Phone: " & value of item 1 of phones of theContact
                end if
                
                return contactInfo
            else
                return "No contact found with name '\(name)'"
            end if
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["Open Contacts app to see complete information"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func updateContact(name: String, field: String, value: String) async throws -> CommandResult {
        let script = """
        tell application "Contacts"
            activate
            set matchingContacts to (every person whose name contains "\(name)")
            if (count of matchingContacts) > 0 then
                set theContact to item 1 of matchingContacts
                
                if "\(field)" contains "email" then
                    if (count of emails of theContact) > 0 then
                        set value of item 1 of emails of theContact to "\(value)"
                    else
                        make new email at end of emails of theContact with properties {label:"work", value:"\(value)"}
                    end if
                else if "\(field)" contains "phone" then
                    if (count of phones of theContact) > 0 then
                        set value of item 1 of phones of theContact to "\(value)"
                    else
                        make new phone at end of phones of theContact with properties {label:"main", value:"\(value)"}
                    end if
                end if
                
                save
                return "Updated \(field) for \(name) to \(value)"
            else
                return "No contact found with name '\(name)'"
            end if
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["The contact has been updated in your address book"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func requestContactsAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            contactStore.requestAccess(for: .contacts) { granted, error in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Text Parsing Methods
    
    private func extractContactDetails(from input: String) -> (name: String, email: String?, phone: String?) {
        var name = ""
        var email: String? = nil
        var phone: String? = nil
        
        // Extract name
        let namePattern = #"(?:add|create) contact\s+([A-Za-z\s]+?)(?:\s+with|\s*$)"#
        if let regex = try? NSRegularExpression(pattern: namePattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range) {
                if let nameRange = Range(match.range(at: 1), in: input) {
                    name = String(input[nameRange]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Extract email
        let emailPattern = #"(?:email|e-mail)\s+([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"#
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range) {
                if let emailRange = Range(match.range(at: 1), in: input) {
                    email = String(input[emailRange])
                }
            }
        }
        
        // Extract phone
        let phonePattern = #"(?:phone|number)\s+([\d\-\(\)\s]+)"#
        if let regex = try? NSRegularExpression(pattern: phonePattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range) {
                if let phoneRange = Range(match.range(at: 1), in: input) {
                    phone = String(input[phoneRange]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return (name, email, phone)
    }
    
    private func extractSearchQuery(from input: String) -> String {
        let patterns = [
            #"(?:search|find|look up).*?contact.*?(?:for|with)?\s+(.+)"#,
            #"(?:search|find|look up)\s+(.+?)(?:\s+in contacts|$)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let queryRange = Range(match.range(at: 1), in: input) {
                        return String(input[queryRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        return input
    }
    
    private func extractContactName(from input: String) -> String {
        let patterns = [
            #"(?:get info for|show.*?details for|info for)\s+(.+)"#,
            #"what's\s+(.+?)'s"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let nameRange = Range(match.range(at: 1), in: input) {
                        return String(input[nameRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        return ""
    }
    
    private func extractUpdateDetails(from input: String) -> (name: String, field: String, value: String) {
        var name = ""
        var field = ""
        var value = ""
        
        // Extract update pattern: "update John's email to john@example.com"
        let updatePattern = #"(?:update|change)\s+(.+?)'s\s+(\w+)\s+to\s+(.+)"#
        if let regex = try? NSRegularExpression(pattern: updatePattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range) {
                if let nameRange = Range(match.range(at: 1), in: input) {
                    name = String(input[nameRange]).trimmingCharacters(in: .whitespaces)
                }
                if let fieldRange = Range(match.range(at: 2), in: input) {
                    field = String(input[fieldRange]).trimmingCharacters(in: .whitespaces)
                }
                if let valueRange = Range(match.range(at: 3), in: input) {
                    value = String(input[valueRange]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return (name, field, value)
    }
}