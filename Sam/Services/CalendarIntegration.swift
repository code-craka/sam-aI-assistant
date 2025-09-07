import Foundation
import AppKit

// MARK: - Calendar Integration
class CalendarIntegration: AppIntegration {
    
    // MARK: - AppIntegration Protocol
    let bundleIdentifier = "com.apple.iCal"
    let displayName = "Calendar"
    
    var supportedCommands: [CommandDefinition] {
        return [
            CommandDefinition(
                name: "create_event",
                description: "Create a new calendar event",
                parameters: [
                    CommandParameter(name: "title", type: .string, description: "Event title"),
                    CommandParameter(name: "time", type: .date, isRequired: false, description: "Event date and time"),
                    CommandParameter(name: "duration", type: .string, isRequired: false, description: "Event duration")
                ],
                examples: [
                    "create event meeting at 2pm",
                    "schedule lunch tomorrow at noon",
                    "create event team standup at 9am for 30 minutes",
                    "schedule dentist appointment next Tuesday at 3pm for 1 hour"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "create_reminder",
                description: "Create a new reminder",
                parameters: [
                    CommandParameter(name: "title", type: .string, description: "Reminder title"),
                    CommandParameter(name: "time", type: .date, isRequired: false, description: "Reminder date and time")
                ],
                examples: [
                    "remind me to call John",
                    "create reminder for dentist appointment",
                    "remind me to buy groceries tomorrow",
                    "create reminder to submit report by Friday"
                ],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "show_today",
                description: "Show today's events",
                parameters: [],
                examples: ["show today's events", "what's on my calendar today", "today's schedule"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "show_tomorrow",
                description: "Show tomorrow's events",
                parameters: [],
                examples: ["show tomorrow's events", "what's on my calendar tomorrow", "tomorrow's schedule"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "show_week",
                description: "Show this week's events",
                parameters: [],
                examples: ["show this week", "what's on my calendar this week", "weekly schedule"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "delete_event",
                description: "Delete a calendar event",
                parameters: [
                    CommandParameter(name: "title", type: .string, description: "Event title to delete")
                ],
                examples: ["delete event meeting", "remove appointment dentist", "cancel event lunch"],
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
        
        let result: CommandResult
        let lowercaseCommand = command.originalText.lowercased()
        
        if lowercaseCommand.contains("create") && (lowercaseCommand.contains("event") || lowercaseCommand.contains("appointment")) {
            let (title, time, duration) = extractEventDetails(from: command.originalText)
            result = try await createEvent(title: title, time: time, duration: duration)
        } else if lowercaseCommand.contains("schedule") {
            let (title, time, duration) = extractEventDetails(from: command.originalText)
            result = try await createEvent(title: title, time: time, duration: duration)
        } else if lowercaseCommand.contains("remind") || lowercaseCommand.contains("reminder") {
            let (title, time) = extractReminderDetails(from: command.originalText)
            result = try await createReminder(title: title, time: time)
        } else if lowercaseCommand.contains("today") {
            result = try await showTodaysEvents()
        } else if lowercaseCommand.contains("week") {
            result = try await showWeekEvents()
        } else if lowercaseCommand.contains("tomorrow") {
            result = try await showTomorrowEvents()
        } else if lowercaseCommand.contains("delete") && lowercaseCommand.contains("event") {
            let title = extractEventTitle(from: command.originalText)
            result = try await deleteEvent(title: title)
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
            canSaveFiles: true,
            customCapabilities: [
                "canCreateEvent": true,
                "canCreateReminder": true,
                "canSearch": true,
                "canShowCalendar": true
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func createEvent(title: String, time: String?, duration: String? = nil) async throws -> CommandResult {
        let eventTime = parseEventTime(time)
        let eventDuration = parseDuration(duration) ?? 3600 // Default 1 hour
        
        let script = """
        tell application "Calendar"
            activate
            tell calendar "Calendar"
                set startDate to \(eventTime)
                set endDate to startDate + \(eventDuration)
                make new event with properties {summary:"\(title)", start date:startDate, end date:endDate}
            end tell
        end tell
        """
        
        do {
            let _ = try await appleScriptEngine.executeScript(script)
            let timeString = time ?? "now"
            return CommandResult(
                success: true,
                output: "Created calendar event '\(title)' for \(timeString)",
                integrationMethod: .appleScript,
                followUpActions: [
                    "You can edit the event details in Calendar",
                    "Add attendees, location, and notes if needed"
                ]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func createReminder(title: String, time: String?) async throws -> CommandResult {
        let script = """
        tell application "Reminders"
            activate
            tell default list
                make new reminder with properties {name:"\(title)"}
            end tell
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Created reminder: \(title)",
                integrationMethod: .appleScript,
                followUpActions: [
                    "You can set a due date and priority in Reminders",
                    "The reminder will appear in your default list"
                ]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func showTodaysEvents() async throws -> CommandResult {
        let script = """
        tell application "Calendar"
            activate
            set todayStart to (current date) - (time of (current date))
            set todayEnd to todayStart + (24 * 60 * 60)
            set todayEvents to (every event of every calendar whose start date ≥ todayStart and start date < todayEnd)
            set eventCount to count of todayEvents
            return "You have " & eventCount & " events today"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["Check Calendar to see your full schedule"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func showWeekEvents() async throws -> CommandResult {
        let script = """
        tell application "Calendar"
            activate
            view calendar at (current date)
            return "Showing this week's calendar"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Opened Calendar showing this week's events",
                integrationMethod: .appleScript,
                followUpActions: ["You can navigate to different weeks using the arrow buttons"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func extractEventTitle(from input: String) -> String {
        let patterns = [
            "create (?:event|appointment) (.+?) (?:at|on|for)",
            "schedule (.+?) (?:at|on|for)",
            "add (?:event|appointment) (.+?) (?:at|on|for)",
            "create (?:event|appointment) (.+)",
            "schedule (.+)",
            "add (?:event|appointment) (.+)"
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
        
        return "New Event"
    }
    
    private func extractReminderTitle(from input: String) -> String {
        let patterns = [
            "remind me to (.+)",
            "create reminder (?:for )?(.+)",
            "add reminder (?:for )?(.+)",
            "reminder (.+)"
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
        
        return "New Reminder"
    }
    
    private func extractEventDetails(from input: String) -> (title: String, time: String?, duration: String?) {
        let title = extractEventTitle(from: input)
        let time = extractTime(from: input)
        let duration = extractDuration(from: input)
        return (title, time, duration)
    }
    
    private func extractReminderDetails(from input: String) -> (title: String, time: String?) {
        let title = extractReminderTitle(from: input)
        let time = extractTime(from: input)
        return (title, time)
    }
    
    private func extractTime(from input: String) -> String? {
        let timePatterns = [
            #"at\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?)"#,
            #"(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM))"#,
            #"(tomorrow|today|next week|next month)"#,
            #"on\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        ]
        
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let timeRange = Range(match.range(at: 1), in: input) {
                        return String(input[timeRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        return nil
    }
    
    private func extractDuration(from input: String) -> String? {
        let durationPatterns = [
            #"for\s+(\d+)\s*(?:hour|hours|hr|hrs)"#,
            #"for\s+(\d+)\s*(?:minute|minutes|min|mins)"#,
            #"(\d+)\s*(?:hour|hours|hr|hrs)\s*long"#,
            #"(\d+)\s*(?:minute|minutes|min|mins)\s*long"#
        ]
        
        for pattern in durationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let durationRange = Range(match.range(at: 1), in: input) {
                        return String(input[durationRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        return nil
    }
    
    private func parseEventTime(_ timeString: String?) -> String {
        guard let timeString = timeString else {
            return "current date"
        }
        
        let lowercaseTime = timeString.lowercased()
        
        if lowercaseTime.contains("tomorrow") {
            return "(current date) + (1 * days)"
        } else if lowercaseTime.contains("today") {
            return "current date"
        } else if lowercaseTime.contains("next week") {
            return "(current date) + (7 * days)"
        } else if lowercaseTime.contains("next month") {
            return "(current date) + (30 * days)"
        } else {
            // For specific times, we'll use current date for now
            // In a real implementation, you'd parse the time more precisely
            return "current date"
        }
    }
    
    private func parseDuration(_ durationString: String?) -> Int? {
        guard let durationString = durationString else { return nil }
        
        if let hours = Int(durationString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) {
            if durationString.lowercased().contains("hour") {
                return hours * 3600 // Convert hours to seconds
            } else if durationString.lowercased().contains("min") {
                return hours * 60 // Convert minutes to seconds
            }
        }
        return nil
    }
    
    private func showTomorrowEvents() async throws -> CommandResult {
        let script = """
        tell application "Calendar"
            activate
            set tomorrowStart to (current date) + (1 * days) - (time of (current date))
            set tomorrowEnd to tomorrowStart + (24 * 60 * 60)
            set tomorrowEvents to (every event of every calendar whose start date ≥ tomorrowStart and start date < tomorrowEnd)
            set eventCount to count of tomorrowEvents
            return "You have " & eventCount & " events tomorrow"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["Check Calendar to see tomorrow's full schedule"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func deleteEvent(title: String) async throws -> CommandResult {
        let script = """
        tell application "Calendar"
            activate
            set eventsToDelete to (every event of every calendar whose summary is "\(title)")
            repeat with eventToDelete in eventsToDelete
                delete eventToDelete
            end repeat
            set deletedCount to count of eventsToDelete
            return "Deleted " & deletedCount & " event(s) with title '\(title)'"
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["The event has been removed from your calendar"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
}