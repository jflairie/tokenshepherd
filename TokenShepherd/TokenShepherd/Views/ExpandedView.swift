import SwiftUI

struct ExpandedView: View {
    @ObservedObject var dataService: DataService
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("TokenShepherd")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onCollapse) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Today Section
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)

                HStack(spacing: 20) {
                    // Tokens today
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tokens")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Text(formatTokens(dataService.usageData.tokensUsedToday))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    // Messages today
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Messages")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(dataService.usageData.messagesCountToday)")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // All Time Section
            VStack(alignment: .leading, spacing: 8) {
                Text("ALL TIME")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)

                // Token breakdown
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Input")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Text(formatTokens(dataService.usageData.inputTokensTotal))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Output")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Text(formatTokens(dataService.usageData.outputTokensTotal))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Est. Cost")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Text(formatCost(dataService.usageData.totalCost))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }

                // Cache stats
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Cache: \(formatTokens(dataService.usageData.cacheReadTokens)) read")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))

                    if dataService.usageData.cacheHitRatio > 0 {
                        Text("(\(Int(dataService.usageData.cacheHitRatio * 100))% hit rate)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                // Sessions and messages
                HStack {
                    Image(systemName: "message")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(dataService.usageData.totalMessages) messages")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))

                    Text("•")
                        .foregroundColor(.white.opacity(0.3))

                    Text("\(dataService.usageData.totalSessions) sessions")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Error message if any
            if let error = dataService.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.orange.opacity(0.8))
                        .lineLimit(2)
                }
            }

            // Last updated
            HStack {
                Spacer()
                Text("Updated \(formatRelativeTime(dataService.usageData.lastUpdated))")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }

    private func formatCost(_ cost: Double) -> String {
        if cost >= 1000 {
            return String(format: "$%.0f", cost)
        } else if cost >= 100 {
            return String(format: "$%.1f", cost)
        } else if cost < 0.01 {
            return "<$0.01"
        }
        return String(format: "$%.2f", cost)
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

#Preview {
    ExpandedView(dataService: DataService(), onCollapse: {})
        .padding()
        .background(Color.gray)
}
