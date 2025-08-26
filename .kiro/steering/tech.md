# Technical Stack - Sam macOS AI Assistant

## Core Technology Stack

### Frontend (macOS App)
- **Language**: Swift + SwiftUI
- **Architecture**: MVVM with Combine
- **UI Framework**: Native macOS design system
- **Target**: macOS 13.0+ (Ventura and later)
- **Performance**: 60fps UI, <200MB memory baseline

### AI/ML Framework
- **Local Models**: CoreML optimized for Apple Silicon
- **Base Model**: Fine-tuned Llama 3.2 3B or similar lightweight models
- **NLP Framework**: Apple's NaturalLanguage framework for classification
- **Inference**: On-device processing prioritized for privacy
- **Cloud Fallback**: OpenAI GPT-4/Claude for complex reasoning

### Data & Storage
- **Local Storage**: Core Data for chat history and user preferences
- **Security**: Keychain Services for API keys and sensitive data
- **File System**: Native macOS APIs for file operations
- **Context Management**: Local indexing system for file/app awareness

### System Integration
- **Automation**: AppleScript/AppleEvents for app control
- **Accessibility**: macOS Accessibility APIs for universal app interaction
- **System APIs**: NSWorkspace, FileManager, SystemConfiguration
- **Permissions**: Proper sandboxing with required entitlements

## Build System & Commands

### Development Setup
```bash
# Open project in Xcode
open Sam.xcodeproj

# Build for development
xcodebuild -project Sam.xcodeproj -scheme Sam -configuration Debug

# Run tests
xcodebuild test -project Sam.xcodeproj -scheme Sam -destination 'platform=macOS'
```

### Code Quality
```bash
# SwiftLint for code style
swiftlint lint --config .swiftlint.yml

# SwiftFormat for consistent formatting  
swiftformat Sources/ --config .swiftformat
```

### Performance Testing
```bash
# Memory and performance profiling
instruments -t "Time Profiler" -D trace_output.trace Sam.app

# Core Data performance analysis
instruments -t "Core Data" -D coredata_trace.trace Sam.app
```

## Architecture Patterns

### Hybrid Processing Model
```swift
// Task classification determines local vs cloud processing
enum ProcessingRoute {
    case local      // File ops, simple queries, system info
    case cloud      // Complex reasoning, multi-step tasks
    case hybrid     // Local classification + cloud execution
}
```

### Privacy-First Design
- Local processing for 80%+ of tasks
- Minimal data sent to cloud services
- User control over cloud processing preferences
- No user data used for model training

### Performance Requirements
- **Response Time**: <2s local tasks, <5s cloud tasks
- **Memory Usage**: <200MB baseline, <500MB peak
- **CPU Usage**: <10% idle, <50% during processing
- **Battery Impact**: <5% additional drain per hour

## Code Style Guidelines

### Swift Conventions
- Use SwiftUI for all UI components
- Async/await for asynchronous operations
- Combine for reactive programming patterns
- Protocol-oriented design for extensibility

### File Organization
```
Sources/
├── Models/          # Core Data models and data structures
├── Views/           # SwiftUI views and UI components  
├── Managers/        # Business logic and state management
├── Services/        # External integrations and system APIs
├── Utils/           # Helper functions and extensions
└── Resources/       # Assets, localizations, configurations
```

### Testing Strategy
- Unit tests for all business logic
- Integration tests for system APIs
- UI tests for critical user workflows
- Performance tests for AI inference and file operations