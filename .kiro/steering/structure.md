# Project Structure - Sam macOS AI Assistant

## Repository Organization

### Root Level Files
- **PRD Documents**: Product requirements and research analysis
- **Development Plans**: AI-assisted development strategy and assessments
- **Specs**: Detailed implementation tasks and milestones

### Core Project Structure
```
Sam/                                 # Main Xcode project
├── Sam.xcodeproj                   # Xcode project file
├── Sources/
│   ├── Models/                     # Data models and Core Data
│   │   ├── CoreData/              # .xcdatamodeld and NSManagedObject subclasses
│   │   ├── ChatModels.swift       # Chat message and conversation models
│   │   ├── TaskModels.swift       # Task classification and execution models
│   │   └── UserModels.swift       # User preferences and settings
│   ├── Views/                      # SwiftUI views and UI components
│   │   ├── Chat/                  # Chat interface components
│   │   ├── Settings/              # Settings and configuration views
│   │   ├── Onboarding/           # Welcome and setup flows
│   │   └── Shared/               # Reusable UI components
│   ├── Managers/                   # Business logic and state management
│   │   ├── ChatManager.swift     # Chat conversation management
│   │   ├── TaskManager.swift     # Task execution coordination
│   │   ├── ContextManager.swift  # System context and file awareness
│   │   └── WorkflowManager.swift # Multi-step task automation
│   ├── Services/                   # External integrations and system APIs
│   │   ├── AI/                   # AI model integration
│   │   ├── FileSystem/           # File operations and management
│   │   ├── System/               # macOS system integration
│   │   └── Apps/                 # Third-party app integrations
│   ├── Utils/                      # Helper functions and extensions
│   │   ├── Extensions/           # Swift and Foundation extensions
│   │   ├── Constants.swift       # App-wide constants and configuration
│   │   └── Helpers.swift         # Utility functions
│   └── Resources/                  # Assets, localizations, configurations
│       ├── Assets.xcassets       # App icons, images, colors
│       ├── Localizable.strings   # Localization files
│       └── Configurations/       # Build configurations and plists
├── Tests/                          # Test suites
│   ├── UnitTests/                # Unit tests for business logic
│   ├── IntegrationTests/         # Integration tests for system APIs
│   └── UITests/                  # UI automation tests
└── Documentation/                  # Technical documentation
    ├── API.md                    # API documentation
    ├── Architecture.md           # System architecture overview
    └── Deployment.md             # Build and deployment guide
```

## Development Workflow

### Feature Development Pattern
1. **Models First**: Define data structures and Core Data models
2. **Services Layer**: Implement business logic and external integrations
3. **Managers**: Create state management and coordination logic
4. **Views**: Build SwiftUI interface components
5. **Testing**: Add comprehensive test coverage

### Code Organization Principles

#### Separation of Concerns
- **Models**: Pure data structures, no business logic
- **Services**: External API calls and system integration
- **Managers**: Business logic and state coordination
- **Views**: UI presentation only, minimal logic

#### Dependency Flow
```
Views → Managers → Services → Models
```

#### Naming Conventions
- **Files**: PascalCase with descriptive names (e.g., `ChatManager.swift`)
- **Classes**: PascalCase (e.g., `TaskClassificationService`)
- **Properties/Methods**: camelCase (e.g., `processUserInput`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_RETRY_ATTEMPTS`)

## Key Architectural Components

### Core Managers
- **ChatManager**: Handles conversation flow and message persistence
- **TaskManager**: Coordinates task classification and execution
- **ContextManager**: Maintains system and file context awareness
- **SettingsManager**: Manages user preferences and configuration

### Service Layer
- **AIService**: Local and cloud AI model integration
- **FileSystemService**: File operations and metadata extraction
- **SystemService**: macOS system information and control
- **AppIntegrationService**: Third-party application automation

### Data Flow Architecture
```
User Input → ChatManager → TaskManager → Services → System APIs
                ↓              ↓           ↓
            Core Data ← ContextManager ← Results
```

## Configuration Management

### Environment-Specific Settings
- **Development**: Local testing with mock services
- **Beta**: Limited cloud processing with telemetry
- **Production**: Full feature set with privacy controls

### Feature Flags
- Cloud processing toggle
- Advanced automation features
- Beta feature access
- Debug logging levels

## Documentation Standards

### Code Documentation
- Swift DocC comments for public APIs
- Inline comments for complex business logic
- README files for each major component
- Architecture decision records (ADRs) for significant choices

### User Documentation
- In-app help system with contextual guidance
- Command reference with examples
- Privacy policy and data handling transparency
- Troubleshooting guides for common issues