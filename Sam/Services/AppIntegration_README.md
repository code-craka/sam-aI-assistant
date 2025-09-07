# App Integration System

The App Integration System provides a comprehensive framework for controlling and interacting with macOS applications through natural language commands. It supports multiple integration methods and provides a plugin architecture for extending functionality.

## Overview

The system consists of several key components:

- **AppIntegrationManager**: Central coordinator for all app integrations
- **CommandParser**: Natural language processing for command interpretation
- **AppDiscoveryService**: Automatic discovery of installed applications
- **Integration Engines**: URL schemes, AppleScript, Accessibility API handlers
- **Specific Integrations**: Safari, Mail, Calendar, Finder, and generic app support

## Architecture

```
User Command → CommandParser → AppIntegrationManager → Specific Integration → Integration Engine → macOS App
```

## Supported Integration Methods

### 1. URL Schemes (Priority 1)
- Fastest and most reliable method
- Used for opening URLs, composing emails, etc.
- Limited to apps that support URL schemes

### 2. AppleScript (Priority 2)
- Powerful automation capabilities
- Works with most macOS applications
- Can perform complex multi-step operations

### 3. Accessibility API (Priority 3)
- Universal compatibility with all apps
- Requires accessibility permissions
- Can interact with any UI element

### 4. Native SDK (Priority 4)
- Direct API integration where available
- Most reliable but limited availability
- App-specific implementation required

### 5. GUI Automation (Priority 5)
- Last resort fallback method
- Simulates user interactions
- Least reliable but universally applicable

## Built-in Integrations

### Safari Integration
```swift
// Supported commands:
"open google.com in Safari"
"search for Swift programming in Safari"
"bookmark this page in Safari"
"open new tab in Safari"
"close current tab in Safari"
```

### Mail Integration
```swift
// Supported commands:
"send email to john@example.com about meeting"
"check new mail"
"search emails for project update"
"create mailbox called Archive"
```

### Calendar Integration
```swift
// Supported commands:
"create event Team Meeting at 2pm"
"show today's events"
"remind me to call John"
"schedule lunch tomorrow at noon"
```

### Finder Integration
```swift
// Supported commands:
"open Downloads folder"
"create folder called Projects"
"search for PDF files"
"reveal document.pdf in Finder"
"empty trash"
```

### Generic App Integration
```swift
// Supported commands for any app:
"launch TextEdit"
"quit Calculator"
"minimize Preview"
"open file.txt with TextEdit"
```

## Usage Examples

### Basic Usage

```swift
let appIntegrationManager = AppIntegrationManager()

// Wait for initialization
while !appIntegrationManager.isInitialized {
    try await Task.sleep(nanoseconds: 100_000_000)
}

// Execute a command
do {
    let result = try await appIntegrationManager.executeCommand("open google.com in Safari")
    print("Success: \(result.output)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Custom Integration

```swift
class MyAppIntegration: AppIntegration {
    let bundleIdentifier = "com.mycompany.myapp"
    let displayName = "My App"
    
    var supportedCommands: [CommandDefinition] {
        return [
            CommandDefinition(
                name: "custom_action",
                description: "Perform a custom action",
                parameters: [
                    CommandParameter(name: "param", type: .string, description: "Action parameter")
                ],
                examples: ["do something with My App"],
                integrationMethod: .appleScript
            )
        ]
    }
    
    let integrationMethods: [IntegrationMethod] = [.appleScript, .accessibility]
    var isInstalled: Bool { return true }
    
    func canHandle(_ command: ParsedCommand) -> Bool {
        return command.targetApplication == bundleIdentifier
    }
    
    func execute(_ command: ParsedCommand) async throws -> CommandResult {
        // Implementation here
        return CommandResult(
            success: true,
            output: "Custom action executed",
            integrationMethod: .appleScript
        )
    }
    
    func getCapabilities() -> AppCapabilities {
        return AppCapabilities(canLaunch: true, canQuit: true)
    }
}

// Register the integration
appIntegrationManager.registerIntegration(MyAppIntegration())
```

### Command Parsing

```swift
let parser = CommandParser()
let parsed = parser.parseCommand("send email to john@example.com about project update")

print("Intent: \(parsed.intent)")                    // .appControl
print("Target App: \(parsed.targetApplication)")     // "com.apple.mail"
print("Parameters: \(parsed.parameters)")            // ["email": "john@example.com", "subject": "project update"]
print("Confidence: \(parsed.confidence)")            // 0.85
```

### App Discovery

```swift
let appDiscovery = AppDiscoveryService()
await appDiscovery.discoverInstalledApps()

