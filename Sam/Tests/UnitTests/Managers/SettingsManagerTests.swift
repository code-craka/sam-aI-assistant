import XCTest
import Combine
@testable import Sam

@MainActor
final class SettingsManagerTests: XCTestCase {
    var settingsManager: SettingsManager!
    var mockKeychainManager: MockKeychainManager!
    var mockUserDefaults: MockUserDefaults!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockKeychainManager = MockKeychainManager()
        mockUserDefaults = MockUserDefaults()
        settingsManager = SettingsManager(
            keychainManager: mockKeychainManager,
            userDefaults: mockUserDefaults
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        settingsManager = nil
        mockKeychainManager = nil
        mockUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - API Key Management Tests
    
    func testSetAPIKey() async throws {
        // Given
        let apiKey = "test-api-key-12345"
        
        // When
        try await settingsManager.setAPIKey(apiKey)
        
        // Then
        XCTAssertTrue(mockKeychainManager.setKeyCalled)
        XCTAssertEqual(mockKeychainManager.lastStoredKey, apiKey)
        XCTAssertEqual(mockKeychainManager.lastKeyIdentifier, "openai_api_key")
    }
    
    func testGetAPIKey() async throws {
        // Given
        let expectedKey = "stored-api-key-67890"
        mockKeychainManager.mockStoredKey = expectedKey
        
        // When
        let retrievedKey = try await settingsManager.getAPIKey()
        
        // Then
        XCTAssertEqual(retrievedKey, expectedKey)
        XCTAssertTrue(mockKeychainManager.getKeyCalled)
    }
    
    func testGetAPIKeyWhenNotSet() async throws {
        // Given
        mockKeychainManager.mockStoredKey = nil
        
        // When & Then
        do {
            _ = try await settingsManager.getAPIKey()
            XCTFail("Expected error when API key not set")
        } catch SettingsError.apiKeyNotSet {
            // Expected
        }
    }
    
    func testDeleteAPIKey() async throws {
        // Given
        mockKeychainManager.mockStoredKey = "existing-key"
        
        // When
        try await settingsManager.deleteAPIKey()
        
        // Then
        XCTAssertTrue(mockKeychainManager.deleteKeyCalled)
        XCTAssertEqual(mockKeychainManager.lastDeletedKeyIdentifier, "openai_api_key")
    }
    
    // MARK: - User Preferences Tests
    
    func testSetPreferredModel() {
        // Given
        let model = AIModel.gpt4Turbo
        
        // When
        settingsManager.setPreferredModel(model)
        
        // Then
        XCTAssertEqual(settingsManager.preferredModel, model)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "preferred_model")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? String, model.rawValue)
    }
    
    func testGetPreferredModel() {
        // Given
        mockUserDefaults.mockValues["preferred_model"] = AIModel.gpt4.rawValue
        
        // When
        let model = settingsManager.preferredModel
        
        // Then
        XCTAssertEqual(model, .gpt4)
    }
    
    func testSetMaxTokens() {
        // Given
        let maxTokens = 2048
        
        // When
        settingsManager.setMaxTokens(maxTokens)
        
        // Then
        XCTAssertEqual(settingsManager.maxTokens, maxTokens)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "max_tokens")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? Int, maxTokens)
    }
    
    func testSetTemperature() {
        // Given
        let temperature: Float = 0.7
        
        // When
        settingsManager.setTemperature(temperature)
        
        // Then
        XCTAssertEqual(settingsManager.temperature, temperature, accuracy: 0.01)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "temperature")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? Float, temperature)
    }
    
    func testSetAutoExecuteTasks() {
        // Given
        let autoExecute = true
        
        // When
        settingsManager.setAutoExecuteTasks(autoExecute)
        
        // Then
        XCTAssertEqual(settingsManager.autoExecuteTasks, autoExecute)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "auto_execute_tasks")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? Bool, autoExecute)
    }
    
    func testSetConfirmDangerousOperations() {
        // Given
        let confirmDangerous = false
        
        // When
        settingsManager.setConfirmDangerousOperations(confirmDangerous)
        
        // Then
        XCTAssertEqual(settingsManager.confirmDangerousOperations, confirmDangerous)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "confirm_dangerous_operations")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? Bool, confirmDangerous)
    }
    
    // MARK: - Theme and Appearance Tests
    
    func testSetThemeMode() {
        // Given
        let themeMode = ThemeMode.dark
        
        // When
        settingsManager.setThemeMode(themeMode)
        
        // Then
        XCTAssertEqual(settingsManager.themeMode, themeMode)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "theme_mode")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? String, themeMode.rawValue)
    }
    
    func testSetShowLineNumbers() {
        // Given
        let showLineNumbers = true
        
        // When
        settingsManager.setShowLineNumbers(showLineNumbers)
        
        // Then
        XCTAssertEqual(settingsManager.showLineNumbers, showLineNumbers)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "show_line_numbers")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? Bool, showLineNumbers)
    }
    
    // MARK: - Keyboard Shortcuts Tests
    
    func testAddKeyboardShortcut() {
        // Given
        let shortcut = KeyboardShortcut(
            id: UUID(),
            name: "Quick Search",
            key: "f",
            modifiers: [.command],
            action: "search_files"
        )
        
        // When
        settingsManager.addKeyboardShortcut(shortcut)
        
        // Then
        XCTAssertTrue(settingsManager.keyboardShortcuts.contains { $0.id == shortcut.id })
        XCTAssertTrue(mockUserDefaults.setValueCalled)
    }
    
    func testRemoveKeyboardShortcut() {
        // Given
        let shortcut = KeyboardShortcut(
            id: UUID(),
            name: "Test Shortcut",
            key: "t",
            modifiers: [.command],
            action: "test_action"
        )
        settingsManager.addKeyboardShortcut(shortcut)
        
        // When
        settingsManager.removeKeyboardShortcut(shortcut.id)
        
        // Then
        XCTAssertFalse(settingsManager.keyboardShortcuts.contains { $0.id == shortcut.id })
    }
    
    func testUpdateKeyboardShortcut() {
        // Given
        let originalShortcut = KeyboardShortcut(
            id: UUID(),
            name: "Original",
            key: "o",
            modifiers: [.command],
            action: "original_action"
        )
        settingsManager.addKeyboardShortcut(originalShortcut)
        
        let updatedShortcut = KeyboardShortcut(
            id: originalShortcut.id,
            name: "Updated",
            key: "u",
            modifiers: [.command, .shift],
            action: "updated_action"
        )
        
        // When
        settingsManager.updateKeyboardShortcut(updatedShortcut)
        
        // Then
        let storedShortcut = settingsManager.keyboardShortcuts.first { $0.id == originalShortcut.id }
        XCTAssertEqual(storedShortcut?.name, "Updated")
        XCTAssertEqual(storedShortcut?.key, "u")
        XCTAssertEqual(storedShortcut?.modifiers, [.command, .shift])
    }
    
    // MARK: - Privacy Settings Tests
    
    func testSetDataSharingEnabled() {
        // Given
        let dataSharingEnabled = false
        
        // When
        settingsManager.setDataSharingEnabled(dataSharingEnabled)
        
        // Then
        XCTAssertEqual(settingsManager.dataSharingEnabled, dataSharingEnabled)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "data_sharing_enabled")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? Bool, dataSharingEnabled)
    }
    
    func testSetAnalyticsEnabled() {
        // Given
        let analyticsEnabled = true
        
        // When
        settingsManager.setAnalyticsEnabled(analyticsEnabled)
        
        // Then
        XCTAssertEqual(settingsManager.analyticsEnabled, analyticsEnabled)
        XCTAssertTrue(mockUserDefaults.setValueCalled)
        XCTAssertEqual(mockUserDefaults.lastSetKey, "analytics_enabled")
        XCTAssertEqual(mockUserDefaults.lastSetValue as? Bool, analyticsEnabled)
    }
    
    // MARK: - Settings Validation Tests
    
    func testValidateSettings() async throws {
        // Given
        mockKeychainManager.mockStoredKey = "valid-api-key"
        settingsManager.setMaxTokens(4096)
        settingsManager.setTemperature(0.7)
        
        // When
        let isValid = try await settingsManager.validateSettings()
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testValidateSettingsWithInvalidAPIKey() async throws {
        // Given
        mockKeychainManager.mockStoredKey = nil
        
        // When
        let isValid = try await settingsManager.validateSettings()
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testValidateSettingsWithInvalidTemperature() async throws {
        // Given
        mockKeychainManager.mockStoredKey = "valid-key"
        settingsManager.setTemperature(2.0) // Invalid temperature
        
        // When
        let isValid = try await settingsManager.validateSettings()
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Settings Export/Import Tests
    
    func testExportSettings() async throws {
        // Given
        settingsManager.setPreferredModel(.gpt4)
        settingsManager.setMaxTokens(2048)
        settingsManager.setTemperature(0.8)
        settingsManager.setAutoExecuteTasks(true)
        
        // When
        let exportedSettings = try await settingsManager.exportSettings()
        
        // Then
        XCTAssertNotNil(exportedSettings["preferred_model"])
        XCTAssertNotNil(exportedSettings["max_tokens"])
        XCTAssertNotNil(exportedSettings["temperature"])
        XCTAssertNotNil(exportedSettings["auto_execute_tasks"])
        
        // API key should not be included in export
        XCTAssertNil(exportedSettings["api_key"])
    }
    
    func testImportSettings() async throws {
        // Given
        let settingsToImport: [String: Any] = [
            "preferred_model": AIModel.gpt35Turbo.rawValue,
            "max_tokens": 1024,
            "temperature": 0.5,
            "auto_execute_tasks": false,
            "theme_mode": ThemeMode.light.rawValue
        ]
        
        // When
        try await settingsManager.importSettings(settingsToImport)
        
        // Then
        XCTAssertEqual(settingsManager.preferredModel, .gpt35Turbo)
        XCTAssertEqual(settingsManager.maxTokens, 1024)
        XCTAssertEqual(settingsManager.temperature, 0.5, accuracy: 0.01)
        XCTAssertFalse(settingsManager.autoExecuteTasks)
        XCTAssertEqual(settingsManager.themeMode, .light)
    }
    
    // MARK: - Settings Reset Tests
    
    func testResetToDefaults() async throws {
        // Given
        settingsManager.setPreferredModel(.gpt4)
        settingsManager.setMaxTokens(4096)
        settingsManager.setTemperature(0.9)
        
        // When
        try await settingsManager.resetToDefaults()
        
        // Then
        XCTAssertEqual(settingsManager.preferredModel, .gpt35Turbo) // Default
        XCTAssertEqual(settingsManager.maxTokens, 2048) // Default
        XCTAssertEqual(settingsManager.temperature, 0.7, accuracy: 0.01) // Default
        XCTAssertTrue(settingsManager.autoExecuteTasks) // Default
    }
    
    // MARK: - Reactive Updates Tests
    
    func testSettingsChangeNotifications() {
        // Given
        var receivedUpdates: [String] = []
        
        settingsManager.settingsDidChange
            .sink { settingKey in
                receivedUpdates.append(settingKey)
            }
            .store(in: &cancellables)
        
        // When
        settingsManager.setPreferredModel(.gpt4)
        settingsManager.setMaxTokens(1024)
        
        // Then
        XCTAssertTrue(receivedUpdates.contains("preferred_model"))
        XCTAssertTrue(receivedUpdates.contains("max_tokens"))
    }
    
    // MARK: - Performance Tests
    
    func testSettingsLoadPerformance() {
        measure {
            _ = SettingsManager(
                keychainManager: mockKeychainManager,
                userDefaults: mockUserDefaults
            )
        }
    }
    
    func testConcurrentSettingsAccess() async throws {
        // When
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    self.settingsManager.setMaxTokens(1000 + i)
                    self.settingsManager.setTemperature(Float(i) / 10.0)
                }
            }
        }
        
        // Then
        // Should not crash or cause data corruption
        XCTAssertGreaterThan(settingsManager.maxTokens, 1000)
        XCTAssertGreaterThan(settingsManager.temperature, 0.0)
    }
}

