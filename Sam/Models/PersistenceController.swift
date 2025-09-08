import CoreData
import Foundation
import OSLog

/// Core Data persistence controller with background context support and error handling
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    // Simple logging for now
    private func log(_ message: String) {
        print("[PersistenceController] \(message)")
    }
    
    /// Preview instance for SwiftUI previews with sample data
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        // Return without sample data for now to avoid initialization issues
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
                self?.log("Core Data error: \(error.localizedDescription)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            self?.log("Core Data store loaded successfully: \(storeDescription.url?.absoluteString ?? "unknown")")
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
            self?.log("Remote Core Data changes detected")
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
                log("View context saved successfully")
            } catch {
                log("Failed to save view context: \(error.localizedDescription)")
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// Save a background context with error handling
    func saveBackground(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        try context.save()
        log("Background context saved successfully")
    }
    
    /// Perform a background task with proper error handling
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    self.log("Background task failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Clean up old data based on user preferences
    func cleanupOldData() async {
        // TODO: Implement cleanup once Core Data entities are properly configured
        log("Cleanup old data called - implementation pending")
    }
    
    /// Get or create user preferences
    func getUserPreferences() async -> Bool {
        // TODO: Implement once Core Data entities are properly configured
        log("Get user preferences called - implementation pending")
        return false
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