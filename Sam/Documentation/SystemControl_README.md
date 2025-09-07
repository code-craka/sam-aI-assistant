# System Control Service

The System Control Service extends Sam's capabilities to include direct control over macOS system settings and maintenance operations. This service provides a comprehensive interface for managing volume, brightness, network settings, and system maintenance tasks.

## Features

### 🔊 Audio Control
- **Volume Management**: Set, increase, decrease, and mute system volume
- **Audio Device Information**: Get details about input/output devices
- **Real-time Feedback**: Track volume changes with before/after values

### 💡 Display Control
- **Brightness Management**: Adjust display brightness with precise control
- **Display Information**: Get details about connected displays
- **Sleep Control**: Put displays to sleep on command

### 🌐 Network Management
- **Wi-Fi Control**: Toggle Wi-Fi on/off
- **Bluetooth Control**: Toggle Bluetooth connectivity
- **Network Configuration**: Get detailed network status and settings
- **VPN Management**: Monitor VPN connections (read-only)

### 🧹 System Maintenance
- **Cache Management**: Clear system and user caches
- **Trash Management**: Empty trash with size reporting
- **Disk Cleanup**: Comprehensive cleanup operations
- **Maintenance Analysis**: Identify cleanup opportunities

### ⚡ System Power
- **Sleep Control**: Put system or display to sleep
- **Restart/Shutdown**: System power operations with confirmation
- **Power State Management**: Control system power states

### 🎛️ System Preferences
- **Do Not Disturb**: Toggle focus modes
- **Night Shift**: Control blue light filtering
- **System Settings**: Access common preference controls

## Usage

### Basic Volume Control

```swift
let systemService = SystemService()

// Set volume to 50%
let result = try await systemService.setVolume(0.5)
print(result.message) // "Volume set to 50%"

// Increase volume by 10%
let upResult = try await systemService.volumeUp()

// Toggle mute
let muteResult = try await systemService.toggleMute()
```

### Brightness Control

```swift
// Set brightness to 70%
let result = try await systemService.setBrightness(0.7)

// Increase brightness
let upResult = try await systemService.brightnessUp()

// Decrease brightness
let downResult = try await systemService.brightnessDown()
```

### Network Management

```swift
// Get network configuration
let config = try await systemService.getNetworkConfiguration()
print("Wi-Fi enabled: \(config.wifiEnabled)")

// Toggle Wi-Fi (requires user confirmation)
let wifiResult = try await systemService.toggleWiFi()

// Toggle Bluetooth
let bluetoothResult = try await systemService.toggleBluetooth()
```

### System Maintenance

```swift
// Get maintenance information
let maintenanceInfo = try await systemService.getMaintenanceInfo()
print("Total cleanable space: \(maintenanceInfo.totalCleanableSizeGB) GB")

// Clear system cache
let cacheResult = try await systemService.clearSystemCache()

// Empty trash
let trashResult = try await systemService.emptyTrash()

// Perform comprehensive cleanup
let cleanupResult = try await systemService.performDiskCleanup()
```

### System Control Operations

```swift
// Execute operations through unified interface
let result = try await systemService.executeSystemControl(.volumeUp)

// Operations with parameters
let setResult = try await systemService.executeSystemControl(.volumeSet, value: 0.6)

// Check if operation requires confirmation
if operation.requiresConfirmation {
    // Show confirmation dialog
    let confirmed = await showConfirmationDialog(for: operation)
    if confirmed {
        let result = try await systemService.executeSystemControl(operation)
    }
}
```

## Data Models

### SystemControlOperation

Enumeration of all available system control operations:

```swift
enum SystemControlOperation: String, CaseIterable {
    case volumeUp, volumeDown, volumeMute, volumeSet
    case brightnessUp, brightnessDown, brightnessSet
    case displaySleep, systemSleep
    case wifiToggle, bluetoothToggle
    case doNotDisturbToggle, nightShiftToggle
    case cacheClear, diskCleanup, emptyTrash
    case restartSystem, shutdownSystem
    
    var requiresConfirmation: Bool { /* ... */ }
    var displayName: String { /* ... */ }
}
```

### SystemControlResult

Result structure for system control operations:

```swift
struct SystemControlResult {
    let operation: SystemControlOperation
    let success: Bool
    let message: String
    let previousValue: Double?  // For value-changing operations
    let newValue: Double?       // For value-changing operations
    let timestamp: Date
}
```

### MaintenanceInfo

System maintenance analysis results:

```swift
struct MaintenanceInfo {
    let cacheSize: Int64
    let trashSize: Int64
    let logSize: Int64
    let tempFilesSize: Int64
    let downloadsSize: Int64
    let lastCleanupDate: Date?
    let recommendedActions: [MaintenanceAction]
    
    var totalCleanableSize: Int64 { /* ... */ }
    var totalCleanableSizeGB: Double { /* ... */ }
}
```

## Security & Permissions

### Required Permissions

The system control functionality requires various macOS permissions:

- **Accessibility**: For system control operations
- **Automation**: For AppleScript execution
- **Full Disk Access**: For comprehensive maintenance operations
- **System Events**: For system preference modifications

