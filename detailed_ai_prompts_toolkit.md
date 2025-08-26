# AI Prompts & Development Toolkit
## Building Sam - macOS AI Assistant

---

## 🎯 **Detailed AI Prompts for Specific Features**

### **Phase 1: Foundation & Architecture**

#### **1.1 Project Setup & Structure**

**Comprehensive Project Generation Prompt:**
```
Create a complete macOS SwiftUI application called "Sam" with the following specifications:

ARCHITECTURE:
- MVVM pattern with proper separation of concerns
- Core Data stack for persistent storage
- Combine framework for reactive programming
- Async/await for modern concurrency

APP STRUCTURE:
- Main chat interface similar to modern AI assistants
- Settings panel with multiple tabs
- Menu bar integration with global shortcuts
- System tray icon with quick actions

CORE DATA MODELS:
- ChatMessage: id, content, timestamp, isUser, taskResult
- UserSettings: preferences, apiKeys, shortcuts
- TaskHistory: command, result, executionTime, success

SWIFTUI VIEWS:
- ContentView (main container)
- ChatView (conversation interface)
- SettingsView (configuration panel)
- MessageBubble (individual chat messages)
- TaskResultView (command execution results)

MANAGERS:
- ChatManager: handles conversation flow
- TaskProcessor: executes commands
- SettingsManager: manages user preferences
- AIService: handles OpenAI API calls
- SystemService: macOS system integration

FILES TO GENERATE:
1. App.swift (main app file)
2. ContentView.swift
3. Models/ folder with all data models
4. Views/ folder with all SwiftUI views
5. Managers/ folder with business logic
6. Services/ folder with external integrations
7. Utils/ folder with helper functions
8. Info.plist with proper permissions

REQUIREMENTS:
- Native macOS design language
- Accessibility support (VoiceOver, keyboard navigation)
- Dark/light mode compatibility
- Proper error handling throughout
- Memory management best practices
- Thread safety for all async operations

Generate the complete project structure with all necessary files, including proper Swift code, no placeholders or TODOs.
```

#### **1.2 Core Data Stack Setup**

**Core Data Implementation Prompt:**
```
Create a robust Core Data stack for the Sam macOS app with these requirements:

ENTITIES:
1. ChatMessage
   - id: UUID (primary key)
   - content: String (user input or assistant response)
   - timestamp: Date
   - isUserMessage: Bool
   - taskType: String (optional - file_op, system_query, etc.)
   - taskResult: String (optional - execution result)
   - executionTime: Double (optional - how long task took)

2. UserPreferences
   - id: UUID (primary key)
   - openaiApiKey: String (encrypted)
   - preferredModel: String (gpt-4, gpt-3.5-turbo)
   - maxTokens: Int32
   - temperature: Float
   - autoExecuteTasks: Bool
   - confirmDangerous: Bool
   - themeMode: String (auto, light, dark)

3. TaskShortcut
   - id: UUID (primary key)
   - name: String (user-friendly name)
   - command: String (actual command text)
   - keyboardShortcut: String (optional)
   - category: String (file, system, app, etc.)
   - createdAt: Date
   - usageCount: Int32

IMPLEMENTATION:
- PersistenceController class with shared instance
- Proper error handling for Core Data operations
- Migration strategy for future schema changes
- CloudKit sync preparation (but not enabled initially)
- Background context for heavy operations
- Fetch request builders for common queries

SECURITY:
- Encrypt sensitive data (API keys) using Keychain Services
- Secure deletion of sensitive information
- Proper data validation and constraints

Generate complete Core Data implementation including:
- .xcdatamodeld file structure
- PersistenceController.swift
- Core Data model extensions
- Repository pattern for data access
- Sample data for testing
```

### **Phase 2: Core Intelligence System**

#### **2.1 Task Classification Engine**

