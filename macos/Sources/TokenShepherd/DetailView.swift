import SwiftUI

struct DetailView: View {
    let quota: QuotaData
    let credentials: OAuthCredentials?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sonnet quota (if present)
            if let sonnet = quota.sevenDaySonnet {
                HStack {
                    Text("Sonnet (7-Day)")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(sonnet.utilization * 100))%")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(sonnet.utilization >= 0.9 ? .red : sonnet.utilization >= 0.7 ? .orange : .primary)
                }
                ProgressView(value: sonnet.utilization)
                    .tint(sonnet.utilization >= 0.9 ? .red : sonnet.utilization >= 0.7 ? .orange : .green)
            }

            // Extra usage
            if quota.extraUsage.isEnabled {
                HStack {
                    Text("Extra Usage")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let used = quota.extraUsage.usedCredits, let limit = quota.extraUsage.monthlyLimit {
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

            if quota.sevenDaySonnet != nil || quota.extraUsage.isEnabled {
                Divider()
            }

            // Plan tier
            if let tier = credentials?.subscriptionType {
                HStack {
                    Text("Plan")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(tier.capitalized)
                        .font(.system(.caption))
                        .foregroundStyle(.primary)
                }
            }

            // Last refreshed
            HStack {
                Text("Last refreshed")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(quota.fetchedAt, style: .time)
                    .font(.system(.caption))
                    .foregroundStyle(.primary)
            }

            // Trust note
            Text("Reads quota data only. Never consumes tokens.")
                .font(.system(.caption2))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 260)
    }
}
