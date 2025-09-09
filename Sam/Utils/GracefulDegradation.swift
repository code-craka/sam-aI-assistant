import Foundation

// MARK: - Feature Availability
enum FeatureAvailability {
    case available
    case degraded(reason: String)
    case unavailable(reason: String)
}

// MARK: - Degradation Strategy
enum DegradationStrategy {
    case fallbackToLocal
    case fallbackToSimple
    case fallbackToManual
    case disableFeature
    case showError
}

// MARK: - Feature Status
struct FeatureStatus {
    let feature: String
    let availability: FeatureAvailability
    let strategy: DegradationStrategy
    let lastChecked: Date
    let errorCount: Int
    let recoveryTime: Date?
}

// MARK: - Graceful Degradation Manager
@MainActor
class GracefulDegradationManager: ObservableObject {
    static let shared = GracefulDegradationManager()
    
    @Published var featureStatuses: [String: FeatureStatus] = [:]
    @Published var systemHealth: SystemHealth = .healthy
    
    private let errorLogger = ErrorLogger.shared
    private let healthCheckInterval: TimeInterval = 30.0
    private var healthCheckTimer: Timer?
    
    enum SystemHealth {
        case healthy
        case degraded
        case critical
    }
    
    private init() {
        initializeFeatures()
        startHealthMonitoring()
    }
    
    // MARK: - Public Methods
    
    func checkFeatureAvailability(_ feature: String) -> FeatureAvailability {
        return featureStatuses[feature]?.availability ?? .unavailable(reason: "Feature not registered")
    }
    
    func executeWithDegradation<T>(
        feature: String,
        primaryOperation: @escaping () async throws -> T,
        fallbackOperation: @escaping () async throws -> T
    ) async -> Result<T, SamError> {
        let status = featureStatuses[feature]
        
        switch status?.availability {
        case .available:
            do {
                let result = try await primaryOperation()
                recordSuccess(for: feature)
                return .success(result)
            } catch let error as SamError {
                recordFailure(for: feature, error: error)
                return await executeFallback(
                    feature: feature,
                    fallbackOperation: fallbackOperation,
                    originalError: error
                )
            } catch {
                let samError = SamError.unknown(error.localizedDescription)
                recordFailure(for: feature, error: samError)
                return await executeFallback(
                    feature: feature,
                    fallbackOperation: fallbackOperation,
                    originalError: samError
                )
            }
            
        case .degraded:
            errorLogger.warning("Feature '\(feature)' is degraded, using fallback", category: "Degradation")
            return await executeFallback(
                feature: feature,
                fallbackOperation: fallbackOperation,
                originalError: SamError.unknown("Feature degraded")
            )
            
        case .unavailable(let reason):
            errorLogger.error("Feature '\(feature)' is unavailable: \(reason)", category: "Degradation")
            return .failure(SamError.unknown("Feature '\(feature)' is unavailable: \(reason)"))
            
        case .none:
            return .failure(SamError.unknown("Feature '\(feature)' is not registered"))
        }
    }
    
    func registerFeature(_ feature: String, strategy: DegradationStrategy = .fallbackToLocal) {
        featureStatuses[feature] = FeatureStatus(
            feature: feature,
            availability: .available,
            strategy: strategy,
            lastChecked: Date(),
            errorCount: 0,
            recoveryTime: nil
        )
    }
    
    func markFeatureUnavailable(_ feature: String, reason: String) {
        guard var status = featureStatuses[feature] else { return }
        
        status = FeatureStatus(
            feature: status.feature,
            availability: .unavailable(reason: reason),
            strategy: status.strategy,
            lastChecked: Date(),
            errorCount: status.errorCount + 1,
            recoveryTime: Date().addingTimeInterval(300) // 5 minutes
        )
        
        featureStatuses[feature] = status
        updateSystemHealth()
        
        errorLogger.warning("Feature '\(feature)' marked unavailable: \(reason)", category: "Degradation")
    }
    
    func markFeatureDegraded(_ feature: String, reason: String) {
        guard var status = featureStatuses[feature] else { return }
        
        status = FeatureStatus(
            feature: status.feature,
            availability: .degraded(reason: reason),
            strategy: status.strategy,
            lastChecked: Date(),
            errorCount: status.errorCount + 1,
            recoveryTime: Date().addingTimeInterval(60) // 1 minute
        )
        
        featureStatuses[feature] = status
        updateSystemHealth()
        
        errorLogger.info("Feature '\(feature)' marked degraded: \(reason)", category: "Degradation")
    }
    