**Intelligent Task Classifier Prompt:**
```
Create a sophisticated task classification system for the Sam AI assistant that can:

CLASSIFICATION CATEGORIES:
1. FILE_OPERATIONS: copy, move, delete, rename, search files
2. SYSTEM_QUERIES: battery, storage, memory, network status
3. APP_CONTROL: launch apps, quit apps, window management
4. TEXT_PROCESSING: summarize, translate, format, spell check
5. CALCULATIONS: math, unit conversions, currency
6. WEB_QUERIES: weather, news, general knowledge
7. AUTOMATION: multi-step workflows, scripting
8. SETTINGS: app preferences, system settings
9. HELP: documentation, command examples

IMPLEMENTATION REQUIREMENTS:
- Use local Natural Language Processing when possible
- Fallback to OpenAI API for complex classification
- Extract parameters from natural language input
- Confidence scoring for classification results
- Handle ambiguous inputs gracefully

NATURAL LANGUAGE EXAMPLES TO HANDLE:
- "copy the file report.pdf from downloads to desktop"
- "what's my battery percentage?"
- "open safari and go to github.com"
- "summarize this text: [long text content]"
- "convert 100 USD to EUR"
- "what's the weather in New York?"
- "create a workflow to organize my photos"

SWIFT IMPLEMENTATION:
```swift
class TaskClassifier {
    enum TaskType: String, CaseIterable {
        case fileOperation, systemQuery, appControl, textProcessing,
             calculation, webQuery, automation, settings, help
    }
    
    struct ClassificationResult {
        let taskType: TaskType
        let confidence: Double
        let parameters: [String: Any]
        let requiresAPI: Bool
    }
    
    func classify(_ input: String) async -> ClassificationResult
    func extractParameters(from input: String, for taskType: TaskType) -> [String: Any]
}
```

PARAMETER EXTRACTION:
- File paths and names
- Application names and bundle identifiers
- Numbers, dates, and units
- Text content for processing
- User preferences and settings

Generate complete implementation with:
- TaskClassifier.swift with all methods
- LocalNLPService.swift for on-device processing
- ParameterExtractor.swift for parsing inputs
- Comprehensive unit tests
- Example usage in chat interface
```

#### **2.2 AI Service Integration**

**OpenAI Integration with Advanced Features:**
```
Create a comprehensive AI service for Sam that integrates with OpenAI's API with these advanced features:

CORE FUNCTIONALITY:
- Multiple model support (GPT-4, GPT-3.5-turbo, GPT-4-turbo)
- Streaming responses for real-time feedback
- Function calling for structured task execution
- Cost tracking and usage monitoring
- Rate limiting and retry logic
- Context management for conversation history

ADVANCED FEATURES:
1. SMART ROUTING:
   - Route simple queries to cheaper models
   - Use GPT-4 only for complex reasoning
   - Local processing for basic tasks

2. FUNCTION CALLING:
   - Define functions for file operations
   - System information queries
   - App control commands
   - Structured data extraction

3. CONTEXT MANAGEMENT:
   - Maintain conversation history
   - Inject system context (current files, running apps)
   - Summarize long conversations to stay within token limits

IMPLEMENTATION STRUCTURE:
```swift
class AIService: ObservableObject {
    // Model management
    enum Model: String {
        case gpt4 = "gpt-4"
        case gpt35turbo = "gpt-3.5-turbo"
        case gpt4turbo = "gpt-4-turbo-preview"
    }
    
    // Streaming response handling
    func streamCompletion(
        messages: [ChatMessage],
        model: Model,
        functions: [FunctionDefinition]?
    ) -> AsyncThrowingStream<String, Error>
    
    // Function calling support
    func executeFunction(
        name: String,
        arguments: [String: Any]
    ) async throws -> FunctionResult
}
```

FUNCTION DEFINITIONS FOR TASK EXECUTION:
- file_operation(action: String, source: String, destination: String)
- system_query(type: String)
- app_control(action: String, app: String)
- text_process(operation: String, content: String)

ERROR HANDLING:
- Network connectivity issues
- API rate limits and quotas
- Invalid API keys
- Malformed responses
- Timeout handling

COST OPTIMIZATION:
- Token counting and estimation
- Response caching for repeated queries
- Smart model selection based on query complexity
- Usage analytics and reporting

Generate complete implementation including:
- AIService.swift with all networking logic
- OpenAIModels.swift with response structures
- FunctionCallHandler.swift for executing functions
- CostTracker.swift for usage monitoring
- Comprehensive error handling
- Unit tests with mock responses
```

