import SwiftUI
import Charts

/// Performance monitoring dashboard view
struct PerformanceDashboardView: View {
    @StateObject private var performanceTracker = PerformanceTracker.shared
    @StateObject private var responseOptimizer = ResponseOptimizer.shared
    @StateObject private var backgroundProcessor = BackgroundProcessor.shared
    @StateObject private var memoryManager = MemoryManager.shared
    
    @State private var selectedTab = 0
    @State private var refreshTimer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Dashboard Tab", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Performance").tag(1)
                    Text("Memory").tag(2)
                    Text("Background Tasks").tag(3)
                    Text("Cache").tag(4)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    OverviewTab()
                        .tag(0)
                    
                    PerformanceTab()
                        .tag(1)
                    
                    MemoryTab()
                        .tag(2)
                    
                    BackgroundTasksTab()
                        .tag(3)
                    
                    CacheTab()
                        .tag(4)
                }
                .tabViewStyle(.automatic)
            }
        }
        .navigationTitle("Performance Dashboard")
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Trigger UI refresh
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    @StateObject private var performanceTracker = PerformanceTracker.shared
    @StateObject private var memoryManager = MemoryManager.shared
    @StateObject private var backgroundProcessor = BackgroundProcessor.shared
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                // Memory Usage Card
                MetricCard(
                    title: "Memory Usage",
                    value: memoryManager.getMemoryStatistics().formattedUsage,
                    subtitle: "Pressure: \(memoryManager.memoryPressure.rawValue.capitalized)",
                    color: memoryPressureColor(memoryManager.memoryPressure)
                )
                
                // Response Time Card
                MetricCard(
                    title: "Avg Response Time",
                    value: String(format: "%.2fs", performanceTracker.currentMetrics.averageResponseTime),
                    subtitle: "Success Rate: \(String(format: "%.1f%%", performanceTracker.currentMetrics.successRate * 100))",
                    color: .blue
                )
                
                // Active Tasks Card
                MetricCard(
                    title: "Active Tasks",
                    value: "\(backgroundProcessor.activeTasks.count)",
                    subtitle: "Completed: \(backgroundProcessor.completedTasks.count)",
                    color: .green
                )
                
                // Cache Performance Card
                MetricCard(
                    title: "Cache Hit Rate",
                    value: String(format: "%.1f%%", ResponseOptimizer.shared.cacheHitRate * 100),
                    subtitle: "Total Requests: \(ResponseOptimizer.shared.totalRequests)",
                    color: .purple
                )
            }
            .padding()
        }
    }
    
    private func memoryPressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .emergency: return .red
        }
    }
}

// MARK: - Performance Tab

