import SwiftUI

struct BindingView: View {
    let quota: QuotaData
    let fiveHourPace: PaceInfo?
    let sevenDayPace: PaceInfo?
    let trend: TrendInfo?
    let sparklineData: [Double]
    let dominantModel: String?
    let lastWindowPeak: Double?  // previous window's peak utilization

    private var isFiveHourBinding: Bool {
        quota.fiveHour.utilization >= quota.sevenDay.utilization
    }
    private var bindingWindow: QuotaWindow { quota.bindingWindow }
    private var nonBindingWindow: QuotaWindow {
        isFiveHourBinding ? quota.sevenDay : quota.fiveHour
    }
    private var bindingPace: PaceInfo? {
        isFiveHourBinding ? fiveHourPace : sevenDayPace
    }
    private var nonBindingPace: PaceInfo? {
        isFiveHourBinding ? sevenDayPace : fiveHourPace
    }
    private var bindingLabel: String {
        isFiveHourBinding ? "5-hour" : "7-day"
    }
    private var nonBindingLabel: String {
        isFiveHourBinding ? "7-day" : "5-hour"
    }

    // Guardian state: only speaks when there's something to say
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
        VStack(alignment: .leading, spacing: 0) {
            bindingHero

            Rectangle()
                .fill(.quaternary.opacity(0.5))
                .frame(height: 0.5)
                .padding(.vertical, 12)

            secondaryWindows
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(width: 260, alignment: .leading)
    }

    // MARK: - Hero

