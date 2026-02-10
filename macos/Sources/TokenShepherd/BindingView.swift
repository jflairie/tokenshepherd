import SwiftUI

struct BindingView: View {
    let quota: QuotaData
    let state: ShepherdState
    let bindingPace: PaceInfo?
    let projectedAtReset: Double?
    let trend: TrendInfo?
    let sparklineData: [Double]
    let tokenSummary: TokenSummary?

    private var bindingWindow: QuotaWindow { quota.bindingWindow }
    private var isFiveHourBinding: Bool {
        quota.fiveHour.utilization >= quota.sevenDay.utilization
    }

    private var windowExpired: Bool {
        bindingWindow.resetsAt.timeIntervalSinceNow <= 0
    }

    private var showsProjection: Bool {
        guard !windowExpired, let projected = projectedAtReset else { return false }
        return projected >= 0.7
            && Int(projected * 100) > Int(bindingWindow.utilization * 100) + 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            heroSection

            if !windowExpired && !bindingWindow.isLocked && sparklineHasVariation {
                SparklineView(
                    data: sparklineData,
                    color: state.chartColor,
                    windowDuration: max(quota.bindingWindowDuration - bindingWindow.resetsAt.timeIntervalSinceNow, 0),
                    windowEnd: Date()
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(width: 280, alignment: .leading)
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        if windowExpired {
            // Window ended — no stale numbers, just the answer: you're fine
            VStack(alignment: .leading, spacing: 4) {
                Text("All clear")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Quota just reset")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                modelLabel
            }
        } else if bindingWindow.isLocked {
            VStack(alignment: .leading, spacing: 4) {
                Text("LIMIT REACHED")
                    .font(.system(.caption, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(state.color)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                    Text("back at \(formatTime(bindingWindow.resetsAt))")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(state.color)
            }
        } else if showsProjection, let projected = projectedAtReset {
            // Projection drives the hero — show where you're heading
            VStack(alignment: .leading, spacing: 4) {
                Text("AT THIS PACE")
                    .font(.system(.caption, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)

                Text("~\(Int(projected * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.color)

                insightLine

                contextLine
            }
        } else {
            // Current utilization — no meaningful projection
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(bindingWindow.utilization * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.color)

                contextLine
            }
        }
    }

    /// Grounds the user: current state + limit warning when applicable
    @ViewBuilder
    private var insightLine: some View {
        let currentPct = Int(bindingWindow.utilization * 100)
        if let pace = bindingPace, pace.showWarning {
            Text("\(currentPct)% now \u{00B7} limit ~\(pace.limitAtFormatted)")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            Text("\(currentPct)% now")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

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

    @ViewBuilder
    private var contextLine: some View {
        HStack(spacing: 4) {
            if let model = tokenSummary?.dominantModel {
                HStack(spacing: 3) {
                    Image(systemName: "cpu")
                        .font(.system(.caption2))
                    Text(model)
                        .font(.system(.caption2))
                }

                Text("\u{00B7}")
                    .font(.system(.caption2))
                    .foregroundStyle(.quaternary)
            }

            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(.caption2))
                Text(formatTime(bindingWindow.resetsAt))
                    .font(.system(.caption2))
            }
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

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

// MARK: - Details Content

struct DetailsContentView: View {
    let quota: QuotaData
    let fiveHourPace: PaceInfo?
    let sevenDayPace: PaceInfo?
    let tokenSummary: TokenSummary?
    let trend: TrendInfo?

    private var isFiveHourBinding: Bool {
        quota.fiveHour.utilization >= quota.sevenDay.utilization
    }
    private var bindingWindow: QuotaWindow { quota.bindingWindow }
    private var nonBindingWindow: QuotaWindow {
        isFiveHourBinding ? quota.sevenDay : quota.fiveHour
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 10) {
                windowRow(
                    label: isFiveHourBinding ? "Short window" : "Long window",
                    window: bindingWindow
                )
                windowRow(
                    label: isFiveHourBinding ? "Long window" : "Short window",
                    window: nonBindingWindow
                )
            }

            if let sonnet = quota.sevenDaySonnet, sonnet.utilization > 0 {
                detailRow(
                    label: "Sonnet 7d",
                    value: Text("\(Int(sonnet.utilization * 100))%")
                        .foregroundStyle(utilColor(sonnet.utilization))
                )
            }

            if quota.extraUsage.isEnabled,
               let used = quota.extraUsage.usedCredits,
               let limit = quota.extraUsage.monthlyLimit {
                detailRow(
                    label: "Extra usage",
                    value: Text(String(format: "$%.0f / $%.0f", used, limit))
                        .foregroundStyle(.secondary)
                )
            }

            if let paceEvidence = paceEvidence {
                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                detailRow(
                    label: "Pace",
                    value: Text(paceEvidence)
                        .foregroundStyle(.secondary)
                )
            }

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
        }
        .padding(.horizontal, 28)
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

    private func windowRow(label: String, window: QuotaWindow) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(label)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                if window.isLocked {
                    Text("Locked")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(window.utilization * 100))%")
                        .font(.system(.caption))
                        .foregroundStyle(utilColor(window.utilization))
                }
            }
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(.caption2))
                if window.isLocked {
                    Text("back \(formatTime(window.resetsAt))")
                        .font(.system(.caption2))
                        .foregroundStyle(.red)
                } else {
                    Text(formatTime(window.resetsAt))
                        .font(.system(.caption2))
                        .foregroundStyle(.quaternary)
                }
            }
            .foregroundStyle(window.isLocked ? Color.red : Color.secondary.opacity(0.3))
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

    // MARK: - Pace evidence (just the observation — hero has the conclusion)

    private var paceEvidence: String? {
        let timeToReset = bindingWindow.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0, bindingWindow.utilization > 0.01, !bindingWindow.isLocked else { return nil }

        let utilPct = Int(bindingWindow.utilization * 100)
        let duration = quota.bindingWindowDuration
        let elapsed = duration - timeToReset
        guard elapsed > 60 else { return nil }

        let projected: Double
        if let t = trend, abs(t.velocityPerHour) > 0.001 {
            let hoursRemaining = timeToReset / 3600
            projected = max(min(bindingWindow.utilization + (t.velocityPerHour * hoursRemaining), 1.0), bindingWindow.utilization)
        } else {
            let rate = bindingWindow.utilization / elapsed
            projected = min(rate * duration, 1.0)
        }

        let projPct = Int(projected * 100)
        guard projPct > utilPct else { return nil }

        return "\(utilPct)% in \(formatElapsed(elapsed))"
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let totalMin = Int(interval) / 60
        let hours = totalMin / 60
        let mins = totalMin % 60
        if hours >= 24 {
            let days = hours / 24
            let remH = hours % 24
            return remH > 0 ? "\(days)d \(remH)h" : "\(days)d"
        }
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
}
