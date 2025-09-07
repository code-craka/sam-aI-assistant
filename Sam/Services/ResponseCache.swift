import Foundation
import CryptoKit

// MARK: - Response Cache
/// Intelligent caching system for task processing results
/// Implements LRU eviction, TTL expiration, and smart cache invalidation
actor ResponseCache {
    
    // MARK: - Private Properties
    private var cache: [String: CacheEntry] = [:]
    private var accessOrder: [String] = [] // For LRU eviction
    private let maxCacheSize: Int
    private let defaultTTL: TimeInterval
    private let maxMemoryUsage: Int64 // in bytes
    private var currentMemoryUsage: Int64 = 0
    
    // Statistics
    private var stats = CacheStatistics()
    
    // MARK: - Initialization
    init(
        maxCacheSize: Int = 1000,
        defaultTTL: TimeInterval = 3600, // 1 hour
        maxMemoryUsage: Int64 = 50 * 1024 * 1024 // 50MB
    ) {
        self.maxCacheSize = maxCacheSize
        self.defaultTTL = defaultTTL
        self.maxMemoryUsage = maxMemoryUsage
        
        // Start cleanup timer
        Task {
            await startPeriodicCleanup()
        }
    }
    
    // MARK: - Public Methods
    
    /// Get cached response for input
    func getCachedResponse(for input: String) async -> TaskProcessingResult? {
        let inputHash = hashInput(input)
        
        guard let entry = cache[inputHash] else {
            stats.totalMisses += 1
            return nil
        }
        
        // Check if entry is expired
        if entry.isExpired {
            cache.removeValue(forKey: inputHash)
            removeFromAccessOrder(inputHash)
            stats.totalMisses += 1
            updateMemoryUsage()
            return nil
        }
        
        // Update access information
        var updatedEntry = entry
        updatedEntry = CacheEntry(
            inputHash: entry.inputHash,
            result: entry.result,
            ttl: defaultTTL
        )
        cache[inputHash] = updatedEntry
        
        // Update LRU order
        updateAccessOrder(inputHash)
        
        // Update statistics
        stats.totalHits += 1
        
        // Mark as cache hit
        var result = entry.result
        result = TaskProcessingResult(
            input: result.input,
            classification: result.classification,
            processingRoute: result.processingRoute,
            success: result.success,
            output: result.output,
            executionTime: result.executionTime,
            tokensUsed: result.tokensUsed,
            cost: result.cost,
            cacheHit: true
        )
        
        return result
    }
    
    /// Cache a processing result
    func cacheResponse(input: String, result: TaskProcessingResult) async {
        let inputHash = hashInput(input)
        
        // Don't cache failed results or very large responses
        guard result.success && shouldCache(result: result) else {
            return
        }
        
        let entry = CacheEntry(
            inputHash: inputHash,
            result: result,
            ttl: getTTLForResult(result)
        )
        
        // Check if we need to evict entries
        await evictIfNecessary()
        
        // Add to cache
        cache[inputHash] = entry
        updateAccessOrder(inputHash)
        
        // Update statistics
        stats.totalEntries = cache.count
        stats.newestEntry = Date()
        if stats.oldestEntry == nil {
            stats.oldestEntry = Date()
        }
        
        updateMemoryUsage()
    }
    
    /// Check if input has cached response
    func hasCachedResponse(for classification: TaskClassificationResult) -> Bool {
        // Simple heuristic: check if we have any cached responses for this task type
        return cache.values.contains { entry in
            !entry.isExpired && 
            entry.result.classification.taskType == classification.taskType &&
            entry.result.classification.parameters.keys.count > 0 &&
            hasParameterOverlap(entry.result.classification.parameters, classification.parameters)
        }
    }
    
    /// Clear all cached responses
    func clearCache() async {
        cache.removeAll()
        accessOrder.removeAll()
        currentMemoryUsage = 0
        stats = CacheStatistics()
    }
    
    /// Get cache health status
    func getHealthStatus() async -> HealthStatus {
        let hitRate = stats.hitRate
        let memoryUsagePercentage = Double(currentMemoryUsage) / Double(maxMemoryUsage)
        
        if hitRate > 0.7 && memoryUsagePercentage < 0.8 {
            return .healthy
        } else if hitRate > 0.4 && memoryUsagePercentage < 0.9 {
            return .degraded
        } else {
            return .unhealthy
        }
    }
    
    /// Get current cache statistics
    func getStatistics() async -> CacheStatistics {
        var currentStats = stats
        currentStats.cacheSize = currentMemoryUsage
        return currentStats
    }
    
    /// Invalidate cache entries matching criteria
    func invalidateCache(taskType: TaskType? = nil, olderThan: Date? = nil) async {
        var keysToRemove: [String] = []
        
        for (key, entry) in cache {
            var shouldRemove = false
            
            if let taskType = taskType, entry.result.classification.taskType == taskType {
                shouldRemove = true
            }
            
            if let olderThan = olderThan, entry.createdAt < olderThan {
                shouldRemove = true
            }
            
            if shouldRemove {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
            removeFromAccessOrder(key)
        }
        
        updateMemoryUsage()
        stats.totalEntries = cache.count
    }
    
    /// Preload cache with common responses
    func preloadCommonResponses() async {
        let commonQueries = [
            ("what's my battery level", createBatteryResponse()),
            ("show storage info", createStorageResponse()),
            ("list running apps", createAppsResponse()),
            ("help", createHelpResponse())
        ]
        
        for (query, result) in commonQueries {
            await cacheResponse(input: query, result: result)
        }
    }
}

// MARK: - Private Methods
private extension ResponseCache {
    
    func hashInput(_ input: String) -> String {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalizedInput.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func shouldCache(result: TaskProcessingResult) -> Bool {
        // Don't cache very large responses
        if result.output.count > 10000 {
            return false
        }
        
        // Don't cache time-sensitive results
        let timeSensitiveTasks: [TaskType] = [.systemQuery]
        if timeSensitiveTasks.contains(result.classification.taskType) {
            return false
        }
        
        // Don't cache personalized results
        if containsPersonalizedContent(result.output) {
            return false
        }
        
        return true
    }
    
    func containsPersonalizedContent(_ content: String) -> Bool {
        let personalizedKeywords = ["your", "you", "current time", "now", "today"]
        let lowercaseContent = content.lowercased()
        
        return personalizedKeywords.contains { lowercaseContent.contains($0) }
    }
    
    func getTTLForResult(_ result: TaskProcessingResult) -> TimeInterval {
        switch result.classification.taskType {
        case .help:
            return 24 * 3600 // 24 hours for help content
        case .calculation:
            return 12 * 3600 // 12 hours for calculations
        case .textProcessing:
            return 6 * 3600 // 6 hours for text processing
        case .fileOperation:
            return 1800 // 30 minutes for file operations
        case .systemQuery:
            return 300 // 5 minutes for system queries
        default:
            return defaultTTL
        }
    }
    
    func evictIfNecessary() async {
        // Remove expired entries first
        await removeExpiredEntries()
        
        // Check memory usage
        if currentMemoryUsage > maxMemoryUsage {
            await evictByMemoryPressure()
        }
        
        // Check cache size
        if cache.count >= maxCacheSize {
            await evictLRUEntries()
        }
    }
    
    func removeExpiredEntries() async {
        let expiredKeys = cache.compactMap { (key, entry) in
            entry.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            removeFromAccessOrder(key)
        }
        
        updateMemoryUsage()
    }
    
    func evictByMemoryPressure() async {
        // Sort by access time and size, evict largest least-recently-used entries
        let sortedEntries = cache.sorted { (entry1, entry2) in
            let size1 = estimateEntrySize(entry1.value)
            let size2 = estimateEntrySize(entry2.value)
            let access1 = accessOrder.firstIndex(of: entry1.key) ?? 0
            let access2 = accessOrder.firstIndex(of: entry2.key) ?? 0
            
            // Prioritize evicting large, old entries
            return (size1 * Double(access1)) > (size2 * Double(access2))
        }
        
        var evictedSize: Int64 = 0
        let targetReduction = currentMemoryUsage - (maxMemoryUsage * 8 / 10) // Reduce to 80%
        
        for (key, _) in sortedEntries {
            if evictedSize >= targetReduction {
                break
            }
            
            if let entry = cache[key] {
                evictedSize += estimateEntrySize(entry)
                cache.removeValue(forKey: key)
                removeFromAccessOrder(key)
            }
        }
        
        updateMemoryUsage()
    }
    
    func evictLRUEntries() async {
        let entriesToRemove = cache.count - (maxCacheSize * 8 / 10) // Keep 80% of max
        
        for i in 0..<min(entriesToRemove, accessOrder.count) {
            let keyToRemove = accessOrder[i]
            cache.removeValue(forKey: keyToRemove)
        }
        
        accessOrder.removeFirst(min(entriesToRemove, accessOrder.count))
        updateMemoryUsage()
    }
    
    func updateAccessOrder(_ key: String) {
        // Remove from current position
        removeFromAccessOrder(key)
        
        // Add to end (most recently used)
        accessOrder.append(key)
    }
    
    func removeFromAccessOrder(_ key: String) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }
    
    func updateMemoryUsage() {
        currentMemoryUsage = cache.values.reduce(0) { total, entry in
            total + estimateEntrySize(entry)
        }
        
        stats.totalEntries = cache.count
        stats.cacheSize = currentMemoryUsage
    }
    
    func estimateEntrySize(_ entry: CacheEntry) -> Int64 {
        let baseSize = MemoryLayout<CacheEntry>.size
        let stringSize = entry.inputHash.count + entry.result.input.count + entry.result.output.count
        return Int64(baseSize + stringSize * 2) // Rough estimate including overhead
    }
    
    func hasParameterOverlap(_ params1: [String: String], _ params2: [String: String]) -> Bool {
        let keys1 = Set(params1.keys)
        let keys2 = Set(params2.keys)
        let overlap = keys1.intersection(keys2)
        
        // Consider it a match if there's at least 50% key overlap
        let overlapPercentage = Double(overlap.count) / Double(max(keys1.count, keys2.count))
        return overlapPercentage >= 0.5
    }
    
    func startPeriodicCleanup() async {
        while true {
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutes
            await removeExpiredEntries()
        }
    }
    
    // MARK: - Preload Response Creators
    
    func createBatteryResponse() -> TaskProcessingResult {
        return TaskProcessingResult(
            input: "what's my battery level",
            classification: TaskClassificationResult(
                taskType: .systemQuery,
                confidence: 0.95,
                parameters: ["queryType": "battery"],
                complexity: .simple,
                processingRoute: .local
            ),
            processingRoute: .local,
            success: true,
            output: "I'll check your battery level for you.",
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createStorageResponse() -> TaskProcessingResult {
        return TaskProcessingResult(
            input: "show storage info",
            classification: TaskClassificationResult(
                taskType: .systemQuery,
                confidence: 0.95,
                parameters: ["queryType": "storage"],
                complexity: .simple,
                processingRoute: .local
            ),
            processingRoute: .local,
            success: true,
            output: "I'll show you your storage information.",
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createAppsResponse() -> TaskProcessingResult {
        return TaskProcessingResult(
            input: "list running apps",
            classification: TaskClassificationResult(
                taskType: .systemQuery,
                confidence: 0.95,
                parameters: ["queryType": "apps"],
                complexity: .simple,
                processingRoute: .local
            ),
            processingRoute: .local,
            success: true,
            output: "I'll list the currently running applications.",
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
    
    func createHelpResponse() -> TaskProcessingResult {
        return TaskProcessingResult(
            input: "help",
            classification: TaskClassificationResult(
                taskType: .help,
                confidence: 0.95,
                parameters: [:],
                complexity: .simple,
                processingRoute: .local
            ),
            processingRoute: .local,
            success: true,
            output: "I'm Sam, your macOS AI assistant. I can help you with file operations, system queries, app control, and more. Just ask me what you'd like to do!",
            executionTime: 0.1,
            tokensUsed: 0,
            cost: 0.0,
            cacheHit: false
        )
    }
}