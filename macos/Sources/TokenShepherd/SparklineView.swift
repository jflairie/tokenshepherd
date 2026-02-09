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

                // Gradient area fill
                smoothAreaPath(points: points, bottomY: geo.size.height)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Smooth stroke
                smoothStrokePath(points: points)
                    .stroke(color.opacity(0.45), lineWidth: 1.5)
            }
            .frame(height: 32)
        }
    }

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
