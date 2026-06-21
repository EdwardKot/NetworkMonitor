import SwiftUI

struct Sparkline: View {
    let data: [CGFloat]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let points = self.points(for: data, in: geo.size)
            
            ZStack {
                if let first = points.first, let last = points.last {
                    Path { path in
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                        path.addLine(to: CGPoint(x: first.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.14), color.opacity(0.015)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                if let first = points.first {
                    Path { path in
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
    
    private func points(for data: [CGFloat], in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        
        let peak = max(data.max() ?? 0, 1)
        let scale = peak * 1.12
        let verticalInset: CGFloat = 1
        let plotHeight = max(0, size.height - verticalInset * 2)
        let step = size.width / CGFloat(data.count - 1)
        
        return data.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * step,
                y: verticalInset + plotHeight - (value / scale * plotHeight)
            )
        }
    }
}
