import SwiftUI
import Combine

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case features = 1
    case permissions = 2
    case apiSetup = 3
    case examples = 4
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .features: return "Features"
        case .permissions: return "Permissions"
        case .apiSetup: return "AI Setup"
        case .examples: return "Examples"
        }
    }
}

@MainActor
class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isCompleted: Bool = false
    @Published var showingOnboarding: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let onboardingCompletedKey = "OnboardingCompleted"
    
    init() {
        isCompleted = userDefaults.bool(forKey: onboardingCompletedKey)
    }
    
    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(OnboardingStep.allCases.count)
    }
    
    var canGoBack: Bool {
        currentStep.rawValue > 0
    }
    
    var isLastStep: Bool {
        currentStep == OnboardingStep.allCases.last
    }
    
    func goNext() {
        guard !isLastStep else { return }
        
        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? currentStep
        }
    }
    
    func goBack() {
        guard canGoBack else { return }
        
        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? currentStep
        }
    }
    
    func goToStep(_ step: OnboardingStep) {
        withAnimation {
            currentStep = step
        }
    }
    
    func completeOnboarding() {
        isCompleted = true
        userDefaults.set(true, forKey: onboardingCompletedKey)
        
        // Track onboarding completion
        AnalyticsManager.shared.track(.onboardingCompleted)
    }
    
    func resetOnboarding() {
        isCompleted = false
        currentStep = .welcome
        userDefaults.set(false, forKey: onboardingCompletedKey)
    }
    
    var shouldShowOnboarding: Bool {
        !isCompleted
    }
}

// MARK: - Analytics Events

extension AnalyticsEvent {
    static let onboardingCompleted = AnalyticsEvent(name: "onboarding_completed")
    static let onboardingStepViewed = AnalyticsEvent(name: "onboarding_step_viewed")
    static let permissionRequested = AnalyticsEvent(name: "permission_requested")
}