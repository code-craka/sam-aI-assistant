# Contributing to Sam macOS AI Assistant

Thank you for your interest in contributing to Sam! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Git
- Swift 5.9+

### Development Tools

Install the following tools for the best development experience:

```bash
# Code quality tools
brew install swiftlint swiftformat

# Documentation tools
brew install sourcedocs
```

## Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/sam-macos-ai-assistant.git
   cd sam-macos-ai-assistant
   ```

2. **Set up upstream remote**
   ```bash
   git remote add upstream https://github.com/sayemrihan/sam-macos-ai-assistant.git
   ```

3. **Open in Xcode**
   ```bash
   open Sam/Sam.xcodeproj
   ```

4. **Install pre-commit hooks** (optional but recommended)
   ```bash
   # Create pre-commit hook for code quality
   cp scripts/pre-commit .git/hooks/pre-commit
   chmod +x .git/hooks/pre-commit
   ```

## Contributing Guidelines

### Types of Contributions

We welcome several types of contributions:

- **🐛 Bug Reports**: Help us identify and fix issues
- **✨ Feature Requests**: Suggest new functionality
- **🔧 Code Contributions**: Implement features or fix bugs
- **📚 Documentation**: Improve or add documentation
- **🎨 UI/UX Improvements**: Enhance the user experience
- **🧪 Testing**: Add or improve test coverage

### Before You Start

1. **Check existing issues** to avoid duplicate work
2. **Create an issue** for significant changes to discuss the approach
3. **Follow the project roadmap** to align with project goals
4. **Consider the scope** - start small and build up

## Pull Request Process

### 1. Create a Feature Branch

```bash
# Update your main branch
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

- Follow the [coding standards](#coding-standards)
- Write tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 3. Commit Your Changes

Use conventional commit messages:

```bash
git commit -m "feat: add real-time message streaming"
git commit -m "fix: resolve memory leak in chat manager"
git commit -m "docs: update installation instructions"
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### 4. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub with:
- Clear title and description
- Reference to related issues
- Screenshots for UI changes
- Test results and performance impact

### 5. Code Review Process

- Maintainers will review your PR
- Address feedback promptly
- Keep the PR updated with main branch
- Be patient and respectful during review

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) with these additions:

#### Naming Conventions
```swift
// Classes: PascalCase
class ChatManager { }

// Properties/Methods: camelCase
var messageCount: Int
func sendMessage() { }

// Constants: UPPER_SNAKE_CASE
let MAX_RETRY_ATTEMPTS = 3

// Enums: PascalCase with lowercase cases
enum TaskType {
    case fileOperation
    case systemQuery
}
```

#### Code Organization
```swift
// MARK: - Public Methods
func publicMethod() { }

// MARK: - Private Methods  
private func privateMethod() { }

// MARK: - Extensions
extension ChatManager { }
```

#### SwiftUI Conventions
```swift
// View names: PascalCase + "View"
struct MessageBubbleView: View { }

// State properties: descriptive names
@State private var isEditing = false
@Published var streamingMessage: StreamingMessage?
```

### Code Quality Tools

Run these before committing:

```bash
# Lint code
swiftlint lint --config .swiftlint.yml

# Format code
swiftformat Sources/ --config .swiftformat

# Generate documentation
sourcedocs generate --spm-module Sam
```

## Testing

### Test Structure

```
Tests/
├── UnitTests/          # Unit tests for business logic
├── IntegrationTests/   # Integration tests for system APIs
└── UITests/           # UI automation tests
```

### Writing Tests

```swift
import XCTest
@testable import Sam

class ChatManagerTests: XCTestCase {
    var chatManager: ChatManager!
    
    override func setUp() {
        super.setUp()
        chatManager = ChatManager()
    }
    
    func testMessageSending() {
        // Test implementation
    }
}
```

### Running Tests

```bash
# Run all tests
xcodebuild test -project Sam.xcodeproj -scheme Sam -destination 'platform=macOS'

# Run specific test suite
xcodebuild test -project Sam.xcodeproj -scheme Sam -destination 'platform=macOS' -only-testing:SamTests.ChatManagerTests
```

## Documentation

### Code Documentation

Use Swift DocC comments for public APIs:

```swift
/// Sends a message to the AI assistant
/// - Parameter content: The message content to send
/// - Returns: The AI response
/// - Throws: `ChatError` if the message fails to send
func sendMessage(_ content: String) async throws -> String {
    // Implementation
}
```

### README Updates

Update relevant documentation when making changes:
- README.md for user-facing changes
- CHANGELOG.md for all changes
- API documentation for code changes

## Issue Templates

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior.

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Environment:**
- macOS version:
- Sam version:
- Hardware:
```

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Additional context**
Any other context about the feature request.
```

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- GitHub contributors page
- Special mentions for significant contributions

## Questions?

- **General Questions**: [GitHub Discussions](https://github.com/sayemrihan/sam-macos-ai-assistant/discussions)
- **Bug Reports**: [GitHub Issues](https://github.com/sayemrihan/sam-macos-ai-assistant/issues)
- **Direct Contact**: sayem.rihan@example.com

## License

By contributing to Sam, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to Sam!**

*This contributing guide is maintained by Sayem Abdullah Rihan and the Sam development team.*