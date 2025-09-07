import Foundation
import Combine

// MARK: - Cost Tracker
@MainActor
class CostTracker: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dailyUsage: DailyUsage = DailyUsage()
    @Published var monthlyUsage: MonthlyUsage = MonthlyUsage()
    @Published var totalUsage: TotalUsage = TotalUsage()
    @Published var currentSessionUsage: SessionUsage = SessionUsage()
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current
    private var usageHistory: [UsageRecord] = []
    
    // MARK: - Initialization
    init() {
        loadUsageHistory()
        updateCurrentPeriodUsage()
    }
    
    // MARK: - Public Methods
    
    /// Track API usage
    func trackUsage(tokens: Int, cost: Double, model: AIModel) async {
        let record = UsageRecord(
            timestamp: Date(),
            model: model,
            tokens: tokens,
            cost: cost
        )
        
        usageHistory.append(record)
        
        // Update current session
        currentSessionUsage.addUsage(tokens: tokens, cost: cost, model: model)
        
        // Update period usage
        updateCurrentPeriodUsage()
        
        // Save to persistent storage
        saveUsageHistory()
        
        // Check for usage alerts
        checkUsageAlerts()
    }
    
    /// Calculate cost for tokens and model
    func calculateCost(tokens: Int, model: AIModel) -> Double {
        return Double(tokens) * model.costPerToken
    }
    
    /// Get usage for specific date range
    func getUsage(from startDate: Date, to endDate: Date) -> [UsageRecord] {
        return usageHistory.filter { record in
            record.timestamp >= startDate && record.timestamp <= endDate
        }
    }
    
    /// Get usage by model
    func getUsageByModel() -> [AIModel: ModelUsage] {
        var modelUsage: [AIModel: ModelUsage] = [:]
        
        for record in usageHistory {
            if var usage = modelUsage[record.model] {
                usage.totalTokens += record.tokens
                usage.totalCost += record.cost
                usage.requestCount += 1
                modelUsage[record.model] = usage
            } else {
                modelUsage[record.model] = ModelUsage(
                    model: record.model,
                    totalTokens: record.tokens,
                    totalCost: record.cost,
                    requestCount: 1
                )
            }
        }
        
        return modelUsage
    }
    
    /// Reset all usage statistics
    func reset() {
        usageHistory.removeAll()
        dailyUsage = DailyUsage()
        monthlyUsage = MonthlyUsage()
        totalUsage = TotalUsage()
        currentSessionUsage = SessionUsage()
        
        saveUsageHistory()
    }
    
    /// Export usage data
    func exportUsageData() -> Data? {
        let exportData = UsageExport(
            exportDate: Date(),
            totalUsage: totalUsage,
            usageHistory: usageHistory,
            modelBreakdown: getUsageByModel()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    /// Get cost estimate for tokens
    func estimateCost(tokens: Int, model: AIModel) -> Double {
        return calculateCost(tokens: tokens, model: model)
    }
    
    /// Check if within budget limits
    func isWithinBudget(dailyLimit: Double? = nil, monthlyLimit: Double? = nil) -> BudgetStatus {
        var status = BudgetStatus()
        
        if let dailyLimit = dailyLimit {
            status.dailyBudgetExceeded = dailyUsage.totalCost > dailyLimit
            status.dailyBudgetPercentage = dailyUsage.totalCost / dailyLimit
        }
        
        if let monthlyLimit = monthlyLimit {
            status.monthlyBudgetExceeded = monthlyUsage.totalCost > monthlyLimit
            status.monthlyBudgetPercentage = monthlyUsage.totalCost / monthlyLimit
        }
        
        return status
    }
}

// MARK: - Private Methods
private extension CostTracker {
    
    func loadUsageHistory() {
        if let data = userDefaults.data(forKey: UserDefaultsKeys.usageStatistics),
           let history = try? JSONDecoder().decode([UsageRecord].self, from: data) {
            usageHistory = history
        }
    }
    
    func saveUsageHistory() {
        if let data = try? JSONEncoder().encode(usageHistory) {
            userDefaults.set(data, forKey: UserDefaultsKeys.usageStatistics)
        }
    }
    
    func updateCurrentPeriodUsage() {
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        // Calculate daily usage
        let todayRecords = usageHistory.filter { record in
            record.timestamp >= startOfDay
        }
        
        dailyUsage = DailyUsage(
            date: startOfDay,
            totalTokens: todayRecords.reduce(0) { $0 + $1.tokens },
            totalCost: todayRecords.reduce(0) { $0 + $1.cost },
            requestCount: todayRecords.count
        )
        
        // Calculate monthly usage
        let monthRecords = usageHistory.filter { record in
            record.timestamp >= startOfMonth
        }
        
        monthlyUsage = MonthlyUsage(
            month: startOfMonth,
            totalTokens: monthRecords.reduce(0) { $0 + $1.tokens },
            totalCost: monthRecords.reduce(0) { $0 + $1.cost },
            requestCount: monthRecords.count
        )
        
        // Calculate total usage
        totalUsage = TotalUsage(
            totalTokens: usageHistory.reduce(0) { $0 + $1.tokens },
            totalCost: usageHistory.reduce(0) { $0 + $1.cost },
            requestCount: usageHistory.count,
            firstUsageDate: usageHistory.first?.timestamp,
            lastUsageDate: usageHistory.last?.timestamp
        )
    }
    
    func checkUsageAlerts() {
        // Check for high usage patterns and send notifications if needed
        let dailyThreshold = 10.0 // $10 daily threshold
        let monthlyThreshold = 100.0 // $100 monthly threshold
        
        if dailyUsage.totalCost > dailyThreshold {
            NotificationCenter.default.post(
                name: .init("HighDailyUsageAlert"),
                object: dailyUsage
            )
        }
        
        if monthlyUsage.totalCost > monthlyThreshold {
            NotificationCenter.default.post(
                name: .init("HighMonthlyUsageAlert"),
                object: monthlyUsage
            )
        }
    }
}

// MARK: - Usage Data Models

struct UsageRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let model: AIModel
    let tokens: Int
    let cost: Double
    
    init(timestamp: Date, model: AIModel, tokens: Int, cost: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.model = model
        self.tokens = tokens
        self.cost = cost
    }
}