// MARK: - Mock Classes

class MockKeychainManager: KeychainManagerProtocol {
    var mockStoredKey: String?
    var setKeyCalled = false
    var getKeyCalled = false
    var deleteKeyCalled = false
    
    var lastStoredKey: String?
    var lastKeyIdentifier: String?
    var lastDeletedKeyIdentifier: String?
    
    func setKey(_ key: String, for identifier: String) throws {
        setKeyCalled = true
        lastStoredKey = key
        lastKeyIdentifier = identifier
        mockStoredKey = key
    }
    
    func getKey(for identifier: String) throws -> String? {
        getKeyCalled = true
        return mockStoredKey
    }
    
    func deleteKey(for identifier: String) throws {
        deleteKeyCalled = true
        lastDeletedKeyIdentifier = identifier
        mockStoredKey = nil
    }
}

class MockUserDefaults: UserDefaultsProtocol {
    var mockValues: [String: Any] = [:]
    var setValueCalled = false
    var lastSetKey: String?
    var lastSetValue: Any?
    
    func setValue(_ value: Any?, forKey key: String) {
        setValueCalled = true
        lastSetKey = key
        lastSetValue = value
        
        if let value = value {
            mockValues[key] = value
        } else {
            mockValues.removeValue(forKey: key)
        }
    }
    
    func value(forKey key: String) -> Any? {
        return mockValues[key]
    }
    
    func string(forKey key: String) -> String? {
        return mockValues[key] as? String
    }
    
    func integer(forKey key: String) -> Int {
        return mockValues[key] as? Int ?? 0
    }
    
    func float(forKey key: String) -> Float {
        return mockValues[key] as? Float ?? 0.0
    }
    
    func bool(forKey key: String) -> Bool {
        return mockValues[key] as? Bool ?? false
    }
    
    func data(forKey key: String) -> Data? {
        return mockValues[key] as? Data
    }
}