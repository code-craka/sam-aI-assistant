import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    @Published var isSettingsOpen = false
    @Published var currentView: AppView = .chat
    @Published var sidebarVisibility: NavigationSplitViewVisibility = .automatic
    
    // Accessibility settings
    @Published var reduceMotion = false
    @Published var increaseContrast = false
    @Published var largerText = false
    
    // Window management
    @Published var windowTitle = "Sam AI Assistant"
    
    private var cancellables = Set<AnyCancellable>()
    
    enum AppView {
        case chat
        case settings
        case help
    }
    
    enum ThemeMode: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    @Published var themeMode: ThemeMode = .system {
        didSet {
            colorScheme = themeMode.colorScheme
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }
    
    var nsAppearance: NSAppearance? {
        switch themeMode {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
    
    init() {
        loadSettings()
        setupAccessibilityObservers()
    }
    
    private func loadSettings() {
        // Load theme preference
        if let savedTheme = UserDefaults.standard.string(forKey: "themeMode"),
           let theme = ThemeMode(rawValue: savedTheme) {
            themeMode = theme
        }
        
        // Load sidebar visibility
        if let savedVisibility = UserDefaults.standard.string(forKey: "sidebarVisibility") {
            switch savedVisibility {
            case "automatic":
                sidebarVisibility = .automatic
            case "doubleColumn":
                sidebarVisibility = .doubleColumn
            case "detailOnly":
                sidebarVisibility = .detailOnly
            default:
                sidebarVisibility = .automatic
            }
        }
    }
    
    private func setupAccessibilityObservers() {
        // Observe accessibility settings changes
        NotificationCenter.default.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
        
        updateAccessibilitySettings()
    }
    
    private func updateAccessibilitySettings() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        
        // Check for larger text preference
        if let fontSize = UserDefaults.standard.object(forKey: "NSFontSize") as? CGFloat {
            largerText = fontSize > 13
        }
    }
    
    func toggleSidebar() {
        switch sidebarVisibility {
        case .automatic, .doubleColumn:
            sidebarVisibility = .detailOnly
        case .detailOnly:
            sidebarVisibility = .doubleColumn
        @unknown default:
            sidebarVisibility = .automatic
        }
        
        UserDefaults.standard.set(sidebarVisibility.description, forKey: "sidebarVisibility")
    }
    
    func openSettings() {
        isSettingsOpen = true
        currentView = .settings
    }
    
    func closeSettings() {
        isSettingsOpen = false
        currentView = .chat
    }
    
    func updateWindowTitle(_ title: String) {
        windowTitle = title
    }
}

// MARK: - NavigationSplitViewVisibility Extension

extension NavigationSplitViewVisibility: CustomStringConvertible {
    public var description: String {
        switch self {
        case .automatic:
            return "automatic"
        case .doubleColumn:
            return "doubleColumn"
        case .detailOnly:
            return "detailOnly"
        @unknown default:
            return "automatic"
        }
    }
}