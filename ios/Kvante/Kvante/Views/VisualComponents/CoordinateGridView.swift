import SwiftUI

struct CoordinateGridVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var xVal: Int { visual.intParam("x") ?? 0 }
    private var yVal: Int { visual.intParam("y") ?? 0 }
    private var pointLabel: String { visual.stringParam("label") ?? "(\(xVal), \(yVal))" }

    // Ranges default to 0-10
    private var xRange: [Int] { rangeParam("x_range") }
    private var yRange: [Int] { rangeParam("y_range") }
    private var xMin: Int { xRange.first ?? 0 }
    private var xMax: Int { xRange.last ?? 10 }
    private var yMin: Int { yRange.first ?? 0 }
    private var yMax: Int { yRange.last ?? 10 }

    private func rangeParam(_ key: String) -> [Int] {
        guard let anyCodable = visual.params[key],
              let array = anyCodable.value as? [AnyCodable] else { return [0, 10] }
        return array.compactMap { $0.value as? Int }
    }

    @State private var showGuideX = false
    @State private var showGuideY = false
    @State private var showPoint = false
    @State private var showAxes = false

    private let gridSize: CGFloat = 200

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Grid background
            Canvas { context, size in
                let stepX = size.width / CGFloat(xMax - xMin)
                let stepY = size.height / CGFloat(yMax - yMin)

                // Grid lines
                for i in 0...(xMax - xMin) {
                    let x = CGFloat(i) * stepX
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
                }
                for i in 0...(yMax - yMin) {
                    let y = size.height - CGFloat(i) * stepY
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
                }
            }
            .frame(width: gridSize, height: gridSize)
            .opacity(showAxes ? 1 : 0)

            // Axes
            if showAxes {
                // Y axis
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: 2, height: gridSize)
                // X axis
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: gridSize, height: 2)
                    .offset(y: gridSize - 2)
            }

            // Guide lines for plot_point
            if action == "plot_point" {
                let px = CGFloat(xVal - xMin) / CGFloat(xMax - xMin) * gridSize
                let py = gridSize - CGFloat(yVal - yMin) / CGFloat(yMax - yMin) * gridSize

                if showGuideX {
                    Path { path in
                        path.move(to: CGPoint(x: px, y: gridSize))
                        path.addLine(to: CGPoint(x: px, y: py))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.orange)
                }

                if showGuideY {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: py))
                        path.addLine(to: CGPoint(x: px, y: py))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.orange)
                }

                if showPoint {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                        .offset(x: px - 6, y: py - 6)

                    Text(pointLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                        .offset(x: px + 8, y: py - 16)
                }
            }
        }
        .frame(width: gridSize, height: gridSize)
        .padding(24)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func startAnimation() {
        switch action {
        case "draw_axes":
            withAnimation(.easeInOut(duration: 0.5)) { showAxes = true }
        case "plot_point":
            showAxes = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) { showGuideX = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.3)) { showGuideY = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.spring(duration: 0.3)) { showPoint = true }
            }
        case "draw_line":
            showAxes = true
            // TODO: animate line drawing between points
        default: break
        }
    }
}
