import SwiftUI

struct BindingView: View {
    let quota: QuotaData
    let fhState: ShepherdState
    let sdState: ShepherdState
    let fhProjection: Double?
    let sdProjection: Double?
    let tokenSummary: TokenSummary?

    private var fhExpired: Bool { quota.fiveHour.resetsAt.timeIntervalSinceNow <= 0 }
    private var sdExpired: Bool { quota.sevenDay.resetsAt.timeIntervalSinceNow <= 0 }
    private var bothExpired: Bool { fhExpired && sdExpired }

    private let labelWidth: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if bothExpired {
                expiredHero
            } else {
                heroTable
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

    // MARK: - Hero Table

    @ViewBuilder
    private var heroTable: some View {
        modelLabel

        // Header
        HStack(spacing: 0) {
            Text("")
                .frame(width: labelWidth, alignment: .leading)
            Text("5h")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
            Text("7d")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }

        // Pace row (primary signal — "will I be interrupted?")
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Pace")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: labelWidth, alignment: .leading)
            paceCell(window: quota.fiveHour, state: fhState, projection: fhProjection, expired: fhExpired)
                .frame(maxWidth: .infinity)
            paceCell(window: quota.sevenDay, state: sdState, projection: sdProjection, expired: sdExpired)
                .frame(maxWidth: .infinity)
        }

        // Now row (current utilization — grounding context)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Now")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: labelWidth, alignment: .leading)
            nowCell(window: quota.fiveHour, state: fhState, expired: fhExpired)
                .frame(maxWidth: .infinity)
            nowCell(window: quota.sevenDay, state: sdState, expired: sdExpired)
                .frame(maxWidth: .infinity)
        }

        // Resets row
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Resets")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: labelWidth, alignment: .leading)
            resetsCell(window: quota.fiveHour, state: fhState, expired: fhExpired)
                .frame(maxWidth: .infinity)
            resetsCell(window: quota.sevenDay, state: sdState, expired: sdExpired)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Cells

    @ViewBuilder
    private func paceCell(window: QuotaWindow, state: ShepherdState, projection: Double?, expired: Bool) -> some View {
        if expired || window.isLocked {
            Text("\u{2014}")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.3))
        } else if let proj = projection,
                  Int(proj * 100) > Int(window.utilization * 100) + 5 {
            Text("~\(Int(proj * 100))%")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.color)
        } else {
            Text("\u{2014}")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.3))
        }
    }

    @ViewBuilder
    private func nowCell(window: QuotaWindow, state: ShepherdState, expired: Bool) -> some View {
        if expired {
            Text("\u{2014}")
                .font(.system(.caption))
                .foregroundStyle(.secondary.opacity(0.3))
        } else if window.isLocked {
            Text("LOCKED")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(state.color)
        } else {
            Text("\(Int(window.utilization * 100))%")
                .font(.system(.caption))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func resetsCell(window: QuotaWindow, state: ShepherdState, expired: Bool) -> some View {
        if expired {
            Text("reset")
                .font(.system(.caption2))
                .foregroundStyle(.secondary.opacity(0.3))
        } else if window.isLocked {
            Text("back \(formatTimeShort(window.resetsAt))")
                .font(.system(.caption2))
                .foregroundStyle(state.color)
        } else {
            Text(formatTimeShort(window.resetsAt))
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
        }
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
