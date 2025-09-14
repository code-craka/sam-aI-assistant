import Foundation

struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
    
    init(name: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.parameters = parameters
        self.timestamp = Date()
    }
}

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var isEnabled = true
    
    private let userDefaults = UserDefaults.standard
    private let analyticsEnabledKey = "AnalyticsEnabled"
    private let eventLogKey = "AnalyticsEventLog"
    
    private init() {
        isEnabled = userDefaults.bool(forKey: analyticsEnabledKey)
    }
    
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        // Log event locally for debugging and improvement
        logEvent(event)
        
        // In a production app, you might send to analytics service
        // sendToAnalyticsService(event)
    }
    
    func setAnalyticsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: analyticsEnabledKey)
    }
    
    private func logEvent(_ event: AnalyticsEvent) {
        var eventLog = getEventLog()
        
        let eventData: [String: Any] = [
            "name": event.name,
            "parameters": event.parameters,
            "timestamp": event.timestamp.timeIntervalSince1970
        ]
        
        eventLog.append(eventData)
        
        // Keep only last 100 events to prevent storage bloat
        if eventLog.count > 100 {
            eventLog = Array(eventLog.suffix(100))
        }
        
        userDefaults.set(eventLog, forKey: eventLogKey)
    }
    
    private func getEventLog() -> [[String: Any]] {
        return userDefaults.array(forKey: eventLogKey) as? [[String: Any]] ?? []
    }
    
    func getRecentEvents(limit: Int = 50) -> [AnalyticsEvent] {
        let eventLog = getEventLog()
        
        return eventLog.suffix(limit).compactMap { eventData in
            guard let name = eventData["name"] as? String,
                  let parameters = eventData["parameters"] as? [String: Any],
                  let timestamp = eventData["timestamp"] as? TimeInterval else {
                return nil
            }
            
            var event = AnalyticsEvent(name: name, parameters: parameters)
            // Note: We can't modify the timestamp after init, so this is a limitation
            return event
        }
    }
    
    func clearEventLog() {
        userDefaults.removeObject(forKey: eventLogKey)
    }
}

// MARK: - Predefined Events

extension AnalyticsEvent {
    // Onboarding events
    static let onboardingStarted = AnalyticsEvent(name: "onboarding_started")
    static let onboardingCompleted = AnalyticsEvent(name: "onboarding_completed")
    static let onboardingStepCompleted = AnalyticsEvent(name: "onboarding_step_completed")
    static let onboardingSkipped = AnalyticsEvent(name: "onboarding_skipped")
    
    // Permission events
    static let permissionRequested = AnalyticsEvent(name: "permission_requested")
    static let permissionGranted = AnalyticsEvent(name: "permission_granted")
    static let permissionDenied = AnalyticsEvent(name: "permission_denied")
    
    // Feature usage events
    static let commandExecuted = AnalyticsEvent(name: "command_executed")
    static let helpViewed = AnalyticsEvent(name: "help_viewed")
    static let suggestionUsed = AnalyticsEvent(name: "suggestion_used")
    static let workflowCreated = AnalyticsEvent(name: "workflow_created")
    static let workflowExecuted = AnalyticsEvent(name: "workflow_executed")
    
    // Error events
    static let errorOccurred = AnalyticsEvent(name: "error_occurred")
    static let errorRecovered = AnalyticsEvent(name: "error_recovered")
    
    // App lifecycle events
    static let appLaunched = AnalyticsEvent(name: "app_launched")
    static let appBackgrounded = AnalyticsEvent(name: "app_backgrounded")
    static let appForegrounded = AnalyticsEvent(name: "app_foregrounded")
    
    // Helper methods for events with parameters
    static func commandExecuted(command: String, taskType: String, success: Bool) -> AnalyticsEvent {
        return AnalyticsEvent(name: "command_executed", parameters: [
            "command": command,
            "task_type": taskType,
            "success": success
        ])
    }
    
    static func onboardingStepCompleted(step: String, timeSpent: TimeInterval) -> AnalyticsEvent {
        return AnalyticsEvent(name: "onboarding_step_completed", parameters: [
            "step": step,
            "time_spent": timeSpent
        ])
    }
    
    static func permissionRequested(permission: String, granted: Bool) -> AnalyticsEvent {
        return AnalyticsEvent(name: "permission_requested", parameters: [
            "permission": permission,
            "granted": granted
        ])
    }
    
    static func helpViewed(category: String, searchQuery: String? = nil) -> AnalyticsEvent {
        var parameters: [String: Any] = ["category": category]
        if let query = searchQuery {
            parameters["search_query"] = query
        }
        return AnalyticsEvent(name: "help_viewed", parameters: parameters)
    }
    
    static func suggestionUsed(suggestionId: String, category: String) -> AnalyticsEvent {
        return AnalyticsEvent(name: "suggestion_used", parameters: [
            "suggestion_id": suggestionId,
            "category": category
        ])
    }
    
    static func errorOccurred(error: String, context: String) -> AnalyticsEvent {
        return AnalyticsEvent(name: "error_occurred", parameters: [
            "error": error,
            "context": context
        ])
    }
}