### **Phase 3: System Integration Features**

#### **3.1 File System Operations**

**Advanced File System Integration:**
```
Create a comprehensive file system service for Sam that can handle complex file operations through natural language commands:

CORE OPERATIONS:
1. Basic Operations: copy, move, rename, delete
2. Batch Operations: process multiple files at once
3. Smart Search: find files by name, type, content, date
4. Organization: auto-organize files by type, date, project
5. Metadata: extract and display file information
6. Permissions: handle file permissions safely

NATURAL LANGUAGE PROCESSING:
Handle commands like:
- "copy all PDFs from Downloads to Documents/Work"
- "find all images larger than 5MB modified this week"
- "organize my Desktop files into folders by type"
- "rename all IMG_ files in this folder with today's date"
- "move duplicate files to a separate folder"

IMPLEMENTATION REQUIREMENTS:
```swift
class FileSystemService {
    // Core operations
    func copyFiles(matching pattern: String, from source: String, to destination: String) async throws -> OperationResult
    func moveFiles(_ files: [URL], to destination: URL) async throws -> OperationResult
    func deleteFiles(_ files: [URL], moveToTrash: Bool = true) async throws -> OperationResult
    func renameFiles(in directory: URL, pattern: String, newPattern: String) async throws -> OperationResult
    
    // Smart search
    func findFiles(in directory: URL, matching criteria: SearchCriteria) async throws -> [FileInfo]
    func searchByContent(_ query: String, in directories: [URL]) async throws -> [FileInfo]
    
    // Organization
    func organizeByType(in directory: URL) async throws -> OrganizationResult
    func organizeByDate(in directory: URL, grouping: DateGrouping) async throws -> OrganizationResult
    func findDuplicates(in directories: [URL]) async throws -> [DuplicateGroup]
}
```

SAFETY FEATURES:
- Dry-run mode to preview operations
- Undo functionality for recent operations
- Permission checks before destructive operations
- User confirmation for dangerous operations
- Backup creation for important operations

ADVANCED FEATURES:
1. FILE TYPE DETECTION:
   - MIME type identification
   - Custom type definitions
   - Smart categorization

2. BATCH PROCESSING:
   - Progress reporting for long operations
   - Cancellation support
   - Error handling for partial failures

3. METADATA EXTRACTION:
   - Image EXIF data
   - Document properties
   - Media file information

INTEGRATION WITH FINDER:
- Reveal files in Finder
- Use Finder tags and labels
- Respect Finder preferences
- Handle alias and symbolic links

Generate complete implementation with:
- FileSystemService.swift with all operations
- FileInfo.swift with metadata structures
- SearchCriteria.swift for flexible searching
- OperationResult.swift for detailed results
- FileOperationHistory.swift for undo functionality
- Comprehensive error handling and logging
- Unit tests with temporary file creation
```

#### **3.2 Application Integration Framework**

**Multi-Method App Integration System:**
```
Create a flexible application integration system that can control macOS applications using multiple methods:

INTEGRATION METHODS (in priority order):
1. Native SDK Integration (future extensibility)
2. URL Schemes (x-callback-url support)
3. AppleScript/Apple Events
4. Accessibility API (universal fallback)
5. GUI Automation (last resort)

SUPPORTED APPLICATIONS:
Built-in Apps:
- Safari: open URLs, manage bookmarks, search tabs
- Mail: compose emails, search, manage folders
- Calendar: create events, search, manage calendars
- Notes: create/edit notes, search, organize
- Finder: file operations, window management
- System Preferences: access specific panes

Third-party Apps (with URL scheme support):
- Things 3: task management
- Obsidian: note management
- VS Code: open files and projects
- Slack: send messages, set status

IMPLEMENTATION ARCHITECTURE:
```swift
protocol AppIntegration {
    var bundleIdentifier: String { get }
    var supportedCommands: [CommandDefinition] { get }
    
    func canHandle(_ command: String) -> Bool
    func execute(_ command: ParsedCommand) async throws -> CommandResult
}

