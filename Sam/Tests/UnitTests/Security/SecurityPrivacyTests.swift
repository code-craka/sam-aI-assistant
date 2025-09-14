import XCTest
import CoreData
@testable import Sam

class SecurityPrivacyTests: XCTestCase {
    
    var privacyManager: PrivacyManager!
    var permissionManager: PermissionManager!
    var keychainManager: KeychainManager!
    var encryptionService: DataEncryptionService!
    var securityAuditService: SecurityAuditService!
    var testContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Initialize test objects
        privacyManager = PrivacyManager()
        permissionManager = PermissionManager()
        keychainManager = KeychainManager.shared
        encryptionService = DataEncryptionService.shared
        securityAuditService = SecurityAuditService.shared
        
        // Set up test Core Data context
        let persistentContainer = NSPersistentContainer(name: "SamDataModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = persistentContainer.viewContext
    }
    
    override func tearDown() {
        // Clean up test data
        keychainManager.clearAllCredentials()
        
        super.tearDown()
    }
    
    // MARK: - Privacy Manager Tests
    
    func testDataSensitivityClassification() {
        // Test public data
        let publicData = "What's the weather like today?"
        XCTAssertEqual(privacyManager.classifyDataSensitivity(publicData), .public)
        
        // Test personal data (email)
        let personalData = "Send email to john@example.com"
        XCTAssertEqual(privacyManager.classifyDataSensitivity(personalData), .personal)
        
        // Test sensitive data
        let sensitiveData = "Copy my password file to Desktop"
        XCTAssertEqual(privacyManager.classifyDataSensitivity(sensitiveData), .sensitive)
        
        // Test confidential data (SSN)
        let confidentialData = "My SSN is 123-45-6789"
        XCTAssertEqual(privacyManager.classifyDataSensitivity(confidentialData), .confidential)
    }
    
    func testShouldProcessLocally() {
        // Test with cloud processing enabled
        privacyManager.allowCloudProcessing = true
        
        let publicData = "What time is it?"
        XCTAssertFalse(privacyManager.shouldProcessLocally(publicData))
        
        let sensitiveData = "password: secret123"
        XCTAssertTrue(privacyManager.shouldProcessLocally(sensitiveData))
        
        // Test with cloud processing disabled
        privacyManager.allowCloudProcessing = false
        XCTAssertTrue(privacyManager.shouldProcessLocally(publicData))
    }
    
    func testDataSanitization() {
        let sensitiveText = "My email is john@example.com and my password is secret123"
        let sanitized = privacyManager.sanitizeForLogging(sensitiveText)
        
        XCTAssertFalse(sanitized.contains("john@example.com"))
        XCTAssertTrue(sanitized.contains("[EMAIL]"))
        XCTAssertTrue(sanitized.contains("password: [REDACTED]"))
    }
    
    func testRequiresUserConsent() {
        privacyManager.requireConfirmationForSensitive = true
        
        let publicData = "What's the weather?"
        XCTAssertFalse(privacyManager.requiresUserConsent(publicData))
        
        let sensitiveData = "Copy my financial documents"
        XCTAssertTrue(privacyManager.requiresUserConsent(sensitiveData))
    }
    
    // MARK: - Keychain Manager Tests
    
    func testAPIKeyStorage() {
        let testKey = "sk-test123456789012345678901234567890"
        
        // Test storing API key
        XCTAssertTrue(keychainManager.storeAPIKey(testKey, provider: .openAI))
        
        // Test retrieving API key
        let retrievedKey = keychainManager.getAPIKey(for: .openAI)
        XCTAssertEqual(retrievedKey, testKey)
        
        // Test key validation
        XCTAssertTrue(keychainManager.validateAPIKey(testKey, for: .openAI))
        
        // Test deleting API key
        XCTAssertTrue(keychainManager.deleteAPIKey(for: .openAI))
        XCTAssertNil(keychainManager.getAPIKey(for: .openAI))
    }
    
    func testAPIKeyValidation() {
        // Test valid OpenAI key
        let validOpenAIKey = "sk-1234567890123456789012345678901234567890123456789"
        XCTAssertTrue(keychainManager.validateAPIKey(validOpenAIKey, for: .openAI))
        
        // Test invalid OpenAI key (wrong prefix)
        let invalidKey1 = "ak-1234567890123456789012345678901234567890123456789"
        XCTAssertFalse(keychainManager.validateAPIKey(invalidKey1, for: .openAI))
        
        // Test invalid OpenAI key (too short)
        let invalidKey2 = "sk-123"
        XCTAssertFalse(keychainManager.validateAPIKey(invalidKey2, for: .openAI))
        
        // Test valid Anthropic key
        let validAnthropicKey = "sk-ant-1234567890123456789012345678901234567890"
        XCTAssertTrue(keychainManager.validateAPIKey(validAnthropicKey, for: .anthropic))
    }
    
