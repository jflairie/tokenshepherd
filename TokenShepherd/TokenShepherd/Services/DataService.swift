import Foundation
import Combine

// MARK: - Data Service

class DataService: ObservableObject {
    // Published state
    @Published var usageData = UsageData()
    @Published var quotaData = QuotaData()
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var hasValidCredentials = false
    @Published var dataLoaded = false

    // File paths
    private let claudeDir: String
    private let statsCachePath: String

    // Watchers and timers
    private var statsCacheWatcher: FileWatcher?
    private var statsPollTimer: Timer?

    // Refresh intervals
    private let statsPollInterval: TimeInterval = 60  // 1 minute

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        claudeDir = "\(homeDir)/.claude"
        statsCachePath = "\(claudeDir)/stats-cache.json"

        // Check credentials
        hasValidCredentials = KeychainService.shared.getAnthropicAPIKey() != nil ||
                             KeychainService.shared.getClaudeToken() != nil
    }

    // MARK: - Public API

    func startMonitoring() {
        // Initial load
        loadStatsCache()

        // Set up file watcher
        setupFileWatcher()

        // Set up polling timer
        setupTimer()
    }

    func stopMonitoring() {
        statsCacheWatcher?.stop()
        statsPollTimer?.invalidate()
    }

    // MARK: - Private Methods

    private func setupFileWatcher() {
        if FileManager.default.fileExists(atPath: statsCachePath) {
            statsCacheWatcher = FileWatcher(path: statsCachePath) { [weak self] in
                self?.loadStatsCache()
            }
            statsCacheWatcher?.start()
        }
    }

    private func setupTimer() {
        statsPollTimer = Timer.scheduledTimer(withTimeInterval: statsPollInterval, repeats: true) { [weak self] _ in
            self?.loadStatsCache()
        }
    }

    private func loadStatsCache() {
        guard FileManager.default.fileExists(atPath: statsCachePath) else {
            DispatchQueue.main.async {
                self.lastError = "stats-cache.json not found"
            }
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: statsCachePath))
            let stats = try JSONDecoder().decode(StatsCache.self, from: data)

            DispatchQueue.main.async { [weak self] in
                self?.processStatsCache(stats)
                self?.dataLoaded = true
                self?.lastError = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.lastError = "Parse error: \(error.localizedDescription)"
            }
            print("Failed to parse stats cache: \(error)")
        }
    }

    private func processStatsCache(_ stats: StatsCache) {
        let today = formattedDate(Date())

        // Get today's activity
        if let dailyActivity = stats.dailyActivity {
            if let todayActivity = dailyActivity.first(where: { $0.date == today }) {
                usageData.messagesCountToday = todayActivity.messageCount ?? 0
            }
        }

        // Get today's tokens
        if let dailyTokens = stats.dailyModelTokens {
            if let todayTokens = dailyTokens.first(where: { $0.date == today }) {
                let totalTokens = todayTokens.tokensByModel?.values.reduce(0, +) ?? 0
                usageData.tokensUsedToday = totalTokens
            }
        }

        // Get cumulative model usage
        if let modelUsage = stats.modelUsage {
            var totalInput = 0
            var totalOutput = 0
            var totalCacheRead = 0
            var totalCacheCreation = 0

            for (_, usage) in modelUsage {
                totalInput += usage.inputTokens ?? 0
                totalOutput += usage.outputTokens ?? 0
                totalCacheRead += usage.cacheReadInputTokens ?? 0
                totalCacheCreation += usage.cacheCreationInputTokens ?? 0
            }

            usageData.inputTokensTotal = totalInput
            usageData.outputTokensTotal = totalOutput
            usageData.cacheReadTokens = totalCacheRead
            usageData.cacheCreationTokens = totalCacheCreation
        }

        // Get totals
        usageData.totalMessages = stats.totalMessages ?? 0
        usageData.totalSessions = stats.totalSessions ?? 0
        usageData.lastUpdated = Date()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
