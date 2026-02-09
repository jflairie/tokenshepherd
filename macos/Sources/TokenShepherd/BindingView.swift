import SwiftUI

struct BindingView: View {
    let quota: QuotaData
    let fiveHourPace: PaceInfo?
    let sevenDayPace: PaceInfo?

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // === BINDING WINDOW (hero) ===
            bindingHero
                .padding(.bottom, 10)

            // === NON-BINDING WINDOW (compact) ===
            nonBindingCompact
                .padding(.bottom, 10)

            // === METADATA ===
            metadataFooter
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 260, alignment: .leading)
    }

    // MARK: - Binding hero

    private var bindingHero: some View {
        VStack(alignment: .leading, spacing: 5) {
            // % + insight
            HStack(alignment: .firstTextBaseline) {
                if bindingWindow.isLocked {
                    Text("Limit reached")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    Spacer()
                    Text("back at \(formatTime(bindingWindow.resetsAt))")
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(bindingWindow.utilization * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    bindingInsight
                }
            }

            // Bar
            if !bindingWindow.isLocked {
                progressBar(utilization: bindingWindow.utilization, color: bindingColor, height: 6)
            }

            // Label + reset
            HStack {
                Text(bindingLabel)
                    .foregroundStyle(.secondary)
                if !bindingWindow.isLocked {
                    Text("\u{00B7} \(bindingWindow.resetsInFormatted)")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(.caption2))
        }
    }

    @ViewBuilder
    private var bindingInsight: some View {
        if let pace = bindingPace, pace.showWarning {
            // Approaching limit — show projected time
            Text("~\(pace.limitAtFormatted)")
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(.red)
        } else if let projected = projectedAtReset(window: bindingWindow) {
            // Calm — show projected usage at reset
            Text("~\(Int(projected * 100))% at reset")
                .font(.system(.callout))
                .foregroundStyle(projected >= 0.8 ? .orange : .secondary)
        } else {
            Text(bindingWindow.resetsInFormatted)
                .font(.system(.callout))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Non-binding compact

    private var nonBindingCompact: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(nonBindingLabel)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                if nonBindingWindow.isLocked {
                    Text("Locked \u{00B7} \(formatTime(nonBindingWindow.resetsAt))")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(nonBindingWindow.utilization * 100))%")
                        .font(.system(.caption))
                        .foregroundStyle(.tertiary)
                    Text("\u{00B7}")
                        .foregroundStyle(.quaternary)
                    Text(nonBindingWindow.resetsInFormatted)
                        .font(.system(.caption))
                        .foregroundStyle(.quaternary)
                    if let pace = nonBindingPace, pace.showWarning {
                        Text("\u{00B7} ~\(pace.limitAtFormatted)")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
            }

            if !nonBindingWindow.isLocked {
                progressBar(utilization: nonBindingWindow.utilization, color: .green.opacity(0.4), height: 3)
            }
        }
    }

    // MARK: - Metadata footer

    private var metadataFooter: some View {
        HStack(spacing: 0) {
            if let sonnet = quota.sevenDaySonnet {
                Text("Sonnet \(Int(sonnet.utilization * 100))%")
                    .foregroundStyle(.quaternary)
                Text("  ")
            }
            if quota.extraUsage.isEnabled, let used = quota.extraUsage.usedCredits, let limit = quota.extraUsage.monthlyLimit {
                Text(String(format: "$%.0f/$%.0f", used, limit))
                    .foregroundStyle(.quaternary)
                Text("  ")
            }
            Spacer()
            Text(quota.fetchedAt, style: .time)
                .foregroundStyle(.quaternary)
        }
        .font(.system(.caption2))
    }

    // MARK: - Components

    private func progressBar(utilization: Double, color: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(geo.size.width * utilization, 2))
            }
        }
        .frame(height: height)
    }

    // MARK: - Helpers

    private var bindingColor: Color {
        if bindingWindow.utilization >= 0.9 { return .red }
        if bindingWindow.utilization >= 0.7 { return .orange }
        return .green
    }

    private func projectedAtReset(window: QuotaWindow) -> Double? {
        let timeToReset = window.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0 else { return nil }
        let duration = quota.bindingWindowDuration
        let elapsed = duration - timeToReset
        guard elapsed > 60, window.utilization > 0.01 else { return nil }
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