    func testAPIKeySecurityAssessment() {
        // Test secure key
        let secureKey = "sk-1234567890abcdef1234567890abcdef1234567890abcdef12"
        let assessment = keychainManager.assessAPIKeySecurity(secureKey)
        XCTAssertTrue(assessment.isSecure)
        XCTAssertGreaterThan(assessment.score, 70)
        
        // Test insecure key (test key)
        let testKey = "sk-test1234567890123456789012345678901234567890"
        let testAssessment = keychainManager.assessAPIKeySecurity(testKey)
        XCTAssertFalse(testAssessment.isSecure)
        XCTAssertLessThan(testAssessment.score, 70)
    }
    
    func testMultipleAPIKeys() {
        let keys: [APIProvider: String] = [
            .openAI: "sk-openai123456789012345678901234567890123456789",
            .anthropic: "sk-ant-anthropic123456789012345678901234567890",
            .google: "google_api_key_1234567890123456789012345678"
        ]
        
        // Store multiple keys
        XCTAssertTrue(keychainManager.storeAPIKeys(keys))
        
        // Retrieve all keys
        let retrievedKeys = keychainManager.getAllAPIKeys()
        XCTAssertEqual(retrievedKeys.count, 3)
        XCTAssertEqual(retrievedKeys[.openAI], keys[.openAI])
        XCTAssertEqual(retrievedKeys[.anthropic], keys[.anthropic])
        XCTAssertEqual(retrievedKeys[.google], keys[.google])
    }
    
    // MARK: - Data Encryption Tests
    
    func testStringEncryption() {
        let testString = "This is sensitive data that should be encrypted"
        
        do {
            // Test encryption
            let encryptedData = try encryptionService.encrypt(testString)
            XCTAssertNotEqual(encryptedData, testString.data(using: .utf8))
            
            // Test decryption
            let decryptedString = try encryptionService.decryptToString(encryptedData)
            XCTAssertEqual(decryptedString, testString)
        } catch {
            XCTFail("Encryption/decryption failed: \(error)")
        }
    }
    
    func testDataEncryption() {
        let testData = "Sensitive binary data".data(using: .utf8)!
        
        do {
            // Test encryption
            let encryptedData = try encryptionService.encrypt(testData)
            XCTAssertNotEqual(encryptedData, testData)
            
            // Test decryption
            let decryptedData = try encryptionService.decrypt(encryptedData)
            XCTAssertEqual(decryptedData, testData)
        } catch {
            XCTFail("Data encryption/decryption failed: \(error)")
        }
    }
    
    func testChatMessageEncryption() {
        let message = ChatMessage.createUserMessage(
            content: "My password is secret123",
            in: testContext
        )
        
        do {
            // Test encryption
            try encryptionService.encryptChatMessage(message)
            XCTAssertTrue(message.isEncrypted)
            XCTAssertNil(message.content)
            XCTAssertNotNil(message.encryptedContent)
            
            // Test decryption
            let decryptedContent = try encryptionService.decryptChatMessage(message)
            XCTAssertEqual(decryptedContent, "My password is secret123")
        } catch {
            XCTFail("Chat message encryption failed: \(error)")
        }
    }
    
    func testEncryptionStatus() {
        let status = encryptionService.getEncryptionStatus()
        XCTAssertTrue(status.isEnabled)
        XCTAssertGreaterThanOrEqual(status.overallEncryptionPercentage, 0)
        XCTAssertLessThanOrEqual(status.overallEncryptionPercentage, 100)
    }
    
    // MARK: - Permission Manager Tests
    
    func testPermissionValidation() {
        // Test file operation task
        let fileTaskValidation = permissionManager.validatePermissionsForTask(.fileOperation)
        XCTAssertTrue(fileTaskValidation.requiredPermissions.contains(.fileSystem))
        
        // Test app control task
        let appTaskValidation = permissionManager.validatePermissionsForTask(.appControl)
        XCTAssertTrue(appTaskValidation.requiredPermissions.contains(.accessibility))
        XCTAssertTrue(appTaskValidation.requiredPermissions.contains(.automation))
        
        // Test system query (no special permissions required)
        let systemTaskValidation = permissionManager.validatePermissionsForTask(.systemQuery)
        XCTAssertTrue(systemTaskValidation.requiredPermissions.isEmpty)
    }
    
    func testPermissionSummary() {
        let summary = permissionManager.getPermissionSummary()
        XCTAssertGreaterThan(summary.totalPermissions, 0)
        XCTAssertGreaterThanOrEqual(summary.completionPercentage, 0)
        XCTAssertLessThanOrEqual(summary.completionPercentage, 100)
    }
    
    // MARK: - Security Audit Tests
    