struct DailyUsage: Codable {
    let date: Date
    let totalTokens: Int
    let totalCost: Double
    let requestCount: Int
    
    init(date: Date = Date(), totalTokens: Int = 0, totalCost: Double = 0, requestCount: Int = 0) {
        self.date = date
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.requestCount = requestCount
    }
}

struct MonthlyUsage: Codable {
    let month: Date
    let totalTokens: Int
    let totalCost: Double
    let requestCount: Int
    
    init(month: Date = Date(), totalTokens: Int = 0, totalCost: Double = 0, requestCount: Int = 0) {
        self.month = month
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.requestCount = requestCount
    }
}

struct TotalUsage: Codable {
    let totalTokens: Int
    let totalCost: Double
    let requestCount: Int
    let firstUsageDate: Date?
    let lastUsageDate: Date?
    
    init(totalTokens: Int = 0, totalCost: Double = 0, requestCount: Int = 0, firstUsageDate: Date? = nil, lastUsageDate: Date? = nil) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.requestCount = requestCount
        self.firstUsageDate = firstUsageDate
        self.lastUsageDate = lastUsageDate
    }
}

struct SessionUsage: Codable {
    var startTime: Date
    var totalTokens: Int
    var totalCost: Double
    var requestCount: Int
    
    init() {
        self.startTime = Date()
        self.totalTokens = 0
        self.totalCost = 0
        self.requestCount = 0
    }
    
    mutating func addUsage(tokens: Int, cost: Double, model: AIModel) {
        totalTokens += tokens
        totalCost += cost
        requestCount += 1
    }
    
    mutating func reset() {
        startTime = Date()
        totalTokens = 0
        totalCost = 0
        requestCount = 0
    }
}

struct ModelUsage: Codable {
    let model: AIModel
    var totalTokens: Int
    var totalCost: Double
    var requestCount: Int
    
    var averageCostPerRequest: Double {
        return requestCount > 0 ? totalCost / Double(requestCount) : 0
    }
    
    var averageTokensPerRequest: Double {
        return requestCount > 0 ? Double(totalTokens) / Double(requestCount) : 0
    }
}

struct BudgetStatus {
    var dailyBudgetExceeded: Bool = false
    var monthlyBudgetExceeded: Bool = false
    var dailyBudgetPercentage: Double = 0
    var monthlyBudgetPercentage: Double = 0
    
    var isWithinBudget: Bool {
        return !dailyBudgetExceeded && !monthlyBudgetExceeded
    }
}

struct UsageExport: Codable {
    let exportDate: Date
    let totalUsage: TotalUsage
    let usageHistory: [UsageRecord]
    let modelBreakdown: [AIModel: ModelUsage]
}