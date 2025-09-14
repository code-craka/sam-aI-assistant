# Sam macOS AI Assistant - Build and Run Guide

## Prerequisites

### System Requirements
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Architecture**: Apple Silicon (M1/M2/M3) or Intel

### Development Tools
- Xcode Command Line Tools
- Git (for version control)

## Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/code-craka/sam-aI-assistant.git
cd sam-mac-ai-assistant
```

### 2. Project Structure
```
Sam/
├── SamApp.swift              # Main app entry point
├── Package.swift             # Swift Package Manager configuration
├── Managers/                 # Business logic managers
├── Models/                   # Data models and Core Data
├── Services/                 # Core services (AI, File System, etc.)
├── Utils/                    # Utility classes and helpers
├── Views/                    # SwiftUI user interface
├── Tests/                    # Unit and integration tests
└── Documentation/            # Project documentation
```

## Build Methods

### Method 1: Using Xcode (Recommended for Development)

1. **Open in Xcode**:
   ```bash
   open Sam/Package.swift
   ```
   Or drag the `Sam` folder into Xcode.

2. **Configure Signing**:
   - Select the Sam target
   - Go to "Signing & Capabilities"
   - Select your development team
   - Ensure "Automatically manage signing" is checked

3. **Build and Run**:
   - Press `Cmd+R` to build and run
   - Or use Product → Run from the menu
   
   **Expected Result**: ❌ Currently has compilation errors that need fixing

### Method 2: Using Swift Package Manager (Command Line)

1. **Navigate to Sam directory**:
   ```bash
   cd Sam
   ```

2. **Build the project**:
   ```bash
   swift build
   ```
   **Expected Result**: ❌ Currently fails with compilation errors

3. **Run the executable**:
   ```bash
   swift run Sam
   ```
   **Expected Result**: ❌ Cannot run until compilation errors are fixed

### Method 3: Build Release Version

1. **Build optimized release**:
   ```bash
   cd Sam
   swift build -c release
   ```

2. **Run release build**:
   ```bash
   .build/release/Sam
   ```

## Running Tests

### Run All Tests
```bash
cd Sam
swift test
```

### Run Specific Test Suite
```bash
# Run unit tests only
swift test --filter SamTests

# Run specific test class
swift test --filter AIServiceTests
```

### Run Tests in Xcode
1. Open project in Xcode
2. Press `Cmd+U` to run all tests
3. Or use Product → Test from the menu

## Configuration

### 1. API Keys Setup
The app requires OpenAI API key for AI functionality:

1. **Get OpenAI API Key**:
   - Visit https://platform.openai.com/api-keys
   - Create a new API key

2. **Configure in App**:
   - Launch the app
   - Go to Settings
   - Enter your OpenAI API key
   - Keys are securely stored in macOS Keychain

### 2. Permissions Setup
Sam requires several macOS permissions:

- **File System Access**: For file operations
- **Accessibility**: For app automation
- **Automation**: For AppleScript execution
- **Contacts/Calendar**: For productivity features (optional)

The app will prompt for these permissions on first use.

## Troubleshooting

### Build Status
⚠️ **Significant Progress Made - Still Some Issues Remaining**

**✅ FIXED:**
- SmartSuggestions.swift: Fixed array conversion issues
- ConversationTopic enum: Added String raw values  
- Actor isolation: Fixed with proper Task wrapping
- Test files: Moved to correct Tests/ directory structure
- Some SwiftUI macOS compatibility issues
- WorkflowDefinition: Added Hashable conformance

**❌ REMAINING ISSUES:**
- Complex SwiftUI binding expressions in settings views
- Duplicate view definitions (PrivacySettingsView, FeatureRow, etc.)
- MemoryPressure type ambiguity between TaskModels and MemoryManager
- UserPreferences type resolution issues
- navigationBarTitleDisplayMode still present in some files
- WorkflowTemplate needs Hashable conformance
- Core Data preview configuration issues

**Current Status**: The project has ~50+ compilation errors remaining, primarily in UI views.

### Common Build Issues

#### 1. "No such module 'XCTest'" Error
**Solution**: ✅ **FIXED** - Test files moved to `Tests/` directory

#### 2. Actor Isolation Warnings
**Solution**: ✅ **FIXED** - Timer callbacks now properly wrapped
```bash
# If you still see warnings, build with Swift 5 compatibility
swift build -Xswiftc -swift-version -Xswiftc 5
```

#### 3. Core Data Model Issues
**Solution**: Ensure Core Data model is properly configured
- Check `SamDataModel.xcdatamodeld` exists
- Verify entity relationships are correct

#### 4. Signing Issues (Xcode)
**Solution**: 
- Select your development team in project settings
- Enable "Automatically manage signing"
- Or create manual provisioning profile

#### 5. SwiftUI macOS Compatibility
**Solution**: ✅ **FIXED** - Removed iOS-only modifiers like PageTabViewStyle

### Performance Issues

#### 1. Slow Build Times
```bash
# Clean build folder
swift package clean

# Or in Xcode: Product → Clean Build Folder
```

#### 2. High Memory Usage
- The app includes memory optimization utilities
- Check `Sam/Utils/MemoryOptimizer.swift` for configuration

## Development Workflow

### 1. Making Changes
```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes
# ...

# Test changes
swift test

# Build to verify
swift build
```

### 2. Code Quality
```bash
# Run SwiftLint (if installed)
swiftlint lint

# Format code (if SwiftFormat installed)
swiftformat .
```

### 3. Debugging
- Use Xcode debugger for interactive debugging
- Check console logs for runtime issues
- Enable verbose logging in Settings

## Deployment

### 1. Create Release Build
```bash
cd Sam
swift build -c release --arch arm64 --arch x86_64
```

### 2. App Store Preparation
See `Sam/Documentation/AppStore_Preparation.md` for detailed App Store submission guidelines.

### 3. Distribution
- **Development**: Use Xcode for local testing
- **Beta**: Use TestFlight for beta distribution
- **Release**: Submit to Mac App Store

## Features Overview

### Core Capabilities
- **AI-Powered Chat**: Natural language interaction
- **File Management**: Advanced file operations and organization
- **System Control**: macOS system information and control
- **App Integration**: Control Safari, Mail, Calendar, and more
- **Workflow Automation**: Create and execute custom workflows
- **Privacy-First**: Local processing with optional cloud features

### Key Services
- `AIService`: OpenAI integration and local AI processing
- `FileSystemService`: File operations and metadata extraction
- `SystemService`: System information and control
- `AppIntegrationManager`: Third-party app automation
- `WorkflowExecutor`: Custom workflow execution

## Support

### Getting Help
1. Check this documentation
2. Review implementation summaries in `TASK_*_IMPLEMENTATION_SUMMARY.md`
3. Check the Issues section on GitHub
4. Review code comments and README files in service directories

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License
See `LICENSE` file for license information.

---

**Note**: This is a comprehensive macOS AI assistant with advanced features. Ensure you have the necessary permissions and API keys configured before running.