import Foundation

/// Demo showcasing AppleScript engine capabilities
class AppleScriptEngineDemo {
    
    private let engine = AppleScriptEngine()
    
    // MARK: - Demo Methods
    
    /// Run all demos
    func runAllDemos() async {
        print("🍎 AppleScript Engine Demo")
        print("=" * 50)
        
        await demoTemplateSystem()
        await demoScriptGeneration()
        await demoFinderAutomation()
        await demoMailAutomation()
        await demoCalendarAutomation()
        await demoSafariAutomation()
        await demoSystemControl()
        await demoErrorHandling()
        await demoCaching()
        await demoPermissionManagement()
        
        print("\n✅ All demos completed!")
    }
    
    /// Demo template system
    private func demoTemplateSystem() async {
        print("\n📋 Template System Demo")
        print("-" * 30)
        
        let templates = engine.getAvailableTemplates()
        print("Available templates: \(templates.count)")
        
        for template in templates.prefix(5) {
            print("• \(template.name): \(template.description)")
            print("  Category: \(template.category.rawValue)")
            print("  Parameters: \(template.parameters.joined(separator: ", "))")
            print("  Target Apps: \(template.targetApps.joined(separator: ", "))")
        }
    }
    
    /// Demo script generation from natural language
    private func demoScriptGeneration() async {
        print("\n🧠 Script Generation Demo")
        print("-" * 30)
        
        let descriptions = [
            "create a new folder",
            "send an email",
            "open a website",
            "create a calendar event",
            "get system information"
        ]
        
        for description in descriptions {
            do {
                let script = try await engine.generateScript(for: description)
                print("Description: '\(description)'")
                print("Generated script preview: \(script.prefix(100))...")
                print()
            } catch {
                print("❌ Failed to generate script for '\(description)': \(error)")
            }
        }
    }
    
    /// Demo Finder automation
    private func demoFinderAutomation() async {
        print("\n📁 Finder Automation Demo")
        print("-" * 30)
        
        // Demo folder creation
        do {
            print("Creating demo folder...")
            let result = try await engine.executeTemplate(
                "create_folder",
                parameters: ["folderName": "SamDemo_\(Date().timeIntervalSince1970)"]
            )
            
            if result.success {
                print("✅ Folder created successfully")
                if let output = result.output {
                    print("Output: \(output)")
                }
            } else {
                print("❌ Failed to create folder: \(result.error ?? "Unknown error")")
            }
        } catch {
            print("❌ Finder automation error: \(error)")
            if case AppleScriptEngine.ScriptError.permissionDenied = error {
                print("💡 Enable automation permissions in System Preferences")
            }
        }
        
        // Demo file info
        do {
            print("\nGetting file info for Desktop...")
            let desktopPath = NSHomeDirectory() + "/Desktop"
            let result = try await engine.executeTemplate(
                "get_file_info",
                parameters: ["filePath": desktopPath]
            )
            
            if result.success {
                print("✅ File info retrieved")
                if let output = result.output {
                    print("Info: \(output)")
                }
            }
        } catch {
            print("❌ File info error: \(error)")
        }
    }
    
    /// Demo Mail automation
    private func demoMailAutomation() async {
        print("\n📧 Mail Automation Demo")
        print("-" * 30)
        
        // Note: This is a demo - we won't actually send emails
        print("Demo: Sending email (dry run)")
        
        do {
            let emailScript = """
            tell application "Mail"
                -- This is a demo script that would send an email
                return "Demo: Would send email to recipient@example.com"
            end tell
            """
            
            let result = try await engine.executeScript(emailScript, useCache: false)
            
            if result.success {
                print("✅ Email script executed (demo mode)")
                if let output = result.output {
                    print("Result: \(output)")
                }
            }
        } catch {
            print("❌ Mail automation error: \(error)")
        }
        
        // Demo reading emails
        print("\nDemo: Reading recent emails")
        do {
            let result = try await engine.executeTemplate(
                "read_emails",
                parameters: ["count": "5"]
            )
            
            if result.success {
                print("✅ Email reading script executed")
            }
        } catch {
            print("❌ Email reading error: \(error)")
        }
    }
    
    /// Demo Calendar automation
    private func demoCalendarAutomation() async {
        print("\n📅 Calendar Automation Demo")
        print("-" * 30)
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowEnd = Calendar.current.date(byAdding: .hour, value: 1, to: tomorrow)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        
        do {
            print("Creating demo calendar event...")
            let result = try await engine.executeTemplate(
                "create_event",
                parameters: [
                    "calendarName": "Calendar",
                    "title": "Sam Demo Event",
                    "startDate": formatter.string(from: tomorrow),
                    "endDate": formatter.string(from: tomorrowEnd)
                ]
            )
            
            if result.success {
                print("✅ Calendar event created")
            } else {
                print("❌ Failed to create event: \(result.error ?? "Unknown error")")
            }
        } catch {
            print("❌ Calendar automation error: \(error)")
        }
    }
    
