import Foundation

// MARK: - Mail and Calendar Integration Demo
class MailCalendarIntegrationDemo {
    
    static func runDemo() {
        print("🎬 Running Mail and Calendar Integration Demo...")
        print("=" * 50)
        
        demonstrateMailIntegration()
        print()
        demonstrateCalendarIntegration()
        print()
        demonstrateContactsIntegration()
        print()
        demonstrateRemindersIntegration()
        
        print("=" * 50)
        print("✅ Mail and Calendar Integration Demo completed!")
    }
    
    // MARK: - Mail Integration Demo
    
    private static func demonstrateMailIntegration() {
        print("📧 Mail Integration Capabilities:")
        print("--------------------------------")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockURLSchemeHandler = MockURLSchemeHandler()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let mailIntegration = MailIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        print("Bundle ID: \(mailIntegration.bundleIdentifier)")
        print("Display Name: \(mailIntegration.displayName)")
        print("Integration Methods: \(mailIntegration.integrationMethods.map { $0.displayName }.joined(separator: ", "))")
        
        print("\nSupported Commands:")
        for command in mailIntegration.supportedCommands {
            print("• \(command.name): \(command.description)")
            print("  Examples: \(command.examples.joined(separator: ", "))")
        }
        
        print("\nCapabilities:")
        let capabilities = mailIntegration.getCapabilities()
        print("• Can Launch: \(capabilities.canLaunch)")
        print("• Can Create Documents: \(capabilities.canCreateDocuments)")
        print("• Custom Capabilities: \(capabilities.customCapabilities)")
        
        print("\nExample Commands:")
        print("• 'send email to john@example.com about project update'")
        print("• 'search emails for budget report'")
        print("• 'check mail'")
        print("• 'create mailbox for client emails'")
        print("• 'reply to this email'")
        print("• 'forward this email to team@company.com'")
    }
    
    // MARK: - Calendar Integration Demo
    
    private static func demonstrateCalendarIntegration() {
        print("📅 Calendar Integration Capabilities:")
        print("------------------------------------")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockURLSchemeHandler = MockURLSchemeHandler()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let calendarIntegration = CalendarIntegration(
            appDiscovery: mockAppDiscovery,
            urlSchemeHandler: mockURLSchemeHandler,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        print("Bundle ID: \(calendarIntegration.bundleIdentifier)")
        print("Display Name: \(calendarIntegration.displayName)")
        print("Integration Methods: \(calendarIntegration.integrationMethods.map { $0.displayName }.joined(separator: ", "))")
        
        print("\nSupported Commands:")
        for command in calendarIntegration.supportedCommands {
            print("• \(command.name): \(command.description)")
            if !command.examples.isEmpty {
                print("  Examples: \(command.examples.prefix(2).joined(separator: ", "))")
            }
        }
        
        print("\nCapabilities:")
        let capabilities = calendarIntegration.getCapabilities()
        print("• Can Launch: \(capabilities.canLaunch)")
        print("• Can Create Documents: \(capabilities.canCreateDocuments)")
        print("• Custom Capabilities: \(capabilities.customCapabilities)")
        
        print("\nExample Commands:")
        print("• 'create event team meeting at 2pm tomorrow'")
        print("• 'schedule lunch with client at noon for 1 hour'")
        print("• 'remind me to call dentist tomorrow at 9am'")
        print("• 'show today's events'")
        print("• 'show this week's calendar'")
        print("• 'delete event old meeting'")
    }
    
    // MARK: - Contacts Integration Demo
    
    private static func demonstrateContactsIntegration() {
        print("👥 Contacts Integration Capabilities:")
        print("------------------------------------")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let contactsIntegration = ContactsIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        print("Bundle ID: \(contactsIntegration.bundleIdentifier)")
        print("Display Name: \(contactsIntegration.displayName)")
        print("Integration Methods: \(contactsIntegration.integrationMethods.map { $0.displayName }.joined(separator: ", "))")
        
        print("\nSupported Commands:")
        for command in contactsIntegration.supportedCommands {
            print("• \(command.name): \(command.description)")
            if !command.examples.isEmpty {
                print("  Examples: \(command.examples.prefix(2).joined(separator: ", "))")
            }
        }
        
        print("\nCapabilities:")
        let capabilities = contactsIntegration.getCapabilities()
        print("• Can Launch: \(capabilities.canLaunch)")
        print("• Can Create Documents: \(capabilities.canCreateDocuments)")
        print("• Custom Capabilities: \(capabilities.customCapabilities)")
        
        print("\nExample Commands:")
        print("• 'add contact John Smith with email john@company.com'")
        print("• 'search for Sarah in contacts'")
        print("• 'get info for Mike Davis'")
        print("• 'update John's email to john.smith@newcompany.com'")
    }
    
    // MARK: - Reminders Integration Demo
    
    private static func demonstrateRemindersIntegration() {
        print("⏰ Reminders Integration Capabilities:")
        print("-------------------------------------")
        
        let mockAppDiscovery = MockAppDiscoveryService()
        let mockAppleScriptEngine = MockAppleScriptEngine()
        
        let remindersIntegration = RemindersIntegration(
            appDiscovery: mockAppDiscovery,
            appleScriptEngine: mockAppleScriptEngine
        )
        
        print("Bundle ID: \(remindersIntegration.bundleIdentifier)")
        print("Display Name: \(remindersIntegration.displayName)")
        print("Integration Methods: \(remindersIntegration.integrationMethods.map { $0.displayName }.joined(separator: ", "))")
        
        print("\nSupported Commands:")
        for command in remindersIntegration.supportedCommands {
            print("• \(command.name): \(command.description)")
            if !command.examples.isEmpty {
                print("  Examples: \(command.examples.prefix(2).joined(separator: ", "))")
            }
        }
        
        print("\nCapabilities:")
        let capabilities = remindersIntegration.getCapabilities()
        print("• Can Launch: \(capabilities.canLaunch)")
        print("• Can Create Documents: \(capabilities.canCreateDocuments)")
        print("• Custom Capabilities: \(capabilities.customCapabilities)")
        
        print("\nExample Commands:")
        print("• 'remind me to call John tomorrow at 2pm'")
        print("• 'add high priority reminder to submit report by Friday'")
        print("• 'create task review documents in work list'")
        print("• 'show today's reminders'")
        print("• 'complete reminder buy groceries'")
        print("• 'create list for personal projects'")
    }
}

// MARK: - Mock Classes for Demo

private class MockAppDiscoveryService {
    func isAppInstalled(bundleIdentifier: String) -> Bool {
        return true // For demo purposes, assume all apps are installed
    }
}

private class MockURLSchemeHandler {
    func openURL(_ url: URL) async throws -> Bool {
        return true
    }
}

private class MockAppleScriptEngine {
    func executeScript(_ script: String) async throws -> String {
        return "Mock script executed successfully"
    }
}

// MARK: - String Extension for Demo Formatting

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}