// Find specific app
if let safari = appDiscovery.findApp(bundleIdentifier: "com.apple.Safari") {
    print("Safari is installed at: \(safari.path)")
    print("Supported methods: \(safari.supportedIntegrationMethods)")
}

// Find apps by name
let textEditors = appDiscovery.findApps(byName: "text")
for app in textEditors {
    print("Found: \(app.displayName)")
}
```

## Error Handling

The system provides comprehensive error handling with specific error types:

```swift
enum AppIntegrationError: LocalizedError {
    case appNotInstalled(String)
    case appNotRunning(String)
    case commandNotSupported(String)
    case integrationMethodFailed(IntegrationMethod, String)
    case permissionDenied(String)
    case invalidParameters([String])
    case executionTimeout
    case unknownError(String)
}
```

Each error includes:
- Localized description
- Recovery suggestions
- Context-specific guidance

## Testing

### Unit Tests
```bash
# Run all app integration tests
xcodebuild test -scheme Sam -destination 'platform=macOS' -only-testing:SamTests/AppIntegrationManagerTests

# Run specific test class
xcodebuild test -scheme Sam -destination 'platform=macOS' -only-testing:SamTests/CommandParserTests
```

### Demo Application
```swift
// Run the interactive demo
let demo = AppIntegrationDemo()
await demo.runFullDemo()

// Or run specific integration demos
await demo.demonstrateSafariIntegration()
await demo.demonstrateMailIntegration()
```

## Configuration

### Permissions Required

1. **Accessibility Access**: Required for Accessibility API integration
   - System Preferences → Security & Privacy → Privacy → Accessibility
   - Add Sam to the list of allowed applications

2. **Automation Access**: Required for AppleScript integration
   - System Preferences → Security & Privacy → Privacy → Automation
   - Allow Sam to control other applications

3. **Full Disk Access**: Optional, for enhanced file operations
   - System Preferences → Security & Privacy → Privacy → Full Disk Access

### Integration Method Priority

You can customize the priority order of integration methods:

```swift
extension IntegrationMethod {
    var priority: Int {
        switch self {
        case .nativeSDK: return 1      // Highest priority
        case .urlScheme: return 2
        case .appleScript: return 3
        case .accessibility: return 4
        case .guiAutomation: return 5  // Lowest priority
        }
    }
}
```

## Performance Considerations

- **Command Parsing**: ~1-5ms for simple commands
- **App Discovery**: ~100-500ms for full system scan
- **URL Scheme Integration**: ~10-50ms execution time
- **AppleScript Integration**: ~50-200ms execution time
- **Accessibility Integration**: ~100-500ms execution time

## Security

- All AppleScript commands are validated before execution
- File paths are sanitized and validated
- User confirmation required for destructive operations
- Sensitive parameters are not logged
- Integration methods fail gracefully with appropriate error messages

## Extending the System

### Adding New App Integrations

1. Create a class implementing `AppIntegration` protocol
2. Define supported commands and parameters
3. Implement command execution logic
4. Register the integration with `AppIntegrationManager`

### Adding New Integration Methods

1. Add new case to `IntegrationMethod` enum
2. Implement handler class (e.g., `MyIntegrationEngine`)
3. Update integration priority and capabilities
4. Add support in specific app integrations

### Adding New Command Types

1. Extend `TaskType` enum with new command type
2. Update `CommandParser` to recognize new patterns
3. Add handling logic in relevant integrations
4. Update command definitions and examples

## Troubleshooting

### Common Issues

1. **"App not installed" error**: Verify app is in standard locations
2. **"Permission denied" error**: Check system privacy settings
3. **"Integration method failed" error**: Try alternative integration method
4. **"Command not supported" error**: Check command syntax and app capabilities

### Debug Mode

Enable debug logging for detailed execution information:

```swift
// Enable debug logging
AppIntegrationManager.debugMode = true

// This will log:
// - Command parsing details
// - Integration method selection
// - Execution timing
// - Error details
```

## Future Enhancements

- **Machine Learning**: Improve command parsing accuracy
- **Voice Integration**: Support for voice commands
- **Workflow Automation**: Multi-step command sequences
- **Third-party SDKs**: Direct integration with popular apps
- **Cloud Sync**: Sync custom integrations across devices
- **Plugin System**: Downloadable integration plugins