import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let color: Color
    let currentLabel: String?
    let windowDuration: TimeInterval?
    let windowEnd: Date?

    @State private var hoverIndex: Int?
    @State private var chartWidth: CGFloat = 1

    init(data: [Double], color: Color, currentLabel: String? = nil,
         windowDuration: TimeInterval? = nil, windowEnd: Date? = nil) {
        self.data = data
        self.color = color
        self.currentLabel = currentLabel
        self.windowDuration = windowDuration
        self.windowEnd = windowEnd
    }

    private var deltas: [Double] {
        guard data.count >= 2 else { return [] }
        var d = [Double](repeating: 0, count: data.count)
        for i in 1..<data.count {
            d[i] = max(data[i] - data[i - 1], 0)
        }
        return d
    }

    var body: some View {
        if data.count < 2 {
            EmptyView()
        } else {
            VStack(spacing: 2) {
                // Chart — clean, no text
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    let pts: [CGPoint] = data.enumerated().map { i, val in
                        CGPoint(
                            x: w * CGFloat(i) / CGFloat(data.count - 1),
                            y: h * (1 - CGFloat(min(max(val, 0), 1)))
                        )
                    }

                    let dels = deltas
                    let maxDel = dels.max() ?? 0.001
                    let barW = max(w / CGFloat(data.count) * 0.65, 3)

                    // 0) Threshold zones
                    thresholdZones(w: w, h: h)

                    // 1) Delta bars
                    if maxDel > 0 {
                        barsPath(dels: dels, maxDel: maxDel, barW: barW, w: w, h: h)
                            .fill(color.opacity(0.15))

                        if let idx = hoverIndex, idx >= 1, idx < dels.count, dels[idx] > 0 {
                            let barH = CGFloat(dels[idx] / maxDel) * h * 0.45
                            let x = w * CGFloat(idx) / CGFloat(data.count - 1)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(color.opacity(0.30))
                                .frame(width: barW, height: max(barH, 2))
                                .position(x: x, y: h - max(barH, 2) / 2)
                        }
                    }

                    // 2) Gradient area fill
                    smoothAreaPath(points: pts, bottomY: h)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.18), color.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // 3) Line stroke
                    smoothStrokePath(points: pts)
                        .stroke(color.opacity(0.45), lineWidth: 1.5)

                    // 4) Hover: vertical rule + dot. No hover: endpoint dot only.
                    if let idx = hoverIndex, idx >= 0, idx < pts.count {
                        let hx = pts[idx].x
                        Path { p in
                            p.move(to: CGPoint(x: hx, y: 0))
                            p.addLine(to: CGPoint(x: hx, y: h))
                        }
                        .stroke(color.opacity(0.25), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .position(x: hx, y: pts[idx].y)
                    } else if let last = pts.last {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .position(x: last.x, y: last.y)
                    }

                    // Capture width for hover calculation
                    Color.clear.onAppear { chartWidth = w }
                }
                .frame(height: 32)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        guard data.count > 1, chartWidth > 0 else { return }
                        let step = chartWidth / CGFloat(data.count - 1)
                        let idx = Int(round(loc.x / step))
                        hoverIndex = max(0, min(idx, data.count - 1))
                    case .ended:
                        hoverIndex = nil
                    @unknown default:
                        break
                    }
                }

                // Info bar — all text lives here
                infoBar
            }
        }
    }

    // MARK: - Info bar

    @ViewBuilder
    private var infoBar: some View {
        HStack(spacing: 0) {
            if let idx = hoverIndex, idx >= 0, idx < data.count {
                Text(richLabel(for: idx))
                    .font(.system(.caption2, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let label = currentLabel {
                Text("\(label) now")
                    .font(.system(.caption2).monospacedDigit())
                    .foregroundStyle(.quaternary)
            }
            Spacer()
        }
        .frame(height: 12)
    }

    private func richLabel(for idx: Int) -> String {
        let pct = "\(Int(data[idx] * 100))%"
        var parts = [pct]

        // Time — all buckets are real data now (no forward-fill)
        if let dur = windowDuration, let end = windowEnd, dur > 0 {
            let start = end.addingTimeInterval(-dur)
            let progress = Double(idx) / Double(data.count - 1)
            let bucketTime = start.addingTimeInterval(dur * progress)
            let secondsAgo = Date().timeIntervalSince(bucketTime)

            if secondsAgo < 90 {
                parts.append("now")
            } else {
                parts.append(formatTimeAgo(secondsAgo))
            }
        }

        // Delta (only if meaningful)
        let dels = deltas
        if idx >= 1, idx < dels.count, dels[idx] * 100 >= 0.5 {
            parts.append("+\(Int(round(dels[idx] * 100)))%")
        }

        return parts.joined(separator: " \u{00B7} ")
    }

    private func formatTimeAgo(_ seconds: TimeInterval) -> String {
        let totalMin = Int(seconds) / 60
        if totalMin < 60 { return "\(totalMin)m ago" }
        let hours = totalMin / 60
        let mins = totalMin % 60
        if hours < 24 {
            return mins > 0 ? "\(hours)h \(mins)m ago" : "\(hours)h ago"
        }
        let days = hours / 24
        let remH = hours % 24
        return remH > 0 ? "\(days)d \(remH)h ago" : "\(days)d ago"
    }

    // MARK: - Threshold zones

    @ViewBuilder
    private func thresholdZones(w: CGFloat, h: CGFloat) -> some View {
        Path { p in p.addRect(CGRect(x: 0, y: 0, width: w, height: h * 0.1)) }
            .fill(Color.red.opacity(0.04))
        Path { p in p.addRect(CGRect(x: 0, y: h * 0.1, width: w, height: h * 0.2)) }
            .fill(Color.orange.opacity(0.03))
        Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.1))
            p.addLine(to: CGPoint(x: w, y: h * 0.1))
        }
        .stroke(Color.red.opacity(0.15), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.3))
            p.addLine(to: CGPoint(x: w, y: h * 0.3))
        }
        .stroke(Color.orange.opacity(0.12), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
    }

    // MARK: - Delta bars

    private func barsPath(dels: [Double], maxDel: Double, barW: CGFloat, w: CGFloat, h: CGFloat) -> Path {
        Path { path in
            for i in 1..<dels.count where dels[i] > 0 {
                let barH = CGFloat(dels[i] / maxDel) * h * 0.45
                let x = w * CGFloat(i) / CGFloat(data.count - 1)
                let rect = CGRect(x: x - barW / 2, y: h - barH, width: barW, height: barH)
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: 1, height: 1))
            }
        }
    }

    // MARK: - Path helpers

    private func smoothStrokePath(points: [CGPoint]) -> Path {
        Path { path in
            guard points.count >= 2 else { return }
            path.move(to: points[0])

            if points.count == 2 {
                path.addLine(to: points[1])
                return
            }

            let firstMid = midpoint(points[0], points[1])
            path.addLine(to: firstMid)

            for i in 1..<points.count - 1 {
                let mid = midpoint(points[i], points[i + 1])
                path.addQuadCurve(to: mid, control: points[i])
            }

            path.addLine(to: points.last!)
        }
    }

    private func smoothAreaPath(points: [CGPoint], bottomY: CGFloat) -> Path {
        Path { path in
            guard points.count >= 2 else { return }

            path.move(to: CGPoint(x: points[0].x, y: bottomY))
            path.addLine(to: points[0])

            if points.count == 2 {
                path.addLine(to: points[1])
            } else {
                let firstMid = midpoint(points[0], points[1])
                path.addLine(to: firstMid)

                for i in 1..<points.count - 1 {
                    let mid = midpoint(points[i], points[i + 1])
                    path.addQuadCurve(to: mid, control: points[i])
                }

                path.addLine(to: points.last!)
            }

            path.addLine(to: CGPoint(x: points.last!.x, y: bottomY))
            path.closeSubpath()
        }
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
