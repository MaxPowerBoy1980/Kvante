import SwiftUI

struct ObjectCollectionVisualView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeObjects: Int  // Objects from previous draw steps
    let cumulativeCrossedOut: Int  // Objects crossed out in previous steps
    let cumulativeRows: Int  // Row count from the original draw step

    private var action: String { visual.action }
    private var count: Int { visual.intParam("count") ?? 0 }
    private var objectShape: String { visual.stringParam("object") ?? "circle" }
    private var rows: Int { visual.intParam("rows") ?? cumulativeRows }  // Fall back to cumulative
    private var fromEnd: Bool { visual.stringParam("from") == "end" }
    private var label: String? { visual.stringParam("label") }

    private var totalObjects: Int {
        switch action {
        case "draw", "add": return cumulativeObjects + count
        default: return cumulativeObjects
        }
    }

    private var columns: Int {
        guard rows > 0 else { return totalObjects }
        return (totalObjects + rows - 1) / rows
    }

    @State private var visibleCount = 0
    @State private var crossedOutCount = 0
    @State private var showHighlight = false
    @State private var showLabel = false

    var body: some View {
        VStack(spacing: 12) {
            // Object grid
            let cols = max(columns, 1)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<cols, id: \.self) { col in
                            let index = row * cols + col
                            if index < totalObjects {
                                objectView(at: index)
                            }
                        }
                    }
                }
            }

            // Label
            if let label, showLabel {
                Text(label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    @ViewBuilder
    private func objectView(at index: Int) -> some View {
        let isNew = index >= cumulativeObjects
        let isCrossedOut = isCrossed(at: index)
        let isHighlighted = showHighlight && !isCrossed(at: index)

        ZStack {
            Circle()
                .fill(isHighlighted ? Color.green : Color.blue)
                .frame(width: 24, height: 24)
                .opacity(objectOpacity(at: index, isNew: isNew))
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
                .animation(.spring(duration: 0.3), value: isHighlighted)

            if isCrossedOut {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .modifier(ShakeModifier(shaking: isCrossedOut))
    }

    private func objectOpacity(at index: Int, isNew: Bool) -> Double {
        if !isNew { return 1.0 }
        return index < (cumulativeObjects + visibleCount) ? 1.0 : 0.0
    }

    private func isCrossed(at index: Int) -> Bool {
        let totalCrossed = cumulativeCrossedOut + crossedOutCount
        if fromEnd {
            return index >= (totalObjects - totalCrossed)
        } else {
            return index < totalCrossed
        }
    }

    private func startAnimation() {
        switch action {
        case "draw", "add":
            for i in 1...count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    withAnimation(.spring(duration: 0.3)) { visibleCount = i }
                }
            }
        case "cross_out":
            visibleCount = 0 // All already visible
            for i in 1...count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                    withAnimation(.spring(duration: 0.2)) { crossedOutCount = i }
                }
            }
        case "highlight_remaining":
            withAnimation(.easeInOut(duration: 0.5)) { showHighlight = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring) { showLabel = true }
            }
        default: break
        }
    }
}

struct ShakeModifier: ViewModifier {
    let shaking: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: shaking) { _, isShaking in
                if isShaking {
                    withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
                        offset = 3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { offset = 0 }
                }
            }
    }
}