class AppIntegrationManager {
    private var integrations: [String: AppIntegration] = [:]
    
    func registerIntegration(_ integration: AppIntegration)
    func findIntegration(for bundleId: String) -> AppIntegration?
    func executeCommand(_ command: String, targetApp: String?) async throws -> CommandResult
}
```

SPECIFIC INTEGRATIONS:

1. SAFARI INTEGRATION:
```swift
class SafariIntegration: AppIntegration {
    // Commands: "open github.com", "find tabs with 'project'", "bookmark current page"
    func openURL(_ url: String) async throws -> CommandResult
    func searchTabs(_ query: String) async throws -> [TabInfo]
    func createBookmark(_ url: String, title: String, folder: String?) async throws
}
```

2. MAIL INTEGRATION:
```swift
class MailIntegration: AppIntegration {
    // Commands: "send email to john about project", "search emails from last week"
    func composeEmail(to: [String], subject: String, body: String) async throws
    func searchEmails(query: String, dateRange: DateInterval?) async throws -> [EmailInfo]
}
```

3. CALENDAR INTEGRATION:
```swift
class CalendarIntegration: AppIntegration {
    // Commands: "create meeting tomorrow at 2pm", "show today's schedule"
    func createEvent(title: String, date: Date, duration: TimeInterval) async throws
    func findEvents(in dateRange: DateInterval) async throws -> [EventInfo]
}
```

APPLE SCRIPT GENERATION:
- Dynamic script generation for complex operations
- Script compilation and caching
- Error handling for script execution
- Permission management for automation

ACCESSIBILITY API USAGE:
```swift
class AccessibilityController {
    func findElement(by identifier: String, in app: NSRunningApplication) -> AXUIElement?
    func performAction(_ action: String, on element: AXUIElement) throws
    func getValue(from element: AXUIElement) throws -> Any?
    func setValue(_ value: Any, for element: AXUIElement) throws
}
```

ERROR HANDLING:
- App not installed or not running
- Permission denied for automation
- Script execution failures
- Network connectivity for web-based integrations

Generate complete implementation including:
- AppIntegrationManager.swift with plugin architecture
- Individual integration classes for each supported app
- AppleScriptGenerator.swift for dynamic script creation
- AccessibilityController.swift for universal app control
- CommandParser.swift for natural language command parsing
- Comprehensive error handling and logging
- Integration tests with mock applications
```

### **Phase 4: Advanced Features & Automation**

#### **4.1 Workflow Automation Engine**

**Multi-Step Workflow System:**
```
Create an advanced workflow automation engine that can chain multiple tasks and handle complex logic:

WORKFLOW CAPABILITIES:
1. Sequential Execution: run tasks in order
2. Conditional Logic: if-then-else branches
3. Loops: repeat actions with variations
4. Error Handling: retry, skip, or abort on failures
5. User Interaction: prompt for input during execution
6. Scheduling: time-based or event-triggered execution

WORKFLOW DEFINITION:
```swift
struct Workflow {
    let id: UUID
    let name: String
    let description: String
    let steps: [WorkflowStep]
    let trigger: WorkflowTrigger?
    let schedule: WorkflowSchedule?
}

enum WorkflowStep {
    case action(WorkflowAction)
    case condition(WorkflowCondition)
    case loop(WorkflowLoop)
    case userInput(UserInputRequest)
    case delay(TimeInterval)
}

struct WorkflowAction {
    let type: ActionType
    let parameters: [String: Any]
    let continueOnError: Bool
    let retryCount: Int
}
```

NATURAL LANGUAGE WORKFLOW CREATION:
Parse commands like:
- "Create a workflow to organize photos: find all HEIC files, convert to JPEG, sort by date into folders, delete originals"
- "Daily backup workflow: compress Documents folder, upload to cloud, clean up old backups"
- "Email processing: check for emails with 'invoice', extract PDF attachments, save to accounting folder, mark as processed"

WORKFLOW EXAMPLES TO IMPLEMENT:

1. PHOTO ORGANIZATION WORKFLOW:
```
Steps:
1. Find all HEIC files in specified directory
2. For each file:
   - Convert HEIC to JPEG
   - Extract date from metadata
   - Create folder structure (Year/Month)
   - Move converted file to appropriate folder
   - Delete original HEIC (with user confirmation)