    func testQuickSecurityCheck() {
        let quickStatus = securityAuditService.quickSecurityCheck()
        XCTAssertGreaterThanOrEqual(quickStatus.score, 0)
        XCTAssertLessThanOrEqual(quickStatus.score, 100)
        XCTAssertNotNil(quickStatus.status)
    }
    
    func testSecurityAudit() async {
        let auditReport = await securityAuditService.conductSecurityAudit()
        
        // Verify audit report structure
        XCTAssertGreaterThanOrEqual(auditReport.overallScore, 0)
        XCTAssertLessThanOrEqual(auditReport.overallScore, 100)
        XCTAssertGreaterThan(auditReport.auditDuration, 0)
        
        // Verify individual audit components
        XCTAssertGreaterThanOrEqual(auditReport.permissionAudit.score, 0)
        XCTAssertGreaterThanOrEqual(auditReport.encryptionAudit.score, 0)
        XCTAssertGreaterThanOrEqual(auditReport.keychainAudit.score, 0)
        XCTAssertGreaterThanOrEqual(auditReport.dataAudit.score, 0)
        XCTAssertGreaterThanOrEqual(auditReport.networkAudit.score, 0)
        XCTAssertGreaterThanOrEqual(auditReport.systemAudit.score, 0)
        
        // Verify recommendations are provided
        XCTAssertNotNil(auditReport.recommendations)
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndEncryption() {
        // Create test data
        let sensitiveMessage = "API key: sk-secret123456789012345678901234567890"
        let message = ChatMessage.createUserMessage(content: sensitiveMessage, in: testContext)
        
        do {
            // Save to Core Data
            try testContext.save()
            
            // Encrypt the message
            try message.encrypt()
            XCTAssertTrue(message.isEncrypted)
            
            // Save encrypted state
            try testContext.save()
            
            // Retrieve and decrypt
            let decryptedContent = message.decryptedContent
            XCTAssertEqual(decryptedContent, sensitiveMessage)
            
        } catch {
            XCTFail("End-to-end encryption test failed: \(error)")
        }
    }
    
    func testPrivacyWorkflow() {
        // Test complete privacy workflow
        let sensitiveInput = "Copy my password file from Documents to Desktop"
        
        // 1. Classify data sensitivity
        let sensitivity = privacyManager.classifyDataSensitivity(sensitiveInput)
        XCTAssertNotEqual(sensitivity, .public)
        
        // 2. Check if should process locally
        let shouldProcessLocally = privacyManager.shouldProcessLocally(sensitiveInput)
        XCTAssertTrue(shouldProcessLocally)
        
        // 3. Check if requires user consent
        let requiresConsent = privacyManager.requiresUserConsent(sensitiveInput)
        XCTAssertTrue(requiresConsent)
        
        // 4. Create privacy summary
        let summary = privacyManager.createPrivacySummary(for: sensitiveInput)
        XCTAssertTrue(summary.contains("Local"))
        XCTAssertTrue(summary.contains("consent"))
    }
    
    func testSecurityConfiguration() {
        // Test that security settings are properly configured
        XCTAssertTrue(encryptionService.isEncryptionAvailable)
        
        // Test privacy manager settings
        XCTAssertNotNil(privacyManager.allowCloudProcessing)
        XCTAssertNotNil(privacyManager.requireConfirmationForSensitive)
        XCTAssertNotNil(privacyManager.encryptLocalData)
        
        // Test keychain availability
        let testKey = "sk-test123456789012345678901234567890"
        XCTAssertTrue(keychainManager.storeAPIKey(testKey))
        XCTAssertNotNil(keychainManager.getAPIKey())
        XCTAssertTrue(keychainManager.deleteAPIKey())
    }
    
    // MARK: - Performance Tests
    
    func testEncryptionPerformance() {
        let largeText = String(repeating: "This is a test message for performance testing. ", count: 1000)
        
        measure {
            do {
                let encrypted = try encryptionService.encrypt(largeText)
                _ = try encryptionService.decryptToString(encrypted)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testClassificationPerformance() {
        let testMessages = [
            "What's the weather today?",
            "Send email to john@example.com",
            "Copy my password file",
            "My SSN is 123-45-6789",
            "Open Safari and go to apple.com"
        ]
        
        measure {
            for message in testMessages {
                _ = privacyManager.classifyDataSensitivity(message)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testEncryptionErrorHandling() {
        // Test with invalid data
        let invalidData = Data()
        
        XCTAssertThrowsError(try encryptionService.decryptToString(invalidData)) { error in
            XCTAssertTrue(error is EncryptionError)
        }
    }
    
    func testKeychainErrorHandling() {
        // Test with invalid API key
        let invalidKey = "invalid-key"
        XCTAssertFalse(keychainManager.storeAPIKey(invalidKey))
        
        // Test validation with invalid key
        XCTAssertFalse(keychainManager.validateAPIKey(invalidKey))
    }
}