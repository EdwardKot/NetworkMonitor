import SwiftUI

struct Sparkline: View {
    let data: [CGFloat]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let points = self.points(for: data, in: geo.size)
            
            ZStack {
                // Gradient Fill
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
                            gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.05)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Line Stroke
                if let first = points.first {
                    Path { path in
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: color.opacity(0.2), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
    
    private func points(for data: [CGFloat], in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        
        let maxVal = data.max() ?? 1
        // Avoid division by zero
        let safeMax = maxVal == 0 ? 1 : maxVal
        
        // Use a slightly wider step if data points are few, or fit to width
        let step = size.width / CGFloat(data.count - 1)
        
        return data.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * step,
                y: size.height - (value / safeMax * size.height)
            )
        }
    }
}
