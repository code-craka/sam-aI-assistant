# AppleScript Engine

The AppleScript Engine provides advanced app automation capabilities for Sam, enabling dynamic script generation, compilation, caching, and execution with comprehensive error handling and permission management.

## Overview

The AppleScript Engine consists of several key components:

- **AppleScriptEngine**: Main engine for script execution and management
- **ScriptTemplateManager**: Template system for common automation tasks
- **AutomationPermissionManager**: Permission handling and security management

## Features

### 🚀 Core Capabilities

- **Dynamic Script Generation**: Generate AppleScript from natural language descriptions
- **Template System**: Pre-built templates for common automation tasks
- **Script Compilation & Caching**: Compile once, execute multiple times for performance
- **Error Handling**: Comprehensive error detection and user-friendly messages
- **Permission Management**: Automatic permission requests and guidance
- **Safety Validation**: Script safety checks before execution

### 📋 Built-in Templates

#### Finder Operations
- `create_folder`: Create new folders
- `delete_file`: Delete files and folders
- `move_file`: Move files between locations
- `get_file_info`: Get file metadata

#### Mail Automation
- `send_email`: Send emails with subject and content
- `read_emails`: Read recent emails from inbox

#### Calendar Integration
- `create_event`: Create calendar events
- `get_events`: Retrieve upcoming events

#### Safari Control
- `open_url`: Open URLs in Safari
- `new_tab`: Create new tabs
- `get_current_url`: Get current tab URL

#### System Control
- `system_info`: Get system information
- `set_volume`: Control system volume
- `display_notification`: Show system notifications

#### Generic Operations
- `launch_app`: Launch applications
- `quit_app`: Quit applications
- `generic_app_control`: Control any application

## Usage

### Basic Script Execution

```swift
let engine = AppleScriptEngine()

// Execute a simple script
let result = try await engine.executeScript("""
    tell application "Finder"
        return name of desktop
    end tell
""")

if result.success {
    print("Result: \(result.output ?? "")")
}
```

### Using Templates

```swift
// Execute a template with parameters
let result = try await engine.executeTemplate(
    "create_folder",
    parameters: ["folderName": "MyNewFolder"]
)
```

### Natural Language Generation

```swift
// Generate script from description
let script = try await engine.generateScript(for: "create a new folder")
let result = try await engine.executeScript(script)
```

### Template Management

```swift
// Get available templates
let templates = engine.getAvailableTemplates()

// Get templates by category
let finderTemplates = templates.filter { $0.category == .finder }

// Get templates for specific app
let mailTemplates = templates.filter { $0.targetApps.contains("Mail") }
```

## Error Handling

The engine provides comprehensive error handling:

```swift
do {
    let result = try await engine.executeScript(script)
} catch AppleScriptEngine.ScriptError.compilationFailed(let message) {
    print("Compilation error: \(message)")
} catch AppleScriptEngine.ScriptError.permissionDenied {
    print("Permission denied - check System Preferences")
} catch AppleScriptEngine.ScriptError.scriptNotFound(let name) {
    print("Template not found: \(name)")
} catch AppleScriptEngine.ScriptError.invalidTemplate(let message) {
    print("Invalid template: \(message)")
}
```

## Permission Management

The engine automatically handles automation permissions:

1. **Automatic Detection**: Checks if automation permissions are granted
2. **User Guidance**: Provides clear instructions for enabling permissions
3. **System Integration**: Opens System Preferences when needed
4. **App-Specific Permissions**: Manages permissions for individual apps

### Enabling Permissions

Users need to enable automation permissions in:
**System Preferences > Security & Privacy > Privacy > Automation**

The engine will guide users through this process automatically.

## Safety Features

### Script Validation

The engine validates scripts before execution:

```swift
let (safe, issues) = permissionManager.validateScriptSafety(script)
if !safe {
    print("Safety issues found: \(issues)")
}
```

### Dangerous Operations Detection

The engine detects potentially dangerous operations:
- System file modifications
- Disk operations
- Network requests
- Administrative commands

## Performance

### Caching System

- **Compilation Caching**: Compiled scripts are cached for reuse
- **Parameter-Aware**: Cache keys include parameters for accuracy
- **Memory Management**: Automatic cache size limits and cleanup
- **Performance Gains**: Significant speed improvements for repeated scripts

### Execution Metrics

```swift
let result = try await engine.executeScript(script)
print("Execution time: \(result.executionTime)s")
```

## Template System

### Template Structure

```swift
ScriptTemplate(
    name: "template_name",
    description: "What this template does",
    source: "AppleScript source with {{parameters}}",
    parameters: ["param1", "param2"],
    category: .finder,
    targetApps: ["Finder"],
    examples: ["Example usage"]
)
```

### Parameter Replacement

Templates use `{{parameterName}}` syntax for dynamic values:

```applescript
tell application "{{appName}}"
    make new folder with properties {name:"{{folderName}}"}
end tell
```

## Integration

### With Task Router

The AppleScript Engine integrates with Sam's task routing system:

```swift
// In TaskRouter
if taskType == .automation {
    let result = try await appleScriptEngine.executeScript(script)
    return result
}
```

### With App Integration Manager

Works alongside other app integration services:

```swift
// Fallback to AppleScript for unsupported operations
if !nativeIntegration.supports(operation) {
    return try await appleScriptEngine.executeTemplate(operation)
}
```

## Testing

### Unit Tests

Run comprehensive tests:

```bash
swift test --filter AppleScriptEngineTests
```

### Demo Mode

Run the demo to see all features:

```swift
await runAppleScriptEngineDemo()
```

### Simple Tests

Quick functionality verification:

```swift
await runAppleScriptEngineSimpleTest()
```

## Configuration

### Cache Settings

```swift
// Configure cache limits
scriptCache.countLimit = 50
scriptCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
```

### Template Loading

```swift
// Load custom templates
templateManager.loadCustomTemplates(from: url)
```

## Best Practices

### 1. Use Templates When Possible
Templates are optimized, tested, and safe. Use them instead of raw scripts.

### 2. Handle Permissions Gracefully
Always handle permission errors and guide users appropriately.

### 3. Validate User Input
Sanitize parameters before script execution.

### 4. Cache Appropriately
Use caching for repeated operations, disable for one-time scripts.

### 5. Monitor Performance
Track execution times and optimize slow operations.

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Solution: Enable automation in System Preferences
   - Check: Specific app permissions

2. **Compilation Errors**
   - Solution: Validate AppleScript syntax
   - Check: Parameter replacement

3. **Template Not Found**
   - Solution: Verify template name
   - Check: Template loading

4. **Execution Timeout**
   - Solution: Optimize script complexity
   - Check: System resources

### Debug Mode

Enable detailed logging:

```swift
engine.debugMode = true
```

## Security Considerations

1. **Script Validation**: All scripts are validated before execution
2. **Permission Checks**: Automation permissions are verified
3. **Safe Templates**: Built-in templates are security-reviewed
4. **User Consent**: Users must explicitly enable automation
5. **Sandboxing**: Scripts run within macOS security boundaries

## Future Enhancements

- [ ] JavaScript for Automation (JXA) support
- [ ] Custom template creation UI
- [ ] Script recording and playback
- [ ] Advanced debugging tools
- [ ] Performance profiling
- [ ] Cloud template sharing

## Requirements

- macOS 13.0+ (Ventura)
- Automation permissions enabled
- Target applications installed
- Swift 5.7+

## Related Components

- `AppIntegrationManager`: Native app integrations
- `TaskRouter`: Task classification and routing
- `SystemService`: System-level operations
- `PermissionManager`: App permission handling