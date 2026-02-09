import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        if data.count < 2 {
            EmptyView()
        } else {
            GeometryReader { geo in
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 1
                let range = max(maxVal - minVal, 0.001)

                let points: [CGPoint] = data.enumerated().map { i, val in
                    let x = geo.size.width * CGFloat(i) / CGFloat(data.count - 1)
                    let y = geo.size.height * (1 - CGFloat((val - minVal) / range))
                    return CGPoint(x: x, y: y)
                }

                // Area fill
                Path { path in
                    path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                    for pt in points { path.addLine(to: pt) }
                    path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.15))

                // Stroke
                Path { path in
                    path.move(to: points[0])
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(color.opacity(0.5), lineWidth: 1.5)
            }
            .frame(height: 30)
        }
    }
}
