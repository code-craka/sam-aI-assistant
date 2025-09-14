// Memory Optimization Utilities
import Foundation

class MemoryOptimizer {
    static let shared = MemoryOptimizer()
    
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    init() {
        setupMemoryPressureMonitoring()
    }
    
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        memoryPressureSource?.resume()
    }
    
    private func handleMemoryPressure() {
        // Clear caches
        ResponseCache.shared.clearCache()
        
        // Trim chat history in memory
        ChatManager.shared.trimMemoryCache()
        
        // Release unused AI resources
        AIService.shared.releaseUnusedResources()
        
        print("🧹 Memory pressure detected - cleaned up resources")
    }
    
    func optimizeForLowMemory() {
        // Implement lazy loading
        // Reduce batch sizes
        // Clear unnecessary caches
    }
}

// Core Data Memory Optimization
extension PersistenceController {
    func optimizeMemoryUsage() {
        // Set reasonable fetch batch sizes
        let fetchRequest = NSFetchRequest<ChatMessage>(entityName: "ChatMessage")
        fetchRequest.fetchBatchSize = 20
        
        // Use faulting to reduce memory footprint
        container.viewContext.stalenessInterval = 0
        
        // Implement automatic memory cleanup
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.container.viewContext.refreshAllObjects()
        }
    }
}