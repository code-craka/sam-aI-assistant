# SystemService - macOS System Information Gathering

## Overview

The `SystemService` is a comprehensive system information gathering service for Sam's macOS AI assistant. It provides real-time access to battery status, storage information, memory usage, network connectivity, CPU performance, and running applications through native macOS APIs.

## Features

### 🔋 Battery Information
- Battery level and charging status
- Power source detection (battery, AC power, UPS)
- Time remaining estimates
- Battery health and cycle count
- Support for devices without batteries

### 💾 Storage Information
- Total, used, and available disk space
- Multiple volume support
- File system information
- Usage percentage calculations
- Internal vs. removable drive detection

### 🧠 Memory Information
- Physical memory usage statistics
- Memory pressure monitoring
- App memory, wired memory, and compressed memory breakdown
- Swap usage tracking
- Real-time memory pressure alerts

### 🌐 Network Information
- Connection status detection
- Network interface enumeration
- WiFi signal strength and quality
- IP address and MAC address information
- Network security type detection

### ⚡ CPU Information
- Real-time CPU usage monitoring
- Per-core usage statistics
- CPU architecture and brand detection
- Core and thread count information
- Thermal state monitoring (when available)

### 📱 Running Applications
- Complete list of running applications
- Process ID and memory usage tracking
- Active vs. background application detection
- Application icon extraction
- Launch date tracking

## Usage

### Basic System Information

```swift
let systemService = SystemService()

// Get comprehensive system information
let systemInfo = try await systemService.getSystemInfo()
print("System: macOS \(systemInfo.systemVersion)")
print("Uptime: \(systemInfo.formattedUptime)")

// Get specific information
let battery = try await systemService.getBatteryInfo()
print("Battery: \(battery.levelPercentage)%")

let storage = try await systemService.getStorageInfo()
print("Storage: \(storage.usagePercentage)% used")
```

### Specific Queries

```swift
// Query specific system aspects
let batteryStatus = try await systemService.querySystem(.battery)
let storageInfo = try await systemService.querySystem(.storage)
let memoryInfo = try await systemService.querySystem(.memory)
let networkStatus = try await systemService.querySystem(.network)
let cpuInfo = try await systemService.querySystem(.cpu)
let runningApps = try await systemService.querySystem(.apps)
let overview = try await systemService.querySystem(.overview)
let performance = try await systemService.querySystem(.performance)
```

### Continuous Monitoring

```swift
// The service automatically updates every 5 seconds
systemService.$cachedSystemInfo
    .compactMap { $0 }
    .sink { systemInfo in
        print("CPU: \(systemInfo.cpu.usage)%")
        print("Memory: \(systemInfo.memory.usagePercentage)%")
    }
    .store(in: &cancellables)
```

## Architecture

### Core Components

1. **SystemService**: Main service class with async methods
2. **SystemModels**: Comprehensive data models for all system information
3. **Native API Integration**: Direct integration with macOS system APIs
4. **Error Handling**: Comprehensive error handling with recovery suggestions

### Data Models

#### SystemInfo
Comprehensive system information container including:
- Battery information (optional)
- Storage information
- Memory information
- Network information
- CPU information
- Running applications list
- System version and build
- Uptime information

#### BatteryInfo
```swift
struct BatteryInfo {
    let level: Double // 0.0 to 1.0
    let isCharging: Bool
    let timeRemaining: TimeInterval?
    let powerSource: PowerSource
    let cycleCount: Int?
    let health: BatteryHealth?
}
```

#### StorageInfo
```swift
struct StorageInfo {
    let totalSpace: Int64
    let availableSpace: Int64
    let usedSpace: Int64
    let volumes: [VolumeInfo]
}
```

#### MemoryInfo
```swift
struct MemoryInfo {
    let totalMemory: Int64
    let usedMemory: Int64
    let availableMemory: Int64
    let appMemory: Int64
    let wiredMemory: Int64
    let compressedMemory: Int64
    let swapUsed: Int64
    let memoryPressure: MemoryPressure
}
```

### System API Integration

The service integrates with multiple macOS system APIs:

- **IOKit**: Battery and power management information
- **SystemConfiguration**: Network configuration and status
- **CoreWLAN**: WiFi-specific information
- **NSWorkspace**: Running applications and system information
- **Mach**: Low-level system statistics (CPU, memory)
- **BSD syscalls**: System information and network interfaces

## Performance

