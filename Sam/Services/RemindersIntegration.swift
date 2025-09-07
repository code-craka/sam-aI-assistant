import Foundation
import AppKit

// MARK: - Reminders Integration
class RemindersIntegration: AppIntegration {
    
    // MARK: - AppIntegration Protocol
    let bundleIdentifier = "com.apple.reminders"
    let displayName = "Reminders"
    
    var supportedCommands: [CommandDefinition] {
        return [
            CommandDefinition(
                name: "create_reminder",
                description: "Create a new reminder",
                parameters: [
                    CommandParameter(name: "title", type: .string, description: "Reminder title"),
                    CommandParameter(name: "due_date", type: .date, isRequired: false, description: "Due date"),
                    CommandParameter(name: "priority", type: .string, isRequired: false, description: "Priority level")
                ],
                examples: [
                    "remind me to call John",
                    "create reminder to buy groceries tomorrow",
                    "add high priority reminder to submit report by Friday",
                    "remind me to take medication at 8am daily"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "create_task",
                description: "Create a new task",
                parameters: [
                    CommandParameter(name: "title", type: .string, description: "Task title"),
                    CommandParameter(name: "list", type: .string, isRequired: false, description: "List name"),
                    CommandParameter(name: "due_date", type: .date, isRequired: false, description: "Due date")
                ],
                examples: [
                    "add task finish project",
                    "create task review documents in work list",
                    "add task to personal list: organize photos"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "complete_reminder",
                description: "Mark a reminder as completed",
                parameters: [
                    CommandParameter(name: "title", type: .string, description: "Reminder title")
                ],
                examples: [
                    "complete reminder call John",
                    "mark done buy groceries",
                    "finish task submit report"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "show_reminders",
                description: "Show reminders",
                parameters: [
                    CommandParameter(name: "filter", type: .string, isRequired: false, description: "Filter criteria")
                ],
                examples: [
                    "show my reminders",
                    "show today's reminders",
                    "show overdue reminders",
                    "show reminders in work list"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "create_list",
                description: "Create a new reminder list",
                parameters: [
                    CommandParameter(name: "name", type: .string, description: "List name")
                ],
                examples: [
                    "create list for work tasks",
                    "make new list called shopping",
                    "add list personal projects"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "delete_reminder",
                description: "Delete a reminder",
                parameters: [
                    CommandParameter(name: "title", type: .string, description: "Reminder title")
                ],
                examples: [
                    "delete reminder call John",
                    "remove task buy groceries",
                    "cancel reminder dentist appointment"
                ],
                integrationMethod: .appleScript
            )
        ]
    }
    
    let integrationMethods: [IntegrationMethod] = [.appleScript, .accessibility]
    
    var isInstalled: Bool {
        return appDiscovery.isAppInstalled(bundleIdentifier: bundleIdentifier)
    }
    
    // MARK: - Properties
    private let appDiscovery: AppDiscoveryService
    private let appleScriptEngine: AppleScriptEngine
    
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
        
        if lowercaseCommand.contains("remind") || (lowercaseCommand.contains("create") && lowercaseCommand.contains("reminder")) {
            let (title, dueDate, priority) = extractReminderDetails(from: command.originalText)
            result = try await createReminder(title: title, dueDate: dueDate, priority: priority)
        } else if lowercaseCommand.contains("add") && lowercaseCommand.contains("task") {
            let (title, list, dueDate) = extractTaskDetails(from: command.originalText)
            result = try await createTask(title: title, list: list, dueDate: dueDate)
        } else if lowercaseCommand.contains("complete") || lowercaseCommand.contains("mark done") || lowercaseCommand.contains("finish") {
            let title = extractReminderTitle(from: command.originalText)
            result = try await completeReminder(title: title)
        } else if lowercaseCommand.contains("show") && lowercaseCommand.contains("reminder") {
            let filter = extractShowFilter(from: command.originalText)
            result = try await showReminders(filter: filter)
        } else if lowercaseCommand.contains("create") && lowercaseCommand.contains("list") {
            let name = extractListName(from: command.originalText)
            result = try await createList(name: name)
        } else if lowercaseCommand.contains("delete") || lowercaseCommand.contains("remove") || lowercaseCommand.contains("cancel") {
            let title = extractReminderTitle(from: command.originalText)
            result = try await deleteReminder(title: title)
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
                "canCreateReminder": true,
                "canCompleteReminder": true,
                "canDeleteReminder": true,
                "canCreateList": true,
                "canShowReminders": true,
                "canSetDueDate": true,
                "canSetPriority": true
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func createReminder(title: String, dueDate: String?, priority: String?) async throws -> CommandResult {
        var script = """
        tell application "Reminders"
            activate
            tell default list
                set newReminder to make new reminder with properties {name:"\(title)"}
        """
        
        if let dueDate = dueDate {
            let dueDateScript = parseDueDateForScript(dueDate)
            script += """
                set due date of newReminder to \(dueDateScript)
            """
        }
        
        if let priority = priority {
            let priorityValue = parsePriorityForScript(priority)
            script += """
                set priority of newReminder to \(priorityValue)
            """
        }
        
        script += """
            end tell
            return "Created reminder: " & name of newReminder
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: [
                    "The reminder has been added to your default list",
                    "You can view and edit it in the Reminders app"
                ]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func createTask(title: String, list: String?, dueDate: String?) async throws -> CommandResult {
        let targetList = list ?? "default list"
        
        var script = """
        tell application "Reminders"
            activate
            tell \(targetList)
                set newTask to make new reminder with properties {name:"\(title)"}
        """
        
        if let dueDate = dueDate {
            let dueDateScript = parseDueDateForScript(dueDate)
            script += """
                set due date of newTask to \(dueDateScript)
            """
        }
        
        script += """
            end tell
            return "Created task: " & name of newTask & " in " & name of \(targetList)
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: [
                    "The task has been added to your \(targetList)",
                    "You can view and edit it in the Reminders app"
                ]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func completeReminder(title: String) async throws -> CommandResult {
        let script = """
        tell application "Reminders"
            activate
            set matchingReminders to (every reminder of every list whose name contains "\(title)")
            if (count of matchingReminders) > 0 then
                set theReminder to item 1 of matchingReminders
                set completed of theReminder to true
                return "Completed reminder: " & name of theReminder
            else
                return "No reminder found with title containing '\(title)'"
            end if
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["The reminder has been marked as completed"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func showReminders(filter: String?) async throws -> CommandResult {
        var script = """
        tell application "Reminders"
            activate
        """
        
        if let filter = filter {
            if filter.lowercased().contains("today") {
                script += """
                    set todayReminders to (every reminder of every list whose due date ≥ (current date) - (time of (current date)) and due date < (current date) - (time of (current date)) + (24 * 60 * 60) and completed is false)
                    set reminderCount to count of todayReminders
                    return "You have " & reminderCount & " reminders due today"
                """
            } else if filter.lowercased().contains("overdue") {
                script += """
                    set overdueReminders to (every reminder of every list whose due date < (current date) and completed is false)
                    set reminderCount to count of overdueReminders
                    return "You have " & reminderCount & " overdue reminders"
                """
            } else {
                script += """
                    set allReminders to (every reminder of every list whose completed is false)
                    set reminderCount to count of allReminders
                    return "You have " & reminderCount & " active reminders"
                """
            }
        } else {
            script += """
                set allReminders to (every reminder of every list whose completed is false)
                set reminderCount to count of allReminders
                return "You have " & reminderCount & " active reminders"
            """
        }
        
        script += """
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["Open Reminders app to see full details"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func createList(name: String) async throws -> CommandResult {
        let script = """
        tell application "Reminders"
            activate
            make new list with properties {name:"\(name)"}
            return "Created new list: \(name)"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["You can now add reminders to this list"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func deleteReminder(title: String) async throws -> CommandResult {
        let script = """
        tell application "Reminders"
            activate
            set matchingReminders to (every reminder of every list whose name contains "\(title)")
            if (count of matchingReminders) > 0 then
                set theReminder to item 1 of matchingReminders
                delete theReminder
                return "Deleted reminder: \(title)"
            else
                return "No reminder found with title containing '\(title)'"
            end if
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["The reminder has been removed from your lists"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    // MARK: - Text Parsing Methods
    
    private func extractReminderDetails(from input: String) -> (title: String, dueDate: String?, priority: String?) {
        var title = ""
        var dueDate: String? = nil
        var priority: String? = nil
        
        // Extract title
        let titlePatterns = [
            #"remind me to (.+?)(?:\s+(?:at|on|by|tomorrow|today)|$)"#,
            #"create reminder (?:to )?(.+?)(?:\s+(?:at|on|by|tomorrow|today)|$)"#,
            #"add.*?reminder (?:to )?(.+?)(?:\s+(?:at|on|by|tomorrow|today)|$)"#
        ]
        
        for pattern in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let titleRange = Range(match.range(at: 1), in: input) {
                        title = String(input[titleRange]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        // Extract due date
        let dueDatePatterns = [
            #"(?:at|on|by)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?)"#,
            #"(tomorrow|today|next week|next month)"#,
            #"by\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        ]
        
        for pattern in dueDatePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let dateRange = Range(match.range(at: 1), in: input) {
                        dueDate = String(input[dateRange]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        // Extract priority
        if input.lowercased().contains("high priority") {
            priority = "high"
        } else if input.lowercased().contains("low priority") {
            priority = "low"
        } else if input.lowercased().contains("medium priority") {
            priority = "medium"
        }
        
        return (title, dueDate, priority)
    }
    
    private func extractTaskDetails(from input: String) -> (title: String, list: String?, dueDate: String?) {
        var title = ""
        var list: String? = nil
        var dueDate: String? = nil
        
        // Extract title
        let titlePatterns = [
            #"add task (.+?)(?:\s+(?:to|in|at|on|by)|$)"#,
            #"create task (.+?)(?:\s+(?:to|in|at|on|by)|$)"#
        ]
        
        for pattern in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let titleRange = Range(match.range(at: 1), in: input) {
                        title = String(input[titleRange]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        // Extract list
        let listPattern = #"(?:to|in)\s+(.+?)\s+list"#
        if let regex = try? NSRegularExpression(pattern: listPattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range) {
                if let listRange = Range(match.range(at: 1), in: input) {
                    list = String(input[listRange]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Extract due date (similar to reminder)
        let dueDatePatterns = [
            #"(?:at|on|by)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?)"#,
            #"(tomorrow|today|next week|next month)"#
        ]
        
        for pattern in dueDatePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let dateRange = Range(match.range(at: 1), in: input) {
                        dueDate = String(input[dateRange]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        return (title, list, dueDate)
    }
    
    private func extractReminderTitle(from input: String) -> String {
        let patterns = [
            #"(?:complete|mark done|finish|delete|remove|cancel).*?(?:reminder|task)\s+(.+)"#,
            #"(?:complete|mark done|finish|delete|remove|cancel)\s+(.+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let titleRange = Range(match.range(at: 1), in: input) {
                        return String(input[titleRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        return ""
    }
    
    private func extractShowFilter(from input: String) -> String? {
        if input.lowercased().contains("today") {
            return "today"
        } else if input.lowercased().contains("overdue") {
            return "overdue"
        } else if input.lowercased().contains("work") {
            return "work"
        } else if input.lowercased().contains("personal") {
            return "personal"
        }
        return nil
    }
    
    private func extractListName(from input: String) -> String {
        let patterns = [
            #"create list (?:for )?(.+)"#,
            #"make.*?list (?:called )?(.+)"#,
            #"add list (.+)"#
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
        
        return "New List"
    }
    
    private func parseDueDateForScript(_ dueDate: String) -> String {
        let lowercaseDate = dueDate.lowercased()
        
        if lowercaseDate.contains("tomorrow") {
            return "(current date) + (1 * days)"
        } else if lowercaseDate.contains("today") {
            return "current date"
        } else if lowercaseDate.contains("next week") {
            return "(current date) + (7 * days)"
        } else if lowercaseDate.contains("next month") {
            return "(current date) + (30 * days)"
        } else {
            // For specific times, we'll use current date for now
            // In a real implementation, you'd parse the time more precisely
            return "current date"
        }
    }
    
    private func parsePriorityForScript(_ priority: String) -> String {
        switch priority.lowercased() {
        case "high":
            return "1"
        case "medium":
            return "5"
        case "low":
            return "9"
        default:
            return "5"
        }
    }
}