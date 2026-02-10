import SwiftUI

struct BindingView: View {
    let quota: QuotaData
    let fiveHourPace: PaceInfo?
    let sevenDayPace: PaceInfo?
    let trend: TrendInfo?
    let sparklineData: [Double]
    let tokenSummary: TokenSummary?

    private var bindingWindow: QuotaWindow { quota.bindingWindow }
    private var bindingPace: PaceInfo? {
        isFiveHourBinding ? fiveHourPace : sevenDayPace
    }
    private var isFiveHourBinding: Bool {
        quota.fiveHour.utilization >= quota.sevenDay.utilization
    }

    private var warning: (text: String, color: Color)? {
        if let pace = bindingPace, pace.showWarning {
            return ("Heads up", .orange)
        }
        if bindingWindow.utilization >= 0.9 {
            return ("Running low", .red)
        }
        if bindingWindow.utilization >= 0.7 {
            return ("Getting warm", .orange)
        }
        if let projected = projectedAtReset(window: bindingWindow), projected >= 0.9 {
            return ("Heads up", .orange)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if bindingWindow.isLocked {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Limit reached")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.red)
                        Spacer()
                        Text("back at \(formatTime(bindingWindow.resetsAt))")
                            .font(.system(.callout, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    Text("\u{1F411}")
                        .font(.system(size: 16))
                        .scaleEffect(y: -1)
                        .opacity(0.12)
                }
            } else {
                projectionLine

                if sparklineHasVariation {
                    SparklineView(
                        data: sparklineData,
                        color: bindingColor,
                        currentLabel: "\(Int(bindingWindow.utilization * 100))%",
                        windowDuration: max(quota.bindingWindowDuration - bindingWindow.resetsAt.timeIntervalSinceNow, 0),
                        windowEnd: Date()
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(width: 260, alignment: .leading)
    }

    // MARK: - Projection

    @ViewBuilder
    private var projectionLine: some View {
        if let pace = bindingPace, pace.showWarning {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("~\(Int(bindingWindow.utilization * 100))%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.red)
                    Text("→ limit ~\(pace.limitAtFormatted)")
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(.red)
                }
                modelLabel
            }
        } else if let projected = projectedAtReset(window: bindingWindow) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("~\(Int(projected * 100))%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(projected >= 0.7 ? .orange : .primary)
                    Text("by \(formatTime(bindingWindow.resetsAt))")
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                modelLabel
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("resets \(formatTime(bindingWindow.resetsAt))")
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.secondary)
                modelLabel
            }
        }
    }

    @ViewBuilder
    private var modelLabel: some View {
        if let model = tokenSummary?.dominantModel {
            Text(model)
                .font(.system(.caption2))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private var sparklineHasVariation: Bool {
        guard sparklineData.count >= 2,
              let min = sparklineData.min(),
              let max = sparklineData.max() else { return false }
        return (max - min) >= 0.02
    }

    private var bindingColor: Color {
        if let w = warning { return w.color }
        if let projected = projectedAtReset(window: bindingWindow) {
            if projected >= 0.7 { return .orange }
        }
        return .green
    }

    private func projectedAtReset(window: QuotaWindow) -> Double? {
        let timeToReset = window.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0, window.utilization > 0.01 else { return nil }

        if let trend, abs(trend.velocityPerHour) > 0.001 {
            let hoursRemaining = timeToReset / 3600
            let projected = window.utilization + (trend.velocityPerHour * hoursRemaining)
            return max(min(projected, 1.0), window.utilization)
        }

        let duration = quota.bindingWindowDuration
        let elapsed = duration - timeToReset
        guard elapsed > 60 else { return nil }
        let rate = window.utilization / elapsed
        return min(rate * duration, 1.0)
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
        .frame(width: 260, alignment: .leading)
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
                        .foregroundStyle(sonnet.utilization >= 0.9 ? .red : sonnet.utilization >= 0.7 ? .orange : .secondary)
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

            if let proj = projectionExplanation {
                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Projection")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(proj.observation)
                        .font(.system(.caption2))
                        .foregroundStyle(.secondary)
                    Text(proj.conclusion)
                        .font(.system(.caption2))
                        .foregroundStyle(.secondary)
                }
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
        .frame(width: 260, alignment: .leading)
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
                        .foregroundStyle(window.utilization >= 0.9 ? .red : window.utilization >= 0.7 ? .orange : .secondary)
                }
            }
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
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM tokens", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK tokens", Double(count) / 1_000)
        }
        return "\(count) tokens"
    }

    // MARK: - Projection explanation

    private var projectionExplanation: (observation: String, conclusion: String)? {
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

        let elapsedStr = formatElapsed(elapsed)
        return (
            observation: "\(utilPct)% used in \(elapsedStr)",
            conclusion: "At this pace \u{2192} ~\(projPct)% at reset"
        )
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