    private var bindingHero: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Heading
            HStack(alignment: .firstTextBaseline) {
                if bindingWindow.isLocked {
                    Text("Limit reached")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                    Spacer()
                    Text("back at \(formatTime(bindingWindow.resetsAt))")
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(.red)
                } else if let warning {
                    // Guardian speaks — verdict as heading
                    Text(warning.text)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(warning.color)
                    Spacer()
                } else {
                    // Calm — context as heading
                    HStack(spacing: 4) {
                        Text(bindingLabel)
                        if let model = dominantModel {
                            Text("\u{00B7}")
                                .foregroundStyle(.tertiary)
                            Text(model)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Insight
            if !bindingWindow.isLocked {
                bindingInsight
            }

            // Velocity
            if !bindingWindow.isLocked, let trend, abs(trend.recentDelta) >= 0.02 {
                let sign = trend.recentDelta > 0 ? "up" : "down"
                let pct = Int(abs(trend.recentDelta) * 100)
                Text("\(sign) \(pct)% in the last hour")
                    .font(.system(.caption2))
                    .foregroundStyle(abs(trend.recentDelta) >= 0.15 ? .red : abs(trend.recentDelta) >= 0.05 ? .orange : .secondary)
            }

            // Utilization: percentage + bar together
            if !bindingWindow.isLocked {
                HStack(alignment: .center, spacing: 8) {
                    Text("\(Int(bindingWindow.utilization * 100))%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    progressBar(utilization: bindingWindow.utilization, color: bindingColor, height: 8)
                }
            }

            // Sparkline
            if sparklineHasVariation {
                SparklineView(data: sparklineData, color: bindingColor)
            }

            // Context line
            HStack {
                if warning != nil {
                    // Warning: full context here (heading was the verdict)
                    Text(bindingLabel)
                        .foregroundStyle(.secondary)
                    if let model = dominantModel {
                        Text("\u{00B7} \(model)")
                            .foregroundStyle(.tertiary)
                    }
                    Text("\u{00B7} resets in \(bindingWindow.resetsInFormatted)")
                        .foregroundStyle(.tertiary)
                } else if !bindingWindow.isLocked {
                    // Calm: heading already has window label, just show reset
                    Text("resets in \(bindingWindow.resetsInFormatted)")
                        .foregroundStyle(.tertiary)
                }
                if let peak = lastWindowPeak {
                    Text("\u{00B7} last peaked \(Int(peak * 100))%")
                        .foregroundStyle(.quaternary)
                }
                Spacer()
                if !bindingWindow.isLocked {
                    Text(quota.fetchedAt, style: .time)
                        .foregroundStyle(.quaternary)
                }
            }
            .font(.system(.caption2))
        }
    }

    @ViewBuilder
    private var bindingInsight: some View {
        if let pace = bindingPace, pace.showWarning {
            Text("limit ~\(pace.limitAtFormatted)")
                .font(.system(.caption))
                .foregroundStyle(.red)
        } else if let projected = projectedAtReset(window: bindingWindow) {
            if projected >= 0.9 {
                Text("on pace for ~\(Int(projected * 100))% — tight")
                    .font(.system(.caption))
                    .foregroundStyle(.orange)
            } else if projected >= 0.7 {
                Text("on pace for ~\(Int(projected * 100))%")
                    .font(.system(.caption))
                    .foregroundStyle(.orange)
            } else if let trend, abs(trend.velocityPerHour) < 0.01 {
                Text("holding steady")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            } else if projected < 0.5 {
                Text("plenty of room")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            } else {
                Text("on pace for ~\(Int(projected * 100))%")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Secondary

    private var secondaryWindows: some View {
        VStack(alignment: .leading, spacing: 6) {
            secondaryRow(
                label: nonBindingLabel,
                content: nonBindingContent
            )

            if let sonnet = quota.sevenDaySonnet {
                secondaryRow(
                    label: "Sonnet 7d",
                    content: Text("\(Int(sonnet.utilization * 100))%")
                        .foregroundStyle(.tertiary)
                )
            }

            if quota.extraUsage.isEnabled,
               let used = quota.extraUsage.usedCredits,
               let limit = quota.extraUsage.monthlyLimit {
                secondaryRow(
                    label: "Extra",
                    content: Text(String(format: "$%.0f / $%.0f", used, limit))
                        .foregroundStyle(.tertiary)
                )
            }
        }
    }

    private func secondaryRow<C: View>(label: String, content: C) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            content
                .font(.system(.caption))
        }
    }

    @ViewBuilder
    private var nonBindingContent: some View {
        if nonBindingWindow.isLocked {
            Text("Locked \u{00B7} \(formatTime(nonBindingWindow.resetsAt))")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.red)
        } else if nonBindingWindow.utilization < 0.01 {
            Text("Fresh \u{00B7} resets \(nonBindingWindow.resetsInFormatted)")
                .foregroundStyle(.green.opacity(0.7))
        } else {
            HStack(spacing: 4) {
                Text("\(Int(nonBindingWindow.utilization * 100))%")
                    .foregroundStyle(.tertiary)
                Text("\u{00B7}")
                    .foregroundStyle(.quaternary)
                Text("resets \(nonBindingWindow.resetsInFormatted)")
                    .foregroundStyle(.quaternary)
                if let pace = nonBindingPace, pace.showWarning {
                    Text("\u{00B7} limit ~\(pace.limitAtFormatted)")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Components

    private func progressBar(utilization: Double, color: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * utilization, height))
            }
        }
        .frame(height: height)
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
        return .green
    }

    private func projectedAtReset(window: QuotaWindow) -> Double? {
        let timeToReset = window.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0, window.utilization > 0.01 else { return nil }

        // Prefer recent velocity — reflects actual current behavior
        if let trend, abs(trend.velocityPerHour) > 0.001 {
            let hoursRemaining = timeToReset / 3600
            let projected = window.utilization + (trend.velocityPerHour * hoursRemaining)
            return max(min(projected, 1.0), window.utilization)
        }

        // Fallback: linear extrapolation from window start
        let duration = quota.bindingWindowDuration
        let elapsed = duration - timeToReset
        guard elapsed > 60 else { return nil }
        let rate = window.utilization / elapsed
        return min(rate * duration, 1.0)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date())!) {
            formatter.dateFormat = "'tomorrow' h:mm a"
        } else {
            formatter.dateFormat = "EEE h:mm a"
        }
        return formatter.string(from: date)
    }
}