### Optimization Features

- **Caching**: Automatic caching with 5-second refresh intervals
- **Async Operations**: All operations are fully asynchronous
- **Efficient APIs**: Uses the most efficient system APIs available
- **Memory Management**: Proper cleanup of system resources
- **Error Recovery**: Graceful handling of unavailable information

### Performance Characteristics

- **Response Time**: < 100ms for cached data, < 500ms for fresh data
- **Memory Usage**: < 5MB additional memory footprint
- **CPU Impact**: < 1% CPU usage during normal operation
- **Battery Impact**: Minimal battery drain from system queries

## Error Handling

### Error Types

```swift
enum SystemServiceError: LocalizedError {
    case permissionDenied(String)
    case serviceUnavailable(String)
    case dataCorrupted(String)
    case networkUnavailable
    case batteryNotFound
    case insufficientPrivileges
    case systemCallFailed(String)
}
```

### Recovery Strategies

- **Graceful Degradation**: Continue operation when some information is unavailable
- **Permission Guidance**: Clear instructions for resolving permission issues
- **Retry Logic**: Automatic retry for transient failures
- **Fallback Methods**: Alternative approaches when primary methods fail

## Privacy and Security

### Privacy Features

- **Local Processing**: All information gathering is performed locally
- **No Network Transmission**: System information never leaves the device
- **Minimal Permissions**: Requests only necessary system access
- **Secure Storage**: No persistent storage of sensitive system information

### Security Considerations

- **Sandboxing**: Respects macOS app sandboxing requirements
- **Permission Requests**: Proper handling of system permission requirements
- **Data Validation**: Validation of all system-provided data
- **Resource Limits**: Protection against resource exhaustion

## Testing

### Test Coverage

The service includes comprehensive tests covering:

- **Unit Tests**: All core functionality and calculations
- **Integration Tests**: Real system API interactions
- **Performance Tests**: Response time and resource usage
- **Error Handling Tests**: All error conditions and recovery
- **Model Tests**: Data model validation and calculations

### Running Tests

```bash
# Run all system service tests
xcodebuild test -project Sam.xcodeproj -scheme Sam -destination 'platform=macOS' -only-testing:SamTests/SystemServiceTests

# Run performance tests
xcodebuild test -project Sam.xcodeproj -scheme Sam -destination 'platform=macOS' -only-testing:SamTests/SystemServiceTests/testSystemInfoPerformance
```

## Demo and Examples

### Running the Demo

```swift
// Run comprehensive demo
await runSystemServiceDemo()

// Run continuous monitoring demo
await runSystemMonitoringDemo()
```

### Example Output

```
🖥️ System Overview
macOS 14.1.0 (Build 23B74)
Uptime: 2d 14h 32m

⚡ CPU: 15.2% usage
🧠 Memory: 68.4% used (normal)
💾 Storage: 45.7% used
🔋 Battery: 87% (Charging)
🌐 Network: Connected via Wi-Fi
📱 Running Apps: 23
```

## Integration with Sam

### Task Classification

The SystemService integrates with Sam's task classification system to handle queries like:

- "What's my battery percentage?"
- "How much storage do I have left?"
- "What's my memory usage?"
- "Show me running applications"
- "What's my CPU usage?"

### Natural Language Responses

The service provides formatted, human-readable responses suitable for natural language interaction:

```swift
// User: "What's my battery level?"
// Response: "🔋 Battery: 87% (Charging)\nPower Source: AC Power\nHealth: Good\nCycle Count: 245"
```

## Requirements Satisfied

This implementation satisfies the following requirements from the Sam specification:

- **4.1**: Battery percentage and charging status queries
- **4.2**: Storage information and usage breakdown  
- **4.3**: Memory usage statistics and pressure monitoring
- **4.4**: Network status detection and connection information
- **4.6**: System performance monitoring with CPU and memory usage

## Future Enhancements

### Planned Features

- **Temperature Monitoring**: CPU and system temperature tracking
- **Detailed Process Information**: Per-process CPU and memory usage
- **Network Speed Testing**: Bandwidth and latency measurements
- **System Health Scoring**: Comprehensive system health assessment
- **Historical Tracking**: System performance trends over time

### API Extensions

- **Streaming Updates**: Real-time system information streaming
- **Custom Alerts**: User-configurable system alerts
- **Export Functionality**: System information export capabilities
- **Remote Monitoring**: Optional remote system monitoring support