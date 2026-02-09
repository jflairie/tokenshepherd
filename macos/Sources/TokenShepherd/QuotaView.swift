import SwiftUI

struct QuotaView: View {
    @ObservedObject var service: QuotaService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch service.state {
            case .loading:
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading quota...")
                        .font(.system(.body))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)

            case .error(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Error", systemImage: "exclamationmark.triangle")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 8)

            case .loaded(let quota):
                quotaContent(quota)
            }
        }
        .padding(12)
        .frame(width: 256)
    }

    @ViewBuilder
    private func quotaContent(_ quota: QuotaData) -> some View {
        Text("Claude Code Usage")
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.primary)

        windowRow(label: "5-Hour Window", window: quota.fiveHour)
        windowRow(label: "7-Day Window", window: quota.sevenDay)

        if let sonnet = quota.sevenDaySonnet {
            windowRow(label: "7-Day Sonnet", window: sonnet)
        }

        if quota.extraUsage.isEnabled {
            Divider()
            extraUsageRow(quota.extraUsage)
        }
    }

    @ViewBuilder
    private func windowRow(label: String, window: QuotaWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(window.resetsIn)
                    .font(.system(.caption2))
                    .foregroundStyle(.tertiary)
            }

            ProgressView(value: window.utilization)
                .tint(tintColor(for: window.utilization))

            Text("\(Int(window.utilization * 100))% used")
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func extraUsageRow(_ extra: ExtraUsage) -> some View {
        HStack {
            Text("Extra Usage")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if let used = extra.usedCredits, let limit = extra.monthlyLimit {
                Text(String(format: "$%.2f / $%.2f", used, limit))
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            } else {
                Text("Enabled")
                    .font(.system(.caption))
                    .foregroundStyle(.green)
            }
        }
    }

    private func tintColor(for utilization: Double) -> Color {
        if utilization >= 0.9 { return .red }
        if utilization >= 0.7 { return .orange }
        return .accentColor
    }
}
