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

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("~\(Int(projected * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(state.color)
                    Text("at reset \(formatTime(bindingWindow.resetsAt))")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                }

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

                    Text("\(Int(bindingWindow.utilization * 100))% now")
                        .font(.system(.caption2))
                }
                .foregroundStyle(.secondary)
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
    let bindingProjection: Double?

    private var isFiveHourBinding: Bool {
        quota.fiveHour.utilization >= quota.sevenDay.utilization
    }
    private var bindingWindow: QuotaWindow { quota.bindingWindow }
    private var nonBindingWindow: QuotaWindow {
        isFiveHourBinding ? quota.sevenDay : quota.fiveHour
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Window table
            windowTable

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
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .frame(width: 280, alignment: .leading)
    }

    // MARK: - Window Table (windows as columns, data as rows)

    private let colLabel: CGFloat = 48
    private let colShort: CGFloat = 80
    private let colLong: CGFloat = 104

    @ViewBuilder
    private var windowTable: some View {
        let fh = quota.fiveHour
        let sd = quota.sevenDay
        let fhExpired = fh.resetsAt.timeIntervalSinceNow <= 0
        let sdExpired = sd.resetsAt.timeIntervalSinceNow <= 0

        // Header
        HStack(spacing: 0) {
            Text("")
                .frame(width: colLabel, alignment: .leading)
            Text("Short")
                .frame(width: colShort, alignment: .trailing)
            Text("Long")
                .frame(width: colLong, alignment: .trailing)
        }
        .font(.system(.caption2, weight: .semibold))
        .foregroundStyle(.tertiary)

        Rectangle()
            .fill(.quaternary.opacity(0.4))
            .frame(height: 0.5)
            .padding(.vertical, 1)

        // Now
        tableRow(label: "Now") {
            cellText(fhExpired ? "reset" : fh.isLocked ? "100%" : "\(Int(fh.utilization * 100))%",
                     color: fhExpired ? Color.secondary.opacity(0.3) : fh.isLocked ? .red : utilColor(fh.utilization),
                     width: colShort)
            cellText(sdExpired ? "reset" : sd.isLocked ? "100%" : "\(Int(sd.utilization * 100))%",
                     color: sdExpired ? Color.secondary.opacity(0.3) : sd.isLocked ? .red : utilColor(sd.utilization),
                     width: colLong)
        }

        // Pace — binding window uses hero projection (rate+trend), non-binding uses rate-only
        tableRow(label: "Pace") {
            if isFiveHourBinding {
                bindingPaceCell(expired: fhExpired, width: colShort)
                paceCell(window: sd, duration: 604_800, expired: sdExpired, width: colLong)
            } else {
                paceCell(window: fh, duration: 18_000, expired: fhExpired, width: colShort)
                bindingPaceCell(expired: sdExpired, width: colLong)
            }
        }

        // Resets
        tableRow(label: "Resets") {
            cellText(fhExpired ? "done" : formatTimeShort(fh.resetsAt),
                     color: fh.isLocked ? .red : Color.secondary.opacity(0.3),
                     width: colShort)
            cellText(sdExpired ? "done" : formatTimeShort(sd.resetsAt),
                     color: sd.isLocked ? .red : Color.secondary.opacity(0.3),
                     width: colLong)
        }
    }

    private func tableRow<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: colLabel, alignment: .leading)
            content()
        }
    }

    private func cellText(_ text: String, color: Color, width: CGFloat) -> some View {
        Text(text)
            .font(.system(.caption).monospacedDigit())
            .foregroundStyle(color)
            .frame(width: width, alignment: .trailing)
    }

    @ViewBuilder
    private func bindingPaceCell(expired: Bool, width: CGFloat) -> some View {
        if expired {
            cellText("—", color: Color.secondary.opacity(0.3), width: width)
        } else if let proj = bindingProjection {
            cellText("~\(Int(proj * 100))%", color: utilColor(proj), width: width)
        } else {
            cellText("—", color: Color.secondary.opacity(0.3), width: width)
        }
    }

    @ViewBuilder
    private func paceCell(window: QuotaWindow, duration: TimeInterval, expired: Bool, width: CGFloat) -> some View {
        if expired {
            cellText("—", color: Color.secondary.opacity(0.3), width: width)
        } else if let proj = projectedUtil(for: window, duration: duration) {
            cellText("~\(Int(proj * 100))%", color: utilColor(proj), width: width)
        } else {
            cellText("—", color: Color.secondary.opacity(0.3), width: width)
        }
    }

    private func projectedUtil(for window: QuotaWindow, duration: TimeInterval) -> Double? {
        let timeToReset = window.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0, window.utilization > 0.01, !window.isLocked else { return nil }
        let elapsed = duration - timeToReset
        guard elapsed > 60 else { return nil }
        let rate = window.utilization / elapsed
        let projected = min(rate * duration, 1.0)
        guard Int(projected * 100) > Int(window.utilization * 100) + 5 else { return nil }
        return projected
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

    private func formatTimeShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "EEE h:mm a"
        }
        return formatter.string(from: date)
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
