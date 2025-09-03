# Sam - macOS AI Assistant

<div align="center">
  <img src="assets/sam-logo.png" alt="Sam AI Assistant" width="128" height="128">
  
  **Your intelligent macOS assistant that performs actual tasks**
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
  [![Version](https://img.shields.io/badge/Version-0.1.0-green.svg)](CHANGELOG.md)
</div>

## Overview

Sam is a native macOS AI assistant that represents a new paradigm of human-computer interaction. Unlike traditional AI assistants that only provide instructions, Sam actually performs tasks through deep system integration and natural language commands.

### Key Features

- **🎯 Task Execution**: Actually performs tasks vs. instruction-giving
- **🔒 Privacy-First**: Local processing with minimal cloud dependencies  
- **🍎 Native Integration**: Deep macOS system and app integration
- **🧠 Contextual Intelligence**: Learns and adapts to user workflows
- **💬 Real-time Streaming**: Character-by-character response streaming
- **✏️ Message Management**: Edit and delete messages with full history
- **🎨 Modern UI**: Native SwiftUI interface with accessibility support

## Quick Start

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Apple Silicon or Intel Mac

### Installation

1. Clone the repository:
```bash
git clone https://github.com/sayemrihan/sam-macos-ai-assistant.git
cd sam-macos-ai-assistant
```

2. Open the project in Xcode:
```bash
open Sam/Sam.xcodeproj
```

3. Build and run the project (⌘R)

### First Launch

1. Grant necessary permissions when prompted
2. Configure your AI preferences in Settings
3. Start chatting with Sam!

## Usage Examples

### File Operations
```
"Copy file.pdf to Desktop"
"Organize my Downloads folder"
"Find all .txt files in Documents"
```

### System Queries
```
"What's my battery level?"
"Show me storage usage"
"List running applications"
```

### App Control
```
"Open Safari and go to apple.com"
"Close all Chrome windows"
"Switch to Finder"
```

### Automation
```
"Create a workflow to backup my photos"
"Set up a daily reminder at 9 AM"
"Automate my morning routine"
```

## Architecture

Sam is built with a modern, privacy-first architecture:

- **Frontend**: Native SwiftUI with MVVM pattern
- **AI Processing**: Hybrid local/cloud processing
- **Data Storage**: Core Data with encryption
- **System Integration**: Native macOS APIs and AppleScript
- **Performance**: <200MB memory baseline, <2s response time

## Development

### Project Structure

```
Sam/
├── Models/           # Data models and Core Data
├── Views/            # SwiftUI views and UI components
├── Managers/         # Business logic and state management
├── Services/         # External integrations and system APIs
├── Utils/            # Helper functions and extensions
└── Resources/        # Assets and configurations
```

### Building from Source

1. Install dependencies:
```bash
# Install SwiftLint for code quality
brew install swiftlint

# Install SwiftFormat for consistent formatting
brew install swiftformat
```

2. Run code quality checks:
```bash
swiftlint lint --config .swiftlint.yml
swiftformat Sources/ --config .swiftformat
```

3. Build and test:
```bash
xcodebuild -project Sam.xcodeproj -scheme Sam -configuration Debug build
xcodebuild test -project Sam.xcodeproj -scheme Sam -destination 'platform=macOS'
```

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and code quality checks
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Privacy & Security

Sam is designed with privacy as a core principle:

- **Local Processing**: 80%+ of tasks processed locally
- **Minimal Cloud Data**: Only complex queries sent to external services
- **No Training Data**: Your data is never used for AI model training
- **Encryption**: Local data encrypted at rest
- **Transparency**: Full control over data sharing preferences

## Roadmap

See our [Project Roadmap](ROADMAP.md) for upcoming features and improvements.

## Support

- **Documentation**: [Wiki](https://github.com/sayemrihan/sam-macos-ai-assistant/wiki)
- **Issues**: [GitHub Issues](https://github.com/sayemrihan/sam-macos-ai-assistant/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sayemrihan/sam-macos-ai-assistant/discussions)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Sayem Abdullah Rihan**
- GitHub: [@sayemrihan](https://github.com/sayemrihan)
- Email: sayem.rihan@example.com

## Acknowledgments

- Apple for the excellent macOS development frameworks
- The Swift community for amazing tools and libraries
- Beta testers and early adopters for valuable feedback

---

<div align="center">
  Made with ❤️ by Sayem Abdullah Rihan
</div>