    func attemptFeatureRecovery(_ feature: String) async {
        guard let status = featureStatuses[feature] else { return }
        
        switch status.availability {
        case .available:
            return // Already available
            
        case .degraded, .unavailable:
            // Attempt to recover the feature
            let recovered = await performFeatureHealthCheck(feature)
            
            if recovered {
                featureStatuses[feature] = FeatureStatus(
                    feature: status.feature,
                    availability: .available,
                    strategy: status.strategy,
                    lastChecked: Date(),
                    errorCount: 0,
                    recoveryTime: nil
                )
                
                updateSystemHealth()
                errorLogger.info("Feature '\(feature)' recovered successfully", category: "Degradation")
            }
        }
    }
    
    func getSystemHealthReport() -> SystemHealthReport {
        let availableFeatures = featureStatuses.values.filter {
            if case .available = $0.availability { return true }
            return false
        }.count
        
        let degradedFeatures = featureStatuses.values.filter {
            if case .degraded = $0.availability { return true }
            return false
        }.count
        
        let unavailableFeatures = featureStatuses.values.filter {
            if case .unavailable = $0.availability { return true }
            return false
        }.count
        
        return SystemHealthReport(
            overallHealth: systemHealth,
            totalFeatures: featureStatuses.count,
            availableFeatures: availableFeatures,
            degradedFeatures: degradedFeatures,
            unavailableFeatures: unavailableFeatures,
            criticalErrors: getCriticalErrorCount(),
            lastHealthCheck: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func initializeFeatures() {
        // Register core features
        registerFeature("ai_service", strategy: .fallbackToLocal)
        registerFeature("file_operations", strategy: .fallbackToSimple)
        registerFeature("app_integration", strategy: .fallbackToManual)
        registerFeature("system_info", strategy: .fallbackToSimple)
        registerFeature("workflow_execution", strategy: .disableFeature)
        registerFeature("task_classification", strategy: .fallbackToLocal)
        registerFeature("network_operations", strategy: .showError)
    }
    
    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.performSystemHealthCheck()
            }
        }
    }
    
    private func performSystemHealthCheck() async {
        for feature in featureStatuses.keys {
            // Check if feature should attempt recovery
            if let status = featureStatuses[feature],
               let recoveryTime = status.recoveryTime,
               Date() >= recoveryTime {
                await attemptFeatureRecovery(feature)
            }
        }
        
        updateSystemHealth()
    }
    
    private func performFeatureHealthCheck(_ feature: String) async -> Bool {
        switch feature {
        case "ai_service":
            return await checkAIServiceHealth()
        case "file_operations":
            return checkFileOperationsHealth()
        case "app_integration":
            return checkAppIntegrationHealth()
        case "system_info":
            return checkSystemInfoHealth()
        case "workflow_execution":
            return checkWorkflowExecutionHealth()
        case "task_classification":
            return checkTaskClassificationHealth()
        case "network_operations":
            return await checkNetworkHealth()
        default:
            return false
        }
    }
    
    private func executeFallback<T>(
        feature: String,
        fallbackOperation: @escaping () async throws -> T,
        originalError: SamError
    ) async -> Result<T, SamError> {
        guard let status = featureStatuses[feature] else {
            return .failure(originalError)
        }
        
        switch status.strategy {
        case .fallbackToLocal, .fallbackToSimple, .fallbackToManual:
            do {
                let result = try await fallbackOperation()
                errorLogger.info("Fallback operation succeeded for '\(feature)'", category: "Degradation")
                return .success(result)
            } catch let error as SamError {
                errorLogger.error("Fallback operation failed for '\(feature)': \(error.localizedDescription)", category: "Degradation")
                return .failure(error)
            } catch {
                let samError = SamError.unknown(error.localizedDescription)
                errorLogger.error("Fallback operation failed for '\(feature)': \(samError.localizedDescription)", category: "Degradation")
                return .failure(samError)
            }
            
        case .disableFeature:
            errorLogger.warning("Feature '\(feature)' is disabled due to errors", category: "Degradation")
            return .failure(SamError.unknown("Feature '\(feature)' is temporarily disabled"))
            
        case .showError:
            return .failure(originalError)
        }
    }
    
    private func recordSuccess(for feature: String) {
        guard let status = featureStatuses[feature] else { return }
        
        // Reset error count on success
        featureStatuses[feature] = FeatureStatus(
            feature: status.feature,
            availability: .available,
            strategy: status.strategy,
            lastChecked: Date(),
            errorCount: 0,
            recoveryTime: nil
        )
    }
    
    private func recordFailure(for feature: String, error: SamError) {
        guard let status = featureStatuses[feature] else { return }
        
        let newErrorCount = status.errorCount + 1
        let newAvailability: FeatureAvailability
        
        // Determine degradation level based on error count and severity
        if newErrorCount >= 5 || error.severity == .critical {
            newAvailability = .unavailable(reason: error.localizedDescription)
        } else if newErrorCount >= 3 || error.severity == .high {
            newAvailability = .degraded(reason: error.localizedDescription)
        } else {
            newAvailability = status.availability
        }
        
        featureStatuses[feature] = FeatureStatus(
            feature: status.feature,
            availability: newAvailability,
            strategy: status.strategy,
            lastChecked: Date(),
            errorCount: newErrorCount,
            recoveryTime: calculateRecoveryTime(errorCount: newErrorCount)
        )
        
        errorLogger.log(error, category: "Degradation", additionalInfo: [
            "feature": feature,
            "errorCount": newErrorCount
        ])
    }
    
    private func calculateRecoveryTime(errorCount: Int) -> Date? {
        let baseDelay: TimeInterval = 60 // 1 minute
        let maxDelay: TimeInterval = 1800 // 30 minutes
        
        let delay = min(baseDelay * pow(2.0, Double(errorCount - 1)), maxDelay)
        return Date().addingTimeInterval(delay)
    }
    
    private func updateSystemHealth() {
        let unavailableCount = featureStatuses.values.filter {
            if case .unavailable = $0.availability { return true }
            return false
        }.count
        
        let degradedCount = featureStatuses.values.filter {
            if case .degraded = $0.availability { return true }
            return false
        }.count
        
        let totalFeatures = featureStatuses.count
        
        if unavailableCount > totalFeatures / 2 {
            systemHealth = .critical
        } else if unavailableCount > 0 || degradedCount > totalFeatures / 3 {
            systemHealth = .degraded
        } else {
            systemHealth = .healthy
        }
    }
    
    private func getCriticalErrorCount() -> Int {
        return ErrorLogger.shared.recentErrors.filter { $0.level == .critical }.count
    }
    
    // MARK: - Health Check Methods
    
    private func checkAIServiceHealth() async -> Bool {
        // Simple health check - try to make a minimal API call
        do {
            // This would be implemented based on your AI service
            return true
        } catch {
            return false
        }
    }
    
    private func checkFileOperationsHealth() -> Bool {
        // Check if we can perform basic file operations
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("health_check.txt")
        
        do {
            try "health check".write(to: tempURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: tempURL)
            return true
        } catch {
            return false
        }
    }
    
    private func checkAppIntegrationHealth() -> Bool {
        // Check if we can access basic app integration features
        return NSWorkspace.shared.runningApplications.count > 0
    }
    
    private func checkSystemInfoHealth() -> Bool {
        // Check if we can access basic system information
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion > 0
    }
    
    private func checkWorkflowExecutionHealth() -> Bool {
        // Check if workflow execution components are available
        return true // Placeholder
    }
    
    private func checkTaskClassificationHealth() -> Bool {
        // Check if task classification is working
        return true // Placeholder
    }
    
    private func checkNetworkHealth() async -> Bool {
        // Simple network connectivity check
        guard let url = URL(string: "https://www.apple.com") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Types

struct SystemHealthReport {
    let overallHealth: GracefulDegradationManager.SystemHealth
    let totalFeatures: Int
    let availableFeatures: Int
    let degradedFeatures: Int
    let unavailableFeatures: Int
    let criticalErrors: Int
    let lastHealthCheck: Date
    
    var healthPercentage: Double {
        guard totalFeatures > 0 else { return 0 }
        return Double(availableFeatures) / Double(totalFeatures) * 100
    }
}