struct PerformanceTab: View {
    @StateObject private var performanceTracker = PerformanceTracker.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Performance Metrics
                GroupBox("Performance Metrics") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Average Response Time:")
                            Spacer()
                            Text(String(format: "%.3fs", performanceTracker.currentMetrics.averageResponseTime))
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Success Rate:")
                            Spacer()
                            Text(String(format: "%.1f%%", performanceTracker.currentMetrics.successRate * 100))
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Total Operations:")
                            Spacer()
                            Text("\(performanceTracker.currentMetrics.operationHistory.count)")
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                // Recent Operations
                GroupBox("Recent Operations") {
                    if performanceTracker.currentMetrics.operationHistory.isEmpty {
                        Text("No operations recorded yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(performanceTracker.currentMetrics.operationHistory.suffix(10).reversed(), id: \.id) { operation in
                                OperationRowView(operation: operation)
                            }
                        }
                    }
                }
                
                // Performance Report
                GroupBox("Detailed Report") {
                    Button("Generate Performance Report") {
                        generatePerformanceReport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
    
    private func generatePerformanceReport() {
        let report = performanceTracker.getPerformanceReport()
        // Handle report generation (could show in a sheet or export)
        print("Performance Report Generated: \(report)")
    }
}

// MARK: - Memory Tab

struct MemoryTab: View {
    @StateObject private var memoryManager = MemoryManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Memory Status
                GroupBox("Memory Status") {
                    let stats = memoryManager.getMemoryStatistics()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Usage:")
                            Spacer()
                            Text(stats.formattedUsage)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Memory Pressure:")
                            Spacer()
                            Text(stats.pressure.rawValue.capitalized)
                                .fontWeight(.semibold)
                                .foregroundColor(memoryPressureColor(stats.pressure))
                        }
                        
                        HStack {
                            Text("Usage Percentage:")
                            Spacer()
                            Text(String(format: "%.1f%%", stats.usagePercentage))
                                .fontWeight(.semibold)
                        }
                        
                        // Memory Usage Bar
                        ProgressView(value: stats.usagePercentage / 100.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: memoryPressureColor(stats.pressure)))
                    }
                }
                
                // Memory Thresholds
                GroupBox("Memory Thresholds") {
                    let stats = memoryManager.getMemoryStatistics()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ThresholdRow(
                            label: "Warning",
                            value: stats.formattedWarningThreshold,
                            color: .yellow
                        )
                        
                        ThresholdRow(
                            label: "Critical",
                            value: stats.formattedCriticalThreshold,
                            color: .orange
                        )
                        
                        ThresholdRow(
                            label: "Emergency",
                            value: ByteCountFormatter.string(fromByteCount: Int64(stats.emergencyThreshold), countStyle: .memory),
                            color: .red
                        )
                    }
                }
                
                // Memory Actions
                GroupBox("Memory Management") {
                    VStack(spacing: 12) {
                        Button("Perform Manual Cleanup") {
                            Task {
                                await memoryManager.performManualCleanup()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(memoryManager.isCleanupInProgress)
                        
                        if memoryManager.isCleanupInProgress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Cleanup in progress...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func memoryPressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .emergency: return .red
        }
    }
}

// MARK: - Background Tasks Tab

struct BackgroundTasksTab: View {
    @StateObject private var backgroundProcessor = BackgroundProcessor.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Task Statistics
                GroupBox("Task Statistics") {
                    let stats = backgroundProcessor.getProcessingStatistics()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Total Tasks:")
                            Spacer()
                            Text("\(stats.totalTasks)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Active Tasks:")
                            Spacer()
                            Text("\(stats.activeTasks)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Completed:")
                            Spacer()
                            Text("\(stats.completedTasks)")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Failed:")
                            Spacer()
                            Text("\(stats.failedTasks)")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            Text("Avg Execution Time:")
                            Spacer()
                            Text(String(format: "%.2fs", stats.averageExecutionTime))
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                // Active Tasks
                if !backgroundProcessor.activeTasks.isEmpty {
                    GroupBox("Active Tasks") {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(backgroundProcessor.activeTasks) { task in
                                TaskRowView(task: task)
                            }
                        }
                    }
                }
                
                // Recent Completed Tasks
                if !backgroundProcessor.completedTasks.isEmpty {
                    GroupBox("Recent Completed Tasks") {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(backgroundProcessor.completedTasks.suffix(10).reversed(), id: \.id) { task in
                                TaskRowView(task: task)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Cache Tab

struct CacheTab: View {
    @StateObject private var responseOptimizer = ResponseOptimizer.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Cache Statistics
                GroupBox("Cache Statistics") {
                    let stats = responseOptimizer.getCacheStatistics()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Hit Rate:")
                            Spacer()
                            Text(String(format: "%.1f%%", stats.hitRate * 100))
                                .fontWeight(.semibold)
                                .foregroundColor(stats.hitRate > 0.5 ? .green : .orange)
                        }
                        
                        HStack {
                            Text("Total Requests:")
                            Spacer()
                            Text("\(stats.totalRequests)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Cache Hits:")
                            Spacer()
                            Text("\(stats.cacheHits)")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Cache Misses:")
                            Spacer()
                            Text("\(stats.cacheMisses)")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        
                        // Hit Rate Progress Bar
                        ProgressView(value: stats.hitRate)
                            .progressViewStyle(LinearProgressViewStyle(tint: stats.hitRate > 0.5 ? .green : .orange))
                    }
                }
                
                // Cache Management
                GroupBox("Cache Management") {
                    VStack(spacing: 12) {
                        Button("Clear Cache") {
                            Task {
                                await responseOptimizer.clearCache()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Text("Cache Size: Loading...")
                            .foregroundColor(.secondary)
                            .task {
                                // Update cache size
                            }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct OperationRowView: View {
    let operation: CompletedOperationMetrics
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(operation.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(operation.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.3fs", operation.duration))
                    .font(.caption)
                    .fontWeight(.medium)
                
                Image(systemName: operation.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(operation.success ? .green : .red)
                    .font(.caption2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TaskRowView: View {
    let task: BackgroundTask
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(task.status.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(statusColor(task.status))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(task.priority.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let duration = task.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .queued: return .blue
        case .running: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

struct ThresholdRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    PerformanceDashboardView()
}