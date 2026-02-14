import SwiftUI
import AppKit

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
            Text("Standing by")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
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
            HStack(spacing: 2) {
                Text("Pace")
                    .font(.system(.caption2, weight: .medium))
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 8))
                    .onTapGesture {
                        NSWorkspace.shared.open(URL(string: "https://github.com/jflairie/tokenshepherd#readme")!)
                    }
            }
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