3. Generate summary report
```

2. DOCUMENT PROCESSING WORKFLOW:
```
Steps:
1. Monitor Downloads folder for PDF files
2. When new PDF appears:
   - Extract text content
   - Classify document type (invoice, contract, etc.)
   - Rename with standardized format
   - Move to appropriate folder
   - Add to document database
   - Send notification
```

WORKFLOW EXECUTION ENGINE:
```swift
class WorkflowExecutor: ObservableObject {
    @Published var activeWorkflows: [ActiveWorkflow] = []
    @Published var executionHistory: [WorkflowExecution] = []
    
    func execute(_ workflow: Workflow, context: ExecutionContext) async throws -> WorkflowResult
    func pause(_ workflowId: UUID) throws
    func resume(_ workflowId: UUID) throws
    func cancel(_ workflowId: UUID) throws
}

struct ExecutionContext {
    let variables: [String: Any]
    let userInteractionHandler: UserInteractionHandler
    let progressHandler: ProgressHandler
}
```

SCHEDULING & TRIGGERS:
- Time-based scheduling (daily, weekly, monthly)
- File system events (file created, modified, deleted)
- System events (login, wake from sleep, battery level)
- Manual triggers from user commands

WORKFLOW BUILDER UI:
```swift
struct WorkflowBuilderView: View {
    @State private var workflow = Workflow()
    
    var body: some View {
        VStack {
            WorkflowStepsList(steps: $workflow.steps)
            WorkflowActionPalette()
            WorkflowTestRunner(workflow: workflow)
        }
    }
}
```

Generate complete implementation including:
- WorkflowEngine.swift with execution logic
- WorkflowDefinition.swift with data structures
- WorkflowBuilder.swift for creating workflows from natural language
- WorkflowScheduler.swift for time-based execution
- WorkflowUI.swift for visual workflow management
- Comprehensive error handling and recovery
- Progress reporting and cancellation
- Workflow sharing and templates
```

---

## 🛠 **Specific Tool Recommendations & Setup Guides**

### **AI Development Tools**

#### **1. Primary AI Coding Assistants**

**Claude (Anthropic) - BEST for Architecture & Complex Logic**
```bash
# Setup
- Sign up for Claude Pro ($20/month)
- Use web interface for major architectural decisions
- Best for: System design, complex algorithms, documentation

# Optimal Usage:
- Start conversations with complete context
- Request full implementations, not snippets
- Ask for error handling and edge cases
- Use for code reviews and optimization
```

**GitHub Copilot - BEST for Real-time Coding**
```bash
# Setup in VS Code/Xcode
1. Install GitHub Copilot extension
2. Sign in with GitHub account ($10/month)
3. Configure for Swift/SwiftUI development

# VS Code Settings for Swift:
{
    "github.copilot.enable": {
        "*": true,
        "swift": true,
        "swiftui": true
    }
}

# Best Practices:
- Write descriptive comments before coding
- Use meaningful variable names
- Break complex functions into smaller parts
```

**Cursor IDE - BEST for AI-First Development**
```bash
# Installation
1. Download from cursor.sh
2. Import VS Code settings and extensions
3. Enable AI features ($20/month)

# Key Features:
- Cmd+K: AI code editing
- Cmd+L: AI chat in context
- @-mentions for specific files
- Codebase understanding

# Setup for macOS Development:
1. Install Swift extensions
2. Configure build tools for Xcode projects
3. Set up AI model preferences
```

#### **2. Development Environment Setup**

**Xcode Configuration for AI-Assisted Development**
```bash
# Essential Setup:
1. Install Xcode 15+ from Mac App Store
2. Install Command Line Tools:
   xcode-select --install

3. Create new macOS project:
   - Template: macOS App
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: Yes

# Recommended Xcode Extensions:
- SwiftFormat (code formatting)
- SwiftLint (code quality)
- SourceKit-LSP (language server)
```

