import Foundation
import AppKit

@MainActor
class ContextManager: ObservableObject {
    @Published var currentContext: ChatContext = ChatContext()
    @Published var isUpdatingContext = false
    
    private var contextUpdateTimer: Timer?
    private let updateInterval: TimeInterval = 30.0 // Update context every 30 seconds
    
    init() {
        startContextUpdates()
        Task {
            await updateContext()
        }
    }
    
    deinit {
        stopContextUpdates()
    }
    
    // MARK: - Public Methods
    
    func getCurrentContext() async -> ChatContext {
        await updateContext()
        return currentContext
    }
    
    func forceContextUpdate() async {
        await updateContext()
    }
    
    func startContextUpdates() {
        contextUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.updateContext()
            }
        }
    }
    
    func stopContextUpdates() {
        contextUpdateTimer?.invalidate()
        contextUpdateTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func updateContext() async {
        guard !isUpdatingContext else { return }
        
        isUpdatingContext = true
        
        defer {
            isUpdatingContext = false
        }
        
        do {
            let systemInfo = try await gatherSystemInfo()
            let currentDirectory = getCurrentDirectory()
            let recentFiles = getRecentFiles()
            let activeApplications = getActiveApplications()
            
            currentContext = ChatContext(
                systemInfo: systemInfo,
                currentDirectory: currentDirectory,
                recentFiles: recentFiles,
                activeApplications: activeApplications,
                conversationHistory: currentContext.conversationHistory
            )
            
        } catch {
            print("Failed to update context: \(error)")
        }
    }
    
    private func gatherSystemInfo() async throws -> SystemInfo {
        let batteryInfo = getBatteryInfo()
        let storageInfo = getStorageInfo()
        let memoryInfo = getMemoryInfo()
        let networkStatus = getNetworkStatus()
        let runningApps = getRunningApps()
        let cpuUsage = getCPUUsage()
        
        return SystemInfo(
            batteryLevel: batteryInfo.level,
            batteryIsCharging: batteryInfo.isCharging,
            availableStorage: storageInfo.available,
            totalStorage: storageInfo.total,
            memoryUsage: memoryInfo,
            networkStatus: networkStatus,
            runningApps: runningApps,
            cpuUsage: cpuUsage
        )
    }
    
    private func getBatteryInfo() -> (level: Double?, isCharging: Bool) {
        // TODO: Implement actual battery info gathering using IOKit
        // For now, return placeholder values
        return (level: 0.85, isCharging: false)
    }
    
    private func getStorageInfo() -> (available: Int64, total: Int64) {
        do {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let resourceValues = try homeURL.resourceValues(forKeys: [
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey
            ])
            
            let available = resourceValues.volumeAvailableCapacity ?? 0
            let total = resourceValues.volumeTotalCapacity ?? 0
            
            return (available: Int64(available), total: Int64(total))
        } catch {
            print("Failed to get storage info: \(error)")
            return (available: 0, total: 0)
        }
    }
    
    private func getMemoryInfo() -> MemoryInfo {
        // TODO: Implement actual memory info gathering using system APIs
        // For now, return placeholder values
        return MemoryInfo(
            totalMemory: 16_000_000_000, // 16GB
            usedMemory: 8_000_000_000,   // 8GB
            availableMemory: 8_000_000_000, // 8GB
            memoryPressure: .normal
        )
    }
    
    private func getNetworkStatus() -> NetworkStatus {
        // TODO: Implement actual network status checking
        // For now, return placeholder values
        return NetworkStatus(
            isConnected: true,
            connectionType: .wifi,
            wifiName: "Home Network",
            ipAddress: "192.168.1.100"
        )
    }
    
    private func getRunningApps() -> [AppInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        
        return runningApps.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  let localizedName = app.localizedName else {
                return nil
            }
            
            return AppInfo(
                id: bundleId,
                name: localizedName,
                isActive: app.isActive,
                memoryUsage: 0, // TODO: Get actual memory usage
                cpuUsage: 0     // TODO: Get actual CPU usage
            )
        }
    }
    
    private func getCPUUsage() -> Double {
        // TODO: Implement actual CPU usage monitoring
        // For now, return placeholder value
        return 0.15 // 15%
    }
    
    private func getCurrentDirectory() -> URL? {
        // Get the user's current working directory
        // For a GUI app, this might be the home directory or last accessed folder
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    private func getRecentFiles() -> [URL] {
        // TODO: Implement recent files tracking
        // This could track recently accessed files through the app
        // or get recent files from the system
        
        let recentItemsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sfl2")
        
        // For now, return some common directories
        let commonDirectories = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        ]
        
        return commonDirectories.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    
    private func getActiveApplications() -> [String] {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.compactMap { app in
            guard app.isActive, let name = app.localizedName else { return nil }
            return name
        }
    }
    
    // MARK: - Context Utilities
    
    func addToConversationHistory(_ message: ChatMessage) {
        var history = currentContext.conversationHistory
        history.append(message)
        
        // Keep only the last 20 messages for context
        if history.count > 20 {
            history = Array(history.suffix(20))
        }
        
        currentContext = ChatContext(
            systemInfo: currentContext.systemInfo,
            currentDirectory: currentContext.currentDirectory,
            recentFiles: currentContext.recentFiles,
            activeApplications: currentContext.activeApplications,
            conversationHistory: history
        )
    }
    
    func getContextSummary() -> String {
        let context = currentContext
        
        var summary = "Current Context:\n"
        
        if let systemInfo = context.systemInfo {
            summary += "• System: "
            if let battery = systemInfo.batteryLevel {
                summary += "Battery \(Int(battery * 100))%, "
            }
            summary += "Storage \(formatBytes(systemInfo.availableStorage)) available\n"
        }
        
        if let currentDir = context.currentDirectory {
            summary += "• Current Directory: \(currentDir.lastPathComponent)\n"
        }
        
        if !context.activeApplications.isEmpty {
            summary += "• Active Apps: \(context.activeApplications.prefix(3).joined(separator: ", "))\n"
        }
        
        if !context.recentFiles.isEmpty {
            summary += "• Recent Files: \(context.recentFiles.count) items\n"
        }
        
        return summary
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Extensions

extension ContextManager {
    func getRelevantContext(for taskType: TaskType) -> String {
        let context = currentContext
        
        switch taskType {
        case .fileOperation:
            var fileContext = "File System Context:\n"
            if let currentDir = context.currentDirectory {
                fileContext += "• Current Directory: \(currentDir.path)\n"
            }
            if !context.recentFiles.isEmpty {
                fileContext += "• Recent Locations: \(context.recentFiles.map { $0.lastPathComponent }.joined(separator: ", "))\n"
            }
            return fileContext
            
        case .systemQuery:
            guard let systemInfo = context.systemInfo else { return "System information not available" }
            
            var systemContext = "System Status:\n"
            if let battery = systemInfo.batteryLevel {
                systemContext += "• Battery: \(Int(battery * 100))%\(systemInfo.batteryIsCharging ? " (charging)" : "")\n"
            }
            systemContext += "• Storage: \(formatBytes(systemInfo.availableStorage)) available of \(formatBytes(systemInfo.totalStorage))\n"
            systemContext += "• Memory: \(formatBytes(systemInfo.memoryUsage.usedMemory)) used of \(formatBytes(systemInfo.memoryUsage.totalMemory))\n"
            return systemContext
            
        case .appControl:
            var appContext = "Application Context:\n"
            if !context.activeApplications.isEmpty {
                appContext += "• Active Apps: \(context.activeApplications.joined(separator: ", "))\n"
            }
            if let systemInfo = context.systemInfo, !systemInfo.runningApps.isEmpty {
                let appNames = systemInfo.runningApps.prefix(10).map { $0.name }
                appContext += "• Running Apps: \(appNames.joined(separator: ", "))\n"
            }
            return appContext
            
        default:
            return getContextSummary()
        }
    }
}