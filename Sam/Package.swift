// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sam",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Sam", targets: ["Sam"])
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "Sam",
            dependencies: [],
            path: ".",
            exclude: [
                "Tests",
                "Documentation",
                "Scripts",
                "Resources",
                "Preview Content",
                "Info.plist",
                "Sam.entitlements",
                "SamDataModel.xcdatamodeld",
                ".build",
                ".swiftpm",
                "TASK_12_IMPLEMENTATION_SUMMARY.md",
                "TASK_14_IMPLEMENTATION_SUMMARY.md",
                "TASK_15_IMPLEMENTATION_SUMMARY.md",
                "TASK_16_IMPLEMENTATION_SUMMARY.md",
                "TASK_17_IMPLEMENTATION_SUMMARY.md",
                "TASK_18_IMPLEMENTATION_SUMMARY.md",
                "TASK_19_IMPLEMENTATION_SUMMARY.md",
                "TASK_20_IMPLEMENTATION_SUMMARY.md",
                "TASK_21_IMPLEMENTATION_SUMMARY.md",
                "TASK_22_IMPLEMENTATION_SUMMARY.md",
                "TASK_23_IMPLEMENTATION_SUMMARY.md",
                "TASK_24_IMPLEMENTATION_SUMMARY.md",
                "TASK_25_IMPLEMENTATION_SUMMARY.md",
                "TASK_27_IMPLEMENTATION_SUMMARY.md",
                "TASK_28_IMPLEMENTATION_SUMMARY.md",
                "TASK_29_IMPLEMENTATION_SUMMARY.md",
                "TASK_30_IMPLEMENTATION_SUMMARY.md",
                "TASK_31_IMPLEMENTATION_SUMMARY.md",
                "TASK_32_IMPLEMENTATION_SUMMARY.md",
                "COMPILATION_FIXES_SUMMARY.md",
                "Models/CoreDataImplementationSummary.md",
                "Models/CoreDataTest.swift",
                "Services/AIService_README.md",
                "Services/AppIntegration_README.md",
                "Services/AppleScriptEngine_README.md",
                "Services/FileSystemService_README.md",
                "Services/SystemService_README.md",
                "Services/TaskRouter_README.md",
                "Services/ConsentDemo.swift",
                "Services/FileMetadataDemo.swift",
                "Services/PerformanceDemo.swift",
                "Services/WorkflowDemo.swift",
                "Services/AppIntegrationDemo.swift",
                "Services/AppleScriptEngineDemo.swift",
                "Services/FileSystemServiceDemo.swift",
                "Services/MailCalendarIntegrationDemo.swift",
                "Services/SafariIntegrationDemo.swift",
                "Services/SystemControlDemo.swift",
                "Services/SystemServiceDemo.swift",
                "Services/TaskRouterDemo.swift",
                "demo_current_state.swift",
                "final_status_demo.swift",
                "onboarding_demo.swift",
                "safety_demo.swift",
                "security_privacy_demo.swift",
                "workflow_demo.swift",
                "test_consent_compilation.swift",
                "test_file_safety.swift",
                "test_performance_monitoring.swift",
                "test_settings_compilation.swift",
                "test_workflow_builder.swift",
                "test_workflow_compilation.swift"
            ],
            sources: [
                "SamApp.swift",
                "TestRunner.swift",
                "Managers",
                "Models", 
                "Services",
                "Utils",
                "Views"
            ]
        ),
        .testTarget(
            name: "SamTests",
            dependencies: ["Sam"],
            path: "Tests"
        )
    ]
)