**Git Repository Setup**
```bash
# Initialize project
git init
git add .
git commit -m "Initial project setup"

# GitHub setup
gh repo create Sam-macos --private
git remote add origin https://github.com/yourusername/Sam-macos.git
git push -u origin main

# AI-Friendly .gitignore
echo "# Xcode
*.xcuserstate
*.xcworkspace/xcuserdata/
DerivedData/
.DS_Store

# AI Generated
ai-prompts/
temp-code/
*.ai-generated" > .gitignore
```

#### **3. API Service Setup**

**OpenAI API Configuration**
```swift
// APIKeys.swift (never commit this file!)
struct APIKeys {
    static let openai = "sk-..." // Your OpenAI API key
}

// Add to .gitignore
echo "APIKeys.swift" >> .gitignore
```

**Environment Configuration**
```swift
// Config.swift
struct Config {
    static let openaiBaseURL = "https://api.openai.com/v1"
    static let maxTokens = 4000
    static let defaultModel = "gpt-4-turbo-preview"
    
    #if DEBUG
    static let enableLogging = true
    static let useTestKeys = true
    #else
    static let enableLogging = false
    static let useTestKeys = false
    #endif
}
```

### **Testing & Quality Tools**

#### **1. Unit Testing Framework**
```swift
// Test setup with XCTest
import XCTest
@testable import Sam

class TaskClassifierTests: XCTestCase {
    var classifier: TaskClassifier!
    
    override func setUp() {
        super.setUp()
        classifier = TaskClassifier()
    }
    
    func testFileOperationClassification() async {
        let result = await classifier.classify("copy file.txt to Desktop")
        XCTAssertEqual(result.taskType, .fileOperation)
        XCTAssertGreaterThan(result.confidence, 0.8)
    }
}
```

#### **2. Performance Monitoring**
```swift
// PerformanceTracker.swift
import os.signpost

class PerformanceTracker {
    private let log = OSLog(subsystem: "com.yourcompany.Sam", category: "performance")
    
    func trackTaskExecution<T>(_ taskName: String, operation: () async throws -> T) async rethrows -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Task Execution", signpostID: signpostID, "%{public}s", taskName)
        
        let result = try await operation()
        
        os_signpost(.end, log: log, name: "Task Execution", signpostID: signpostID)
        return result
    }
}
```

---

## 🔄 **Alternative Approaches for Challenging Parts**

### **Challenge 1: Complex macOS System Integration**

#### **Problem**: Deep system integration requires extensive macOS knowledge

**Alternative Approach 1: Progressive Web App Hybrid**
```javascript
// Use Tauri for system access with web technologies
// tauri.conf.json
{
  "allowlist": {
    "fs": {
      "all": true,
      "readFile": true,
      "writeFile": true,
      "createDir": true
    },
    "shell": {
      "all": false,
      "execute": true,
      "open": true
    }
  }
}

// JavaScript for file operations
import { invoke } from '@tauri-apps/api/tauri';

async function copyFile(source, destination) {
    return await invoke('copy_file', { source, destination });
}
```

**Alternative Approach 2: Shell Script Integration**
```swift
// ExecuteShellCommand.swift
class ShellCommandExecutor {
    func execute(_ command: String, arguments: [String] = []) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [command] + arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error)"
        }
    }
}

// Usage for file operations
let executor = ShellCommandExecutor()
let result = executor.execute("cp", arguments: [source, destination])
```

**Alternative Approach 3: Third-Party Libraries**
```swift
// Use existing Swift packages
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/kareman/SwiftShell", from: "5.1.0"),
    .package(url: "https://github.com/kylef/PathKit", from: "1.0.0"),
    .package(url: "https://github.com/JohnSundell/Files", from: "4.0.0")
]

// Simplified file operations
import Files
import PathKit

class SimpleFileOperations {
    func copyFile(from source: String, to destination: String) throws {
        let sourceFile = try File(path: source)
        try sourceFile.copy(to: Folder(path: destination))
    }
}
```

### **Challenge 2: Local AI Model Integration**

#### **Problem**: CoreML optimization and model integration is complex

