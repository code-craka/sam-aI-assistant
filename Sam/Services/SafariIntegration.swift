import Foundation
import AppKit

// MARK: - Safari Integration
class SafariIntegration: AppIntegration {
    
    // MARK: - AppIntegration Protocol
    let bundleIdentifier = "com.apple.Safari"
    let displayName = "Safari"
    
    var supportedCommands: [CommandDefinition] {
        return [
            CommandDefinition(
                name: "open_url",
                description: "Open a URL in Safari",
                parameters: [
                    CommandParameter(name: "url", type: .url, description: "URL to open")
                ],
                examples: ["open google.com", "go to apple.com", "visit https://github.com"],
                integrationMethod: .urlScheme
            ),
            CommandDefinition(
                name: "bookmark_page",
                description: "Bookmark the current page",
                parameters: [
                    CommandParameter(name: "folder", type: .string, isRequired: false, description: "Bookmark folder name")
                ],
                examples: ["bookmark this page", "add to bookmarks", "bookmark in Work folder"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "organize_bookmarks",
                description: "Organize bookmarks by creating folders",
                parameters: [
                    CommandParameter(name: "folder_name", type: .string, description: "Name of the bookmark folder to create")
                ],
                examples: ["create bookmark folder Work", "organize bookmarks in Development"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "new_tab",
                description: "Open a new tab",
                parameters: [
                    CommandParameter(name: "url", type: .url, isRequired: false, description: "Optional URL to open in new tab")
                ],
                examples: ["open new tab", "new tab with google.com"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "close_tab",
                description: "Close the current tab",
                parameters: [],
                examples: ["close tab", "close current tab"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "navigate_tabs",
                description: "Navigate between tabs",
                parameters: [
                    CommandParameter(name: "direction", type: .string, description: "Direction: next, previous, or tab number")
                ],
                examples: ["next tab", "previous tab", "go to tab 3"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "find_tab",
                description: "Find and switch to a tab by title or URL",
                parameters: [
                    CommandParameter(name: "query", type: .string, description: "Search query for tab title or URL")
                ],
                examples: ["find tab github", "switch to tab containing google"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "search_history",
                description: "Search browsing history",
                parameters: [
                    CommandParameter(name: "query", type: .string, description: "Search query for history")
                ],
                examples: ["search history for apple", "find in history swift documentation"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "get_current_page",
                description: "Get information about the current page",
                parameters: [],
                examples: ["what page am I on", "current page info", "get page title"],
                integrationMethod: .appleScript
            ),
            CommandDefinition(
                name: "search",
                description: "Search for something",
                parameters: [
                    CommandParameter(name: "query", type: .string, description: "Search query")
                ],
                examples: ["search for swift programming", "look up weather"],
                integrationMethod: .urlScheme
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
        
        // Check if we can handle the specific command
        switch command.intent {
        case .appControl:
            return true
        case .webQuery:
            return true
        default:
            return false
        }
    }
    
    func execute(_ command: ParsedCommand) async throws -> CommandResult {
        let startTime = Date()
        
        // Ensure Safari is running for most operations
        if !appDiscovery.isAppRunning(bundleIdentifier: bundleIdentifier) {
            try await launchSafari()
        }
        
        let result: CommandResult
        
        // Determine the specific action based on command parameters and text analysis
        if let url = command.parameters["url"] {
            result = try await openURL(url)
        } else if command.originalText.lowercased().contains("bookmark") {
            let folder = command.parameters["folder"] as? String
            result = try await bookmarkCurrentPage(folder: folder)
        } else if command.originalText.lowercased().contains("organize bookmark") || command.originalText.lowercased().contains("create bookmark folder") {
            let folderName = command.parameters["folder_name"] as? String ?? extractFolderName(from: command.originalText)
            result = try await createBookmarkFolder(folderName)
        } else if command.originalText.lowercased().contains("new tab") {
            let url = command.parameters["url"] as? String
            result = try await openNewTab(url: url)
        } else if command.originalText.lowercased().contains("close tab") {
            result = try await closeCurrentTab()
        } else if command.originalText.lowercased().contains("next tab") {
            result = try await navigateToTab(direction: "next")
        } else if command.originalText.lowercased().contains("previous tab") || command.originalText.lowercased().contains("prev tab") {
            result = try await navigateToTab(direction: "previous")
        } else if command.originalText.lowercased().contains("go to tab") {
            let tabNumber = extractTabNumber(from: command.originalText)
            result = try await navigateToTab(direction: String(tabNumber))
        } else if command.originalText.lowercased().contains("find tab") || command.originalText.lowercased().contains("switch to tab") {
            let query = command.parameters["query"] as? String ?? extractTabQuery(from: command.originalText)
            result = try await findAndSwitchToTab(query: query)
        } else if command.originalText.lowercased().contains("search history") || command.originalText.lowercased().contains("find in history") {
            let query = command.parameters["query"] as? String ?? extractHistoryQuery(from: command.originalText)
            result = try await searchBrowsingHistory(query: query)
        } else if command.originalText.lowercased().contains("current page") || command.originalText.lowercased().contains("page info") || command.originalText.lowercased().contains("what page") {
            result = try await getCurrentPageInfo()
        } else if command.originalText.lowercased().contains("search") {
            let query = extractSearchQuery(from: command.originalText)
            result = try await searchFor(query)
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
            canOpenFiles: true,
            canManageWindows: true,
            canAccessMenus: true,
            customCapabilities: [
                "canOpenURL": true,
                "canBookmark": true,
                "canOrganizeBookmarks": true,
                "canNavigate": true,
                "canManageTabs": true,
                "canSearchTabs": true,
                "canSearchHistory": true,
                "canGetPageInfo": true,
                "canSearch": true
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func launchSafari() async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppIntegrationError.appNotInstalled(bundleIdentifier)
        }
        
        try NSWorkspace.shared.launchApplication(at: appURL, options: [], configuration: [:])
        
        // Wait a moment for Safari to launch
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func openURL(_ urlString: String) async throws -> CommandResult {
        var cleanURL = urlString
        
        // Add protocol if missing
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        guard let url = URL(string: cleanURL) else {
            throw AppIntegrationError.invalidParameters(["Invalid URL: \(urlString)"])
        }
        
        // Try URL scheme first (fastest)
        let success = try await urlSchemeHandler.openURL(url)
        
        if success {
            return CommandResult(
                success: true,
                output: "Opened \(cleanURL) in Safari",
                integrationMethod: .urlScheme,
                followUpActions: ["You can now browse the website", "Say 'bookmark this page' to save it"]
            )
        } else {
            throw AppIntegrationError.integrationMethodFailed(.urlScheme, "Failed to open URL")
        }
    }
    
    private func bookmarkCurrentPage(folder: String? = nil) async throws -> CommandResult {
        let script: String
        
        if let folder = folder {
            script = """
            tell application "Safari"
                tell front window
                    set currentURL to URL of current tab
                    set currentTitle to name of current tab
                    
                    -- Try to find existing folder or create new one
                    try
                        set targetFolder to bookmark folder "\(folder)"
                    on error
                        set targetFolder to make new bookmark folder with properties {name:"\(folder)"}
                    end try
                    
                    -- Add bookmark to the folder
                    tell targetFolder
                        make new bookmark with properties {name:currentTitle, URL:currentURL}
                    end tell
                end tell
            end tell
            """
        } else {
            script = """
            tell application "Safari"
                tell front window
                    set currentURL to URL of current tab
                    set currentTitle to name of current tab
                    make new bookmark with properties {name:currentTitle, URL:currentURL}
                end tell
            end tell
            """
        }
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            let output = folder != nil ? "Added current page to '\(folder!)' bookmark folder" : "Added current page to Safari bookmarks"
            return CommandResult(
                success: true,
                output: output,
                integrationMethod: .appleScript,
                followUpActions: ["You can view your bookmarks in Safari's sidebar", "Say 'organize bookmarks' to create more folders"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func openNewTab(url: String? = nil) async throws -> CommandResult {
        let script: String
        
        if let url = url {
            var cleanURL = url
            if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
                cleanURL = "https://" + cleanURL
            }
            
            script = """
            tell application "Safari"
                tell front window
                    set newTab to make new tab
                    set URL of newTab to "\(cleanURL)"
                end tell
            end tell
            """
        } else {
            script = """
            tell application "Safari"
                tell front window
                    make new tab
                end tell
            end tell
            """
        }
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            let output = url != nil ? "Opened new tab with \(url!)" : "Opened new tab in Safari"
            return CommandResult(
                success: true,
                output: output,
                integrationMethod: .appleScript,
                followUpActions: url == nil ? ["You can now navigate to a website", "Say 'go to [website]' to open a URL"] : ["Page is loading in the new tab"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func closeCurrentTab() async throws -> CommandResult {
        let script = """
        tell application "Safari"
            tell front window
                close current tab
            end tell
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Closed current tab in Safari",
                integrationMethod: .appleScript
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func searchFor(_ query: String) async throws -> CommandResult {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = "https://www.google.com/search?q=\(encodedQuery)"
        
        return try await openURL(searchURL)
    }
    
    private func createBookmarkFolder(_ folderName: String) async throws -> CommandResult {
        let script = """
        tell application "Safari"
            try
                set existingFolder to bookmark folder "\(folderName)"
                return "Folder '\(folderName)' already exists"
            on error
                make new bookmark folder with properties {name:"\(folderName)"}
                return "Created bookmark folder '\(folderName)'"
            end try
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["You can now bookmark pages to this folder", "Say 'bookmark in \(folderName)' to add pages to this folder"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func navigateToTab(direction: String) async throws -> CommandResult {
        let script: String
        
        if let tabNumber = Int(direction) {
            script = """
            tell application "Safari"
                tell front window
                    if (count of tabs) >= \(tabNumber) then
                        set current tab to tab \(tabNumber)
                        set tabTitle to name of current tab
                        return "Switched to tab \(tabNumber): " & tabTitle
                    else
                        return "Tab \(tabNumber) does not exist. There are " & (count of tabs) & " tabs open."
                    end if
                end tell
            end tell
            """
        } else if direction == "next" {
            script = """
            tell application "Safari"
                tell front window
                    set currentIndex to index of current tab
                    set totalTabs to count of tabs
                    if currentIndex < totalTabs then
                        set current tab to tab (currentIndex + 1)
                        set tabTitle to name of current tab
                        return "Switched to next tab: " & tabTitle
                    else
                        set current tab to tab 1
                        set tabTitle to name of current tab
                        return "Wrapped to first tab: " & tabTitle
                    end if
                end tell
            end tell
            """
        } else if direction == "previous" {
            script = """
            tell application "Safari"
                tell front window
                    set currentIndex to index of current tab
                    set totalTabs to count of tabs
                    if currentIndex > 1 then
                        set current tab to tab (currentIndex - 1)
                        set tabTitle to name of current tab
                        return "Switched to previous tab: " & tabTitle
                    else
                        set current tab to tab totalTabs
                        set tabTitle to name of current tab
                        return "Wrapped to last tab: " & tabTitle
                    end if
                end tell
            end tell
            """
        } else {
            throw AppIntegrationError.invalidParameters(["Invalid direction: \(direction)"])
        }
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: ["You can continue navigating with 'next tab' or 'previous tab'"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func findAndSwitchToTab(query: String) async throws -> CommandResult {
        let script = """
        tell application "Safari"
            tell front window
                set foundTab to missing value
                set foundIndex to 0
                
                repeat with i from 1 to count of tabs
                    set tabTitle to name of tab i
                    set tabURL to URL of tab i
                    
                    if tabTitle contains "\(query)" or tabURL contains "\(query)" then
                        set foundTab to tab i
                        set foundIndex to i
                        exit repeat
                    end if
                end repeat
                
                if foundTab is not missing value then
                    set current tab to foundTab
                    set tabTitle to name of foundTab
                    return "Found and switched to tab " & foundIndex & ": " & tabTitle
                else
                    return "No tab found containing '\(query)'"
                end if
            end tell
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            let success = !result.contains("No tab found")
            return CommandResult(
                success: success,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: success ? ["Tab switched successfully"] : ["Try a different search term", "Use 'new tab' to open a new tab"]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func searchBrowsingHistory(query: String) async throws -> CommandResult {
        let script = """
        tell application "Safari"
            -- Note: Direct history access is limited in Safari via AppleScript
            -- This is a workaround using Safari's search functionality
            tell front window
                if (count of tabs) = 0 then
                    make new tab
                end if
                
                -- Open Safari's history search
                set URL of current tab to "safari://history"
                
                return "Opened Safari history. You can search for '\(query)' using the search box."
            end tell
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: "Opened Safari history page. Search for '\(query)' in the search box to find matching pages.",
                integrationMethod: .appleScript,
                followUpActions: [
                    "Use the search box in Safari's history page to find '\(query)'",
                    "You can also use Cmd+F to search within the history page"
                ]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    private func getCurrentPageInfo() async throws -> CommandResult {
        let script = """
        tell application "Safari"
            tell front window
                if (count of tabs) > 0 then
                    set currentTab to current tab
                    set pageTitle to name of currentTab
                    set pageURL to URL of currentTab
                    set tabIndex to index of currentTab
                    set totalTabs to count of tabs
                    
                    return "Current page: " & pageTitle & "\\nURL: " & pageURL & "\\nTab " & tabIndex & " of " & totalTabs
                else
                    return "No tabs are currently open in Safari"
                end if
            end tell
        end tell
        """
        
        do {
            let result = try await appleScriptEngine.executeScript(script)
            return CommandResult(
                success: true,
                output: result,
                integrationMethod: .appleScript,
                followUpActions: [
                    "Say 'bookmark this page' to save it",
                    "Say 'new tab' to open another tab",
                    "Say 'close tab' to close this tab"
                ]
            )
        } catch {
            throw AppIntegrationError.integrationMethodFailed(.appleScript, error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods for Text Parsing
    
    private func extractFolderName(from input: String) -> String {
        let patterns = [
            "create bookmark folder (.+)",
            "organize bookmarks in (.+)",
            "bookmark folder (.+)",
            "folder (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range) {
                    if let folderRange = Range(match.range(at: 1), in: input) {
                        return String(input[folderRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        return "New Folder"
    }
    
    private func extractTabNumber(from input: String) -> Int {
        let pattern = "go to tab (\\d+)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            if let match = regex.firstMatch(in: input, options: [], range: range) {
                if let numberRange = Range(match.range(at: 1), in: input) {
                    return Int(String(input[numberRange])) ?? 1
                }
            }
        }
        
        return 1
    }
    
    private func extractTabQuery(from input: String) -> String {
        let patterns = [
            "find tab (.+)",
            "switch to tab containing (.+)",
            "tab (.+)"
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
        
        return ""
    }
    
    private func extractHistoryQuery(from input: String) -> String {
        let patterns = [
            "search history for (.+)",
            "find in history (.+)",
            "history (.+)"
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
        
        return ""
    }

    private func extractSearchQuery(from input: String) -> String {
        let patterns = [
            "search for (.+)",
            "look up (.+)",
            "find (.+)",
            "google (.+)"
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
        
        // Fallback: return the whole input
        return input
    }
}