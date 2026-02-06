import SwiftUI

struct CompactView: View {
    @ObservedObject var dataService: DataService

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: Color.green.opacity(0.6), radius: 3)

            // Total tokens (abbreviated)
            if dataService.dataLoaded {
                Text(formatTokens(dataService.usageData.inputTokensTotal + dataService.usageData.outputTokensTotal))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Text("tokens")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("Loading...")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Loading indicator
            if dataService.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
                .overlay(
                    Capsule()
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
}

#Preview {
    CompactView(dataService: DataService())
        .padding()
        .background(Color.gray)
}
