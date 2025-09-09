import Foundation
import os.log

/// Response time optimization system with intelligent caching
@MainActor
class ResponseOptimizer: ObservableObject {
    static let shared = ResponseOptimizer()
    
    // MARK: - Properties
    private let cache = ResponseCache()
    private let logger = Logger(subsystem: "com.sam.performance", category: "optimizer")
    private let performanceTracker = PerformanceTracker.shared
    
    // Cache statistics
    @Published var cacheHitRate: Double = 0.0
    @Published var totalRequests: Int = 0
    @Published var cacheHits: Int = 0
    
    private init() {
        setupCacheMonitoring()
    }
    
    // MARK: - Response Optimization
    
    /// Optimize response for a given request with caching and performance tracking
    func optimizeResponse<T: Codable>(
        for request: OptimizableRequest,
        operation: () async throws -> T
    ) async throws -> T {
        let operationId = "optimize_\(UUID().uuidString.prefix(8))"
        
        return try await performanceTracker.trackOperation(operationId, type: .cacheOperation) {
            // Check cache first
            if let cachedResponse: T = await getCachedResponse(for: request) {
                await recordCacheHit()
                logger.info("Cache hit for request: \(request.cacheKey)")
                return cachedResponse
            }
            
            // Execute operation and cache result
            await recordCacheMiss()
            let result = try await operation()
            
            // Cache the result if it's cacheable
            if request.isCacheable {
                await cacheResponse(result, for: request)
            }
            
            return result
        }
    }
    
    /// Get cached response if available
    private func getCachedResponse<T: Codable>(for request: OptimizableRequest) async -> T? {
        return await cache.get(key: request.cacheKey, type: T.self)
    }
    
    /// Cache a response
    private func cacheResponse<T: Codable>(_ response: T, for request: OptimizableRequest) async {
        await cache.set(
            key: request.cacheKey,
            value: response,
            ttl: request.cacheTTL
        )
        logger.debug("Cached response for key: \(request.cacheKey)")
    }
    
    // MARK: - Cache Statistics
    
    private func recordCacheHit() async {
        cacheHits += 1
        totalRequests += 1
        updateCacheHitRate()
    }
    
    private func recordCacheMiss() async {
        totalRequests += 1
        updateCacheHitRate()
    }
    
    private func updateCacheHitRate() {
        if totalRequests > 0 {
            cacheHitRate = Double(cacheHits) / Double(totalRequests)
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() async {
        await cache.clear()
        logger.info("Cache cleared")
    }
    
    func getCacheSize() async -> Int {
        return await cache.size()
    }
    
    func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            hitRate: cacheHitRate,
            totalRequests: totalRequests,
            cacheHits: cacheHits,
            cacheMisses: totalRequests - cacheHits
        )
    }
    
    // MARK: - Monitoring
    
    private func setupCacheMonitoring() {
        // Monitor cache performance
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCacheOptimization()
            }
        }
    }
    
    private func performCacheOptimization() async {
        let size = await getCacheSize()
        
        if size > CacheConstants.maxCacheSize {
            await cache.evictOldEntries()
            logger.info("Performed cache eviction, size was: \(size)")
        }
        
        // Log cache statistics
        logger.info("Cache stats - Hit rate: \(String(format: "%.2f", cacheHitRate * 100))%, Size: \(size)")
    }
}

// MARK: - Supporting Types

struct OptimizableRequest {
    let cacheKey: String
    let isCacheable: Bool
    let cacheTTL: TimeInterval
    let priority: RequestPriority
    
    init(
        cacheKey: String,
        isCacheable: Bool = true,
        cacheTTL: TimeInterval = 300, // 5 minutes default
        priority: RequestPriority = .normal
    ) {
        self.cacheKey = cacheKey
        self.isCacheable = isCacheable
        self.cacheTTL = cacheTTL
        self.priority = priority
    }
}

enum RequestPriority {
    case low
    case normal
    case high
    case critical
}

struct CacheStatistics {
    let hitRate: Double
    let totalRequests: Int
    let cacheHits: Int
    let cacheMisses: Int
}

/// Enhanced response cache with TTL and size management
actor ResponseCache {
    private var cache: [String: CacheEntry] = [:]
    private let maxSize = CacheConstants.maxCacheSize
    
    struct CacheEntry {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }
    
    func get<T: Codable>(key: String, type: T.Type) -> T? {
        guard let entry = cache[key], !entry.isExpired else {
            // Remove expired entry
            cache.removeValue(forKey: key)
            return nil
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: entry.data)
        } catch {
            // Remove corrupted entry
            cache.removeValue(forKey: key)
            return nil
        }
    }
    
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval) {
        do {
            let data = try JSONEncoder().encode(value)
            let entry = CacheEntry(data: data, timestamp: Date(), ttl: ttl)
            cache[key] = entry
            
            // Perform cleanup if needed
            if cache.count > maxSize {
                evictOldEntries()
            }
        } catch {
            // Silently fail to cache if encoding fails
        }
    }
    
    func clear() {
        cache.removeAll()
    }
    
    func size() -> Int {
        return cache.count
    }
    
    func evictOldEntries() {
        // Remove expired entries first
        let now = Date()
        cache = cache.filter { !$0.value.isExpired }
        
        // If still too large, remove oldest entries
        if cache.count > maxSize {
            let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sortedEntries.prefix(cache.count - maxSize + 10) // Remove extra for buffer
            
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
}

struct CacheConstants {
    static let maxCacheSize = 1000
    static let defaultTTL: TimeInterval = 300 // 5 minutes
    static let shortTTL: TimeInterval = 60 // 1 minute
    static let longTTL: TimeInterval = 3600 // 1 hour
}