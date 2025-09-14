//
//  ConsentManagerTests.swift
//  Sam
//
//  Created by Assistant on 12/19/24.
//

import XCTest
@testable import Sam

/// Tests for ConsentManager functionality
@MainActor
class ConsentManagerTests: XCTestCase {
    
    var consentManager: ConsentManager!
    
    override func setUp() async throws {
        try await super.setUp()
        consentManager = ConsentManager()
        
        // Reset all consents for clean testing
        await consentManager.resetAllConsents()
    }
    
    override func tearDown() async throws {
        await consentManager.resetAllConsents()
        consentManager = nil
        try await super.tearDown()
    }
    
    func testInitialConsentState() {
        // All consents should be false initially
        XCTAssertFalse(consentManager.hasConsent(for: .cloudProcessing))
        XCTAssertFalse(consentManager.hasConsent(for: .fileAccess))
        XCTAssertFalse(consentManager.hasConsent(for: .systemAccess))
        XCTAssertFalse(consentManager.hasConsent(for: .dataCollection))
    }
    
    func testGrantConsent() async {
        // Grant consent for cloud processing
        await consentManager.grantConsent(for: .cloudProcessing, context: "Test context")
        
        // Verify consent is granted
        XCTAssertTrue(consentManager.hasConsent(for: .cloudProcessing))
        
        // Verify consent date is set
        let consentDate = consentManager.getConsentDate(for: .cloudProcessing)
        XCTAssertNotNil(consentDate)
        XCTAssertTrue(abs(consentDate!.timeIntervalSinceNow) < 5) // Within 5 seconds
    }
    
    func testRevokeConsent() async {
        // First grant consent
        await consentManager.grantConsent(for: .fileAccess, context: "Test context")
        XCTAssertTrue(consentManager.hasConsent(for: .fileAccess))
        
        // Then revoke it
        await consentManager.revokeConsent(for: .fileAccess)
        XCTAssertFalse(consentManager.hasConsent(for: .fileAccess))
        
        // Verify consent date is removed
        let consentDate = consentManager.getConsentDate(for: .fileAccess)
        XCTAssertNil(consentDate)
    }
    
    func testResetAllConsents() async {
        // Grant multiple consents
        await consentManager.grantConsent(for: .cloudProcessing, context: "Test")
        await consentManager.grantConsent(for: .fileAccess, context: "Test")
        await consentManager.grantConsent(for: .systemAccess, context: "Test")
        
        // Verify they are granted
        XCTAssertTrue(consentManager.hasConsent(for: .cloudProcessing))
        XCTAssertTrue(consentManager.hasConsent(for: .fileAccess))
        XCTAssertTrue(consentManager.hasConsent(for: .systemAccess))
        
        // Reset all consents
        await consentManager.resetAllConsents()
        
        // Verify all are revoked
        XCTAssertFalse(consentManager.hasConsent(for: .cloudProcessing))
        XCTAssertFalse(consentManager.hasConsent(for: .fileAccess))
        XCTAssertFalse(consentManager.hasConsent(for: .systemAccess))
        XCTAssertFalse(consentManager.hasConsent(for: .dataCollection))
    }
    
    func testConsentTypes() {
        // Test all consent types have proper titles and descriptions
        for consentType in ConsentManager.ConsentType.allCases {
            XCTAssertFalse(consentType.title.isEmpty)
            XCTAssertFalse(consentType.description.isEmpty)
            XCTAssertFalse(consentType.risks.isEmpty)
            XCTAssertFalse(consentType.benefits.isEmpty)
        }
    }
}

/// Tests for AuditLogger functionality
class AuditLoggerTests: XCTestCase {
    
    var auditLogger: AuditLogger!
    
    override func setUp() async throws {
        try await super.setUp()
        auditLogger = AuditLogger.shared
        
        // Clear audit log for clean testing
        try await auditLogger.clearAuditLog()
    }
    