### Safety Features

- **Confirmation Required**: Destructive operations require user confirmation
- **Value Clamping**: Volume and brightness values are automatically clamped to valid ranges
- **Error Recovery**: Graceful error handling with user-friendly messages
- **Operation Logging**: All operations are logged with timestamps

### AppleScript Integration

Many operations use AppleScript for system integration:

```applescript
-- Volume control
set volume output volume 50

-- Brightness control
tell application "System Events"
    tell appearance preferences
        set brightness to 0.7
    end tell
end tell

-- Network control
tell application "System Events"
    tell network preferences
        set wifi to not (wifi enabled)
    end tell
end tell
```

## Error Handling

### Error Types

```swift
enum SystemServiceError: LocalizedError {
    case operationFailed(String)
    case unsupportedOperation(String)
    case invalidParameter(String)
    case permissionDenied(String)
    case systemCallFailed(String)
}
```

### Error Recovery

- **Graceful Degradation**: Operations fail safely without system damage
- **User Guidance**: Clear error messages with recovery suggestions
- **Permission Prompts**: Automatic guidance for permission requirements
- **Retry Logic**: Built-in retry for transient failures

## Performance Considerations

### Optimization Features

- **Async Operations**: All operations are asynchronous and non-blocking
- **Caching**: System information is cached to reduce overhead
- **Batch Operations**: Multiple operations can be batched for efficiency
- **Resource Management**: Automatic cleanup of system resources

### Performance Metrics

- **Response Time**: <1s for most operations
- **Memory Usage**: Minimal memory footprint
- **CPU Impact**: Low CPU usage during operations
- **Battery Impact**: Negligible battery drain

## Testing

### Test Coverage

The system control functionality includes comprehensive tests:

- **Unit Tests**: Individual operation testing
- **Integration Tests**: System-level operation testing
- **Performance Tests**: Response time and resource usage
- **Error Handling Tests**: Exception and error condition testing

### Running Tests

```swift
// Run comprehensive tests
let tests = SystemControlTests()
await tests.runAllTests()

// Run simple validation tests
await runSystemControlSimpleTests()

// Run interactive demo
await runInteractiveSystemControlDemo()
```

## Demo and Examples

### Demo Scripts

- **SystemControlDemo.swift**: Comprehensive demonstration of all features
- **SystemControlSimpleTest.swift**: Basic validation and testing
- **Interactive Demo**: Command-line interface for testing operations

### Example Commands

```bash
# Run demo
swift run Sam --demo system-control

# Run tests
swift test --filter SystemControlTests

# Interactive testing
swift run Sam --interactive system-control
```

## Integration with Sam

### Task Classification

System control operations are automatically classified by the task classifier:

```swift
// Natural language input: "turn up the volume"
// Classified as: SystemControlOperation.volumeUp

// Natural language input: "set brightness to 80%"
// Classified as: SystemControlOperation.brightnessSet with value 0.8
```

### Chat Integration

System control operations integrate seamlessly with Sam's chat interface:

```
User: "Can you turn down the volume?"
Sam: "I'll decrease the volume for you."
     [Executes volumeDown operation]
     "Volume decreased from 70% to 60%"

User: "Clear my system cache"
Sam: "This will clear your system cache. Continue? (y/n)"
     [Waits for confirmation]
     "System cache cleared successfully. Freed 150 MB of space."
```

## Future Enhancements

### Planned Features

- **Advanced Display Management**: Multi-monitor configuration
- **Audio Device Switching**: Automatic device selection
- **Network Profile Management**: Wi-Fi profile switching
- **Scheduled Maintenance**: Automatic cleanup scheduling
- **System Monitoring**: Real-time system health monitoring

### Extensibility

The system control service is designed for easy extension:

- **Plugin Architecture**: Support for custom control operations
- **Script Integration**: Custom AppleScript and shell script execution
- **Third-party Integration**: Support for external system tools
- **Configuration Profiles**: User-defined operation sets

## Troubleshooting

### Common Issues

1. **Permission Denied**: Grant required permissions in System Preferences
2. **Operation Failed**: Check system compatibility and try again
3. **AppleScript Errors**: Verify AppleScript support is enabled
4. **Network Operations**: Ensure network interfaces are available

### Debug Mode

Enable debug logging for detailed operation information:

```swift
systemService.enableDebugLogging = true
let result = try await systemService.executeSystemControl(.volumeUp)
// Detailed logs will be printed to console
```

## Compatibility

### System Requirements

- **macOS**: 13.0+ (Ventura and later)
- **Architecture**: Universal (Intel and Apple Silicon)
- **Permissions**: Accessibility, Automation, Full Disk Access
- **Dependencies**: Core Audio, System Configuration, Core WLAN

### Tested Configurations

- ✅ MacBook Pro (M1/M2/M3)
- ✅ MacBook Air (M1/M2)
- ✅ iMac (Intel/M1)
- ✅ Mac Studio (M1/M2)
- ✅ Mac Pro (Intel/M2)

The System Control Service provides a comprehensive and safe interface for managing macOS system settings, enabling Sam to perform real system control operations while maintaining security and user control.