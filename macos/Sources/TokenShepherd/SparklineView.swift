import SwiftUI
import Charts

struct SparklineView: View {
    let entries: [HistoryEntry]
    let keyPath: KeyPath<HistoryEntry, Double>
    let periodLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entries.isEmpty {
                Text("No history yet")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                    .frame(width: 200, height: 40)
            } else {
                Chart(entries, id: \.ts) { entry in
                    LineMark(
                        x: .value("Time", entry.ts),
                        y: .value("Usage", entry[keyPath: keyPath])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue.opacity(0.7))
                }
                .chartYScale(domain: 0...1)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 200, height: 40)
            }

            Text(periodLabel)
                .font(.system(.caption2))
                .foregroundStyle(.tertiary)
        }
        .padding(8)
    }
}