    /// Demo Safari automation
    private func demoSafariAutomation() async {
        print("\n🌐 Safari Automation Demo")
        print("-" * 30)
        
        do {
            print("Opening URL in Safari...")
            let result = try await engine.executeTemplate(
                "open_url",
                parameters: ["url": "https://www.apple.com"]
            )
            
            if result.success {
                print("✅ URL opened in Safari")
            } else {
                print("❌ Failed to open URL: \(result.error ?? "Unknown error")")
            }
        } catch {
            print("❌ Safari automation error: \(error)")
        }
        
        // Demo getting current URL
        do {
            print("Getting current Safari URL...")
            let result = try await engine.executeTemplate("get_current_url")
            
            if result.success {
                print("✅ Current URL retrieved")
                if let output = result.output {
                    print("URL: \(output)")
                }
            }
        } catch {
            print("❌ URL retrieval error: \(error)")
        }
    }
    
    /// Demo system control
    private func demoSystemControl() async {
        print("\n⚙️ System Control Demo")
        print("-" * 30)
        
        // Demo system info
        do {
            print("Getting system information...")
            let result = try await engine.executeTemplate("system_info")
            
            if result.success {
                print("✅ System info retrieved")
                if let output = result.output {
                    print("Info: \(output.prefix(200))...")
                }
            }
        } catch {
            print("❌ System info error: \(error)")
        }
        
        // Demo notification
        do {
            print("Displaying notification...")
            let result = try await engine.executeTemplate(
                "display_notification",
                parameters: [
                    "message": "Hello from Sam's AppleScript Engine!",
                    "title": "Sam Demo"
                ]
            )
            
            if result.success {
                print("✅ Notification displayed")
            }
        } catch {
            print("❌ Notification error: \(error)")
        }
    }
    
    /// Demo error handling
    private func demoErrorHandling() async {
        print("\n🚨 Error Handling Demo")
        print("-" * 30)
        
        // Test compilation error
        do {
            print("Testing compilation error...")
            let _ = try await engine.executeScript("invalid syntax here", useCache: false)
        } catch AppleScriptEngine.ScriptError.compilationFailed(let message) {
            print("✅ Compilation error caught: \(message)")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
        
        // Test missing template
        do {
            print("Testing missing template...")
            let _ = try await engine.executeTemplate("non_existent_template")
        } catch AppleScriptEngine.ScriptError.scriptNotFound(let name) {
            print("✅ Missing template error caught: \(name)")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
        
        // Test invalid parameters
        do {
            print("Testing invalid parameters...")
            let _ = try await engine.executeScript("tell app \"Finder\" to {{missing}}", useCache: false)
        } catch AppleScriptEngine.ScriptError.invalidTemplate(let message) {
            print("✅ Invalid template error caught: \(message)")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }
    
    /// Demo caching system
    private func demoCaching() async {
        print("\n💾 Caching System Demo")
        print("-" * 30)
        
        let script = "return \"cached result\""
        
        do {
            print("First execution (will be cached)...")
            let result1 = try await engine.executeScript(script, useCache: true)
            print("Execution time: \(result1.executionTime)s")
            
            print("Second execution (from cache)...")
            let result2 = try await engine.executeScript(script, useCache: true)
            print("Execution time: \(result2.executionTime)s")
            
            if result2.executionTime < result1.executionTime {
                print("✅ Caching improved performance")
            }
        } catch {
            print("❌ Caching demo error: \(error)")
        }
        
        // Clear cache
        engine.clearCache()
        print("✅ Cache cleared")
    }
    
    /// Demo permission management
    private func demoPermissionManagement() async {
        print("\n🔐 Permission Management Demo")
        print("-" * 30)
        
        // This would show permission dialogs in a real app
        print("Note: Permission dialogs would appear in a real application")
        print("Permissions are managed automatically by the engine")
        print("Users are guided to System Preferences when needed")
        
        print("✅ Permission management system ready")
    }
}

// MARK: - String Extension for Demo

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Demo Runner

/// Run the AppleScript engine demo
func runAppleScriptEngineDemo() async {
    let demo = AppleScriptEngineDemo()
    await demo.runAllDemos()
}