import Foundation

// MARK: - Task Router Demonstration
/// This file demonstrates the task routing system functionality
/// Run this to see how different types of requests are routed and processed

class TaskRouterDemo {

    private let taskRouter = TaskRouter()

    func runDemo() async {
        print("🚀 Sam AI Assistant - Task Routing System Demo")
        print("=" * 50)

        await demonstrateLocalProcessing()
        await demonstrateCloudProcessing()
        await demonstrateHybridProcessing()
        await demonstrateCaching()
        await demonstrateFallbackMechanisms()
        await demonstrateSystemHealth()
        await showRoutingStatistics()

        print("\n✅ Demo completed successfully!")
    }

    // MARK: - Local Processing Demo

    private func demonstrateLocalProcessing() async {
        print("\n📱 Local Processing Examples")
        print("-" * 30)

        let localQueries = [
            "what's my battery level",
            "show storage info",
            "open Safari",
            "help",
        ]

        for query in localQueries {
            do {
                let result = try await taskRouter.processInput(query)
                printResult(query: query, result: result)
            } catch {
                print("❌ Error processing '\(query)': \(error)")
            }
        }
    }

    // MARK: - Cloud Processing Demo

    private func demonstrateCloudProcessing() async {
        print("\n☁️ Cloud Processing Examples")
        print("-" * 30)

        let cloudQueries = [
            "analyze this complex document and provide insights",
            "create a comprehensive workflow for data processing",
            "summarize the latest AI research trends",
            "translate this text to multiple languages",
        ]

        for query in cloudQueries {
            do {
                let result = try await taskRouter.processInput(query)
                printResult(query: query, result: result)
            } catch {
                print("❌ Error processing '\(query)': \(error)")
            }
        }
    }

    // MARK: - Hybrid Processing Demo

    private func demonstrateHybridProcessing() async {
        print("\n🔄 Hybrid Processing Examples")
        print("-" * 30)

        let hybridQueries = [
            "organize my desktop files by type and create a summary",
            "find all PDFs in Downloads and analyze their content",
            "check system performance and suggest optimizations",
        ]

        for query in hybridQueries {
            do {
                let result = try await taskRouter.processInput(query)
                printResult(query: query, result: result)
            } catch {
                print("❌ Error processing '\(query)': \(error)")
            }
        }
    }

    // MARK: - Caching Demo

    private func demonstrateCaching() async {
        print("\n💾 Response Caching Demo")
        print("-" * 30)

        let query = "help"

        // First request - should not be cached
        print("First request (no cache):")
        do {
            let result1 = try await taskRouter.processInput(query)
            printResult(query: query, result: result1)
        } catch {
            print("❌ Error: \(error)")
        }

        // Second request - should be cached
        print("\nSecond request (should be cached):")
        do {
            let result2 = try await taskRouter.processInput(query)
            printResult(query: query, result: result2)
        } catch {
            print("❌ Error: \(error)")
        }

        // Show cache statistics
        let cacheStats = taskRouter.getCacheStatistics()
        print("\n📊 Cache Statistics:")
        print("   Total Entries: \(cacheStats.totalEntries)")
        print("   Cache Hits: \(cacheStats.totalHits)")
        print("   Hit Rate: \(String(format: "%.1f%%", cacheStats.hitRate * 100))")
    }

    // MARK: - Fallback Mechanisms Demo

    private func demonstrateFallbackMechanisms() async {
        print("\n🛡️ Fallback Mechanisms Demo")
        print("-" * 30)

        // Simulate various failure scenarios
        let failureQueries = [
            "process this extremely complex request that might fail",
            "perform an operation that requires unavailable services",
            "execute a task with invalid parameters",
        ]

        for query in failureQueries {
            do {
                let result = try await taskRouter.processInput(query)
                printResult(query: query, result: result)
            } catch {
                print("🔄 Fallback triggered for '\(query)': \(error)")
            }
        }
    }

    // MARK: - System Health Demo

    private func demonstrateSystemHealth() async {
        print("\n🏥 System Health Check")
        print("-" * 30)

        let healthStatus = await taskRouter.checkSystemHealth()

        print(
            "Local Processing: \(healthStatus.localProcessing.displayName) \(healthStatus.localProcessing.color)"
        )
        print(
            "Cloud Processing: \(healthStatus.cloudProcessing.displayName) \(healthStatus.cloudProcessing.color)"
        )
        print(
            "Response Cache: \(healthStatus.responseCache.displayName) \(healthStatus.responseCache.color)"
        )
        print(
            "Overall Status: \(healthStatus.overallStatus.displayName) \(healthStatus.overallStatus.color)"
        )
    }

    // MARK: - Statistics Demo

    private func showRoutingStatistics() async {
        print("\n📈 Routing Statistics")
        print("-" * 30)

        let stats = taskRouter.getRoutingStatistics()

        print("Total Requests: \(stats.totalRequests)")
        print("Success Rate: \(String(format: "%.1f%%", stats.successRate * 100))")
        print("Average Processing Time: \(String(format: "%.2f", stats.averageProcessingTime))s")
        print("")
        print("Route Distribution:")
        print(
            "  Local: \(stats.localRequests) (\(String(format: "%.1f%%", stats.localProcessingPercentage * 100)))"
        )
        print(
            "  Cloud: \(stats.cloudRequests) (\(String(format: "%.1f%%", stats.cloudProcessingPercentage * 100)))"
        )
        print("  Hybrid: \(stats.hybridRequests)")
        print(
            "  Cache Hits: \(stats.cacheHits) (\(String(format: "%.1f%%", stats.cacheHitRate * 100)))"
        )
        print("")
        print("Success Rates by Route:")
        print("  Local: \(String(format: "%.1f%%", stats.localSuccessRate * 100))")
        print("  Cloud: \(String(format: "%.1f%%", stats.cloudSuccessRate * 100))")
        print("  Hybrid: \(String(format: "%.1f%%", stats.hybridSuccessRate * 100))")
    }

    // MARK: - Helper Methods

    private func printResult(query: String, result: TaskProcessingResult) {
        let routeIcon = result.processingRoute.icon
        let cacheIndicator = result.cacheHit ? "💾" : ""
        let statusIcon = result.success ? "✅" : "❌"

        print("\(statusIcon) \(routeIcon) \(cacheIndicator) '\(query)'")
        print("   Route: \(result.processingRoute.displayName)")
        print("   Time: \(String(format: "%.2f", result.executionTime))s")
        print("   Tokens: \(result.tokensUsed)")
        print("   Cost: $\(String(format: "%.4f", result.cost))")
        print("   Output: \(result.output.prefix(100))\(result.output.count > 100 ? "..." : "")")

        if let error = result.error {
            print("   Error: \(error.localizedDescription)")
        }

        print("")
    }
}

// MARK: - String Extension for Repeat
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// MARK: - Demo Runner
/// Uncomment the following lines to run the demo
/*
Task {
    let demo = TaskRouterDemo()
    await demo.runDemo()
}
*/
