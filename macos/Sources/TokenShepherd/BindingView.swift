import SwiftUI

struct BindingView: View {
    let quota: QuotaData
    let fhState: ShepherdState
    let sdState: ShepherdState
    let fhProjection: Double?
    let sdProjection: Double?
    let sparklineData: [Double]
    let sparklineElapsed: TimeInterval
    let tokenSummary: TokenSummary?

    private var fhExpired: Bool { quota.fiveHour.resetsAt.timeIntervalSinceNow <= 0 }
    private var sdExpired: Bool { quota.sevenDay.resetsAt.timeIntervalSinceNow <= 0 }
    private var bothExpired: Bool { fhExpired && sdExpired }

    private var worstState: ShepherdState {
        fhState.severity >= sdState.severity ? fhState : sdState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if bothExpired {
                expiredHero
            } else {
                dualWindowHero
            }

            if !bothExpired && sparklineHasVariation
                && !quota.fiveHour.isLocked && !quota.sevenDay.isLocked {
                SparklineView(
                    data: sparklineData,
                    color: worstState.chartColor,
                    windowDuration: sparklineElapsed,
                    windowEnd: Date()
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(width: 280, alignment: .leading)
    }

    // MARK: - Expired (both windows reset)

    @ViewBuilder
    private var expiredHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All clear")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text("Quota just reset")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
            modelLabel
        }
    }

    // MARK: - Dual Window Hero

    @ViewBuilder
    private var dualWindowHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            modelLabel

            HStack(alignment: .top, spacing: 0) {
                windowColumn(
                    label: "5h",
                    window: quota.fiveHour,
                    state: fhState,
                    projection: fhProjection,
                    expired: fhExpired
                )
                windowColumn(
                    label: "7d",
                    window: quota.sevenDay,
                    state: sdState,
                    projection: sdProjection,
                    expired: sdExpired
                )
            }
        }
    }

    @ViewBuilder
    private func windowColumn(
        label: String,
        window: QuotaWindow,
        state: ShepherdState,
        projection: Double?,
        expired: Bool
    ) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.tertiary)

            if expired {
                Text("\u{2014}")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.3))
                Text("reset")
                    .font(.system(.caption2))
                    .foregroundStyle(.secondary.opacity(0.3))
            } else if window.isLocked {
                Text("100%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.color)
                Text("LOCKED")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(state.color)
                Text("back \(formatTimeShort(window.resetsAt))")
                    .font(.system(.caption2))
                    .foregroundStyle(state.color)
            } else {
                Text("\(Int(window.utilization * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.color)

                if let proj = projection,
                   proj >= 0.7,
                   Int(proj * 100) > Int(window.utilization * 100) + 5 {
                    Text("~\(Int(proj * 100))% pace")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(projectionColor(proj))
                } else {
                    Text("\u{2014}")
                        .font(.system(.caption2))
                        .foregroundStyle(.secondary.opacity(0.3))
                }

                Text("resets \(formatTimeShort(window.resetsAt))")
                    .font(.system(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var modelLabel: some View {
        if let model = tokenSummary?.dominantModel {
            HStack(spacing: 3) {
                Image(systemName: "cpu")
                    .font(.system(.caption2))
                Text(model)
                    .font(.system(.caption2))
            }
            .foregroundStyle(.secondary)
        }
    }

    private func projectionColor(_ projection: Double) -> Color {
        if projection >= 0.9 { return .red }
        if projection >= 0.7 { return .orange }
        return .secondary
    }

    private func formatTimeShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "EEE h a"
        }
        return formatter.string(from: date)
    }

    private var sparklineHasVariation: Bool {
        guard sparklineData.count >= 2,
              let min = sparklineData.min(),
              let max = sparklineData.max() else { return false }
        return (max - min) >= 0.02
    }
}

// MARK: - Details Toggle

struct DetailsToggleView: View {
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 10)
            Text("Details")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(width: 280, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

// MARK: - Details Content (analytics)

struct DetailsContentView: View {
    let quota: QuotaData
    let tokenSummary: TokenSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Sonnet 7d (only when active)
            if let sonnet = quota.sevenDaySonnet, sonnet.utilization > 0 {
                detailRow(
                    label: "Sonnet 7d",
                    value: Text("\(Int(sonnet.utilization * 100))%")
                        .foregroundStyle(utilColor(sonnet.utilization))
                )
            }

            // Extra usage
            if quota.extraUsage.isEnabled,
               let used = quota.extraUsage.usedCredits,
               let limit = quota.extraUsage.monthlyLimit {
                detailRow(
                    label: "Extra usage",
                    value: Text(String(format: "$%.0f / $%.0f", used, limit))
                        .foregroundStyle(.secondary)
                )
            }

            // Token counts
            if let summary = tokenSummary, summary.last7Days > 0 {
                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                if summary.today > 0 {
                    detailRow(
                        label: "Today",
                        value: Text(formatTokenCount(summary.today))
                            .foregroundStyle(.secondary)
                    )
                }
                if summary.yesterday > 0 {
                    detailRow(
                        label: "Yesterday",
                        value: Text(formatTokenCount(summary.yesterday))
                            .foregroundStyle(.secondary)
                    )
                }
                detailRow(
                    label: "Last 7 days",
                    value: Text(formatTokenCount(summary.last7Days))
                        .foregroundStyle(.secondary)
                )
            }

            // Window history
            let summaries = WindowSummaryStore.read()
            let recentLocks = summaries.filter {
                $0.wasLocked && $0.closedAt > Date().addingTimeInterval(-7 * 86400)
            }
            if !recentLocks.isEmpty {
                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                detailRow(
                    label: "Locked (7d)",
                    value: Text("\(recentLocks.count)\u{00D7}")
                        .foregroundStyle(.red)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .frame(width: 280, alignment: .leading)
    }

    private func utilColor(_ util: Double) -> Color {
        if util >= 0.9 { return .red }
        if util >= 0.7 { return .orange }
        return .secondary
    }

    private func detailRow<C: View>(label: String, value: C) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            value
                .font(.system(.caption))
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM tokens", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK tokens", Double(count) / 1_000)
        }
        return "\(count) tokens"
    }
}
