import CoreData
import Foundation

// MARK: - TaskShortcut Extensions
extension TaskShortcut {
    
    /// Computed property for category enum
    var taskCategory: TaskType {
        get {
            return TaskType(rawValue: category) ?? .unknown
        }
        set {
            category = newValue.rawValue
        }
    }
    
    /// Formatted creation date
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Usage frequency description
    var usageFrequency: String {
        switch usageCount {
        case 0:
            return "Never used"
        case 1:
            return "Used once"
        case 2...10:
            return "Used \(usageCount) times"
        case 11...50:
            return "Used frequently (\(usageCount) times)"
        default:
            return "Used very frequently (\(usageCount) times)"
        }
    }
    
    /// Check if shortcut has keyboard shortcut
    var hasKeyboardShortcut: Bool {
        return keyboardShortcut != nil && !keyboardShortcut!.isEmpty
    }
    
    /// Formatted keyboard shortcut for display
    var formattedKeyboardShortcut: String? {
        guard let shortcut = keyboardShortcut, !shortcut.isEmpty else { return nil }
        return shortcut
    }
    
    /// Command preview (first 50 characters)
    var commandPreview: String {
        return String(command.prefix(50))
    }
    
    /// Increment usage count
    func incrementUsage() {
        usageCount += 1
    }
    
    /// Check if shortcut is recently created (within last 7 days)
    var isRecentlyCreated: Bool {
        return createdAt.timeIntervalSinceNow > -604800 // 7 days
    }
    
    /// Check if shortcut is frequently used (more than 10 times)
    var isFrequentlyUsed: Bool {
        return usageCount > 10
    }
    
    /// Validation before saving
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateShortcut()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateShortcut()
    }
    
    private func validateShortcut() throws {
        // Validate name is not empty
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ShortcutValidationError.emptyName
        }
        
        // Validate command is not empty
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ShortcutValidationError.emptyCommand
        }
        
        // Validate usage count is not negative
        if usageCount < 0 {
            throw ShortcutValidationError.negativeUsageCount
        }
        
        // Validate category exists
        if TaskType(rawValue: category) == nil {
            throw ShortcutValidationError.invalidCategory
        }
        
        // Validate keyboard shortcut format if provided
        if let shortcut = keyboardShortcut, !shortcut.isEmpty {
            if !isValidKeyboardShortcut(shortcut) {
                throw ShortcutValidationError.invalidKeyboardShortcut
            }
        }
    }
    
    private func isValidKeyboardShortcut(_ shortcut: String) -> Bool {
        // Basic validation for keyboard shortcut format
        // Should contain at least one modifier key (⌘, ⌥, ⌃, ⇧) and one key
        let modifiers = ["⌘", "⌥", "⌃", "⇧", "cmd", "opt", "ctrl", "shift"]
        return modifiers.contains { shortcut.contains($0) } && shortcut.count >= 2
    }
}

// MARK: - Fetch Requests
extension TaskShortcut {
    
    /// Fetch request for shortcuts by category
    static func fetchRequest(category: TaskType) -> NSFetchRequest<TaskShortcut> {
        let request: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskShortcut.usageCount, ascending: false)]
        return request
    }
    
    /// Fetch request for enabled shortcuts only
    static var enabledShortcutsRequest: NSFetchRequest<TaskShortcut> {
        let request: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskShortcut.usageCount, ascending: false)]
        return request
    }
    
    /// Fetch request for shortcuts with keyboard shortcuts
    static var keyboardShortcutsRequest: NSFetchRequest<TaskShortcut> {
        let request: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
        request.predicate = NSPredicate(format: "keyboardShortcut != nil AND keyboardShortcut != ''")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskShortcut.name, ascending: true)]
        return request
    }
    
    /// Fetch request for frequently used shortcuts
    static var frequentlyUsedRequest: NSFetchRequest<TaskShortcut> {
        let request: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
        request.predicate = NSPredicate(format: "usageCount > 10")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskShortcut.usageCount, ascending: false)]
        return request
    }
    
    /// Fetch request for recently created shortcuts
    static var recentlyCreatedRequest: NSFetchRequest<TaskShortcut> {
        let request: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
        let weekAgo = Date().addingTimeInterval(-604800)
        request.predicate = NSPredicate(format: "createdAt >= %@", weekAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskShortcut.createdAt, ascending: false)]
        return request
    }
    
    /// Search shortcuts by name or command
    static func searchRequest(term: String) -> NSFetchRequest<TaskShortcut> {
        let request: NSFetchRequest<TaskShortcut> = TaskShortcut.fetchRequest()
        request.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR command CONTAINS[cd] %@",
            term, term
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskShortcut.usageCount, ascending: false)]
        return request
    }
}

// MARK: - Convenience Initializers
extension TaskShortcut {
    
    /// Create a new task shortcut
    static func createShortcut(
        name: String,
        command: String,
        category: TaskType,
        keyboardShortcut: String? = nil,
        in context: NSManagedObjectContext
    ) -> TaskShortcut {
        let shortcut = TaskShortcut(context: context)
        shortcut.id = UUID()
        shortcut.name = name
        shortcut.command = command
        shortcut.taskCategory = category
        shortcut.keyboardShortcut = keyboardShortcut
        shortcut.createdAt = Date()
        shortcut.usageCount = 0
        shortcut.isEnabled = true
        return shortcut
    }
}

// MARK: - Shortcut Validation Errors
enum ShortcutValidationError: LocalizedError {
    case emptyName
    case emptyCommand
    case negativeUsageCount
    case invalidCategory
    case invalidKeyboardShortcut
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Shortcut name cannot be empty"
        case .emptyCommand:
            return "Shortcut command cannot be empty"
        case .negativeUsageCount:
            return "Usage count cannot be negative"
        case .invalidCategory:
            return "Invalid task category"
        case .invalidKeyboardShortcut:
            return "Invalid keyboard shortcut format"
        }
    }
}