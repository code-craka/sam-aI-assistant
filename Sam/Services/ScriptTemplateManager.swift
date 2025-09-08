import Foundation

/// Manages AppleScript templates for common automation tasks
class ScriptTemplateManager {
    
    // MARK: - Types
    
    struct ScriptTemplate {
        let name: String
        let description: String
        let source: String
        let parameters: [String]
        let category: TemplateCategory
        let targetApps: [String]
        let examples: [String]
    }
    
    enum TemplateCategory: String, CaseIterable {
        case finder = "Finder"
        case mail = "Mail"
        case calendar = "Calendar"
        case safari = "Safari"
        case system = "System"
        case textEditor = "Text Editor"
        case generic = "Generic"
    }
    
    // MARK: - Properties
    
    private var templates: [String: ScriptTemplate] = [:]
    
    // MARK: - Public Methods
    
    func loadBuiltInTemplates() {
        loadFinderTemplates()
        loadMailTemplates()
        loadCalendarTemplates()
        loadSafariTemplates()
        loadSystemTemplates()
        loadTextEditorTemplates()
        loadGenericTemplates()
    }
    
    func getTemplate(_ name: String) -> ScriptTemplate? {
        return templates[name]
    }
    
    func getAllTemplates() -> [ScriptTemplate] {
        return Array(templates.values)
    }
    
    func getTemplates(for category: TemplateCategory) -> [ScriptTemplate] {
        return templates.values.filter { $0.category == category }
    }
    
    func getTemplates(for app: String) -> [ScriptTemplate] {
        return templates.values.filter { $0.targetApps.contains(app) }
    }
    
    func generateFromDescription(_ description: String, targetApp: String? = nil) async throws -> String {
        // Simple template matching based on keywords
        let lowercased = description.lowercased()
        
        // Finder operations
        if lowercased.contains("file") || lowercased.contains("folder") || lowercased.contains("finder") {
            if lowercased.contains("create") {
                return getTemplate("create_folder")?.source ?? ""
            } else if lowercased.contains("delete") {
                return getTemplate("delete_file")?.source ?? ""
            } else if lowercased.contains("move") {
                return getTemplate("move_file")?.source ?? ""
            }
        }
        
        // Mail operations
        if lowercased.contains("email") || lowercased.contains("mail") {
            if lowercased.contains("send") {
                return getTemplate("send_email")?.source ?? ""
            } else if lowercased.contains("read") {
                return getTemplate("read_emails")?.source ?? ""
            }
        }
        
        // Calendar operations
        if lowercased.contains("calendar") || lowercased.contains("event") || lowercased.contains("meeting") {
            if lowercased.contains("create") || lowercased.contains("add") {
                return getTemplate("create_event")?.source ?? ""
            }
        }
        
        // Safari operations
        if lowercased.contains("browser") || lowercased.contains("safari") || lowercased.contains("web") {
            if lowercased.contains("open") {
                return getTemplate("open_url")?.source ?? ""
            } else if lowercased.contains("tab") {
                return getTemplate("new_tab")?.source ?? ""
            }
        }
        
        // Default to generic app control
        return getTemplate("generic_app_control")?.source ?? ""
    }
    
    // MARK: - Template Loading Methods
    
    private func loadFinderTemplates() {
        templates["create_folder"] = ScriptTemplate(
            name: "create_folder",
            description: "Create a new folder",
            source: """
            tell application "Finder"
                make new folder at desktop with properties {name:"{{folderName}}"}
            end tell
            """,
            parameters: ["folderName"],
            category: .finder,
            targetApps: ["Finder"],
            examples: ["Create folder named 'Documents'"]
        )
        
        templates["delete_file"] = ScriptTemplate(
            name: "delete_file",
            description: "Delete a file or folder",
            source: """
            tell application "Finder"
                delete (POSIX file "{{filePath}}")
            end tell
            """,
            parameters: ["filePath"],
            category: .finder,
            targetApps: ["Finder"],
            examples: ["Delete file at /Users/user/file.txt"]
        )
        
        templates["move_file"] = ScriptTemplate(
            name: "move_file",
            description: "Move a file to another location",
            source: """
            tell application "Finder"
                move (POSIX file "{{sourcePath}}") to (POSIX file "{{destinationPath}}")
            end tell
            """,
            parameters: ["sourcePath", "destinationPath"],
            category: .finder,
            targetApps: ["Finder"],
            examples: ["Move file from source to destination"]
        )
        
        templates["get_file_info"] = ScriptTemplate(
            name: "get_file_info",
            description: "Get information about a file",
            source: """
            tell application "Finder"
                set fileInfo to info for (POSIX file "{{filePath}}")
                return fileInfo
            end tell
            """,
            parameters: ["filePath"],
            category: .finder,
            targetApps: ["Finder"],
            examples: ["Get info for file at path"]
        )
    }
    
