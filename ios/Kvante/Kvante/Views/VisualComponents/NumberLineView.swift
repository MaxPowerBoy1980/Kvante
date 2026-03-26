import SwiftUI

struct NumberLineVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var start: Int { visual.intParam("start") ?? 0 }
    private var jumps: Int { visual.intParam("jumps") ?? 1 }
    private var size: Int { visual.intParam("size") ?? 1 }
    private var minVal: Int { visual.intParam("min") ?? 0 }
    private var maxVal: Int { visual.intParam("max") ?? (start + jumps * size + 2) }
    private var pointValue: Int { visual.intParam("value") ?? 0 }
    private var pointLabel: String { visual.stringParam("label") ?? "" }

    private var isForward: Bool { action == "jump_forward" }
    private var range: Int { max(maxVal - minVal, 1) }

    @State private var completedJumps = 0
    @State private var showPoint = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - 40
            ZStack(alignment: .leading) {
                // Base line
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: width, height: 2)
                    .offset(x: 20, y: 60)

                // Tick marks
                ForEach(tickValues, id: \.self) { val in
                    let x = xPosition(for: val, width: width)
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: 1, height: 10)
                        Text("\(val)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .offset(x: 20 + x - 0.5, y: 55)
                }

                // Jump arcs
                if action == "jump_forward" || action == "jump_backward" {
                    ForEach(0..<completedJumps, id: \.self) { i in
                        let jumpStart = isForward ? start + i * size : start - i * size
                        let jumpEnd = isForward ? jumpStart + size : jumpStart - size
                        jumpArc(from: jumpStart, to: jumpEnd, width: width, label: isForward ? "+\(size)" : "-\(size)")
                    }
                }

                // Point marker
                if action == "mark_point" && showPoint {
                    let x = xPosition(for: pointValue, width: width)
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                        .offset(x: 20 + x - 6, y: 54)
                        .transition(.scale)

                    Text(pointLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                        .offset(x: 20 + x - 6, y: 38)
                }
            }
        }
        .frame(height: 100)
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private var tickValues: [Int] {
        var vals: [Int] = [minVal, maxVal]
        if action == "jump_forward" || action == "jump_backward" {
            for i in 0...jumps {
                let val = isForward ? start + i * size : start - i * size
                if !vals.contains(val) { vals.append(val) }
            }
        }
        if action == "mark_point" && !vals.contains(pointValue) {
            vals.append(pointValue)
        }
        return vals.sorted()
    }

    private func xPosition(for value: Int, width: CGFloat) -> CGFloat {
        CGFloat(value - minVal) / CGFloat(range) * width
    }

    @ViewBuilder
    private func jumpArc(from: Int, to: Int, width: CGFloat, label: String) -> some View {
        let x1 = xPosition(for: from, width: width) + 20
        let x2 = xPosition(for: to, width: width) + 20
        let midX = (x1 + x2) / 2

        Path { path in
            path.move(to: CGPoint(x: x1, y: 55))
            path.addQuadCurve(
                to: CGPoint(x: x2, y: 55),
                control: CGPoint(x: midX, y: 20)
            )
        }
        .stroke(Color.blue, lineWidth: 2)

        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
            .position(x: midX, y: 15)
    }

    private func startAnimation() {
        switch action {
        case "jump_forward", "jump_backward":
            for i in 1...jumps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                    withAnimation(.spring(duration: 0.4)) { completedJumps = i }
                }
            }
        case "mark_point":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.4)) { showPoint = true }
            }
        default: break
        }
    }
}
