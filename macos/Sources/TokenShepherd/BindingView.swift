import SwiftUI

struct BindingView: View {
    let quota: QuotaData
    let fiveHourPace: PaceInfo?
    let sevenDayPace: PaceInfo?
    let trend: TrendInfo?
    let sparklineData: [Double]
    let dominantModel: String?

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
            if bindingWindow.isLocked {
                // Locked
                HStack(alignment: .firstTextBaseline) {
                    Text("Limit reached")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                    Spacer()
                    Text("back at \(formatTime(bindingWindow.resetsAt))")
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(.red)
                }
            } else {
                // Projection — the hero
                projectionLine

                // Bar with small current %
                HStack(alignment: .center, spacing: 6) {
                    progressBar(utilization: bindingWindow.utilization, color: bindingColor, height: 6)
                    Text("\(Int(bindingWindow.utilization * 100))%")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .trailing)
                }

                // Sparkline
                if sparklineHasVariation {
                    SparklineView(data: sparklineData, color: bindingColor)
                }
            }
        }
    }

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
                        .foregroundStyle(projected >= 0.9 ? .orange : .primary)
                    Text("by \(formatTime(bindingWindow.resetsAt))")
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(projected >= 0.9 ? .orange : .secondary)
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
        if let model = dominantModel {
            Text(model)
                .font(.system(.caption2))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Secondary

    private var secondaryWindows: some View {
        VStack(alignment: .leading, spacing: 6) {
            secondaryRow(
                label: "resets \(formatTime(nonBindingWindow.resetsAt))",
                content: nonBindingContent
            )

            if let sonnet = quota.sevenDaySonnet, sonnet.utilization >= 0.5 {
                secondaryRow(
                    label: "Sonnet 7d",
                    content: Text("\(Int(sonnet.utilization * 100))%")
                        .foregroundStyle(sonnet.utilization >= 0.9 ? .red : .orange)
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
            Text("Locked")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.red)
        } else {
            HStack(spacing: 4) {
                Text("\(Int(nonBindingWindow.utilization * 100))%")
                    .foregroundStyle(.tertiary)
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
        if let projected = projectedAtReset(window: bindingWindow) {
            if projected >= 0.9 { return .orange }
            if projected >= 0.7 { return .orange }
        }
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

}