    func testLogConsentGranted() async {
        await auditLogger.logConsentGranted(type: .cloudProcessing, context: "Test context")
        
        let events = await auditLogger.getAllAuditEvents()
        XCTAssertEqual(events.count, 1)
        
        let event = events.first!
        XCTAssertEqual(event.type, .consentGranted)
        XCTAssertTrue(event.description.contains("cloud processing"))
        XCTAssertEqual(event.metadata["consent_type"], "cloud_processing")
        XCTAssertEqual(event.metadata["context"], "Test context")
    }
    
    func testLogDataAccess() async {
        await auditLogger.logDataAccess(
            dataType: "chat_history",
            operation: "read",
            filePath: "/path/to/file"
        )
        
        let events = await auditLogger.getAllAuditEvents()
        XCTAssertEqual(events.count, 1)
        
        let event = events.first!
        XCTAssertEqual(event.type, .dataAccess)
        XCTAssertEqual(event.metadata["data_type"], "chat_history")
        XCTAssertEqual(event.metadata["operation"], "read")
        XCTAssertEqual(event.metadata["file_path"], "/path/to/file")
    }
    
    func testAuditStatistics() async {
        // Log several events
        await auditLogger.logConsentGranted(type: .cloudProcessing, context: "Test 1")
        await auditLogger.logConsentGranted(type: .fileAccess, context: "Test 2")
        await auditLogger.logDataAccess(dataType: "test", operation: "read")
        
        let stats = await auditLogger.getAuditStatistics()
        XCTAssertEqual(stats.totalEvents, 3)
        XCTAssertEqual(stats.eventCounts[.consentGranted], 2)
        XCTAssertEqual(stats.eventCounts[.dataAccess], 1)
    }
    
    func testFilterEventsByType() async {
        // Log different types of events
        await auditLogger.logConsentGranted(type: .cloudProcessing, context: "Test")
        await auditLogger.logDataAccess(dataType: "test", operation: "read")
        await auditLogger.logError(error: NSError(domain: "test", code: 1), context: "test")
        
        let consentEvents = await auditLogger.getAuditEvents(ofType: .consentGranted)
        XCTAssertEqual(consentEvents.count, 1)
        XCTAssertEqual(consentEvents.first?.type, .consentGranted)
        
        let dataEvents = await auditLogger.getAuditEvents(ofType: .dataAccess)
        XCTAssertEqual(dataEvents.count, 1)
        XCTAssertEqual(dataEvents.first?.type, .dataAccess)
    }
}

/// Tests for DataExportManager functionality
@MainActor
class DataExportManagerTests: XCTestCase {
    
    var dataExportManager: DataExportManager!
    
    override func setUp() async throws {
        try await super.setUp()
        dataExportManager = DataExportManager()
    }
    
    override func tearDown() async throws {
        dataExportManager = nil
        try await super.tearDown()
    }
    
    func testDataTypes() {
        // Test all data types have proper display names and descriptions
        for dataType in DataExportManager.DataType.allCases {
            XCTAssertFalse(dataType.displayName.isEmpty)
            XCTAssertFalse(dataType.description.isEmpty)
        }
    }
    
    func testExportFormats() {
        // Test all export formats have proper properties
        for format in DataExportManager.ExportFormat.allCases {
            XCTAssertFalse(format.displayName.isEmpty)
            XCTAssertFalse(format.fileExtension.isEmpty)
        }
    }
    
    func testExportResult() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.json")
        
        let successResult = DataExportManager.ExportResult.success(
            path: tempURL,
            recordCount: 10,
            fileSize: 1024
        )
        
        XCTAssertTrue(successResult.success)
        XCTAssertEqual(successResult.exportPath, tempURL)
        XCTAssertEqual(successResult.recordCount, 10)
        XCTAssertEqual(successResult.fileSize, 1024)
        XCTAssertNil(successResult.error)
        
        let error = NSError(domain: "test", code: 1)
        let failureResult = DataExportManager.ExportResult.failure(error: error)
        
        XCTAssertFalse(failureResult.success)
        XCTAssertNil(failureResult.exportPath)
        XCTAssertEqual(failureResult.recordCount, 0)
        XCTAssertEqual(failureResult.fileSize, 0)
        XCTAssertNotNil(failureResult.error)
    }
}