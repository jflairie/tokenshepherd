import SwiftUI

struct WindowRowView: View {
    let label: String
    let window: QuotaWindow
    let pace: PaceInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: Label + percentage
            HStack {
                Text(label)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if window.isLocked {
                    Text("Limit reached")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(window.utilization * 100))%")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(utilizationColor)
                }
            }

            // Line 2: Progress bar (hidden when locked)
            if !window.isLocked {
                ProgressView(value: window.utilization)
                    .tint(utilizationColor)
            }

            // Line 3: Reset + pace warning
            HStack {
                Text("Resets in \(window.resetsInFormatted)")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                if let pace = pace, pace.showWarning {
                    Text("Limit in \(pace.timeToLimitFormatted)")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 260)
    }

    private var utilizationColor: Color {
        if window.utilization >= 0.9 { return .red }
        if window.utilization >= 0.7 { return .orange }
        return .green
    }
}
