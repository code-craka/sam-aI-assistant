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
        // Add any external dependencies here
    ],
    targets: [
        .executableTarget(
            name: "Sam",
            dependencies: [],
            path: ".",
            exclude: [
                "Resources",
                "Preview Content",
                "Info.plist",
                "Sam.entitlements",
                "SamDataModel.xcdatamodeld",
                "Tests",
                "Services/AIService_README.md",
                "Services/TaskRouter_README.md",
                "Services/FileSystemService_README.md",
                "Services/SystemService_README.md",
                "Services/AppIntegration_README.md",
                "Services/AIServiceTests.swift",
                "Services/TaskRouterTests.swift",
                "Services/TaskRouterDemo.swift",
                "Services/FileSystemServiceTests.swift",
                "Services/FileSystemServiceDemo.swift",
                "Services/FileSystemServiceSimpleTest.swift",
                "Services/SystemServiceTests.swift",
                "Services/SystemServiceDemo.swift",
                "Services/AppIntegrationManagerTests.swift",
                "Services/AppIntegrationDemo.swift",
                "Services/AppIntegrationSimpleTest.swift",
                "Models/CoreDataImplementationSummary.md",
                "Models/CoreDataTest.swift",
                "FileSystemModels.o",
                "FileSystemService.o",
                "test_runner",
                "TASK_12_IMPLEMENTATION_SUMMARY.md",
                "TASK_14_IMPLEMENTATION_SUMMARY.md",
                "TASK_15_IMPLEMENTATION_SUMMARY.md",
                "safety_demo.swift",
                "test_file_safety.swift",
                "SystemModels.o",
                "Documentation"
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