import CoreData
import Foundation

/// Simple test to verify Core Data stack functionality
class CoreDataTest {
    
    static func testCoreDataStack() {
        print("Testing Core Data stack...")
        
        // Test persistence controller initialization
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Test creating user preferences
        let preferences = UserPreferences.createDefault(in: context)
        print("✓ Created user preferences: \(preferences.id)")
        
        // Test creating a conversation
        let conversation = Conversation.createConversation(title: "Test Conversation", in: context)
        print("✓ Created conversation: \(conversation.title)")
        
        // Test creating a user message
        let userMessage = ChatMessage.createUserMessage(
            content: "Hello, Sam!",
            in: context,
            conversation: conversation
        )
        print("✓ Created user message: \(userMessage.content)")
        
        // Test creating an assistant message
        let assistantMessage = ChatMessage.createAssistantMessage(
            content: "Hello! How can I help you today?",
            taskType: .help,
            executionTime: 0.5,
            tokens: 15,
            cost: 0.0002,
            in: context,
            conversation: conversation
        )
        print("✓ Created assistant message: \(assistantMessage.content)")
        
        // Test creating a shortcut
        let shortcut = TaskShortcut.createShortcut(
            name: "Test Shortcut",
            command: "test command",
            category: .help,
            in: context
        )
        preferences.addShortcut(shortcut)
        print("✓ Created shortcut: \(shortcut.name)")
        
        // Test creating a workflow
        let workflow = Workflow.createWorkflow(
            name: "Test Workflow",
            description: "A test workflow",
            in: context
        )
        preferences.addWorkflow(workflow)
        print("✓ Created workflow: \(workflow.name)")
        
        // Test saving
        do {
            try context.save()
            print("✓ Successfully saved all entities to Core Data")
        } catch {
            print("✗ Failed to save: \(error)")
        }
        
        // Test fetching
        do {
            let conversationRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            let conversations = try context.fetch(conversationRequest)
            print("✓ Fetched \(conversations.count) conversations")
            
            let messageRequest: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
            let messages = try context.fetch(messageRequest)
            print("✓ Fetched \(messages.count) messages")
            
            let preferencesRequest: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
            let allPreferences = try context.fetch(preferencesRequest)
            print("✓ Fetched \(allPreferences.count) user preferences")
            
        } catch {
            print("✗ Failed to fetch: \(error)")
        }
        
        print("Core Data stack test completed!")
    }
}