**Alternative Approach 1: Cloud-First with Smart Caching**
```swift
// CloudAIService.swift with intelligent caching
class SmartAIService {
    private let cache = NSCache<NSString, CacheItem>()
    private let localClassifier = SimpleTaskClassifier()
    
    func processTask(_ input: String) async -> TaskResult {
        // Try local classification first
        if let localResult = localClassifier.tryLocal(input) {
            return localResult
        }
        
        // Check cache for similar queries
        let cacheKey = generateCacheKey(input)
        if let cached = cache.object(forKey: cacheKey) {
            return cached.result
        }
        
        // Fall back to cloud processing
        let cloudResult = await processWithCloud(input)
        cache.setObject(CacheItem(result: cloudResult), forKey: cacheKey)
        return cloudResult
    }
}
```

**Alternative Approach 2: Ollama Integration**
```swift
// Local LLM via Ollama (easier than CoreML)
class OllamaService {
    private let baseURL = "http://localhost:11434"
    
    func generateCompletion(prompt: String) async throws -> String {
        let request = OllamaRequest(
            model: "llama3.2:3b",
            prompt: prompt,
            stream: false
        )
        
        // Simple HTTP request to local Ollama instance
        let response = try await URLSession.shared.data(for: createRequest(request))
        return parseResponse(response)
    }
}

// User installs Ollama separately, app just communicates with it
```

**Alternative Approach 3: Hybrid Lightweight Approach**
```swift
// Use NaturalLanguage framework for basic classification
import NaturalLanguage

class LightweightClassifier {
    private let recognizer = NLLanguageRecognizer()
    
    func classifyIntent(_ text: String) -> TaskIntent {
        // Use built-in sentiment analysis and keyword matching
        let sentiment = NLTagger(tagSchemes: [.sentimentScore])
        sentiment.string = text
        
        // Simple keyword-based classification
        let keywords = [
            "copy|move|delete|rename": TaskIntent.fileOperation,
            "battery|storage|memory": TaskIntent.systemQuery,
            "open|launch|quit": TaskIntent.appControl,
            "weather|time|calculate": TaskIntent.webQuery
        ]
        
        for (pattern, intent) in keywords {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return intent
            }
        }
        
        return .complexQuery // Send to cloud
    }
}
```

### **Challenge 3: Advanced App Integration**

#### **Problem**: Complex app automation requires deep knowledge of each app

**Alternative Approach 1: URL Scheme Focus**
```swift
// URLSchemeManager.swift - Focus on apps with good URL scheme support
struct AppURLSchemes {
    static let schemes: [String: [String: String]] = [
        "Things 3": [
            "add_task": "things:///add?title={title}&notes={notes}",
            "show_today": "things:///today"
        ],
        "Obsidian": [
            "open_note": "obsidian://open?vault={vault}&file={file}",
            "new_note": "obsidian://new?vault={vault}&name={name}"
        ],
        "VS Code": [
            "open_file": "vscode://file/{path}",
            "open_folder": "vscode://file/{path}"
        ]
    ]
    
    static func executeURLScheme(app: String, action: String, parameters: [String: String]) -> Bool {
        guard let schemes = schemes[app],
              let urlTemplate = schemes[action] else { return false }
        
        var urlString = urlTemplate
        for (key, value) in parameters {
            urlString = urlString.replacingOccurrences(of: "{\(key)}", with: value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        }
        
        guard let url = URL(string: urlString) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
```

**Alternative Approach 2: AppleScript Templates**
```swift
// AppleScriptTemplates.swift - Pre-written scripts for common tasks
class AppleScriptTemplates {
    static let templates: [String: String] = [
        "safari_open_url": """
            tell application "Safari"
                activate
                tell window 1
                    set current tab to (make new tab with properties {URL:"{url}"})
                end tell
            end tell
        """,
        
        "mail_compose": """
            tell application "Mail"
                activate
                set newMessage to make new outgoing message with properties {subject:"{subject}", content:"{body}"}
                tell newMessage
                    make new to recipient with properties {address:"{to}"}
                end tell
                activate
            end tell
        """,
        
        "finder_reveal": """
            tell application "Finder"
                activate
                reveal POSIX file "{path}"
            end tell
        """
    ]
    
    static func execute(template: String