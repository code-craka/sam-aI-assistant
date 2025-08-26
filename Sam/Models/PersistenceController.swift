import CoreData
import Foundation
import OSLog

/// Core Data persistence controller with background context support and error handling
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    private let logger = Logger(subsystem: "com.sam.assistant", category: "CoreData")
    
    /// Preview instance for SwiftUI previews with sample data
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for previews
        let samplePreferences = UserPreferences(context: viewContext)
        samplePreferences.id = UUID()
        samplePreferences.preferredModel = "gpt-4-turbo-preview"
        samplePreferences.maxTokens = 4000
        samplePreferences.temperature = 0.7
        samplePreferences.autoExecuteTasks = false
        samplePreferences.confirmDangerousOperations = true
        samplePreferences.themeMode = "system"
        
        let sampleConversation = Conversation(context: viewContext)
        sampleConversation.id = UUID()
        sampleConversation.title = "Sample Conversation"
        sampleConversation.createdAt = Date()
        sampleConversation.lastMessageAt = Date()
        sampleConversation.messageCount = 2
        sampleConversation.totalTokens = 150
        sampleConversation.totalCost = 0.003
        
        let userMessage = ChatMessage(context: viewContext)
        userMessage.id = UUID()
        userMessage.content = "What's my battery level?"
        userMessage.timestamp = Date().addingTimeInterval(-300)
        userMessage.isUserMessage = true
        userMessage.taskType = "system_query"
        userMessage.executionTime = 0
        userMessage.tokens = 10
        userMessage.cost = 0.0001
        userMessage.conversation = sampleConversation
        
        let assistantMessage = ChatMessage(context: viewContext)
        assistantMessage.id = UUID()
        assistantMessage.content = "Your battery is at 85% and charging."
        assistantMessage.timestamp = Date().addingTimeInterval(-290)
        assistantMessage.isUserMessage = false
        assistantMessage.taskType = "system_query"
        assistantMessage.taskResult = "Battery: 85%, Charging: true"
        assistantMessage.executionTime = 1.2
        assistantMessage.tokens = 15
        assistantMessage.cost = 0.0002
        assistantMessage.conversation = sampleConversation
        
        let sampleShortcut = TaskShortcut(context: viewContext)
        sampleShortcut.id = UUID()
        sampleShortcut.name = "Check Battery"
        sampleShortcut.command = "what's my battery level?"
        sampleShortcut.keyboardShortcut = "⌘B"
        sampleShortcut.category = "system_query"
        sampleShortcut.createdAt = Date()
        sampleShortcut.usageCount = 5
        sampleShortcut.isEnabled = true
        sampleShortcut.userPreferences = samplePreferences
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    /// Background context for performing operations off the main thread
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SamDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure persistent store for production
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }
            
            // Enable persistent history tracking
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable WAL mode for better performance
            description.setOption("WAL" as NSString, forKey: NSSQLitePragmasOption)
        }
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                self?.logger.error("Core Data error: \(error.localizedDescription)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            self?.logger.info("Core Data store loaded successfully: \(storeDescription.url?.absoluteString ?? "unknown")")
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set up remote change notifications
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.logger.debug("Remote Core Data changes detected")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Save the view context with error handling
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                logger.debug("View context saved successfully")
            } catch {
                logger.error("Failed to save view context: \(error.localizedDescription)")
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// Save a background context with error handling
    func saveBackground(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        try context.save()
        logger.debug("Background context saved successfully")
    }
    
    /// Perform a background task with proper error handling
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    self.logger.error("Background task failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Clean up old data based on user preferences
    func cleanupOldData() async {
        do {
            try await performBackgroundTask { context in
                // Fetch user preferences to check cleanup settings
                let preferencesRequest: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
                let preferences = try context.fetch(preferencesRequest).first
                
                guard let preferences = preferences,
                      preferences.autoDeleteOldChats else {
                    return
                }
                
                let cutoffDate = Calendar.current.date(
                    byAdding: .day,
                    value: -Int(preferences.autoDeleteAfterDays),
                    to: Date()
                ) ?? Date()
                
                // Delete old conversations
                let conversationRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
                conversationRequest.predicate = NSPredicate(format: "lastMessageAt < %@", cutoffDate as NSDate)
                
                let oldConversations = try context.fetch(conversationRequest)
                for conversation in oldConversations {
                    context.delete(conversation)
                }
                
                if context.hasChanges {
                    try context.save()
                    self.logger.info("Cleaned up \(oldConversations.count) old conversations")
                }
            }
        } catch {
            logger.error("Failed to cleanup old data: \(error.localizedDescription)")
        }
    }
    
    /// Get or create user preferences
    func getUserPreferences() async -> UserPreferences {
        do {
            return try await performBackgroundTask { context in
                let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
                
                if let existing = try context.fetch(request).first {
                    return existing
                } else {
                    // Create default preferences
                    let preferences = UserPreferences(context: context)
                    preferences.id = UUID()
                    preferences.preferredModel = "gpt-4-turbo-preview"
                    preferences.maxTokens = 4000
                    preferences.temperature = 0.7
                    preferences.autoExecuteTasks = false
                    preferences.confirmDangerousOperations = true
                    preferences.themeMode = "system"
                    preferences.dataSensitivityLevel = "balanced"
                    preferences.enableNotifications = true
                    preferences.encryptLocalData = true
                    preferences.storeConversationHistory = true
                    preferences.autoDeleteOldChats = false
                    preferences.autoDeleteAfterDays = 30
                    preferences.shareUsageData = false
                    preferences.taskCompletionNotifications = true
                    preferences.errorNotifications = true
                    preferences.usageReportNotifications = false
                    preferences.soundEnabled = true
                    preferences.notificationSound = "default"
                    
                    try context.save()
                    return preferences
                }
            }
        } catch {
            logger.error("Failed to get user preferences: \(error.localizedDescription)")
            // Return a temporary preferences object as fallback
            let tempPreferences = UserPreferences(context: container.viewContext)
            tempPreferences.id = UUID()
            return tempPreferences
        }
    }
}

// MARK: - Core Data Error Handling
extension PersistenceController {
    enum CoreDataError: LocalizedError {
        case saveError(Error)
        case fetchError(Error)
        case deleteError(Error)
        
        var errorDescription: String? {
            switch self {
            case .saveError(let error):
                return "Failed to save data: \(error.localizedDescription)"
            case .fetchError(let error):
                return "Failed to fetch data: \(error.localizedDescription)"
            case .deleteError(let error):
                return "Failed to delete data: \(error.localizedDescription)"
            }
        }
    }
}