    private func loadMailTemplates() {
        templates["send_email"] = ScriptTemplate(
            name: "send_email",
            description: "Send an email",
            source: """
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:"{{subject}}", content:"{{content}}"}
                tell newMessage
                    make new to recipient at end of to recipients with properties {address:"{{recipient}}"}
                    send
                end tell
            end tell
            """,
            parameters: ["subject", "content", "recipient"],
            category: .mail,
            targetApps: ["Mail"],
            examples: ["Send email with subject and content"]
        )
        
        templates["read_emails"] = ScriptTemplate(
            name: "read_emails",
            description: "Read recent emails",
            source: """
            tell application "Mail"
                set recentMessages to messages 1 thru {{count}} of inbox
                set emailList to {}
                repeat with msg in recentMessages
                    set end of emailList to {subject of msg, sender of msg, date received of msg}
                end repeat
                return emailList
            end tell
            """,
            parameters: ["count"],
            category: .mail,
            targetApps: ["Mail"],
            examples: ["Read 10 recent emails"]
        )
    }
    
    private func loadCalendarTemplates() {
        templates["create_event"] = ScriptTemplate(
            name: "create_event",
            description: "Create a calendar event",
            source: """
            tell application "Calendar"
                tell calendar "{{calendarName}}"
                    make new event with properties {summary:"{{title}}", start date:date "{{startDate}}", end date:date "{{endDate}}"}
                end tell
            end tell
            """,
            parameters: ["calendarName", "title", "startDate", "endDate"],
            category: .calendar,
            targetApps: ["Calendar"],
            examples: ["Create event in calendar"]
        )
        
        templates["get_events"] = ScriptTemplate(
            name: "get_events",
            description: "Get upcoming events",
            source: """
            tell application "Calendar"
                set todayEvents to events of calendar "{{calendarName}}" whose start date is greater than (current date)
                set eventList to {}
                repeat with evt in todayEvents
                    set end of eventList to {summary of evt, start date of evt, end date of evt}
                end repeat
                return eventList
            end tell
            """,
            parameters: ["calendarName"],
            category: .calendar,
            targetApps: ["Calendar"],
            examples: ["Get events from calendar"]
        )
    }
    
    private func loadSafariTemplates() {
        templates["open_url"] = ScriptTemplate(
            name: "open_url",
            description: "Open a URL in Safari",
            source: """
            tell application "Safari"
                activate
                open location "{{url}}"
            end tell
            """,
            parameters: ["url"],
            category: .safari,
            targetApps: ["Safari"],
            examples: ["Open https://example.com"]
        )
        
        templates["new_tab"] = ScriptTemplate(
            name: "new_tab",
            description: "Open a new tab in Safari",
            source: """
            tell application "Safari"
                activate
                tell window 1
                    set current tab to (make new tab with properties {URL:"{{url}}"})
                end tell
            end tell
            """,
            parameters: ["url"],
            category: .safari,
            targetApps: ["Safari"],
            examples: ["Open new tab with URL"]
        )
        
        templates["get_current_url"] = ScriptTemplate(
            name: "get_current_url",
            description: "Get current Safari tab URL",
            source: """
            tell application "Safari"
                return URL of current tab of window 1
            end tell
            """,
            parameters: [],
            category: .safari,
            targetApps: ["Safari"],
            examples: ["Get current tab URL"]
        )
    }
    
    private func loadSystemTemplates() {
        templates["system_info"] = ScriptTemplate(
            name: "system_info",
            description: "Get system information",
            source: """
            set systemInfo to system info
            return systemInfo
            """,
            parameters: [],
            category: .system,
            targetApps: ["System"],
            examples: ["Get system information"]
        )
        
        templates["set_volume"] = ScriptTemplate(
            name: "set_volume",
            description: "Set system volume",
            source: """
            set volume output volume {{volume}}
            """,
            parameters: ["volume"],
            category: .system,
            targetApps: ["System"],
            examples: ["Set volume to 50"]
        )
        
        templates["display_notification"] = ScriptTemplate(
            name: "display_notification",
            description: "Display a system notification",
            source: """
            display notification "{{message}}" with title "{{title}}"
            """,
            parameters: ["message", "title"],
            category: .system,
            targetApps: ["System"],
            examples: ["Display notification with message"]
        )
    }
    
    private func loadTextEditorTemplates() {
        templates["create_text_file"] = ScriptTemplate(
            name: "create_text_file",
            description: "Create a text file",
            source: """
            tell application "TextEdit"
                activate
                make new document with properties {text:"{{content}}"}
                save document 1 in file "{{filePath}}"
            end tell
            """,
            parameters: ["content", "filePath"],
            category: .textEditor,
            targetApps: ["TextEdit"],
            examples: ["Create text file with content"]
        )
    }
    
    private func loadGenericTemplates() {
        templates["generic_app_control"] = ScriptTemplate(
            name: "generic_app_control",
            description: "Generic app control template",
            source: """
            tell application "{{appName}}"
                activate
                {{command}}
            end tell
            """,
            parameters: ["appName", "command"],
            category: .generic,
            targetApps: ["Any"],
            examples: ["Control any application"]
        )
        
        templates["quit_app"] = ScriptTemplate(
            name: "quit_app",
            description: "Quit an application",
            source: """
            tell application "{{appName}}"
                quit
            end tell
            """,
            parameters: ["appName"],
            category: .generic,
            targetApps: ["Any"],
            examples: ["Quit Safari"]
        )
        
        templates["launch_app"] = ScriptTemplate(
            name: "launch_app",
            description: "Launch an application",
            source: """
            tell application "{{appName}}"
                activate
            end tell
            """,
            parameters: ["appName"],
            category: .generic,
            targetApps: ["Any"],
            examples: ["Launch Calculator"]
        )
    }
}